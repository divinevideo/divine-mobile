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

    /// Per-instance forwarder pushing native diagnostics over THIS engine's
    /// global channel. `DivineVideoPlayerLog.shared.sink` is a process-wide
    /// singleton, so a second FlutterEngine (e.g. the FCM background isolate
    /// that also runs the plugin registrant) would otherwise overwrite it and
    /// route video logs to the wrong isolate. We re-assert it in `handle` —
    /// player operations only ever reach the UI engine.
    private lazy var logSink: (String, String, String) -> Void = {
        [weak self] level, message, name in
        DispatchQueue.main.async {
            self?.globalChannel?.invokeMethod(
                "onNativeLog",
                arguments: ["level": level, "message": message, "name": name]
            )
        }
    }

    private func installLogSink() {
        DivineVideoPlayerLog.shared.sink = logSink
    }

    /// Resolves the binary messenger for `registrar`, bridging the iOS
    /// `messenger()` method vs the macOS `messenger` property. Every
    /// ownership key (`register`, `create`, `detachFromEngine`) derives from
    /// this single resolution so all three always agree on the engine's
    /// identity.
    private static func messenger(
        for registrar: FlutterPluginRegistrar
    ) -> FlutterBinaryMessenger {
        #if os(iOS)
        return registrar.messenger()
        #elseif os(macOS)
        return registrar.messenger
        #endif
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = Self.messenger(for: registrar)

        // Hot restart re-calls register(with:) on the SAME engine without
        // disposing the previous run's players, leaving zombie timers /
        // display links. Scope cleanup to THIS engine (keyed on its binary
        // messenger) so a second FlutterEngine registering the plugin — the
        // FCM background isolate — never disposes another live engine's
        // players. The previous-run plugin instance can leak (retain cycle
        // with its channel), so we key on the engine's messenger, which is
        // stable across hot restart, not the plugin instance. See #5397.
        PlayerRegistry.shared.disposeForEngine(messenger)

        let globalChannel = FlutterMethodChannel(
            name: "divine_video_player",
            binaryMessenger: messenger
        )
        let plugin = DivineVideoPlayerPlugin()
        plugin.registrar = registrar
        plugin.globalChannel = globalChannel
        plugin.installLogSink()
        registrar.addMethodCallDelegate(plugin, channel: globalChannel)

        registrar.register(
            DivineVideoPlayerViewFactory(messenger: messenger),
            withId: "divine_video_player_view"
        )

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

    @objc private func appWillResignActive() {
        PlayerRegistry.shared.forAll { $0.onAppBackgrounded() }
    }

    @objc private func appDidBecomeActive() {
        PlayerRegistry.shared.forAll { $0.onAppForegrounded() }
    }

    /// Called when this plugin's `FlutterEngine` is torn down — including
    /// the teardown paths the Dart `dispose`/`disposeAll` channel never
    /// reaches (OOM reclaim of the `FlutterViewController`, `destroyContext`,
    /// multi-engine teardown). Without this, a `VideoTextureOutput`'s
    /// `CADisplayLink` (which strongly retains the output) keeps firing
    /// `textureFrameAvailable` into the freed engine shell.
    ///
    /// Scoped to this engine's own players via `disposeForEngine(_:)` so that
    /// the FCM background isolate's engine detaching does not dispose the UI
    /// engine's live players (`PlayerRegistry.shared` is process-wide).
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        DivineVideoPlayerLog.shared.info(
            "Engine detaching — disposing this engine's players",
            name: "DivineVideoPlayer.Lifecycle"
        )
        let messenger = Self.messenger(for: registrar)
        PlayerRegistry.shared.disposeForEngine(messenger)
        NotificationCenter.default.removeObserver(self)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Re-claim the shared sink in case another FlutterEngine overwrote it.
        installLogSink()
        // Methods that require no arguments are handled before the
        // args guard to avoid returning FlutterMethodNotImplemented.
        if call.method == "disposeAll" {
            DivineVideoPlayerLog.shared.info(
                "disposeAll — releasing all players",
                name: "DivineVideoPlayer.Lifecycle"
            )
            PlayerRegistry.shared.disposeAll()
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
                  let registrar = self.registrar else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "Missing player id",
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
            // Record the owning engine by its binary messenger. The plugin
            // instance whose global channel received this `create` is the
            // engine the Dart side is talking to, so its detach and its
            // hot-restart re-register dispose this player; another live
            // engine's never touches it. See #5397.
            PlayerRegistry.shared.set(instance, for: id, engine: messenger)

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

/// Global registry so that ``DivineVideoPlayerViewFactory`` can find
/// instances created during the `create` method call.
///
/// `shared` is process-wide and outlives any single `FlutterEngine`. Each
/// player records the engine that created it — keyed by the engine's binary
/// messenger identity — so a teardown or hot-restart of one engine disposes
/// only its own players via `disposeForEngine(_:)`. A blanket `disposeAll()`
/// on detach or register would otherwise free the UI engine's live players
/// when the FCM background isolate's engine detaches or registers.
/// Main-thread only, like all plugin entry points.
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
        engine messenger: FlutterBinaryMessenger
    ) {
        players[id] = instance
        engines[id] = ObjectIdentifier(messenger as AnyObject)
    }
    @discardableResult
    func remove(_ id: Int) -> DivineVideoPlayerInstance? {
        engines[id] = nil
        let instance = players.removeValue(forKey: id)
        return instance
    }
    func disposeAll() {
        players.values.forEach { $0.dispose() }
        players.removeAll()
        engines.removeAll()
    }

    /// Disposes only the players created by the engine identified by
    /// `messenger` (one `FlutterEngine`), leaving every other engine's
    /// players running. Called on engine detach and at hot-restart register
    /// so a torn-down or restarted engine cannot leave a zombie
    /// `CADisplayLink` firing `textureFrameAvailable` into its freed shell —
    /// without disposing a second live engine's players.
    func disposeForEngine(_ messenger: FlutterBinaryMessenger) {
        let engineId = ObjectIdentifier(messenger as AnyObject)
        let ownedIds = engines.compactMap { $0.value == engineId ? $0.key : nil }
        for id in ownedIds {
            remove(id)?.dispose()
        }
    }
    func forAll(_ action: (DivineVideoPlayerInstance) -> Void) {
        players.values.forEach(action)
    }
}
