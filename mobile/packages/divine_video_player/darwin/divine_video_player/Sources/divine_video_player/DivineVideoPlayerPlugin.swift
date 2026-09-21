import AVFoundation
#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import Cocoa
import FlutterMacOS
#endif

/// Entry point for the divine_video_player plugin (iOS and macOS).
///
/// Manages the lifecycle of ``DivineVideoPlayerInstance`` objects and
/// registers the platform view factory for rendering.
public class DivineVideoPlayerPlugin: NSObject, FlutterPlugin {

    /// The registrar for THIS plugin instance's engine. Per-instance rather
    /// than a process-wide static so `create` uses the messenger / texture
    /// registry of the engine that received the method call. A second
    /// FlutterEngine (e.g. the FCM background isolate that also runs the
    /// plugin registrant) registering the plugin must not repoint player
    /// creation at its own messenger. See #5397.
    private var registrar: FlutterPluginRegistrar?

    private var globalChannel: FlutterMethodChannel?

    /// Identity of the engine this instance serves, keyed by its binary
    /// messenger (stable across hot restart). Captured at `register`
    /// because `detachFromEngine(for:)` runs inside the engine's `dealloc`,
    /// where `registrar.messenger()` resolves through a weak engine
    /// reference that already reads as nil.
    private var engineId: ObjectIdentifier?

    /// Set once this engine's shell is gone or about to go. Every path that
    /// could still reach the engine afterwards checks it: the log sink
    /// below delivers asynchronously on the main queue, so an entry logged
    /// during teardown would otherwise land in `sendOnChannel:` after
    /// `destroyContext` and dereference the null shell.
    private var isEngineTornDown = false

    #if os(iOS)
    /// Identity of the `FlutterViewController` this engine renders into,
    /// captured from the registrar the first time a method call arrives.
    /// Stored as an `ObjectIdentifier` because it is compared inside that
    /// controller's `dealloc`, when every weak reference to it — including
    /// `registrar.viewController` — already reads nil. Stays nil for a
    /// headless engine, which has no controller and whose shell no
    /// controller destroys.
    private var renderingViewControllerId: ObjectIdentifier?

    /// Posted by `FlutterViewController` at the top of its `dealloc`; the
    /// engine's own observer answers it with `destroyContext`. Not in a
    /// public header, but it is the event the engine itself keys on, and
    /// missing it degrades to the engine-dealloc backstop rather than to a
    /// crash.
    private static let viewControllerWillDeallocNotification =
        Notification.Name("FlutterViewControllerWillDealloc")
    #endif

    /// Which plugin instance last installed the process-wide sink. A
    /// teardown hands the sink back only while this instance still owns
    /// it, so it never mutes a second live engine. Weak, so the record
    /// cannot keep a torn-down plugin alive.
    private static weak var logSinkOwner: DivineVideoPlayerPlugin?

    /// Per-instance forwarder pushing native diagnostics over THIS engine's
    /// global channel. `DivineVideoPlayerLog.shared.sink` is a process-wide
    /// singleton, so a second FlutterEngine (e.g. the FCM background isolate
    /// that also runs the plugin registrant) would otherwise overwrite it and
    /// route video logs to the wrong isolate. We re-assert it in `handle` —
    /// player operations only ever reach the UI engine.
    private lazy var logSink: (String, String, String) -> Void = {
        [weak self] level, message, name in
        DispatchQueue.main.async {
            guard let self, !self.isEngineTornDown else { return }
            self.globalChannel?.invokeMethod(
                "onNativeLog",
                arguments: ["level": level, "message": message, "name": name]
            )
        }
    }

    private func installLogSink() {
        DivineVideoPlayerLog.shared.sink = logSink
        Self.logSinkOwner = self
    }

    /// Resolves the binary messenger for `registrar`, bridging the iOS
    /// `messenger()` method vs the macOS `messenger` property. Every
    /// ownership key (`register`, `create`) derives from this single
    /// resolution so they always agree on the engine's identity.
    private static func messenger(
        for registrar: FlutterPluginRegistrar
    ) -> FlutterBinaryMessenger {
        #if os(iOS)
        return registrar.messenger()
        #elseif os(macOS)
        return registrar.messenger
        #endif
    }

    /// The engine's identity as the registry records it. `ObjectIdentifier`
    /// holds no strong reference, so an orphaned record never keeps a
    /// torn-down messenger alive.
    private static func engineId(
        for messenger: FlutterBinaryMessenger
    ) -> ObjectIdentifier {
        ObjectIdentifier(messenger as AnyObject)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = Self.messenger(for: registrar)
        let engineId = Self.engineId(for: messenger)

        // Hot restart re-calls register(with:) on the SAME engine without
        // disposing the previous run's players, leaving zombie timers /
        // display links. Scope cleanup to THIS engine (keyed on its binary
        // messenger) so a second FlutterEngine registering the plugin — the
        // FCM background isolate — never disposes another live engine's
        // players. The previous-run plugin instance can leak (retain cycle
        // with its channel), so we key on the engine's messenger, which is
        // stable across hot restart, not the plugin instance. See #5397.
        PlayerRegistry.shared.disposeForEngine(engineId)

        let globalChannel = FlutterMethodChannel(
            name: "divine_video_player",
            binaryMessenger: messenger
        )
        let plugin = DivineVideoPlayerPlugin()
        plugin.registrar = registrar
        plugin.engineId = engineId
        plugin.globalChannel = globalChannel
        plugin.installLogSink()
        // Flutter delivers `detachFromEngine(for:)` only to a plugin that
        // published itself (FlutterPlugin.h). Without this line the hook
        // below never runs and an engine torn down through view-controller
        // dealloc leaves its players' display links firing into the freed
        // shell. See #9342.
        registrar.publish(plugin)
        registrar.addMethodCallDelegate(plugin, channel: globalChannel)

        registrar.register(
            DivineVideoPlayerViewFactory(messenger: messenger),
            withId: "divine_video_player_view"
        )

        #if os(iOS)
        // Scene disconnect and app termination both make the view
        // controller destroy the engine's shell (`-[FlutterEngine
        // destroyContext]`) while the engine object stays alive. These are
        // the delegate callbacks UIKit sends in the same dispatch, so
        // `tearDownEngine()` disposes this engine's players before the
        // shell goes. See #9342.
        registrar.addSceneDelegate(plugin)
        registrar.addApplicationDelegate(plugin)
        // A view controller released for any other reason runs the same
        // `destroyContext` from `notifyViewControllerDeallocated`, with no
        // delegate callback ahead of it. The controller posts this
        // notification first, synchronously, so the players are gone
        // before the engine's observer destroys the shell — without
        // waiting for an engine dealloc that the app may hold off
        // indefinitely (see `detachFromEngine`).
        NotificationCenter.default.addObserver(
            plugin,
            selector: #selector(flutterViewControllerWillDealloc(_:)),
            name: Self.viewControllerWillDeallocNotification,
            object: nil
        )
        #endif

        // Observe app lifecycle to pause/resume all players.
        #if os(iOS)
        let willBackgroundNotification = UIApplication.willResignActiveNotification
        let didForegroundNotification = UIApplication.didBecomeActiveNotification
        #elseif os(macOS)
        let willBackgroundNotification = NSApplication.willResignActiveNotification
        let didForegroundNotification = NSApplication.didBecomeActiveNotification
        #endif
        NotificationCenter.default.addObserver(
            plugin,
            selector: #selector(appWillResignActive),
            name: willBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            plugin,
            selector: #selector(appDidBecomeActive),
            name: didForegroundNotification,
            object: nil
        )
    }

    /// Only this engine's players: the registry is process-wide, and after
    /// a scene reconnect the new engine's plugin instance must not re-arm
    /// frame delivery on players that belong to the torn-down engine.
    @objc private func appWillResignActive() {
        guard let engineId else { return }
        PlayerRegistry.shared.forEngine(engineId) { $0.onAppBackgrounded() }
    }

    @objc private func appDidBecomeActive() {
        guard let engineId else { return }
        PlayerRegistry.shared.forEngine(engineId) { $0.onAppForegrounded() }
    }

    /// Runs inside `-[FlutterEngine dealloc]`, which the engine delivers
    /// only because `register` published the plugin. It is the last
    /// backstop, not a hook to rely on: an app can keep the engine alive
    /// past its shell — Divine's `NostrBridgeAttestationPlugin` holds the
    /// plugin registry, which is the engine, in a static until the next
    /// engine replaces it — so the shell-destroying events above are what
    /// tear the players down in time.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        tearDownEngine()
    }

    #if os(iOS)
    /// `FlutterViewController` answers `UIApplicationWillTerminateNotification`
    /// with `destroyContext`; the plugin lifecycle delegate hands this to us
    /// from the same notification. It reaches every engine's plugin
    /// instance in the process — the registration is on the shared app
    /// delegate — hence the rendering gate.
    public func applicationWillTerminate(_ application: UIApplication) {
        tearDownIfRendering()
    }

    /// Correct only for an engine created with `allowHeadlessExecution: NO`,
    /// because only then does the controller's dealloc destroy the shell
    /// (`notifyViewControllerDeallocated`). An engine created with YES keeps
    /// its shell and just loses its owner; tearing it down here would latch
    /// a live engine, and `create` would refuse from then on. This app's
    /// storyboard controller builds its own engine with NO. It would instead
    /// adopt `FlutterAppDelegate`'s launch engine, created with YES, if
    /// anything registered plugins through the app delegate, as
    /// `GeneratedPluginRegistrant.register(with: self)` does. `FlutterEngine`
    /// exposes no getter for the flag, so this cannot check it at runtime.
    @objc private func flutterViewControllerWillDealloc(_ note: Notification) {
        guard let renderingViewControllerId,
              let controller = note.object as AnyObject?,
              ObjectIdentifier(controller) == renderingViewControllerId
        else { return }
        tearDownEngine()
    }

    /// Only an engine that renders into a `FlutterViewController` has its
    /// shell destroyed by the scene and application events: a headless
    /// engine (the notification isolate runs one) keeps its shell, so
    /// tearing it down would strand the players it may create later and
    /// skip `unregisterTexture` against a registry that is still alive.
    private func tearDownIfRendering() {
        guard registrar?.viewController != nil else { return }
        tearDownEngine()
    }

    /// Remembers which controller this engine renders into, for the
    /// dealloc notification above. Cheap enough to run on every call; the
    /// controller is attached only after plugin registration, so `register`
    /// is too early to read it.
    private func noteRenderingViewController() {
        guard renderingViewControllerId == nil,
              let controller = registrar?.viewController
        else { return }
        renderingViewControllerId = ObjectIdentifier(controller)
    }
    #endif

    /// Disposes this engine's players without touching the engine. Called
    /// once the shell is gone or about to go, from every path that destroys
    /// it: scene disconnect, app termination, view-controller dealloc, and
    /// engine dealloc. One-way: `create` refuses afterwards. Disposal
    /// here skips `unregisterTexture` and the channel log because both
    /// dereference the shell exactly like `textureFrameAvailable:`; the
    /// messenger's handler-clearing paths are shell-guarded by the engine.
    /// Nothing may run between the shell going and this — UIKit delivers
    /// the delegate callback and the notification the view controller reacts
    /// to in one dispatch, so no display-link tick or AVFoundation callback
    /// can slip in — and after it there is no output left to deliver.
    private func tearDownEngine() {
        guard !isEngineTornDown, let engineId else { return }
        isEngineTornDown = true
        NotificationCenter.default.removeObserver(self)
        DivineVideoPlayerLog.shared.info(
            "Engine tearing down — disposing this engine's players",
            name: "DivineVideoPlayer.Lifecycle"
        )
        // `logSink` drops every entry once `isEngineTornDown` is set, and
        // the sink it is installed on is process-wide. Leaving this
        // instance's closure in place would mute native video logging for
        // every OTHER live engine until one of them next handled a method
        // call and re-claimed it. Hand it back, but only while this
        // instance is still the installer.
        if Self.logSinkOwner === self {
            DivineVideoPlayerLog.shared.sink = nil
            Self.logSinkOwner = nil
        }
        PlayerRegistry.shared.disposeForEngine(engineId, engineTearingDown: true)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Re-claim the shared sink in case another FlutterEngine overwrote it.
        installLogSink()
        #if os(iOS)
        noteRenderingViewController()
        #endif
        if call.method == "getDiagnostics" {
            result(PlayerRegistry.shared.diagnostics())
            return
        }
        // Methods that require no arguments are handled before the
        // args guard to avoid returning FlutterMethodNotImplemented.
        if call.method == "disposeAll" {
            DivineVideoPlayerLog.shared.info(
                "disposeAll — releasing this engine's players",
                name: "DivineVideoPlayer.Lifecycle"
            )
            // Dart asks for the players of the engine it runs in; another
            // live engine's players are not its to release.
            if let engineId {
                PlayerRegistry.shared.disposeForEngine(engineId)
            }
            result(nil)
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            result(FlutterMethodNotImplemented)
            return
        }

        switch call.method {
        case "create":
            guard let id = args["id"] as? Int,
                  let registrar = self.registrar,
                  let engineId else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "Missing player id or engine registration",
                        details: nil
                    )
                )
                return
            }
            // The teardown is one-way: its observers are gone and it will
            // not run again, so a player created now would be the zombie
            // the teardown exists to prevent. The shell is going anyway.
            guard !isEngineTornDown else {
                result(
                    FlutterError(
                        code: "ENGINE_TORN_DOWN",
                        message: "The Flutter engine is shutting down",
                        details: nil
                    )
                )
                return
            }
            // Dispose any existing player with the same ID before
            // creating the new one to avoid leaking zombie players.
            PlayerRegistry.shared.remove(id)?.dispose()

            let messenger = Self.messenger(for: registrar)
            let debugLabel = args["debugLabel"] as? String
            let instance = DivineVideoPlayerInstance(
                messenger: messenger,
                playerId: id,
                debugLabel: debugLabel
            )
            // Record the owning engine using the key captured at register,
            // not a second resolution through the registrar. The plugin
            // instance whose global channel received this `create` is the
            // engine the Dart side is talking to, so its teardown and its
            // hot-restart re-register dispose this player; another live
            // engine's never touches it. See #5397. Re-deriving here would
            // give the filing key and every sweeping key two independent
            // derivations, and `registrar.messenger()` reads through a weak
            // engine reference that can already be nil.
            PlayerRegistry.shared.set(
                instance,
                for: id,
                engine: engineId
            )

            let useTexture = args["useTexture"] as? Bool ?? false
            let logTarget = debugLabel.map { "Player \(id) (\($0))" }
                ?? "Player \(id)"
            DivineVideoPlayerLog.shared.info(
                "\(logTarget) created (useTexture=\(useTexture))",
                name: "DivineVideoPlayer.Lifecycle"
            )
            if useTexture {
                #if os(iOS)
                let textures = registrar.textures()
                #elseif os(macOS)
                let textures = registrar.textures
                #endif
                let textureId = instance.enableTextureOutput(
                    registry: textures
                )
                result(["textureId": textureId])
            } else {
                result(nil)
            }

        case "dispose":
            guard let id = args["id"] as? Int else {
                result(nil)
                return
            }
            DivineVideoPlayerLog.shared.info(
                "Player \(id) disposed",
                name: "DivineVideoPlayer.Lifecycle"
            )
            PlayerRegistry.shared.remove(id)?.dispose()
            result(nil)

        case "preload":
            let clips = args["clips"] as? [[String: Any]] ?? []
            Self.handlePreload(clips: clips, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Best-effort preload of video metadata by loading `AVURLAsset`
    /// properties asynchronously before a real player requests them.
    ///
    /// There is no disk cache behind this on Apple platforms: AVFoundation
    /// loads media through its own stack and never consults `URLCache`, so
    /// the plugin deliberately configures none. Playback caching is the
    /// app's job (the Dart-side media cache hands the player local files).
    /// The temporary asset is discarded when its task finishes, so this does
    /// not promise that metadata remains warm for a later player.
    private static func handlePreload(
        clips: [[String: Any]],
        result: @escaping FlutterResult
    ) {
        guard !clips.isEmpty else {
            result(nil)
            return
        }

        let group = DispatchGroup()

        for clipMap in clips {
            guard let uri = clipMap["uri"] as? String else { continue }

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                continue
            }

            group.enter()
            let asset = AVURLAsset(url: url)
            Task {
                _ = try? await asset.load(.duration, .tracks)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            result(nil)
        }
    }
}

#if os(iOS)
extension DivineVideoPlayerPlugin: FlutterSceneLifeCycleDelegate {
    /// UIKit disconnects the scene when the user swipes the app away in the
    /// switcher, or to reclaim a backgrounded app's memory; the process
    /// survives either. `FlutterViewController` answers the matching
    /// `UISceneDidDisconnectNotification` with `destroyContext`.
    ///
    /// The engine registers every plugin instance with the single scene,
    /// headless ones included, so this mirrors the controller's own
    /// `shouldHandleSceneNotification:`: no controller, no shell teardown;
    /// a controller whose window sits in another scene is not the one
    /// going away; a controller whose window is already detached is.
    public func sceneDidDisconnect(_ scene: UIScene) {
        guard let controller = registrar?.viewController else { return }
        if let windowScene = controller.viewIfLoaded?.window?.windowScene,
           windowScene !== scene {
            return
        }
        tearDownEngine()
    }
}
#endif

/// Global registry so that ``DivineVideoPlayerViewFactory`` can find
/// instances created during the `create` method call.
///
/// `shared` is process-wide and outlives any single `FlutterEngine`. Each
/// player records the engine that created it — keyed by the engine's binary
/// messenger identity — so every operation a plugin instance performs
/// (teardown, hot-restart re-register, Dart's `disposeAll`, the app
/// lifecycle notifications) reaches only that engine's players. A blanket
/// sweep would otherwise free — or re-arm — the players of another engine:
/// the FCM background isolate's, or the torn-down engine's after a scene
/// reconnect. Main-thread only, like all plugin entry points.
final class PlayerRegistry {
    static let shared = PlayerRegistry()
    private var players: [Int: DivineVideoPlayerInstance] = [:]
    /// Owning engine per player id, keyed by the engine's binary messenger
    /// identity. The messenger is a stable singleton for the life of a
    /// `FlutterEngine` and survives that engine's hot restart, so it
    /// identifies the engine even when the previous-run plugin instance
    /// leaks. `ObjectIdentifier` holds no strong reference, so an orphaned
    /// record never keeps a torn-down messenger alive.
    private var engines: [Int: ObjectIdentifier] = [:]
    private init() {}

    func get(_ id: Int) -> DivineVideoPlayerInstance? { players[id] }
    func set(
        _ instance: DivineVideoPlayerInstance,
        for id: Int,
        engine engineId: ObjectIdentifier
    ) {
        players[id] = instance
        PlaybackDiagnostics.shared.track(instance)
        engines[id] = engineId
    }
    @discardableResult
    func remove(_ id: Int) -> DivineVideoPlayerInstance? {
        engines[id] = nil
        let instance = players.removeValue(forKey: id)
        return instance
    }

    /// Disposes only the players created by the engine identified by
    /// `engineId` (one `FlutterEngine`), leaving every other engine's
    /// players running. With `engineTearingDown` the engine's shell is being
    /// destroyed, so the players are released without calling into it.
    func disposeForEngine(
        _ engineId: ObjectIdentifier,
        engineTearingDown: Bool = false
    ) {
        for id in ownedIds(of: engineId) {
            remove(id)?.dispose(engineTearingDown: engineTearingDown)
        }
    }

    func forEngine(
        _ engineId: ObjectIdentifier,
        _ action: (DivineVideoPlayerInstance) -> Void
    ) {
        for id in ownedIds(of: engineId) {
            if let instance = players[id] {
                action(instance)
            }
        }
    }

    private func ownedIds(of engineId: ObjectIdentifier) -> [Int] {
        engines.compactMap { $0.value == engineId ? $0.key : nil }
    }

    func diagnostics() -> [String: Any] {
        PlaybackDiagnostics.shared.snapshot(registeredPlayers: players.count)
    }
}
