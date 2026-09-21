import XCTest
import WebKit
import background_uploader
import divine_camera
import divine_video_player
import Flutter
import LibProofMode
import ObjectivePGP
@testable import Runner

/// Native coverage for the Nostr bridge frame-attestation plugin. The plugin's
/// security guarantees rest on two pieces of native logic that the Dart-side
/// mocks cannot cover:
///
///   1. The single-instance attach/detach state machine that decides whether
///      a second sandbox WebView is allowed to overwrite an existing
///      attestation handler. If this lets a second attach silently win, the
///      previous sandbox stops receiving attested events and degrades to
///      nonce-only enforcement without any signal — exactly the failure mode
///      the structural fix in this PR is meant to prevent.
///
///   2. The WKScriptMessage → Dart event translation that determines what
///      isMainFrame value reaches Dart. If the dictionary shape regresses or
///      starts including unintended fields, downstream callers may grow
///      reliance on data the contract no longer guarantees.
///
/// Both are pure logic, extracted so they can be exercised here without a
/// real WKWebView, FlutterEngine, or Dart channel. The
/// WKUserContentController integration test below additionally proves the
/// WebKit APIs the plugin depends on (script handler add/remove + document-
/// start user script with main-frame-only) actually behave as expected on
/// the iOS version this app targets.

final class NostrBridgeAttestationPolicyTests: XCTestCase {
  func testInitialStateNoAttachment() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testAttachReturnsOkWhenNothingAttached() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertEqual(policy.attach(webViewId: 1), .ok)
    XCTAssertEqual(policy.attachedWebViewId, 1)
  }

  func testAttachIsIdempotentForSameWebViewId() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 7)
    XCTAssertEqual(policy.attach(webViewId: 7), .noOp)
    XCTAssertEqual(policy.attachedWebViewId, 7)
  }

  func testAttachRefusesDifferentWebViewIdWhileOneIsAttached() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    XCTAssertEqual(policy.attach(webViewId: 2), .alreadyAttached(existing: 1))
    XCTAssertEqual(
      policy.attachedWebViewId, 1,
      "second attach must not overwrite the existing attachment"
    )
  }

  func testDetachClearsMatchingAttachment() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 9)
    XCTAssertTrue(policy.detach(webViewId: 9))
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testDetachIsNoOpForUnattachedWebViewId() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    XCTAssertFalse(policy.detach(webViewId: 2))
    XCTAssertEqual(
      policy.attachedWebViewId, 1,
      "stale detach call must not clear the live attachment"
    )
  }

  func testDetachIsNoOpWhenNothingAttached() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertFalse(policy.detach(webViewId: 1))
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testReAttachAfterDetachSucceeds() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    _ = policy.detach(webViewId: 1)
    XCTAssertEqual(policy.attach(webViewId: 2), .ok)
    XCTAssertEqual(policy.attachedWebViewId, 2)
  }
}

final class FrameAttestingScriptMessageHandlerTests: XCTestCase {
  func testEventPayloadIncludesMessageBody() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "hello",
      isMainFrame: true
    )
    XCTAssertEqual(payload["message"] as? String, "hello")
  }

  func testEventPayloadIncludesIsMainFrameTrue() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: true
    )
    XCTAssertEqual(payload["isMainFrame"] as? Bool, true)
  }

  func testEventPayloadIncludesIsMainFrameFalse() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: false
    )
    XCTAssertEqual(payload["isMainFrame"] as? Bool, false)
  }

  func testEventPayloadHasOnlyMessageAndIsMainFrame() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: true
    )
    XCTAssertEqual(
      Set(payload.keys), ["message", "isMainFrame"],
      "payload must not leak host/port/scheme or any other origin fields — Dart only consumes message + isMainFrame"
    )
  }
}

/// Smoke test for the WebKit APIs the plugin depends on. If a future iOS SDK
/// change deprecates or alters the behaviour of `removeScriptMessageHandler`
/// or `addUserScript(_:atDocumentStart:forMainFrameOnly:)` this fails loudly.
final class WebKitContentControllerIntegrationTests: XCTestCase {
  func testHandlerSwapAndDocumentStartUserScriptInstallation() {
    let webView = WKWebView()
    let contentController = webView.configuration.userContentController
    let bridgeName = NostrBridgeAttestationPlugin.bridgeChannelName

    // Simulate the pigeon-managed handler that addJavaScriptChannel installs.
    let pigeonStub = FrameAttestingScriptMessageHandler { _ in }
    contentController.add(pigeonStub, name: bridgeName)

    // The plugin's attach path swaps it for the attesting handler.
    contentController.removeScriptMessageHandler(forName: bridgeName)
    let attesting = FrameAttestingScriptMessageHandler { _ in }
    contentController.add(attesting, name: bridgeName)

    // And installs the bootstrap script at document start, main-frame only.
    XCTAssertEqual(contentController.userScripts.count, 0)
    let userScript = WKUserScript(
      source: "void(0);",
      injectionTime: .atDocumentStart,
      forMainFrameOnly: true
    )
    contentController.addUserScript(userScript)

    XCTAssertEqual(contentController.userScripts.count, 1)
    let installed = contentController.userScripts.first
    XCTAssertEqual(installed?.injectionTime, .atDocumentStart)
    XCTAssertTrue(installed?.isForMainFrameOnly ?? false)
  }
}

/// Native coverage for the divine_camera foreground-scoping state machine that
/// fixes #6090 (a "Recording" media control lingering on the Lock Screen after
/// the app was backgrounded with the camera open).
///
/// `VolumeKeyHandler`'s claim/release of the iOS "Now Playing" session is
/// entangled with `UIApplication` and `MediaPlayer` singletons and cannot be
/// exercised from a unit test. The decision logic is extracted into
/// `MediaSessionScopePolicy` (pure, no UIKit/MediaPlayer) so the transitions can
/// be verified here — each case pins one edge of the table and fails loudly if
/// the foreground scoping regresses.
final class MediaSessionScopePolicyTests: XCTestCase {
  func testStartsDisabledAndInactive() {
    let policy = MediaSessionScopePolicy()
    XCTAssertFalse(policy.isEnabled)
    XCTAssertFalse(policy.isMediaSessionActive)
  }

  func testEnableWhileForegroundClaimsSession() {
    var policy = MediaSessionScopePolicy()
    XCTAssertTrue(policy.onEnable(appActive: true))
    XCTAssertTrue(policy.isEnabled)
    XCTAssertTrue(policy.isMediaSessionActive)
  }

  func testEnableWhileBackgroundedDefersClaim() {
    var policy = MediaSessionScopePolicy()
    XCTAssertFalse(
      policy.onEnable(appActive: false),
      "must not claim the session while backgrounded (#6090)"
    )
    XCTAssertTrue(policy.isEnabled)
    XCTAssertFalse(policy.isMediaSessionActive)
  }

  func testDeferredClaimHappensOnBecomeActive() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: false)
    XCTAssertTrue(policy.onBecomeActive())
    XCTAssertTrue(policy.isMediaSessionActive)
  }

  func testEnableIsIdempotent() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: true)
    XCTAssertFalse(
      policy.onEnable(appActive: true),
      "second enable while already enabled is a no-op"
    )
    XCTAssertTrue(policy.isMediaSessionActive)
  }

  func testBackgroundReleasesSessionButStaysEnabled() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: true)
    XCTAssertTrue(policy.onEnterBackground())
    XCTAssertFalse(
      policy.isMediaSessionActive,
      "released on background so no control lingers on the Lock Screen (#6090)"
    )
    XCTAssertTrue(policy.isEnabled, "still enabled — will re-claim on foreground")
  }

  func testBackgroundForegroundCycleReclaims() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: true)
    _ = policy.onEnterBackground()
    XCTAssertTrue(policy.onBecomeActive(), "re-claim on unlock")
    XCTAssertTrue(policy.isMediaSessionActive)
  }

  func testBecomeActiveIsIdempotentWhenAlreadyActive() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: true)
    XCTAssertFalse(
      policy.onBecomeActive(),
      "already active — no duplicate claim / re-suppression"
    )
    XCTAssertTrue(policy.isMediaSessionActive)
  }

  func testBecomeActiveDoesNotClaimWhenDisabled() {
    var policy = MediaSessionScopePolicy()
    XCTAssertFalse(policy.onBecomeActive())
    XCTAssertFalse(policy.isMediaSessionActive)
  }

  func testEnterBackgroundWhenInactiveIsNoOp() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: false)
    XCTAssertFalse(policy.onEnterBackground())
    XCTAssertFalse(policy.isMediaSessionActive)
  }

  func testDisableReleasesActiveSession() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: true)
    XCTAssertTrue(policy.onDisable(), "should release the claimed session")
    XCTAssertFalse(policy.isEnabled)
    XCTAssertFalse(policy.isMediaSessionActive)
  }

  func testDisableWhenInactiveDoesNotRequestRelease() {
    var policy = MediaSessionScopePolicy()
    _ = policy.onEnable(appActive: false)
    XCTAssertFalse(policy.onDisable(), "nothing to release")
    XCTAssertFalse(policy.isEnabled)
  }

  func testDisableWhenAlreadyDisabledIsNoOp() {
    var policy = MediaSessionScopePolicy()
    XCTAssertFalse(policy.onDisable())
    XCTAssertFalse(policy.isEnabled)
  }
}

/// Divine passes every ProofMode option as false (see `AppDelegate`), and the
/// network fields must then stay out of the signed proof (#9073). Upstream
/// LibProofMode records them whatever the options say, so this fails if a
/// vendor refresh drops Divine's `showMobileNetwork` gate.
final class LibProofModeNetworkFieldsTests: XCTestCase {
  private var folder: URL!
  private var originalDocumentFolder: URL?
  private var originalPgpKey: Key?

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true
    )
    // Generate the throwaway signing key here, not in the host app's
    // Documents folder.
    originalDocumentFolder = Proof.shared.defaultDocumentFolder
    originalPgpKey = Proof.shared.pgpKey
    Proof.shared.defaultDocumentFolder = folder
    Proof.shared.pgpKey = nil
  }

  override func tearDownWithError() throws {
    Proof.shared.pgpKey = originalPgpKey
    Proof.shared.defaultDocumentFolder = originalDocumentFolder
    try? FileManager.default.removeItem(at: folder)
  }

  func testDivineOptionsKeepNetworkFieldsOutOfTheSignedProof() throws {
    let item = MediaItem(mediaData: Data("clip".utf8))
    item.proofFolder = folder
    let options = ProofGenerationOptions(
      showDeviceIds: false,
      showLocation: false,
      showMobileNetwork: false,
      notarizationProviders: []
    )

    let hash = try XCTUnwrap(
      Proof.shared.getProof(for: item, force: true, options: options)
    )
    let csv = try String(
      contentsOf: folder.appendingPathComponent("\(hash).proof.csv"),
      encoding: .utf8
    )
    let header = try XCTUnwrap(csv.split(separator: "\n").first)
    let columns = Set(header.split(separator: ",").map(String.init))

    XCTAssertTrue(
      columns.contains("File Hash SHA256"),
      "the proof CSV was not written"
    )
    for field in ["IPv4", "IPv6", "Network", "NetworkType", "DataType"] {
      XCTAssertFalse(
        columns.contains(field),
        "\(field) must not enter the signed proof"
      )
    }
  }
}

/// Records what the plugin asks of its engine's texture registry, so a test
/// can assert what reaches the engine — and, on the teardown path, what must
/// not: `-[FlutterEngine unregisterTexture:]` dereferences the shell exactly
/// like `textureFrameAvailable:` does.
private final class FakeTextureRegistry: NSObject, FlutterTextureRegistry {
  private var nextId: Int64 = 1
  private(set) var registered: [Int64] = []
  private(set) var unregistered: [Int64] = []
  /// Frames pushed at the engine. This is the exact call the teardown
  /// work exists to prevent after the shell is gone, so it is recorded
  /// rather than dropped.
  private(set) var frames: [Int64] = []

  func register(_ texture: FlutterTexture) -> Int64 {
    let id = nextId
    nextId += 1
    registered.append(id)
    return id
  }

  func textureFrameAvailable(_ textureId: Int64) {
    frames.append(textureId)
  }

  func unregisterTexture(_ textureId: Int64) {
    unregistered.append(textureId)
  }
}

/// Records every send, so a test can prove a teardown path never talks to
/// the engine.
private final class FakeBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private var nextConnection: FlutterBinaryMessengerConnection = 1
  private(set) var sentChannels: [String] = []

  func send(onChannel channel: String, message: Data?) {
    sentChannels.append(channel)
  }

  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: FlutterBinaryReply?
  ) {
    sentChannels.append(channel)
  }

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    defer { nextConnection += 1 }
    return nextConnection
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

/// One fake engine: its own messenger, a record of what registration hooked,
/// and a count of how often the plugin came back for the messenger.
private final class FakePluginRegistrar: NSObject, FlutterPluginRegistrar {
  /// The one key this registrar publishes under, mirroring
  /// `-[FlutterEngine registrarForPlugin:]`.
  static let pluginKey = "BackgroundUploaderPlugin"

  let fakeMessenger = FakeBinaryMessenger()
  let fakeTextures = FakeTextureRegistry()
  private(set) var published: NSObject?
  private(set) var methodCallDelegates: [AnyObject] = []
  private(set) var sceneDelegates: [AnyObject] = []
  private(set) var applicationDelegates: [AnyObject] = []
  private(set) var messengerResolutions = 0

  /// The controller this engine renders into. Nil is a headless engine —
  /// the notification isolate's shape — whose shell no controller destroys.
  var viewController: UIViewController?

  func messenger() -> FlutterBinaryMessenger {
    messengerResolutions += 1
    return fakeMessenger
  }

  func textures() -> FlutterTextureRegistry { fakeTextures }

  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}

  func register(
    _ factory: FlutterPlatformViewFactory,
    withId factoryId: String,
    gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {}

  func publish(_ value: NSObject) { published = value }

  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
    methodCallDelegates.append(delegate)
  }

  func addApplicationDelegate(_ delegate: FlutterPlugin) {
    applicationDelegates.append(delegate)
  }

  func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {
    sceneDelegates.append(delegate)
  }

  func lookupKey(forAsset asset: String) -> String { asset }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String { asset }

  /// `-[FlutterEngineBaseRegistrar valuePublishedByPlugin:]` is a lookup in the
  /// engine-wide publication dictionary, so it answers nil for a key nothing
  /// published. Returning `published` for every key would let a test assert a
  /// publication that Flutter would not have made.
  func valuePublished(byPlugin pluginKey: String) -> NSObject? {
    pluginKey == Self.pluginKey ? published : nil
  }
}

/// `BackgroundUploadCoordinator` is process-wide and outlives every
/// `FlutterEngine`; each engine's `register` hands it a method channel that
/// only `detachFromEngine(for:)` takes back. Flutter delivers that hook solely
/// to a plugin that published itself (FlutterPlugin.h), and it runs inside
/// `-[FlutterEngine dealloc]`, where every weak reference to the engine —
/// the registrar's and the messenger relay's — already reads nil (#9342).
///
/// The host app has registered the real plugin too, so the coordinator's
/// counters include its channel: tests compare deltas, never absolutes.
final class BackgroundUploaderEngineTeardownTests: XCTestCase {
  private var registrar: FakePluginRegistrar!
  private var plugin: BackgroundUploaderPlugin!

  override func setUpWithError() throws {
    try super.setUpWithError()
    registrar = FakePluginRegistrar()
    BackgroundUploaderPlugin.register(with: registrar)
    // Resolved through the method-call delegate rather than the publication,
    // so teardown still finds the instance when publishing regresses.
    plugin = try XCTUnwrap(
      registrar.methodCallDelegates.first as? BackgroundUploaderPlugin,
      "register must install the plugin as the channel's method-call delegate"
    )
  }

  override func tearDownWithError() throws {
    // Takes the fake engine's channel back out of the process-wide
    // coordinator; idempotent, so a failing test leaves nothing behind.
    try XCTUnwrap(plugin).detachFromEngine(for: registrar)
    plugin = nil
    registrar = nil
    try super.tearDownWithError()
  }

  private func diagnostic(_ key: String) throws -> Int {
    var value: Int?
    plugin.handle(FlutterMethodCall(methodName: "diagnostics", arguments: nil)) { result in
      value = (result as? [String: Any])?[key] as? Int
    }
    return try XCTUnwrap(value, "diagnostics must answer synchronously with \(key)")
  }

  private func beginForegroundSession(_ sessionId: String) {
    plugin.handle(
      FlutterMethodCall(
        methodName: "beginForegroundSession",
        arguments: ["sessionId": sessionId]
      )
    ) { _ in }
  }

  func testRegisterPublishesTheInstanceServingTheChannel() throws {
    let published = try XCTUnwrap(
      registrar.published as? BackgroundUploaderPlugin,
      "register must publish the plugin: Flutter delivers detachFromEngine to published plugins only"
    )
    XCTAssertTrue(
      published === plugin,
      "the published object must be the instance holding this engine's channel"
    )
    XCTAssertTrue(
      registrar.applicationDelegates.contains { $0 === plugin },
      "handleEventsForBackgroundURLSession reaches the plugin only as an application delegate"
    )
    XCTAssertNil(
      registrar.valuePublished(byPlugin: "APluginThatPublishedNothing"),
      "valuePublishedByPlugin: is a keyed lookup, not a single-slot accessor"
    )
    XCTAssertTrue(
      plugin.responds(to: NSSelectorFromString("detachFromEngineForRegistrar:")),
      "dealloc dispatches the hook through respondsToSelector, not Swift"
    )
  }

  func testDetachFromEngineReleasesThisEnginesChannel() throws {
    let attached = try diagnostic("attachedChannels")

    plugin.detachFromEngine(for: registrar)

    XCTAssertEqual(try diagnostic("attachedChannels"), attached - 1)
  }

  func testDetachFromEngineClosesTheSessionsItsDartCanNoLongerEnd() throws {
    let open = try diagnostic("activeForegroundSessions")
    beginForegroundSession("runner-tests-\(UUID().uuidString)")
    XCTAssertEqual(try diagnostic("activeForegroundSessions"), open + 1)

    plugin.detachFromEngine(for: registrar)

    XCTAssertEqual(
      try diagnostic("activeForegroundSessions"), open,
      "an open session holds every later background wake until the watchdog fires"
    )
  }

  func testDetachFromEngineOffTheMainThreadStillReleasesTheChannel() throws {
    let attached = try diagnostic("attachedChannels")
    let detached = expectation(description: "detach hopped to the main queue")

    DispatchQueue.global().async {
      self.plugin.detachFromEngine(for: self.registrar)
      // Queued behind the hop detach itself enqueued, so the fulfil observes it.
      DispatchQueue.main.async { detached.fulfill() }
    }

    wait(for: [detached], timeout: 5)
    XCTAssertEqual(try diagnostic("attachedChannels"), attached - 1)
  }

  func testDetachFromEngineNeverGoesThroughTheRegistrar() throws {
    XCTAssertEqual(registrar.messengerResolutions, 1, "register resolves the messenger once")
    XCTAssertEqual(registrar.fakeMessenger.sentChannels, [])

    plugin.detachFromEngine(for: registrar)

    XCTAssertEqual(
      registrar.messengerResolutions, 1,
      "inside dealloc the registrar's weak engine reads nil; detach must not resolve the messenger"
    )
    XCTAssertEqual(
      registrar.fakeMessenger.sentChannels, [],
      "detach has nothing to tell the engine; a send would only log a dead channel"
    )
  }
}

/// `FlutterViewController` answers scene disconnect and app termination with
/// `-[FlutterEngine destroyContext]`, which frees the engine's shell while
/// the engine object, the plugin and every player stay alive; the next
/// display-link tick or AVFoundation callback then dereferenced the null
/// shell inside `textureFrameAvailable:` (#9342). The plugin's only teardown
/// hook, `detachFromEngine`, had never run: Flutter delivers it solely to a
/// plugin that published itself.
///
/// These tests pin the contract on a fake engine: registration hooks the
/// callbacks that precede each teardown and publishes the plugin, and every
/// hook releases the engine's own players — nobody else's — without calling
/// back into the engine.
final class DivineVideoPlayerEngineTeardownTests: XCTestCase {
  /// Far above any id the host app's Dart side hands out, so a test player
  /// never displaces one of the host's in the process-wide registry.
  private static let playerIdBase = Int.max - 100

  private var registrar: FakePluginRegistrar!
  private var plugin: DivineVideoPlayerPlugin!
  /// Held for the test's lifetime so the plugin sees the same controller
  /// on every call; released (and its dealloc simulated) explicitly.
  private var viewController: UIViewController!

  override func setUpWithError() throws {
    try super.setUpWithError()
    viewController = UIViewController()
    registrar = FakePluginRegistrar()
    registrar.viewController = viewController
    DivineVideoPlayerPlugin.register(with: registrar)
    plugin = try XCTUnwrap(
      registrar.published as? DivineVideoPlayerPlugin,
      "register must publish the plugin: Flutter delivers detachFromEngine to published plugins only"
    )
  }

  override func tearDown() {
    // Idempotent; releases whatever a failing test left behind.
    plugin?.detachFromEngine(for: registrar)
    plugin = nil
    registrar = nil
    viewController = nil
    super.tearDown()
  }

  /// A second engine that renders into its own controller.
  private func makeRenderingPlugin() throws -> (FakePluginRegistrar, DivineVideoPlayerPlugin) {
    let otherRegistrar = FakePluginRegistrar()
    otherRegistrar.viewController = UIViewController()
    DivineVideoPlayerPlugin.register(with: otherRegistrar)
    let otherPlugin = try XCTUnwrap(otherRegistrar.published as? DivineVideoPlayerPlugin)
    return (otherRegistrar, otherPlugin)
  }

  private func createTexturePlayer(
    _ plugin: DivineVideoPlayerPlugin,
    id: Int
  ) throws -> Int64 {
    var textureId: Int64?
    plugin.handle(
      FlutterMethodCall(
        methodName: "create",
        arguments: ["id": id, "useTexture": true]
      )
    ) { result in
      textureId = (result as? [String: Any])?["textureId"] as? Int64
    }
    return try XCTUnwrap(textureId, "create must answer synchronously with a texture id")
  }

  /// Process-wide count; the host app's own players are in it too, so
  /// tests compare deltas rather than absolute values.
  private func registeredPlayers(_ plugin: DivineVideoPlayerPlugin) throws -> Int {
    var count: Int?
    plugin.handle(FlutterMethodCall(methodName: "getDiagnostics", arguments: nil)) { result in
      count = (result as? [String: Any])?["registeredPlayers"] as? Int
    }
    return try XCTUnwrap(count)
  }

  func testRegisterHooksEveryCallbackThatPrecedesShellTeardown() {
    XCTAssertTrue(
      registrar.sceneDelegates.contains { $0 === plugin },
      "scene disconnect destroys the shell; the plugin must hear it first"
    )
    XCTAssertTrue(
      registrar.applicationDelegates.contains { $0 === plugin },
      "app termination destroys the shell; the plugin must hear it first"
    )
  }

  /// Flutter delivers both teardown hooks through `respondsToSelector:`
  /// — `FlutterPluginAppLifeCycleDelegate` for the app hook and
  /// `FlutterSceneLifeCycle` for the scene one — because each is an
  /// `@optional` protocol requirement. The tests below call them as
  /// direct Swift methods, which passes whether or not the Objective-C
  /// selector exists. Moving either into an extension that does not
  /// restate the conformance would drop the selector, both hooks would
  /// silently never fire, and #9342 would return with every other test
  /// still green. Looked up by name so a lost selector fails here
  /// instead of failing to compile.
  func testTeardownHooksAreReachableThroughObjectiveCDispatch() {
    XCTAssertTrue(
      plugin.responds(to: NSSelectorFromString("applicationWillTerminate:")),
      "the engine dispatches applicationWillTerminate: via respondsToSelector:"
    )
    XCTAssertTrue(
      plugin.responds(to: NSSelectorFromString("sceneDidDisconnect:")),
      "the engine dispatches sceneDidDisconnect: via respondsToSelector:"
    )
  }

  func testWillTerminateReleasesPlayersWithoutTouchingTheEngine() throws {
    let before = try registeredPlayers(plugin)
    let textureId = try createTexturePlayer(plugin, id: Self.playerIdBase)
    XCTAssertEqual(registrar.fakeTextures.registered, [textureId])
    XCTAssertEqual(try registeredPlayers(plugin), before + 1)

    plugin.applicationWillTerminate(UIApplication.shared)

    XCTAssertEqual(try registeredPlayers(plugin), before)
    XCTAssertEqual(
      registrar.fakeTextures.unregistered, [],
      "unregisterTexture dereferences the shell like textureFrameAvailable; teardown must not call it"
    )
  }

  func testSceneDisconnectReleasesPlayersWithoutTouchingTheEngine() throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 1)

    plugin.sceneDidDisconnect(scene)

    XCTAssertEqual(try registeredPlayers(plugin), before)
    XCTAssertEqual(registrar.fakeTextures.unregistered, [])
  }

  func testDetachFromEngineReleasesPlayersWithoutTouchingTheEngine() throws {
    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 2)

    plugin.detachFromEngine(for: registrar)

    XCTAssertEqual(try registeredPlayers(plugin), before)
    XCTAssertEqual(registrar.fakeTextures.unregistered, [])
  }

  /// `FlutterViewController` posts this at the top of its `dealloc`, and
  /// the engine's own observer answers it with `destroyContext`. It is the
  /// one shell teardown with no delegate callback ahead of it, and the
  /// engine dealloc that would otherwise back it up can be held off
  /// indefinitely by the app (`NostrBridgeAttestationPlugin.shared` keeps
  /// the engine). Every weak reference to the controller already reads nil
  /// inside its dealloc, so the plugin must match the notification's object
  /// against an identity it captured earlier.
  func testViewControllerDeallocReleasesPlayersWithoutTouchingTheEngine() throws {
    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 8)

    NotificationCenter.default.post(
      name: Notification.Name("FlutterViewControllerWillDealloc"),
      object: viewController
    )

    XCTAssertEqual(try registeredPlayers(plugin), before)
    XCTAssertEqual(registrar.fakeTextures.unregistered, [])
  }

  func testAnotherControllersDeallocLeavesPlayersAlone() throws {
    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 9)

    NotificationCenter.default.post(
      name: Notification.Name("FlutterViewControllerWillDealloc"),
      object: UIViewController()
    )

    XCTAssertEqual(
      try registeredPlayers(plugin), before + 1,
      "a controller this engine does not render into takes no shell with it"
    )
  }

  /// The engine registers every plugin instance with the single scene and
  /// the shared app delegate, so a headless engine — the notification
  /// isolate's — receives both callbacks although no controller destroys
  /// its shell. Tearing it down would strand players it creates later and
  /// skip `unregisterTexture` against a registry that is still alive.
  func testHeadlessEngineIsNotTornDownBySceneOrApplicationEvents() throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
    let headlessRegistrar = FakePluginRegistrar()
    DivineVideoPlayerPlugin.register(with: headlessRegistrar)
    let headlessPlugin = try XCTUnwrap(headlessRegistrar.published as? DivineVideoPlayerPlugin)
    defer { headlessPlugin.detachFromEngine(for: headlessRegistrar) }
    let before = try registeredPlayers(plugin)
    let id = Self.playerIdBase + 10
    let textureId = try createTexturePlayer(headlessPlugin, id: id)

    headlessPlugin.sceneDidDisconnect(scene)
    headlessPlugin.applicationWillTerminate(UIApplication.shared)

    XCTAssertEqual(try registeredPlayers(plugin), before + 1, "its shell is alive; nothing to tear down")

    headlessPlugin.handle(FlutterMethodCall(methodName: "dispose", arguments: ["id": id])) { _ in }
    XCTAssertEqual(
      headlessRegistrar.fakeTextures.unregistered, [textureId],
      "a live engine still gets its texture back"
    )
  }

  /// The teardown is one-way — its observers are gone and it never runs
  /// again — so a player created afterwards would be exactly the zombie it
  /// exists to prevent.
  func testCreateIsRefusedAfterTeardown() throws {
    plugin.applicationWillTerminate(UIApplication.shared)

    var error: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "create",
        arguments: ["id": Self.playerIdBase + 12, "useTexture": true]
      )
    ) { result in
      error = result as? FlutterError
    }

    XCTAssertEqual(error?.code, "ENGINE_TORN_DOWN")
    XCTAssertEqual(registrar.fakeTextures.registered, [], "no texture may be registered on a shell that is going")
  }

  func testDartDisposeStillUnregistersTheTexture() throws {
    let id = Self.playerIdBase + 3
    let textureId = try createTexturePlayer(plugin, id: id)

    plugin.handle(FlutterMethodCall(methodName: "dispose", arguments: ["id": id])) { _ in }

    XCTAssertEqual(
      registrar.fakeTextures.unregistered, [textureId],
      "a live engine still gets its texture back"
    )
  }

  func testTeardownLeavesAnotherEnginesPlayersAlone() throws {
    let (otherRegistrar, otherPlugin) = try makeRenderingPlugin()
    defer { otherPlugin.detachFromEngine(for: otherRegistrar) }

    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 4)
    _ = try createTexturePlayer(otherPlugin, id: Self.playerIdBase + 5)
    XCTAssertEqual(try registeredPlayers(plugin), before + 2)

    otherPlugin.applicationWillTerminate(UIApplication.shared)

    XCTAssertEqual(
      try registeredPlayers(plugin), before + 1,
      "the registry is process-wide; a torn-down engine releases only its own players"
    )
    XCTAssertEqual(registrar.fakeTextures.unregistered, [])
  }

  func testDartDisposeAllReleasesOnlyTheCallingEnginesPlayers() throws {
    let (otherRegistrar, otherPlugin) = try makeRenderingPlugin()
    defer { otherPlugin.detachFromEngine(for: otherRegistrar) }

    let before = try registeredPlayers(plugin)
    _ = try createTexturePlayer(plugin, id: Self.playerIdBase + 6)
    let otherTextureId = try createTexturePlayer(otherPlugin, id: Self.playerIdBase + 7)

    otherPlugin.handle(FlutterMethodCall(methodName: "disposeAll", arguments: nil)) { _ in }

    XCTAssertEqual(try registeredPlayers(plugin), before + 1)
    XCTAssertEqual(otherRegistrar.fakeTextures.unregistered, [otherTextureId])
    XCTAssertEqual(registrar.fakeTextures.unregistered, [])
  }
}

/// The registry iOS hands this plugin *is* the `FlutterEngine`, and the plugin
/// lives in a process-lifetime static — so a strong reference there stops
/// `-[FlutterEngine dealloc]` from ever running, and that is the only non-test
/// place Flutter dispatches `detachFromEngineForRegistrar:` (#9393). It
/// therefore disabled the hook #9381 had just published to make reachable.
/// `NostrBridgeAttestationPlugin.pluginRegistry` carries the full rationale.
final class NostrBridgeAttestationEnginePinTests: XCTestCase {
  func testSetupDoesNotRetainThePluginRegistry() {
    weak var weakRegistry: FakePluginRegistry?

    autoreleasepool {
      let registry = FakePluginRegistry()
      weakRegistry = registry
      NostrBridgeAttestationPlugin.setup(
        messenger: FakeBinaryMessenger(),
        pluginRegistry: registry
      )
      XCTAssertNotNil(
        weakRegistry,
        "positive control: the registry is observably alive while this scope holds it"
      )
    }

    XCTAssertNil(
      weakRegistry,
      """
      setup must not strongly retain the plugin registry. On iOS that registry \
      is the FlutterEngine, and the plugin's process-lifetime `shared` static \
      turns any strong reference here into a permanent one — which stops \
      -[FlutterEngine dealloc] from ever running and disables \
      detachFromEngine(for:) for every plugin in the app (#9393).
      """
    )
  }
}

/// The three-method registry protocol `FlutterEngine` itself implements.
/// Deliberately inert: the pin test needs only an object whose lifetime it can
/// observe, never a working registry.
private final class FakePluginRegistry: NSObject, FlutterPluginRegistry {
  func registrar(forPlugin pluginKey: String) -> (any FlutterPluginRegistrar)? { nil }

  func hasPlugin(_ pluginKey: String) -> Bool { false }

  func valuePublished(byPlugin pluginKey: String) -> NSObject? { nil }
}
