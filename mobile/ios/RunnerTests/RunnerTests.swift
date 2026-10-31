import XCTest
import AVFoundation
import WebKit
import background_uploader
import divine_camera
@testable import divine_video_player
import CryptoKit
import Flutter
@testable import LibProofMode
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

/// LibProofMode used to read the whole recording into memory to hash and sign
/// it, and ObjectivePGP copied it three more times, so stopping a long take
/// got the app killed (#10197). The media is now streamed; these pin that the
/// signature it writes is still the one ObjectivePGP would have written.
final class LibProofModeStreamingSignatureTests: XCTestCase {
  // Generating an RSA-3072 key takes seconds, so the tests share one.
  private static let key = KeyGenerator().generate(
    for: "noone@proofmode.witness.org", passphrase: "password"
  )

  private var folder: URL!
  private var originalDocumentFolder: URL?
  private var originalPgpKey: Key?

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true
    )
    originalDocumentFolder = Proof.shared.defaultDocumentFolder
    originalPgpKey = Proof.shared.pgpKey
    Proof.shared.defaultDocumentFolder = folder
    Proof.shared.pgpKey = Self.key
  }

  override func tearDownWithError() throws {
    Proof.shared.pgpKey = originalPgpKey
    Proof.shared.defaultDocumentFolder = originalDocumentFolder
    try? FileManager.default.removeItem(at: folder)
  }

  func testStreamedSignatureIsTheOneObjectivePGPWrites() throws {
    let media = try writeMedia()
    let reference = try ObjectivePGP.sign(
      media.data, detached: true, using: [Self.key],
      passphraseForKey: { _ in "password" }
    )

    let digest = try MediaDigest(
      reading: XCTUnwrap(InputStream(url: media.url))
    )
    let streamed = try DetachedSignature.sign(
      digest, with: Self.key, passphrase: "password",
      createdAt: creationTime(of: reference)
    )

    XCTAssertEqual(
      digest.sha256, SHA256.hash(data: media.data).hexStr.lowercased()
    )
    XCTAssertEqual(streamed, reference)
  }

  func testFileProofSignsTheFileWithoutLoadingIt() throws {
    let media = try writeMedia()
    let item = MediaItem(mediaUrl: media.url)
    let options = ProofGenerationOptions(
      showDeviceIds: false,
      showLocation: false,
      showMobileNetwork: false,
      notarizationProviders: []
    )

    let done = expectation(description: "proof generated")
    Proof.shared.process(mediaItem: item, options: options) { _ in
      done.fulfill()
    }
    wait(for: [done], timeout: 60)

    let hash = try XCTUnwrap(item.mediaItemHash)
    XCTAssertEqual(hash, SHA256.hash(data: media.data).hexStr.lowercased())
    XCTAssertNil(item.data, "the recording must not be read into memory")

    let armored = try String(
      contentsOf: folder.appendingPathComponent(hash, isDirectory: true)
        .appendingPathComponent("\(hash).asc"),
      encoding: .utf8
    )
    XCTAssertNoThrow(
      try ObjectivePGP.verify(
        media.data, withSignature: Armor.readArmored(armored),
        using: [Self.key], passphraseForKey: nil
      )
    )
  }

  /// A little over 2.5 MiB, so the digest reads it in several chunks and the
  /// last one is partial.
  private func writeMedia() throws -> (url: URL, data: Data) {
    let data = Data((0..<(5 << 19) + 7).map { UInt8(truncatingIfNeeded: $0 &* 31) })
    let url = folder.appendingPathComponent("clip.mp4")
    try data.write(to: url)
    return (url, data)
  }

  /// The creation time ObjectivePGP hashed into [signature], so the streamed
  /// one can be made at the same second and compared byte for byte.
  private func creationTime(of signature: Data) throws -> Date {
    let bytes = [UInt8](signature)
    // A new-format header with a two-octet length, then version, signature
    // type, key and hash algorithms and the hashed subpacket count.
    let subpacket = 3 + 6
    XCTAssertEqual(bytes[0], 0xC2, "a new-format signature packet")
    XCTAssertEqual(bytes[subpacket + 1], 2, "a creation-time subpacket")
    let seconds = bytes[(subpacket + 2)..<(subpacket + 6)]
      .reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    return Date(timeIntervalSince1970: TimeInterval(seconds))
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
/// the engine, and keeps the handlers the plugin installs, so a test can talk
/// to a player the way its Dart controller does.
private final class FakeBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private var nextConnection: FlutterBinaryMessengerConnection = 1
  private(set) var sentChannels: [String] = []
  private(set) var sentMessages: [(channel: String, message: Data?)] = []
  private(set) var handlers: [String: FlutterBinaryMessageHandler] = [:]

  func send(onChannel channel: String, message: Data?) {
    sentChannels.append(channel)
    sentMessages.append((channel, message))
  }

  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: FlutterBinaryReply?
  ) {
    sentChannels.append(channel)
    sentMessages.append((channel, message))
  }

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
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
  /// indefinitely by anything in the app that strongly holds the engine.
  /// Every weak reference to the controller already reads nil
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

/// A non-looping player that has played to its end has to come back from a
/// seek the way the Android one does. The editor's detached clips are exactly
/// such players, driven by seeks: on iOS they froze once they had run out,
/// because the queue player dropped the finished item and every later seek
/// failed.
final class DivineVideoPlayerPlaybackEndTests: XCTestCase {
  private static let playerId = Int.max - 50
  private static let channel = "divine_video_player/player_\(playerId)"
  private static let codec = FlutterStandardMethodCodec.sharedInstance()
  /// How long a wait may take when AVFoundation prepares an item for it. On a
  /// starved CI simulator one step of that preparation, about 1 ms otherwise,
  /// has stalled for 7 to 19 s, holding up the main thread with it.
  private static let mediaTimeout: TimeInterval = 60

  private var registrar: FakePluginRegistrar!
  private var plugin: DivineVideoPlayerPlugin!
  private var clipURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    registrar = FakePluginRegistrar()
    registrar.viewController = UIViewController()
    DivineVideoPlayerPlugin.register(with: registrar)
    plugin = try XCTUnwrap(registrar.published as? DivineVideoPlayerPlugin)
    plugin.handle(
      FlutterMethodCall(
        methodName: "create",
        arguments: ["id": Self.playerId, "useTexture": true]
      )
    ) { _ in }
    _ = try invoke("listen", on: "\(Self.channel)/events")

    clipURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("playback_end_\(UUID().uuidString).mp4")
    let clip = try XCTUnwrap(
      Data(base64Encoded: Self.clipBase64, options: .ignoreUnknownCharacters)
    )
    try clip.write(to: clipURL)
    _ = try invoke("setClips", ["clips": [["uri": clipURL.path, "startMs": 0]]])
    try waitForState("the clip loads") { $0["status"] as? String == "paused" }
  }

  override func tearDown() {
    plugin?.handle(
      FlutterMethodCall(methodName: "dispose", arguments: ["id": Self.playerId])
    ) { _ in }
    plugin?.detachFromEngine(for: registrar)
    if let clipURL { try? FileManager.default.removeItem(at: clipURL) }
    plugin = nil
    registrar = nil
    super.tearDown()
  }

  func testPausedLoadStillDeliversFirstVideoFrame() throws {
    try waitForState("the paused clip has a renderable frame") {
      $0["status"] as? String == "paused" && $0["isFirstFrameRendered"] as? Bool == true
    }
    XCTAssertFalse(registrar.fakeTextures.frames.isEmpty)
    let instance = try XCTUnwrap(PlayerRegistry.shared.get(Self.playerId))
    XCTAssertEqual(try XCTUnwrap(instance.getPlayer()).rate, 0)
  }

  func testPrerollCompletingAfterPlayDoesNotPausePlayback() throws {
    let instance = try XCTUnwrap(PlayerRegistry.shared.get(Self.playerId))
    let player = try XCTUnwrap(instance.getPlayer())
    let item = try XCTUnwrap(player.currentItem)
    _ = try invoke("play")
    XCTAssertGreaterThan(player.rate, 0)

    // Complete a paused-frame request after a newer play command, without
    // relying on decoder scheduling to happen to produce the race.
    instance.finishPausedPreroll(player, item: item, at: .zero)

    XCTAssertGreaterThan(player.rate, 0, "a stale paused-frame completion must not pause playback")
    try waitForState("the clip still plays to its end") { $0["status"] as? String == "completed" }
  }

  func testSeekFromTheEndPlaysOnWhilePlaybackIsRequested() throws {
    _ = try invoke("play")
    try waitForState("the clip plays to its end") { $0["status"] as? String == "completed" }
    let player = try XCTUnwrap(PlayerRegistry.shared.get(Self.playerId)?.getPlayer())
    let reportsBeforeSeek = registrar.fakeMessenger.sentMessages.count
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let sought = expectation(description: "seek answered")
    var rateWhenAnswered: Float = 0
    let seekSent = Date()
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in
      // Answered from the seek's completion, right after it resumes.
      rateWhenAnswered = player.rate
      sought.fulfill()
    }
    wait(for: [sought], timeout: Self.mediaTimeout)
    XCTAssertGreaterThan(rateWhenAnswered, 0, "the seek must resume playback")

    // A fresh end proves the clock ran; sampling a 1 s clip mid-play misses
    // on a starved runner.
    try waitForState("the clip plays to its end again", since: reportsBeforeSeek) {
      $0["status"] as? String == "completed"
    }
    // Playing the whole second again takes at least that long however
    // starved the runner is; an end reached from near the end would not.
    XCTAssertGreaterThan(
      Date().timeIntervalSince(seekSent), 0.8, "the seek must start the clip over"
    )
  }

  func testSeekFromTheEndStaysPausedOnceItWasPaused() throws {
    _ = try invoke("play")
    try waitForState("the clip plays to its end") { $0["status"] as? String == "completed" }
    _ = try invoke("pause")

    _ = try invoke("seekTo", ["positionMs": 0])

    try waitForState("the seek leaves the end, paused") { $0["status"] as? String == "paused" }
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "paused")
    XCTAssertEqual(state["positionMs"] as? Int, 0, "a paused seek must not start playback")
  }

  func testPauseDuringSeekFromTheEndPreventsResume() throws {
    _ = try invoke("play")
    try waitForState("the clip plays to its end") { $0["status"] as? String == "completed" }

    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let sought = expectation(description: "seek answered")
    var seekAnswered = false
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in
      seekAnswered = true
      sought.fulfill()
    }
    XCTAssertFalse(seekAnswered, "pause must precede seek completion")
    // Deliver pause before allowing the asynchronous seek completion to run.
    _ = try invoke("pause")
    wait(for: [sought], timeout: Self.mediaTimeout)

    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "paused")
    XCTAssertEqual(state["positionMs"] as? Int, 0, "a late seek must not override pause")
  }

  func testConsecutiveSeeksFromTheEndPreservePlaybackIntent() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    let player = try XCTUnwrap(PlayerRegistry.shared.get(Self.playerId)?.getPlayer())
    let reportsBeforeSeeks = registrar.fakeMessenger.sentMessages.count
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let first = expectation(description: "first seek answered")
    let second = expectation(description: "second seek answered")
    var firstAnswered = false
    var rateWhenSecondAnswered: Float = 0
    let seeksSent = Date()
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in firstAnswered = true; first.fulfill() }
    XCTAssertFalse(firstAnswered, "the seeks must overlap")
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 400]
    ))) { _ in
      rateWhenSecondAnswered = player.rate
      second.fulfill()
    }
    wait(for: [first, second], timeout: Self.mediaTimeout)
    // Playback only moves on from where the winning seek put it, so a starved
    // runner can push this later but never back below 400 ms.
    XCTAssertGreaterThanOrEqual(player.currentTime().seconds, 0.39, "the latest seek must win")
    XCTAssertGreaterThan(rateWhenSecondAnswered, 0, "the latest seek must resume playback")

    try waitForState("the clip plays to its end again", since: reportsBeforeSeeks) {
      $0["status"] as? String == "completed"
    }
    // The last 600 ms take at least that long to play however starved the
    // runner is; a seek landing past its target would end sooner.
    XCTAssertGreaterThan(
      Date().timeIntervalSince(seeksSent), 0.45, "playback must resume from 400 ms"
    )
  }

  func testStopDuringSeekFromTheEndKeepsMediaStopped() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let sought = expectation(description: "cancelled seek answered")
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in sought.fulfill() }
    _ = try invoke("stop")
    wait(for: [sought], timeout: Self.mediaTimeout)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "idle")
    XCTAssertEqual(state["clipCount"] as? Int, 0)
    // A stopped player reports nothing more, so a resume the cancelled seek
    // left behind only shows once media is loaded again: it plays at once.
    _ = try invoke("setClips", ["clips": [["uri": clipURL.path, "startMs": 0]]])
    try waitForState("the next media loads paused") { $0["status"] as? String == "paused" }
  }

  func testReplacementDuringSeekFromTheEndStaysPaused() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let sought = expectation(description: "superseded seek answered")
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in sought.fulfill() }
    _ = try invoke("setClips", ["clips": [["uri": clipURL.path, "startMs": 0]]])
    wait(for: [sought], timeout: Self.mediaTimeout)
    try waitForState("replacement loads paused") { $0["status"] as? String == "paused" }
    let loadedPosition = try XCTUnwrap(latestState()?["positionMs"] as? Int)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "paused")
    XCTAssertEqual(state["positionMs"] as? Int, loadedPosition)
  }

  func testSeekCompletingWhileInactiveDefersPlaybackUntilForeground() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    let player = try XCTUnwrap(PlayerRegistry.shared.get(Self.playerId)?.getPlayer())
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[Self.channel])
    let sought = expectation(description: "background seek answered")
    var seekAnswered = false
    handler(Self.codec.encode(FlutterMethodCall(
      methodName: "seekTo", arguments: ["positionMs": 0]
    ))) { _ in
      seekAnswered = true
      sought.fulfill()
    }
    XCTAssertFalse(seekAnswered, "the seek must complete after the app resigns active")
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    defer {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    wait(for: [sought], timeout: Self.mediaTimeout)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    // Dart hears nothing while inactive, so ask the player itself.
    XCTAssertEqual(player.rate, 0, "the seek must not play while inactive")
    XCTAssertLessThan(player.currentTime().seconds, 0.1, "the seek must land and stay at the start")

    // Becoming active resumes inside the post and reports at once. That
    // report's position is read after play() and may already be a few ms in.
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertEqual(
      latestState()?["status"] as? String, "playing", "the deferred seek must resume in foreground"
    )
    // A fresh end proves the clock ran; sampling a 1 s clip mid-play misses
    // on a starved runner.
    try waitForState("the resumed clip plays to its end") {
      $0["status"] as? String == "completed"
    }
  }

  func testPauseWhileInactiveCancelsDeferredSeekResume() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    defer {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    _ = try invoke("seekTo", ["positionMs": 0])
    _ = try invoke("pause")
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "paused")
    XCTAssertEqual(state["positionMs"] as? Int, 0)
  }

  func testStopWhileInactiveCancelsDeferredSeekResume() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    defer {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    _ = try invoke("seekTo", ["positionMs": 0])
    _ = try invoke("stop")
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(state["status"] as? String, "idle", "a stopped player must stay stopped")
    // A resume that outlived stop only shows once media is loaded again: it plays at once.
    _ = try invoke("setClips", ["clips": [["uri": clipURL.path, "startMs": 0]]])
    try waitForState("the next media loads paused") { $0["status"] as? String == "paused" }
  }

  func testReplacementWhileInactiveCancelsDeferredSeekResume() throws {
    _ = try invoke("play")
    try waitForState("the clip ends") { $0["status"] as? String == "completed" }
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    defer {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    _ = try invoke("seekTo", ["positionMs": 0])
    _ = try invoke("setClips", ["clips": [["uri": clipURL.path, "startMs": 0]]])
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let state = try XCTUnwrap(latestState())
    XCTAssertEqual(
      state["status"] as? String, "paused", "the replacement must not inherit the deferred resume"
    )
  }

  func testOrdinaryBackgroundPausePreservesExistingForegroundResume() throws {
    _ = try invoke("play")
    try waitForState("the clip is playing") { $0["status"] as? String == "playing" }
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    defer {
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    // Dart's lifecycle pause must not cancel the existing native resume policy.
    _ = try invoke("pause")
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    try waitForState("ordinary playback resumes in foreground") {
      $0["status"] as? String == "playing"
    }
  }

  func testSeekBeforeAnyMediaIsLoadedIsAnswered() throws {
    let bareId = Self.playerId - 1
    plugin.handle(
      FlutterMethodCall(methodName: "create", arguments: ["id": bareId, "useTexture": true])
    ) { _ in }
    addTeardownBlock { [plugin] in
      plugin?.handle(FlutterMethodCall(methodName: "dispose", arguments: ["id": bareId])) { _ in }
    }

    // Nothing is loaded, so there is no queue to seek; the call must still answer.
    _ = try invoke("seekTo", ["positionMs": 0], on: "divine_video_player/player_\(bareId)")
  }

  /// Calls [method] the way the Dart controller does and waits for its answer.
  @discardableResult
  private func invoke(
    _ method: String,
    _ arguments: Any? = nil,
    on channel: String = DivineVideoPlayerPlaybackEndTests.channel
  ) throws -> Any? {
    let handler = try XCTUnwrap(registrar.fakeMessenger.handlers[channel], "no handler on \(channel)")
    let answered = expectation(description: "\(method) answered")
    var answer: Any?
    handler(Self.codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))) { reply in
      answer = reply.flatMap { Self.codec.decodeEnvelope($0) }
      answered.fulfill()
    }
    wait(for: [answered], timeout: Self.mediaTimeout)
    if let error = answer as? FlutterError {
      XCTFail("\(method) failed: \(error.code) \(error.message ?? "")")
    }
    return answer
  }

  /// The last state the player sent to Dart.
  private func latestState() -> [String: Any]? {
    let events = "\(Self.channel)/events"
    return registrar.fakeMessenger.sentMessages.reversed().lazy
      .filter { $0.channel == events }
      .compactMap { $0.message.flatMap { Self.codec.decodeEnvelope($0) } as? [String: Any] }
      .first
  }

  /// The states the player sent to Dart from message [index] on, oldest first.
  private func states(since index: Int) -> [[String: Any]] {
    let events = "\(Self.channel)/events"
    return registrar.fakeMessenger.sentMessages[index...]
      .filter { $0.channel == events }
      .compactMap { $0.message.flatMap { Self.codec.decodeEnvelope($0) } as? [String: Any] }
  }

  /// Polls until the latest state matches. With [since], any state sent from
  /// that message index on counts instead, so a state from before an action
  /// cannot pass for its effect.
  private func waitForState(
    _ description: String,
    since firstMessage: Int? = nil,
    timeout: TimeInterval = DivineVideoPlayerPlaybackEndTests.mediaTimeout,
    _ matches: ([String: Any]) -> Bool
  ) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let firstMessage {
        if states(since: firstMessage).contains(where: matches) { return }
      } else if let state = latestState(), matches(state) {
        return
      }
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    throw StateTimeout(description: "timed out waiting until \(description); last state: \(latestState() ?? [:])")
  }

  private struct StateTimeout: Error, CustomStringConvertible {
    let description: String
  }

  /// A 30 fps H.264 clip of 30 grey 64×64 frames, 1 s long, as `AVAssetWriter`
  /// encodes it. Committed rather than encoded per test: encoding started a
  /// video encoder in every `setUp`, which took seconds on a busy simulator and
  /// longest on the first test of a freshly booted one.
  private static let clipBase64 = """
    AAAAHGZ0eXBtcDQyAAAAAWlzb21tcDQxbXA0MgAAAAFtZGF0AAAAAAAABfAAAAALBgAHgu8EgAAA
    QIAAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAAEyW4ICC/hFXaZvinXKA8sSKBzpwAAAAUJRLg
    gIL/hFXaZvinXKA8sSKBzpwAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAAByHhCRP/CUgAAAAH
    IROEJE8JSAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHAaiBYn9qQAAAAAgBEqIFif9qQAAA
    ABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHIeIREf+JNgAAAAghE4hER/+JNgAAABUGBREDh/RO
    zQpL3KGUOsPUmxcfAIAAAAAHAajDYn9qQAAAAAgBEqMNif9qQAAAABUGBREDh/ROzQpL3KGUOsPU
    mxcfAIAAAAAIIeMZEO/+HGAAAAAJIROMZEO//hxgAAAAFQYFEQOH9E7NCkvcoZQ6w9SbFx8AgAAA
    AAcBqQViEVBAAAAACAESpBWIR1BAAAAAFQYFEQOH9E7NCkvcoZQ6w9SbFx8AgAAAAAgh5CEQQ/6U
    OAAAAAkhE5CEQQ/+lDgAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAABwGpR2IbLyAAAAAIARKl
    HYhvLyAAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAACCHlKRBD/pQ4AAAACSETlKRBD/6UOAAA
    ABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHAamJYh0tYAAAAAgBEqYliHctYAAAABUGBREDh/RO
    zQpL3KGUOsPUmxcfAIAAAAAIIeYxEEP+lDgAAAAJIROYxEEP/pQ4AAAAFQYFEQOH9E7NCkvcoZQ6
    w9SbFx8AgAAAAAcBqctiHS1gAAAACAESpy2Idy1gAAAAFQYFEQOH9E7NCkvcoZQ6w9SbFx8AgAAA
    AAgh5zkQQ/6UOAAAAAkhE5zkQQ/+lDgAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAABwGqDWId
    LWAAAAAIARKoNYh3LWAAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAACCHoQRBD/pQ4AAAACSET
    oQRBD/6UOAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHAapPYh0tYAAAAAgBEqk9iHctYAAA
    ABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAIIelJEEP+lDgAAAAJIROlJEEP/pQ4AAAAFQYFEQOH
    9E7NCkvcoZQ6w9SbFx8AgAAAAAcBqpFiHS1gAAAACAESqkWIdy1gAAAAFQYFEQOH9E7NCkvcoZQ6
    w9SbFx8AgAAAAAgh6lEQQ/6UOAAAAAkhE6lEQQ/+lDgAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCA
    AAAABwGq02IdLWAAAAAIARKrTYh3LWAAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCAAAAACCHrWRBD
    /pQ4AAAACSETrWRBD/6UOAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHAasVYh0tYAAAAAgB
    EqxViHctYAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAIIexhEEP+lDgAAAAJIROxhEEP/pQ4
    AAAAFQYFEQOH9E7NCkvcoZQ6w9SbFx8AgAAAAAcBq1diHS1gAAAACAESrV2Idy1gAAAAFQYFEQOH
    9E7NCkvcoZQ6w9SbFx8AgAAAAAgh7WkQQ/6UOAAAAAkhE7WkQQ/+lDgAAAAVBgURA4f0Ts0KS9yh
    lDrD1JsXHwCAAAAABwGrmWIdLWAAAAAIARKuZYh3LWAAAAAVBgURA4f0Ts0KS9yhlDrD1JsXHwCA
    AAAACCHucRBD/pQ4AAAACSETucRBD/6UOAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAHAavb
    Yh0tYAAAAAgBEq9tiHctYAAAABUGBREDh/ROzQpL3KGUOsPUmxcfAIAAAAAIAe91Id/+HGAAAAAJ
    ARO91Id//hxgAAAET21vb3YAAABsbXZoZAAAAADnCl9/5wpfgAAAAlgAAAJYAAEAAAEAAAAAAAAA
    AAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAIAAAPbdHJhawAAAFx0a2hkAAAAAecKX3/nCl+AAAAAAQAAAAAAAAJYAAAAAAAA
    AAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAABAAAAAQAAAAAAA
    JGVkdHMAAAAcZWxzdAAAAAAAAAABAAACWAAAABQAAQAAAAADU21kaWEAAAAgbWRoZAAAAADnCl9/
    5wpfgAAAAlgAAAJYVcQAAAAAADFoZGxyAAAAAAAAAAB2aWRlAAAAAAAAAAAAAAAAQ29yZSBNZWRp
    YSBWaWRlbwAAAAL6bWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAA
    AAABAAAADHVybCAAAAABAAACunN0YmwAAACgc3RzZAAAAAAAAAABAAAAkGF2YzEAAAAAAAAAAQAA
    AAAAAAAAAAAAAAAAAAAAQABAAEgAAABIAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAY//8AAAAqYXZjQwFkAAr/4QATJ2QACqxSMQmwFqBAQEYVr3vgIAEABCj+CYsAAAAQ
    cGFzcAAAAAEAAAABAAAAGHN0dHMAAAAAAAAAAQAAAB4AAAAUAAABAGN0dHMAAAAAAAAAHgAAAAEA
    AAAUAAAAAQAAACgAAAABAAAAAAAAAAEAAAAoAAAAAQAAAAAAAAABAAAAKAAAAAEAAAAAAAAAAQAA
    ACgAAAABAAAAAAAAAAEAAAAoAAAAAQAAAAAAAAABAAAAKAAAAAEAAAAAAAAAAQAAACgAAAABAAAA
    AAAAAAEAAAAoAAAAAQAAAAAAAAABAAAAKAAAAAEAAAAAAAAAAQAAACgAAAABAAAAAAAAAAEAAAAo
    AAAAAQAAAAAAAAABAAAAKAAAAAEAAAAAAAAAAQAAACgAAAABAAAAAAAAAAEAAAAoAAAAAQAAAAAA
    AAABAAAAFAAAABRzdHNzAAAAAAAAAAEAAAABAAAAKnNkdHAAAAAAIBAYEBgQGBAYEBgQGBAYEBgQ
    GBAYEBgQGBAYEBgYAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAAeAAAAAQAAAIxzdHN6AAAAAAAAAAAA
    AAAeAAAAVwAAAC8AAAAwAAAAMAAAADAAAAAyAAAAMAAAADIAAAAwAAAAMgAAADAAAAAyAAAAMAAA
    ADIAAAAwAAAAMgAAADAAAAAyAAAAMAAAADIAAAAwAAAAMgAAADAAAAAyAAAAMAAAADIAAAAwAAAA
    MgAAADAAAAAyAAAAFHN0Y28AAAAAAAAAAQAAACw=
    """
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

/// The fisheye draws Core Image's `CIBumpDistortion` on iOS and macOS, and a
/// shader that reproduces its mapping on Android (`FisheyeVideoEffect`).
/// Apple does not document that mapping, so this pins it: a change to the
/// filter would otherwise let the platforms drift apart unnoticed.
final class FisheyeVideoEffectTests: XCTestCase {
  func testSamplesWhereTheAndroidShaderDoes() {
    let width = 90, height = 160, intensity = 0.7
    // Every pixel holds its own centre coordinates, so the output shows where
    // each pixel sampled the frame.
    var pixels = [Float](repeating: 1, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        pixels[(y * width + x) * 4] = Float(x) + 0.5
        pixels[(y * width + x) * 4 + 1] = Float(y) + 0.5
      }
    }
    let frame = CIImage(
      bitmapData: Data(bytes: pixels, count: pixels.count * 4),
      bytesPerRow: width * 16,
      size: CGSize(width: width, height: height),
      format: .RGBAf,
      colorSpace: nil)

    let output = FisheyeVideoEffect(params: ["intensity": intensity])
      .render(frame, history: [], timeUs: 0, effectTimeUs: 0)

    var sampled = [Float](repeating: 0, count: pixels.count)
    let context = CIContext(options: [
      .workingColorSpace: NSNull(), .workingFormat: CIFormat.RGBAf,
    ])
    sampled.withUnsafeMutableBytes {
      context.render(
        output, toBitmap: $0.baseAddress!, rowBytes: width * 16,
        bounds: frame.extent, format: .RGBAf, colorSpace: nil)
    }
    XCTAssertEqual(output.extent, frame.extent)

    // The Android shader: source = centre + offset * pull.
    let scale = 0.8 * intensity
    let cx = Double(width) / 2, cy = Double(height) / 2
    let radius = (cx * cx + cy * cy).squareRoot()
    var worst = 0.0
    for y in 0..<height {
      for x in 0..<width {
        let ox = Double(x) + 0.5 - cx, oy = Double(y) + 0.5 - cy
        let t = min(1, (ox * ox + oy * oy).squareRoot() / radius)
        let pull = 1 - scale * (1 - t * t * (3 - 2 * t))
        let i = (y * width + x) * 4
        worst = max(
          worst,
          abs(Double(sampled[i]) - (cx + ox * pull)),
          abs(Double(sampled[i + 1]) - (cy + oy * pull)))
      }
    }
    XCTAssertLessThan(worst, 0.05, "pixels off the shader's mapping, in px")
  }
}

/// The drops are drawn with a Metal kernel on iOS and macOS, and with the
/// same shader in GLSL on Android (`DropsVideoEffect`) and in the effects
/// picker (`shaders/drops.frag`). These tests pin where the drops are, and
/// check every pixel of the kernel against the shader's formulas computed
/// here on the CPU, so a change to one copy that is not made to the others
/// fails, and so does a kernel that reads its textures upside down.
final class DropsVideoEffectTests: XCTestCase {
  private let width = 90
  private let height = 160

  func testPlacesTheDropsWhereAndroidAndDartDo() {
    // The same numbers are pinned in the Dart `dropsLayout` test.
    let cases: [(DropsSettings, Double, [DropsLayout.Drop])] = [
      (
        DropsSettings(), 7,
        [
          .init(x: 0.370810, y: 0.336231, radius: 0.17),
          .init(x: 0.240065, y: 0.584015, radius: 0.13),
          .init(x: 0.629452, y: 0.605205, radius: 0.15),
        ]
      ),
      (
        settings(count: 5, size: 1, speed: 0, seed: 2), 5,
        [
          .init(x: 0.260919, y: 0.330758, radius: 0.255),
          .init(x: 0.301859, y: 0.663046, radius: 0.195),
          .init(x: 0.680109, y: 0.581244, radius: 0.225),
          .init(x: 0.352791, y: 0.674857, radius: 0.165),
          .init(x: 0.379547, y: 0.649744, radius: 0.21),
        ]
      ),
      (
        settings(count: 1, size: 0, speed: 1), 3,
        [.init(x: 0.490785, y: 0.367983, radius: 0.085)]
      ),
    ]
    for (settings, seconds, expected) in cases {
      let drops = DropsLayout.drops(settings, seconds: seconds)
      XCTAssertEqual(drops.count, DropsLayout.maxDrops)
      for (i, drop) in drops.enumerated() {
        let want = i < expected.count ? expected[i] : DropsLayout.Drop(x: -100, y: -100, radius: 0)
        XCTAssertEqual(drop.x, want.x, accuracy: 1e-5, "drop \(i) at \(seconds) s")
        XCTAssertEqual(drop.y, want.y, accuracy: 1e-5, "drop \(i) at \(seconds) s")
        XCTAssertEqual(drop.radius, want.radius, accuracy: 1e-9, "drop \(i) at \(seconds) s")
      }
    }
  }

  func testDrawsWhatTheAndroidShaderDraws() {
    // Red and green hold each pixel's position, so a wrong bend shows; blue
    // is a checkerboard, so the frost, the light and the shadow show.
    var rgb = [Double](repeating: 0, count: width * height * 3)
    for y in 0..<height {
      for x in 0..<width {
        let i = (y * width + x) * 3
        rgb[i] = (Double(x) + 0.5) / Double(width)
        rgb[i + 1] = (Double(y) + 0.5) / Double(height)
        rgb[i + 2] = (x / 6 + y / 6) % 2 == 0 ? 0.2 : 0.7
      }
    }
    // A bitmap's first row is the top of the image, Core Image's y = 0 the bottom.
    var pixels = [Float](repeating: 1, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let s = (y * width + x) * 3, d = ((height - 1 - y) * width + x) * 4
        for k in 0..<3 { pixels[d + k] = Float(rgb[s + k]) }
      }
    }
    let frame = CIImage(
      bitmapData: Data(bytes: pixels, count: pixels.count * 4),
      bytesPerRow: width * 16,
      size: CGSize(width: width, height: height),
      format: .RGBAf,
      colorSpace: nil)
    let context = CIContext(options: [.workingColorSpace: NSNull()])

    let cases: [(Double, [String: Any], Double)] = [
      (0.7, [:], 0),
      (1, ["count": 5, "size": 1.0, "frost": 1.0, "fringes": 1.0, "seed": 3], 7),
      (0.35, ["count": 1, "size": 0.0, "speed": 1.0, "frost": 0.0, "fringes": 0.0], 12.3),
      (0, [:], 3),
    ]
    for (intensity, params, seconds) in cases {
      var all = params
      all["intensity"] = intensity
      let output = DropsVideoEffect(params: all)
        .render(frame, history: [], timeUs: 0, effectTimeUs: Int64(seconds * 1_000_000))
      XCTAssertEqual(output.extent, frame.extent)
      var drawn = [Float](repeating: 0, count: pixels.count)
      drawn.withUnsafeMutableBytes {
        context.render(
          output, toBitmap: $0.baseAddress!, rowBytes: width * 16,
          bounds: frame.extent, format: .RGBAf, colorSpace: nil)
      }

      let expected = draw(
        rgb, intensity: intensity, settings: DropsSettings(params: all), seconds: seconds)
      var worst = 0.0
      for y in 0..<height {
        for x in 0..<width {
          for k in 0..<3 {
            let got = Double(drawn[((height - 1 - y) * width + x) * 4 + k])
            worst = max(worst, abs(got - expected[(y * width + x) * 3 + k]))
          }
        }
      }
      // Half-float textures round to about 0.0005.
      XCTAssertLessThan(worst, 0.003, "intensity \(intensity), \(params), \(seconds) s")
    }
  }

  private func settings(count: Int, size: Double, speed: Double, seed: Int = 0)
    -> DropsSettings
  {
    var settings = DropsSettings()
    settings.count = count
    settings.size = size
    settings.speed = speed
    settings.seed = seed
    return settings
  }

  /// The shader on the CPU, for an RGB frame stored bottom row first.
  private func draw(
    _ rgb: [Double], intensity: Double, settings: DropsSettings, seconds: Double
  ) -> [Double] {
    let w = Double(width), h = Double(height), s = min(w, h)
    let z = DropsLayout.scale(settings)
    let drops = DropsLayout.drops(settings, seconds: seconds).map {
      (x: $0.x * w, y: $0.y * h, r: $0.radius * s)
    }
    func tap(_ qx: Double, _ qy: Double) -> [Double] {
      let x = min(max(qx, 0.5), w - 0.5) - 0.5, y = min(max(qy, 0.5), h - 0.5) - 0.5
      let x0 = Int(x), y0 = Int(y), x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
      let fx = x - Double(x0), fy = y - Double(y0)
      return (0..<3).map { k in
        let row0 = rgb[(y0 * width + x0) * 3 + k] * (1 - fx) + rgb[(y0 * width + x1) * 3 + k] * fx
        let row1 = rgb[(y1 * width + x0) * 3 + k] * (1 - fx) + rgb[(y1 * width + x1) * 3 + k] * fx
        return row0 * (1 - fy) + row1 * fy
      }
    }
    func frosted(_ qx: Double, _ qy: Double, _ r: Double) -> [Double] {
      var sum = tap(qx, qy)
      for i in 0..<8 {
        let n = Double(i), angle = n * 2.399963, reach = r * ((n + 0.5) / 8).squareRoot()
        let more = tap(qx + reach * cos(angle), qy + reach * sin(angle))
        for k in 0..<3 { sum[k] += more[k] }
      }
      return sum.map { $0 / 9 }
    }
    func smoothstep(_ edge: Double, _ x: Double) -> Double {
      let v = min(max(x / edge, 0), 1)
      return v * v * (3 - 2 * v)
    }
    func smin(_ a: Double, _ b: Double, _ k: Double) -> Double {
      let blend = max(k - abs(a - b), 0) / k
      return min(a, b) - blend * blend * k * 0.25
    }
    func distance(_ x: Double, _ y: Double) -> Double {
      drops.reduce(1e5) { d, drop in smin(d, hypot(x - drop.x, y - drop.y) - drop.r, 0.13 * s * z) }
    }

    var out = [Double](repeating: 0, count: rgb.count)
    for yi in 0..<height {
      for xi in 0..<width {
        let px = Double(xi) + 0.5, py = Double(yi) + 0.5
        let d = distance(px, py)
        let shadow = 1 - smoothstep(0.07 * s * z, distance(px, py + 0.018 * s * z))
        let background = tap(px, py).map { $0 * (1 - shadow * 0.3 * intensity) }
        var result = background
        if d <= 1 {
          let gx = distance(px + 1, py) - distance(px - 1, py)
          let gy = distance(px, py + 1) - distance(px, py - 1)
          let length = max(hypot(gx, gy), 1e-4)
          let nx = gx / length, ny = gy / length
          let e = 1 - min(max(-d / (0.11 * s * z), 0), 1)
          let slope = e * e * e * pow(max(1 - e * e * e * e, 1e-4), -0.75)
          let bend = slope / (1 + slope * slope).squareRoot() * 0.95 * intensity * 0.11 * s * z
          let r = 0.028 * s * settings.frost * intensity
          let spread = 0.28 * settings.fringes
          let shifted = { (f: Double) -> [Double] in
            frosted(px - nx * bend * f, py - ny * bend * f, r)
          }
          let rim: Double = 1 - smoothstep(0.014 * s * z, -d)
          let light: Double = nx * -0.5524 + ny * 0.8336
          let lit: Double = max(light, 0)
          let back: Double = max(-light, 0)
          let highlight: Double = lit * lit * lit + 0.45 * back * back * back
          let glow: Double = intensity * rim * (0.85 * highlight + 0.08)
          let lift: Double = (0.05 + 0.12 * settings.frost) * intensity
          let bent: [Double] = [shifted(1 - spread)[0], shifted(1)[1], shifted(1 + spread)[2]]
          let color: [Double] = bent.map { (channel: Double) -> Double in
            min(max(channel + (1 - channel) * lift + glow, 0), 1)
          }
          let cover: Double = min(max(0.5 - d, 0), 1)
          result = (0..<3).map { (k: Int) -> Double in
            background[k] + (color[k] - background[k]) * cover
          }
        }
        for k in 0..<3 { out[(yi * width + xi) * 3 + k] = result[k] }
      }
    }
    return out
  }
}

/// Light leak, particles, tilt-shift, swirl, ripple, fluted glass, zoom blur
/// and comic are drawn with Metal kernels on iOS and macOS
/// (`ShaderVideoEffect`), and with the same shaders in GLSL on Android and in
/// the effects picker (`shaders/*.frag`). These tests
/// check every pixel each kernel draws against its shader's formulas computed
/// here on the CPU, so a change to one copy that is not made to the others
/// fails, and so does a kernel that reads its textures upside down.
///
/// The CPU copies spell out every type and keep each statement short: Swift
/// type-checks a long arithmetic expression over overloaded functions such as
/// `max`, `exp` and `sin` by trying their overloads together, and older Xcode
/// releases give up on the longer ones.
final class ShaderVideoEffectTests: XCTestCase {
  private let width = 144
  private let height = 256

  /// Red and green hold each pixel's position, so a wrong offset shows; blue
  /// is a checkerboard, so blurs, edges, the ink and the dots show. Every value
  /// is a multiple of 1/256, which the kernels' half-float textures hold
  /// exactly.
  private lazy var rgb: [Double] = {
    var rgb = [Double](repeating: 0, count: width * height * 3)
    for y in 0..<height {
      for x in 0..<width {
        let i: Int = (y * width + x) * 3
        let red: Int = x * 256 / width
        let green: Int = y * 256 / height
        let blue: Int = (x / 12 + y / 12) % 2 == 0 ? 0 : 255
        rgb[i] = Double(red) / 256
        rgb[i + 1] = Double(green) / 256
        rgb[i + 2] = Double(blue) / 256
      }
    }
    return rgb
  }()

  /// The frame as Core Image sees it: a bitmap's first row is the top of the
  /// image, Core Image's y = 0 the bottom.
  private lazy var frame: CIImage = {
    var pixels = [Float](repeating: 1, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let s: Int = (y * width + x) * 3
        let d: Int = ((height - 1 - y) * width + x) * 4
        for k in 0..<3 { pixels[d + k] = Float(rgb[s + k]) }
      }
    }
    return CIImage(
      bitmapData: Data(bytes: pixels, count: pixels.count * 4),
      bytesPerRow: width * 16,
      size: CGSize(width: width, height: height),
      format: .RGBAf,
      colorSpace: nil)
  }()

  private let context = CIContext(options: [.workingColorSpace: NSNull()])

  func testLightLeakDrawsWhatTheAndroidShaderDraws() {
    for (intensity, seconds) in [(0.7, 0.0), (1.0, 9.0), (0.35, 23.5)] {
      let effect = LightLeakVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.lightLeak(px, py, intensity: intensity, seconds: seconds)
      }
      let difference = compare(effect, seconds: seconds, expected)
      // Half-float textures round to about 0.0005.
      XCTAssertLessThan(difference.worst, 0.003, "intensity \(intensity), \(seconds) s")
    }
  }

  func testParticlesDrawWhatTheAndroidShaderDraws() {
    for style in ParticlesVideoEffect.Style.allCases {
      for (intensity, seconds) in [(1.0, 3.0), (0.6, 17.25)] {
        let effect = ParticlesVideoEffect(style: style, params: ["intensity": intensity])
        let look = ParticleLook(style: style.rawValue)
        let expected = eachPixel { (px: Double, py: Double) -> [Double] in
          self.particles(px, py, look: look, intensity: intensity, seconds: seconds)
        }
        let difference = compare(effect, seconds: seconds, expected)
        // The GPU's sine drifts from the CPU's at large angles, which moves a
        // few of the confetti's hard edges by a fraction of a pixel; a change
        // to any particle's shape, place or colour moves far more.
        XCTAssertLessThan(difference.share, 0.002, "\(style), \(intensity), \(seconds) s")
      }
    }
  }

  func testTiltShiftDrawsWhatTheAndroidShaderDraws() {
    for intensity in [1.0, 0.45] {
      let effect = TiltShiftVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.tiltShift(px, py, intensity: intensity)
      }
      let difference = compare(effect, seconds: 0, expected)
      XCTAssertLessThan(difference.worst, 0.003, "intensity \(intensity)")
    }
  }

  func testZoomBlurDrawsWhatTheAndroidShaderDraws() {
    for intensity in [1.0, 0.45] {
      let effect = ZoomBlurVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.zoomBlur(px, py, strength: intensity)
      }
      let difference = compare(effect, seconds: 0, expected)
      XCTAssertLessThan(difference.worst, 0.006, "intensity \(intensity)")
    }
  }

  func testComicDrawsWhatTheAndroidShaderDraws() {
    for intensity in [1.0, 0.45] {
      let effect = ComicVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.comic(px, py, intensity: intensity)
      }
      let difference = compare(effect, seconds: 0, expected)
      // A pixel whose brightness lies right on the edge of a band can land in
      // either, on the GPU and here; a change to the bands, the dots or the
      // ink moves far more.
      XCTAssertLessThan(difference.share, 0.002, "intensity \(intensity)")
    }
  }

  func testSwirlDrawsWhatTheAndroidShaderDraws() {
    for intensity in [1.0, 0.45] {
      let effect = SwirlVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.swirl(px, py, intensity: intensity)
      }
      let difference = compare(effect, seconds: 0, expected)
      XCTAssertLessThan(difference.worst, 0.003, "intensity \(intensity)")
    }
  }

  func testRippleDrawsWhatTheAndroidShaderDraws() {
    for (intensity, seconds) in [(1.0, 0.0), (0.6, 1.5), (0.8, 41.9)] {
      let effect = RippleVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.ripple(px, py, intensity: intensity, seconds: seconds)
      }
      let difference = compare(effect, seconds: seconds, expected)
      // The crests light the frame by up to 12%, which scales the GPU's
      // filtering and half-float rounding with it; a change to the rings, the
      // push or the light moves far more.
      XCTAssertLessThan(difference.worst, 0.004, "intensity \(intensity), \(seconds) s")
    }
  }

  func testFlutedGlassDrawsWhatTheAndroidShaderDraws() {
    for intensity in [1.0, 0.45] {
      let effect = FlutedGlassVideoEffect(params: ["intensity": intensity])
      let expected = eachPixel { (px: Double, py: Double) -> [Double] in
        self.flutedGlass(px, py, intensity: intensity)
      }
      let difference = compare(effect, seconds: 0, expected)
      XCTAssertLessThan(difference.worst, 0.003, "intensity \(intensity)")
    }
  }

  func testLeavesTheFrameAloneAtNoIntensity() {
    let effects: [ShaderVideoEffect] = [
      LightLeakVideoEffect(params: ["intensity": 0]),
      ParticlesVideoEffect(style: .snow, params: ["intensity": 0]),
      TiltShiftVideoEffect(params: ["intensity": 0]),
      SwirlVideoEffect(params: ["intensity": 0]),
      RippleVideoEffect(params: ["intensity": 0]),
      FlutedGlassVideoEffect(params: ["intensity": 0]),
      ZoomBlurVideoEffect(params: ["intensity": 0]),
      ComicVideoEffect(params: ["intensity": 0]),
    ]
    for effect in effects {
      let output = effect.render(frame, history: [], timeUs: 0, effectTimeUs: 1_000_000)
      XCTAssertTrue(output === frame, "\(type(of: effect))")
    }
  }

  func testZoomBlurOnTheBeatFadesEachHitOutOverHalfASecond() {
    let beats: [Int64]? = ZoomBlurHits.beats(["beatsUs": [1_200_000, 200_000]])
    XCTAssertEqual(beats, [200_000, 1_200_000])
    XCTAssertNil(ZoomBlurHits.beats(["intensity": 0.5]))
    let cases: [(Int64, Double)] = [
      (0, 0), (200_000, 0.8), (450_000, 0.2), (699_999, 0), (1_200_000, 0.8),
      (1_325_000, 0.45),
    ]
    for (time, expected) in cases {
      let strength: Double = ZoomBlurHits.strength(
        intensity: 0.8, beatsUs: beats, effectTimeUs: time)
      XCTAssertEqual(strength, expected, accuracy: 1e-5, "\(time) us")
    }
    let allThrough: Double = ZoomBlurHits.strength(
      intensity: 0.8, beatsUs: nil, effectTimeUs: 123)
    XCTAssertEqual(allThrough, 0.8)
  }

  /// How far `effect`'s output is from `expected`: the worst channel, and the
  /// share of channels off by more than 0.01.
  private func compare(_ effect: ShaderVideoEffect, seconds: Double, _ expected: [Double])
    -> (worst: Double, share: Double)
  {
    let effectTimeUs = Int64(seconds * 1_000_000)
    let output = effect.render(frame, history: [], timeUs: 0, effectTimeUs: effectTimeUs)
    XCTAssertEqual(output.extent, frame.extent)
    var drawn = [Float](repeating: 0, count: width * height * 4)
    drawn.withUnsafeMutableBytes {
      context.render(
        output, toBitmap: $0.baseAddress!, rowBytes: width * 16,
        bounds: frame.extent, format: .RGBAf, colorSpace: nil)
    }
    var worst: Double = 0
    var off = 0
    for y in 0..<height {
      for x in 0..<width {
        for k in 0..<3 {
          let got = Double(drawn[((height - 1 - y) * width + x) * 4 + k])
          let difference: Double = abs(got - expected[(y * width + x) * 3 + k])
          worst = max(worst, difference)
          if difference > 0.01 { off += 1 }
        }
      }
    }
    return (worst, Double(off) / Double(width * height * 3))
  }

  // MARK: The shaders on the CPU, for the RGB frame stored bottom row first.

  /// Runs `shade` for each pixel's centre, in pixels with y up.
  private func eachPixel(_ shade: (Double, Double) -> [Double]) -> [Double] {
    var out = [Double](repeating: 0, count: rgb.count)
    for yi in 0..<height {
      for xi in 0..<width {
        let color: [Double] = shade(Double(xi) + 0.5, Double(yi) + 0.5)
        for k in 0..<3 { out[(yi * width + xi) * 3 + k] = color[k] }
      }
    }
    return out
  }

  /// The frame at a point, bilinear, clamped to its edge pixels.
  private func tap(_ qx: Double, _ qy: Double) -> [Double] {
    let w = Double(width)
    let h = Double(height)
    let x: Double = min(max(qx, 0.5), w - 0.5) - 0.5
    let y: Double = min(max(qy, 0.5), h - 0.5) - 0.5
    let x0 = Int(x)
    let y0 = Int(y)
    let x1: Int = min(x0 + 1, width - 1)
    let y1: Int = min(y0 + 1, height - 1)
    let fx: Double = x - Double(x0)
    let fy: Double = y - Double(y0)
    var color = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let a: Double = rgb[(y0 * width + x0) * 3 + k]
      let b: Double = rgb[(y0 * width + x1) * 3 + k]
      let c: Double = rgb[(y1 * width + x0) * 3 + k]
      let d: Double = rgb[(y1 * width + x1) * 3 + k]
      let bottom: Double = a + (b - a) * fx
      let top: Double = c + (d - c) * fx
      color[k] = bottom + (top - bottom) * fy
    }
    return color
  }

  private func fract(_ x: Double) -> Double { x - x.rounded(.down) }

  private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

  private func sign(_ x: Double) -> Double { x > 0 ? 1 : (x < 0 ? -1 : 0) }

  private func mix(_ a: [Double], _ b: [Double], _ t: Double) -> [Double] {
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 { out[k] = a[k] + (b[k] - a[k]) * t }
    return out
  }

  private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let v: Double = clamp((x - edge0) / (edge1 - edge0))
    return v * v * (3 - 2 * v)
  }

  /// Interleaved gradient noise, which turns or shifts each pixel's taps.
  private func noise(_ px: Double, _ py: Double) -> Double {
    let inner: Double = fract(px * 0.06711056 + py * 0.00583715)
    return fract(52.9829189 * inner)
  }

  /// `a + b · sin(f · t + phase)`, a light's path along one axis.
  private func path(_ a: Double, _ b: Double, _ f: Double, _ phase: Double, _ t: Double)
    -> Double
  {
    let angle: Double = f * t + phase
    return a + b * sin(angle)
  }

  /// What one light adds at a pixel, its centre and reach as shares of the
  /// frame's size and longer side.
  private func light(
    _ px: Double, _ py: Double, x: Double, y: Double, reachX: Double, reachY: Double,
    color: [Double]
  ) -> [Double] {
    let w = Double(width)
    let h = Double(height)
    let l: Double = max(w, h)
    let dx: Double = (px - x * w) / (reachX * l)
    let dy: Double = (py - y * h) / (reachY * l)
    let falloff: Double = exp(-(dx * dx + dy * dy))
    return [color[0] * falloff, color[1] * falloff, color[2] * falloff]
  }

  private func lightLeak(_ px: Double, _ py: Double, intensity: Double, seconds t: Double)
    -> [Double]
  {
    let base: [Double] = tap(px, py)
    let orange: [Double] = light(
      px, py, x: path(-0.06, 0.16, 0.37, 0.4, t), y: path(0.62, 0.3, 0.21, 1.1, t),
      reachX: 0.32, reachY: 0.6, color: [0.95, 0.49, 0.17])
    let red: [Double] = light(
      px, py, x: path(0.45, 0.4, 0.18, 2.2, t), y: path(1.04, 0.08, 0.31, 0.3, t),
      reachX: 0.55, reachY: 0.26, color: [0.75, 0.21, 0.24])
    let gold: [Double] = light(
      px, py, x: path(0.18, 0.42, 0.27, 4.0, t), y: path(0.8, 0.18, 0.47, 2.6, t),
      reachX: 0.24, reachY: 0.24, color: [0.55, 0.45, 0.28])
    var color = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let glow: Double = orange[k] + red[k] + gold[k]
      let leak: Double = clamp(glow * intensity)
      color[k] = 1 - (1 - base[k]) * (1 - leak)
    }
    return color
  }

  private func hash3(_ px: Double, _ py: Double) -> [Double] {
    let qx: Double = fract(px * 0.1031)
    let qy: Double = fract(py * 0.1030)
    let qz: Double = fract(px * 0.0973)
    let dx: Double = qx * (qy + 3.33)
    let dy: Double = qy * (qx + 3.33)
    let dz: Double = qz * (qz + 3.33)
    let d: Double = dx + dy + dz
    let x: Double = qx + d
    let y: Double = qy + d
    let z: Double = qz + d
    return [fract((x + y) * z), fract((x + z) * y), fract((y + z) * x)]
  }

  /// Signed distance to a heart with its tip at the origin, one unit tall.
  private func heart(_ px: Double, _ y: Double) -> Double {
    let x: Double = abs(px)
    if y + x > 1 { return hypot(x - 0.25, y - 0.75) - 0.353553 }
    let m: Double = 0.5 * max(x + y, 0)
    let a: Double = x * x + (y - 1) * (y - 1)
    let b: Double = (x - m) * (x - m) + (y - m) * (y - m)
    return min(a, b).squareRoot() * sign(x - y)
  }

  private func turn(_ dx: Double, _ dy: Double, _ angle: Double) -> (x: Double, y: Double) {
    let c: Double = cos(angle)
    let n: Double = sin(angle)
    return (c * dx + n * dy, c * dy - n * dx)
  }

  /// Per style: the cell size, how fast and which way the cells move, how far
  /// a particle sways and how many cells hold one.
  private struct ParticleLook {
    let style: Int
    var cell = 0.14
    var speed = -0.22
    var drift = 0.0
    var sway = 0.1
    var density = 0.75

    init(style: Double) {
      self.style = Int(style + 0.5)
      switch self.style {
      case 1: (cell, speed, sway, density) = (0.13, -0.32, 0.08, 0.6)
      case 2: (cell, speed, sway, density) = (0.17, 0.12, 0.1, 0.35)
      case 3: (cell, speed, sway, density) = (0.15, 0.03, 0.0, 0.45)
      case 4: (cell, speed, sway, density) = (0.2, -1.5, 0.0, 0.7)
      case 5: (cell, speed, sway, density) = (0.2, -0.14, 0.1, 0.4)
      case 6: (cell, speed, sway, density) = (0.15, -0.12, 0.1, 0.45)
      case 7: (cell, speed, sway, density) = (0.18, 0.09, 0.08, 0.35)
      case 8: (cell, speed, sway, density) = (0.32, 0.025, 0.05, 0.45)
      case 9: (cell, speed, sway, density) = (0.2, 0.1, 0.06, 0.35)
      case 10: (cell, speed, sway, density) = (0.15, -0.1, 0.08, 0.45)
      case 11: (cell, speed, sway, density) = (0.18, 0.015, 0.06, 0.4)
      case 12: (cell, speed, sway, density) = (0.13, 0.35, 0.09, 0.55)
      case 13: (cell, speed, sway, density) = (0.2, -0.2, 0.1, 0.45)
      case 14: (cell, speed, sway, density) = (0.3, 0.1, 0.06, 0.35)
      default: break
      }
      // How fast the cells move sideways, for the rain and petals the wind
      // slants.
      drift = self.style == 4 ? 0.22 : (self.style == 6 ? 0.08 : 0.0)
    }
  }

  private func particles(
    _ px: Double, _ py: Double, look: ParticleLook, intensity: Double, seconds t: Double
  ) -> [Double] {
    let s = Double(min(width, height))
    var color: [Double] = tap(px, py)
    let fallLength: Double = hypot(look.drift, look.speed)
    let fallX: Double = look.drift / fallLength
    let fallY: Double = look.speed / fallLength
    for k in 0..<3 {
      let layer = Double(k)
      let depth: Double = 0.55 + 0.225 * layer
      let size: Double = s * look.cell * depth
      let qx: Double = (px - look.drift * depth * t * s) / size + 0.37 * layer
      let qy: Double = (py - look.speed * depth * t * s) / size
      let idx: Double = qx.rounded(.down) + 131 * layer
      let idy: Double = qy.rounded(.down) + 71 * layer
      let h: [Double] = hash3(idx, idy)
      if h[2] >= look.density * intensity { continue }
      let g: [Double] = hash3(idx + 17, idy + 17)
      let swayAngle: Double = t * (0.6 + 0.6 * g[0]) + 6.2832 * g[1]
      let dx: Double = fract(qx) - (0.25 + 0.5 * h[0]) - look.sway * sin(swayAngle)
      let dy: Double = fract(qy) - (0.25 + 0.5 * h[1])
      let alpha: Double = 0.55 + 0.45 * depth
      switch look.style {
      case 1: color = confetti(color, dx, dy, h, g, alpha: alpha, seconds: t)
      case 2: color = heartParticle(color, dx, dy, g, alpha: alpha, seconds: t)
      case 3: color = sparkle(color, dx, dy, g, alpha: alpha, seconds: t)
      case 4: color = raindrop(color, dx, dy, g, alpha: alpha, fallX: fallX, fallY: fallY)
      case 5: color = leaf(color, dx, dy, h, g, alpha: alpha, seconds: t)
      case 6: color = petal(color, dx, dy, h, g, alpha: alpha, seconds: t)
      case 7: color = bubble(color, dx, dy, g, alpha: alpha, seconds: t)
      case 8: color = bokeh(color, dx, dy, g, alpha: alpha, seconds: t)
      case 9: color = note(color, dx, dy, g, alpha: alpha, seconds: t)
      case 10: color = starParticle(color, dx, dy, h, g, alpha: alpha, seconds: t)
      case 11: color = firefly(color, dx, dy, g, alpha: alpha, seconds: t)
      case 12:
        let height: Double = py / Double(self.height)
        color = ember(color, dx, dy, g, alpha: alpha, seconds: t, height: height)
      case 13: color = banknote(color, dx, dy, h, g, alpha: alpha, seconds: t)
      case 14: color = balloon(color, dx, dy, g, alpha: alpha, seconds: t)
      default: color = snowflake(color, dx, dy, g, alpha: alpha)
      }
    }
    return color
  }

  private func sparkle(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let twinkleAngle: Double = t * (1.6 + 1.6 * g[0]) + 6.2832 * g[1]
    let twinkle: Double = 0.5 + 0.5 * sin(twinkleAngle)
    let reach: Double = (0.1 + 0.1 * g[2]) * (0.3 + 0.7 * twinkle)
    let mx: Double = abs(dx)
    let my: Double = abs(dy)
    let across: Double = exp(-mx / 0.016) * max(1 - my / reach, 0)
    let up: Double = exp(-my / 0.016) * max(1 - mx / reach, 0)
    let core: Double = exp(-(dx * dx + dy * dy) / (reach * reach * 0.05))
    let glint: Double = min(across + up + core, 1)
    return mix(color, [1.0, 0.93, 0.75], alpha * twinkle * glint)
  }

  private func heartParticle(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let size: Double = 0.13 + 0.04 * g[2]
    let wobbleAngle: Double = t * (1 + g[0]) + 6.2832 * g[1]
    let turned = turn(dx, dy, 0.3 * sin(wobbleAngle))
    let edge: Double = heart(turned.x / size, turned.y / size + 0.5) * size
    let pink: [Double] = mix([0.93, 0.13, 0.3], [1.0, 0.45, 0.65], fract(g[2] * 7.31))
    let cover: Double = 1 - smoothstep(-0.012, 0.012, edge)
    return mix(color, pink, alpha * 0.92 * cover)
  }

  private func confetti(
    _ color: [Double], _ dx: Double, _ dy: Double, _ h: [Double], _ g: [Double],
    alpha: Double, seconds t: Double
  ) -> [Double] {
    let tumbleAngle: Double = t * (3 + 3 * g[1]) + 6.2832 * h[1]
    let tumble: Double = cos(tumbleAngle)
    let spin: Double = t * (1.5 + 2.5 * g[0]) * sign(h[0] - 0.5)
    let turned = turn(dx, dy, 6.2832 * g[2] + spin)
    let bx: Double = abs(turned.x) - (0.11 * abs(tumble) + 0.01)
    let by: Double = abs(turned.y) - 0.05
    let outside: Double = hypot(max(bx, 0), max(by, 0))
    let inside: Double = min(max(bx, by), 0)
    let edge: Double = outside + inside
    let hue: Double = fract(g[2] * 7.31)
    let shade: Double = 0.65 + 0.35 * abs(tumble)
    var paper = [Double](repeating: 0, count: 3)
    let offsets: [Double] = [0.0, 0.33, 0.67]
    for k in 0..<3 {
      let wave: Double = cos(6.2832 * (hue + offsets[k]))
      paper[k] = (0.55 + 0.45 * wave) * shade
    }
    let cover: Double = 1 - smoothstep(-0.012, 0.012, edge)
    return mix(color, paper, alpha * cover)
  }

  private func snowflake(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double
  ) -> [Double] {
    let r: Double = 0.07 + 0.05 * g[2]
    let cover: Double = 1 - smoothstep(r * 0.3, r, hypot(dx, dy))
    return mix(color, [0.97, 0.98, 1.0], alpha * cover)
  }

  /// Signed distance to a box of half-size `bx` by `by` around the origin.
  private func box(_ px: Double, _ py: Double, _ bx: Double, _ by: Double) -> Double {
    let qx: Double = abs(px) - bx
    let qy: Double = abs(py) - by
    let outside: Double = hypot(max(qx, 0), max(qy, 0))
    return outside + min(max(qx, qy), 0)
  }

  /// Distance to the segment from (ax, ay) to (bx, by).
  private func segment(
    _ px: Double, _ py: Double, _ ax: Double, _ ay: Double, _ bx: Double, _ by: Double
  ) -> Double {
    let pax: Double = px - ax
    let pay: Double = py - ay
    let bax: Double = bx - ax
    let bay: Double = by - ay
    let along: Double = (pax * bax + pay * bay) / (bax * bax + bay * bay)
    let h: Double = clamp(along)
    return hypot(pax - bax * h, pay - bay * h)
  }

  /// Signed distance to a lens around the origin, pointed at y = ±b and w
  /// wide on either side of its middle.
  private func lens(_ px: Double, _ py: Double, _ b: Double, _ w: Double) -> Double {
    let d: Double = 0.5 * (b * b / w - w)
    let x: Double = abs(px)
    let y: Double = abs(py)
    if (y - b) * d > x * b { return hypot(x, y - b) }
    return hypot(x + d, y) - d - w
  }

  /// Signed distance to a five-pointed star around the origin with its
  /// points r out and its inner corners rf of the way there.
  private func star(_ px: Double, _ py: Double, _ r: Double, _ rf: Double) -> Double {
    let kx: Double = 0.809017
    let ky: Double = -0.587785
    var x: Double = abs(px)
    var y: Double = py
    let first: Double = max(kx * x + ky * y, 0)
    x -= 2 * first * kx
    y -= 2 * first * ky
    let second: Double = max(-kx * x + ky * y, 0)
    x += 2 * second * kx
    y -= 2 * second * ky
    x = abs(x)
    y -= r
    let bax: Double = -rf * ky
    let bay: Double = rf * kx - 1
    let along: Double = (x * bax + y * bay) / (bax * bax + bay * bay)
    let h: Double = min(max(along, 0), r)
    let side: Double = sign(y * bax - x * bay)
    return hypot(x - bax * h, y - bay * h) * side
  }

  /// `light` added to `color` the way a screen blend does.
  private func glow(_ color: [Double], _ light: [Double]) -> [Double] {
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let added: Double = clamp(light[k])
      out[k] = 1 - (1 - color[k]) * (1 - added)
    }
    return out
  }

  /// `color` times `factor`, channel by channel.
  private func scaled(_ color: [Double], _ factor: Double) -> [Double] {
    [color[0] * factor, color[1] * factor, color[2] * factor]
  }

  /// `a + b · cos(2π (hue + offset))` for each channel's offset.
  private func palette(
    _ hue: Double, _ a: Double, _ b: Double, _ offsets: [Double]
  ) -> [Double] {
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let wave: Double = cos(6.2832 * (hue + offsets[k]))
      out[k] = a + b * wave
    }
    return out
  }

  private func raindrop(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    fallX: Double, fallY: Double
  ) -> [Double] {
    let along: Double = dx * fallX + dy * fallY
    let across: Double = abs(fallX * dy - fallY * dx)
    let reach: Double = 0.14 + 0.08 * g[2]
    let past: Double = max(abs(along) - reach, 0)
    let line: Double = 1 - smoothstep(0.004, 0.011, hypot(across, past))
    let head: Double = 0.25 + 0.75 * smoothstep(-reach, reach, along)
    return mix(color, [0.82, 0.88, 0.96], alpha * 0.7 * line * head)
  }

  private func leaf(
    _ color: [Double], _ dx: Double, _ dy: Double, _ h: [Double], _ g: [Double],
    alpha: Double, seconds t: Double
  ) -> [Double] {
    let tumbleAngle: Double = t * (1.2 + 1.2 * g[2]) + 6.2832 * h[1]
    let tumble: Double = abs(cos(tumbleAngle))
    let rockAngle: Double = t * (0.6 + 0.6 * g[0]) + 6.2832 * g[1]
    let tilt: Double = 2 * g[2] - 1 + 0.6 * cos(rockAngle)
    let u = turn(dx, dy, tilt)
    let blade: Double = lens(u.x, u.y, 0.11, 0.05 * tumble + 0.006)
    let stalk: Double = segment(u.x, u.y, 0, -0.11, 0, -0.128) - 0.006
    let hue: Double = fract(g[2] * 7.31)
    var tone: [Double] = mix([0.78, 0.2, 0.08], [0.95, 0.5, 0.1], smoothstep(0, 0.5, hue))
    tone = mix(tone, [0.92, 0.72, 0.18], smoothstep(0.5, 1, hue))
    let brown: Double = fract(g[2] * 13.7) >= 0.8 ? 1 : 0
    tone = mix(tone, [0.5, 0.28, 0.12], brown)
    let vein: Double = 1 - smoothstep(0.003, 0.007, abs(u.x))
    let shade: Double = (0.6 + 0.4 * tumble) * (1 - 0.35 * vein)
    tone = scaled(tone, shade)
    let onStalk: Double = blade >= stalk ? 1 : 0
    tone = mix(tone, scaled(tone, 0.6), onStalk)
    let cover: Double = 1 - smoothstep(-0.012, 0.012, min(blade, stalk))
    return mix(color, tone, alpha * cover)
  }

  private func petal(
    _ color: [Double], _ dx: Double, _ dy: Double, _ h: [Double], _ g: [Double],
    alpha: Double, seconds t: Double
  ) -> [Double] {
    let flutterAngle: Double = t * (2 + 2 * g[1]) + 6.2832 * h[1]
    let flutter: Double = abs(cos(flutterAngle))
    let spin: Double = t * (0.8 + 1.2 * g[0]) * sign(h[0] - 0.5)
    let u = turn(dx, dy, 6.2832 * g[2] + spin)
    let w: Double = 0.075 * (0.25 + 0.75 * flutter)
    let taper: Double = 0.8 + 0.25 * min(max(u.y / 0.1, -1), 1)
    let ex: Double = u.x / (w * taper)
    let ey: Double = u.y / 0.1
    let body: Double = (hypot(ex, ey) - 1) * w
    let bounds: Double = max(abs(u.y) - 0.1, abs(u.x) - 0.08)
    let notch: Double = 0.03 - hypot(u.x, u.y - 0.11)
    let edge: Double = max(max(body, bounds), notch)
    let tint: [Double] = mix([0.96, 0.55, 0.7], [1.0, 0.87, 0.91], smoothstep(-1, 1, ey))
    let cover: Double = 1 - smoothstep(-0.012, 0.012, edge)
    return mix(color, scaled(tint, 0.75 + 0.25 * flutter), alpha * 0.95 * cover)
  }

  private func bubble(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let r: Double = 0.08 + 0.07 * g[2]
    let wobbleAngle: Double = t * (2 + 2 * g[0]) + 6.2832 * g[1]
    let wobble: Double = 0.04 * sin(wobbleAngle)
    let ux: Double = dx * (1 + wobble)
    let uy: Double = dy * (1 - wobble)
    let l: Double = hypot(ux, uy)
    let film: Double = 1 - smoothstep(-0.006, 0.006, l - r)
    let rim: Double = pow(clamp(l / r), 6) * film
    let swirl: Double = g[0] + 0.12 * t + 0.5 * (ux - 0.6 * uy) / r
    let iris: [Double] = palette(swirl, 0.6, 0.4, [0.0, 0.33, 0.67])
    let sx: Double = ux + 0.4 * r
    let sy: Double = uy - 0.45 * r
    let shine: Double = exp(-(sx * sx + sy * sy) / (0.04 * r * r))
    let tinted: [Double] = mix(color, iris, alpha * (0.08 * film + 0.6 * rim))
    let light: Double = alpha * film * 0.8 * shine
    return glow(tinted, [light, light, light])
  }

  private func bokeh(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let r: Double = 0.11 + 0.08 * g[2]
    let l: Double = hypot(dx, dy)
    let inside: Double = 1 - smoothstep(r - 0.025, r, l)
    let ring: Double = 0.6 + 0.4 * smoothstep(0.5 * r, r, l)
    let pulseAngle: Double = t * (0.5 + 0.5 * g[0]) + 6.2832 * g[1]
    let pulse: Double = 0.5 + 0.5 * sin(pulseAngle)
    let strength: Double = alpha * inside * ring * (0.2 + 0.35 * pulse)
    let tint: [Double] = palette(fract(g[2] * 7.31), 0.75, 0.25, [0.0, 0.2, 0.45])
    return glow(color, scaled(tint, strength))
  }

  /// Signed distance to a note's head around the origin, in the note's units.
  private func noteHead(_ x: Double, _ y: Double) -> Double {
    let turned = turn(x, y, 0.4)
    return (hypot(turned.x / 0.3, turned.y / 0.21) - 1) * 0.21
  }

  private func note(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let size: Double = 0.155
    let pair: Bool = fract(g[2] * 13.7) > 0.5
    let rockAngle: Double = t * (1 + g[0]) + 6.2832 * g[1]
    let turned = turn(dx, dy, 0.35 * sin(rockAngle))
    let ux: Double = turned.x / size + (pair ? 0.36 : 0.14)
    let uy: Double = turned.y / size + (pair ? 0.48 : 0.4)
    var edge: Double = noteHead(ux, uy)
    edge = min(edge, segment(ux, uy, 0.27, 0.06, 0.27, 1.0) - 0.045)
    if pair {
      let vx: Double = ux - 0.72
      let vy: Double = uy - 0.16
      edge = min(edge, noteHead(vx, vy))
      edge = min(edge, segment(vx, vy, 0.27, 0.06, 0.27, 1.0) - 0.045)
      edge = min(edge, segment(ux, uy, 0.27, 0.93, 0.99, 1.09) - 0.075)
    } else {
      edge = min(edge, segment(ux, uy, 0.27, 1.0, 0.55, 0.62) - 0.05)
      edge = min(edge, segment(ux, uy, 0.55, 0.62, 0.5, 0.42) - 0.045)
    }
    edge *= size
    let fill: Double = 1 - smoothstep(-0.012, 0.012, edge)
    let ink: Double = 1 - smoothstep(0, 0.03, edge)
    let tint: [Double] = palette(fract(g[2] * 7.31), 0.82, 0.18, [0.0, 0.33, 0.67])
    let outline: Double = alpha * 0.6 * max(ink - fill, 0)
    let inked: [Double] = mix(color, scaled(color, 0.35), outline)
    return mix(inked, tint, alpha * fill)
  }

  private func starParticle(
    _ color: [Double], _ dx: Double, _ dy: Double, _ h: [Double], _ g: [Double],
    alpha: Double, seconds t: Double
  ) -> [Double] {
    let r: Double = 0.1 + 0.04 * g[2]
    let spin: Double = t * (0.6 + 0.8 * g[0]) * sign(h[0] - 0.5)
    let u = turn(dx, dy, 6.2832 * g[2] + spin)
    let edge: Double = star(u.x, u.y, r, 0.45)
    let inner: Double = clamp(-edge / (0.35 * r))
    let glintAngle: Double = t * (2 + 2 * g[1]) + 6.2832 * h[1]
    let glint: Double = 0.5 + 0.5 * sin(glintAngle)
    let gold: [Double] = mix([0.93, 0.6, 0.1], [1.0, 0.95, 0.6], inner)
    let silver: [Double] = [0.72 + 0.24 * inner, 0.76 + 0.24 * inner, 0.84 + 0.24 * inner]
    let isSilver: Double = fract(g[2] * 7.31) >= 0.75 ? 1 : 0
    let tone: [Double] = scaled(mix(gold, silver, isSilver), 0.85 + 0.25 * glint)
    let lit: [Double] = [min(tone[0], 1), min(tone[1], 1), min(tone[2], 1)]
    let cover: Double = 1 - smoothstep(-0.012, 0.012, edge)
    return mix(color, lit, alpha * 0.95 * cover)
  }

  private func firefly(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let wanderAngle: Double = t * (0.5 + 0.5 * g[2]) + 6.2832 * g[0]
    let y: Double = dy - 0.06 * sin(wanderAngle)
    let blinkAngle: Double = t * (0.9 + 0.9 * g[0]) + 6.2832 * g[1]
    let blink: Double = smoothstep(0.25, 0.9, 0.5 + 0.5 * sin(blinkAngle))
    let r2: Double = dx * dx + y * y
    let core: Double = exp(-r2 / 0.0008)
    let halo: Double = exp(-r2 / 0.006)
    let tint: [Double] = mix([0.75, 1.0, 0.3], [1.0, 1.0, 0.85], core)
    return glow(color, scaled(tint, blink * alpha * (core + 0.55 * halo)))
  }

  private func ember(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double, height: Double
  ) -> [Double] {
    let jitterAngle: Double = t * (3 + 2 * g[2]) + 6.2832 * g[0]
    let x: Double = dx - 0.03 * sin(jitterAngle)
    let flickerAngle: Double = t * (6 + 6 * g[0]) + 6.2832 * g[1]
    let flicker: Double = 0.6 + 0.4 * sin(flickerAngle)
    let ey: Double = dy * 0.45
    let core: Double = exp(-(x * x + ey * ey) / 0.0006)
    let halo: Double = exp(-(x * x + dy * dy) / 0.0036)
    let hot: [Double] = mix([1.0, 0.32, 0.06], [1.0, 0.72, 0.25], fract(g[2] * 7.31))
    let tint: [Double] = mix(hot, [1.0, 0.92, 0.7], 0.6 * core)
    let fade: Double = 1 - 0.7 * height
    return glow(color, scaled(tint, alpha * flicker * fade * (1.3 * core + 0.5 * halo)))
  }

  private func banknote(
    _ color: [Double], _ dx: Double, _ dy: Double, _ h: [Double], _ g: [Double],
    alpha: Double, seconds t: Double
  ) -> [Double] {
    let tumbleAngle: Double = t * (2 + 2 * g[1]) + 6.2832 * h[1]
    let tumble: Double = abs(cos(tumbleAngle))
    let spin: Double = t * (0.6 + 1.0 * g[0]) * sign(h[0] - 0.5)
    let u = turn(dx, dy, 6.2832 * g[2] + spin)
    let breadth: Double = 0.062 * tumble + 0.004
    let edge: Double = box(u.x, u.y, 0.12, breadth)
    let frame: Double = box(u.x, u.y, 0.106, breadth - 0.014 * tumble)
    let oval: Double = hypot(u.x / 0.12 / 0.3, u.y / breadth / 0.62)
    let dark: [Double] = [0.18, 0.42, 0.24]
    var tone: [Double] = mix([0.6, 0.8, 0.55], dark, smoothstep(-0.003, 0.003, frame))
    tone = mix(tone, [0.78, 0.9, 0.72], 0.6 * (1 - smoothstep(0.8, 0.9, oval)))
    tone = mix(tone, dark, 0.85 * (1 - smoothstep(0.08, 0.16, abs(oval - 1))))
    let cover: Double = 1 - smoothstep(-0.012, 0.012, edge)
    return mix(color, scaled(tone, 0.6 + 0.4 * tumble), alpha * cover)
  }

  private func balloon(
    _ color: [Double], _ dx: Double, _ dy: Double, _ g: [Double], alpha: Double,
    seconds t: Double
  ) -> [Double] {
    let size: Double = 0.16
    let swingAngle: Double = t * (0.6 + 0.6 * g[0]) + 6.2832 * g[1]
    let turned = turn(dx, dy, 0.12 * sin(swingAngle))
    let ux: Double = turned.x / size
    let uy: Double = turned.y / size
    let qy: Double = uy - 0.38
    let taper: Double = 1 - 0.15 * min(max(qy / 0.72, -1), 1)
    let n: Double = hypot(ux * taper / 0.6, qy / 0.72)
    let body: Double = (n - 1) * 0.6
    let knot: Double = hypot(ux, uy + 0.41) - 0.08
    let waveAngle: Double = 6 * uy + 2 * t + 6.2832 * g[1]
    let wave: Double = 0.06 * sin(waveAngle)
    let ends: Double = max(-1.12 - uy, uy + 0.45)
    let line: Double = max(abs(ux - wave) - 0.02, ends)
    let hue: Double = fract(g[2] * 7.31)
    let offsets: [Double] = [0.0, 0.6667, 0.3333]
    var tone = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let ramp: Double = abs(fract(hue + offsets[k]) * 6 - 3) - 1
      tone[k] = (0.2 + 0.8 * clamp(ramp)) * 0.92
    }
    let sx: Double = ux + 0.25
    let sy: Double = qy - 0.3
    let shine: Double = 0.7 * exp(-(sx * sx + sy * sy) / 0.02)
    let skin: [Double] = mix(scaled(tone, 1 - 0.35 * smoothstep(0.3, 1, n)), [1, 1, 1], shine)
    let string: Double = 1 - smoothstep(0, 0.06, line)
    var out: [Double] = mix(color, [0.9, 0.9, 0.9], alpha * 0.7 * string)
    out = mix(out, scaled(tone, 0.7), alpha * (1 - smoothstep(-0.075, 0.075, knot)))
    return mix(out, skin, alpha * 0.95 * (1 - smoothstep(-0.075, 0.075, body)))
  }

  private func tiltShift(_ px: Double, _ py: Double, intensity: Double) -> [Double] {
    let s = Double(min(width, height))
    let away: Double = abs(py / Double(height) - 0.5)
    let r: Double = 0.03 * s * intensity * smoothstep(0.1, 0.42, away)
    var color: [Double] = tap(px, py)
    if r > 0.5 {
      let spin: Double = 6.2832 * noise(px, py)
      for i in 0..<32 {
        let n = Double(i)
        let angle: Double = n * 2.399963 + spin
        let reach: Double = r * ((n + 0.5) / 32).squareRoot()
        let more: [Double] = tap(px + reach * cos(angle), py + reach * sin(angle))
        for k in 0..<3 { color[k] += more[k] }
      }
      for k in 0..<3 { color[k] /= 33 }
    }
    let luma: Double = color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let vivid: Double = luma + (color[k] - luma) * (1 + 0.4 * intensity)
      out[k] = clamp((vivid - 0.5) * (1 + 0.12 * intensity) + 0.5)
    }
    return out
  }

  private func swirl(_ px: Double, _ py: Double, intensity: Double) -> [Double] {
    let cx: Double = Double(width) / 2
    let cy: Double = Double(height) / 2
    let dx: Double = px - cx
    let dy: Double = py - cy
    let w: Double = max(1 - hypot(dx, dy) / (0.5 * Double(min(width, height))), 0)
    let angle: Double = 3 * intensity * w * w
    let co: Double = cos(angle)
    let si: Double = sin(angle)
    return tap(cx + co * dx - si * dy, cy + si * dx + co * dy)
  }

  private func ripple(_ px: Double, _ py: Double, intensity: Double, seconds t: Double)
    -> [Double]
  {
    let cx: Double = Double(width) / 2
    let cy: Double = Double(height) / 2
    let dx: Double = px - cx
    let dy: Double = py - cy
    let r: Double = hypot(dx, dy)
    let s = Double(min(width, height))
    let phase: Double = 6.2832 * fract(r / (0.1 * s) - fract(t * 0.75))
    let fade: Double = smoothstep(0, 0.2 * s, r)
    let push: Double = 0.012 * s * intensity * fade * sin(phase)
    let zoom: Double = 1 - 0.025 * intensity
    let reach: Double = push / max(r, 0.001)
    let color: [Double] = tap(cx + dx * zoom + dx * reach, cy + dy * zoom + dy * reach)
    let light: Double = 1 + 0.12 * intensity * fade * cos(phase)
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 { out[k] = clamp(color[k] * light) }
    return out
  }

  private func flutedGlass(_ px: Double, _ py: Double, intensity: Double) -> [Double] {
    let rib: Double = 0.08 * Double(min(width, height))
    let across: Double = fract((px - 0.5 * Double(width)) / rib + 0.5) - 0.5
    let x: Double = abs(px + 1.5 * intensity * across * rib)
    let color: [Double] = tap(Double(width) - abs(Double(width) - x), py)
    let shade: Double = 1 - 0.6 * intensity * across * across
    let glint: Double = 1 - smoothstep(0, 0.15, abs(across + 0.22))
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 { out[k] = clamp(color[k] * shade + 0.1 * intensity * glint) }
    return out
  }

  private func zoomBlur(_ px: Double, _ py: Double, strength: Double) -> [Double] {
    let cx: Double = Double(width) / 2
    let cy: Double = Double(height) / 2
    let jitter: Double = noise(px, py)
    var color = [Double](repeating: 0, count: 3)
    for i in 0..<32 {
      let share: Double = (Double(i) + jitter) / 32
      let reach: Double = 1 - 0.22 * strength * share
      let more: [Double] = tap(cx + (px - cx) * reach, cy + (py - cy) * reach)
      for k in 0..<3 { color[k] += more[k] }
    }
    for k in 0..<3 { color[k] /= 32 }
    return color
  }

  private func luma(_ c: [Double]) -> Double { c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114 }

  private func comic(_ px: Double, _ py: Double, intensity: Double) -> [Double] {
    let s = Double(min(width, height))
    let e: Double = max(1, s / 540)
    let color: [Double] = tap(px, py)
    let tl: Double = luma(tap(px - e, py + e))
    let tc: Double = luma(tap(px, py + e))
    let tr: Double = luma(tap(px + e, py + e))
    let ml: Double = luma(tap(px - e, py))
    let mr: Double = luma(tap(px + e, py))
    let bl: Double = luma(tap(px - e, py - e))
    let bc: Double = luma(tap(px, py - e))
    let br: Double = luma(tap(px + e, py - e))
    let gx: Double = tr + 2 * mr + br - tl - 2 * ml - bl
    let gy: Double = tl + 2 * tc + tr - bl - 2 * bc - br
    let ink: Double = smoothstep(0.3, 0.8, hypot(gx, gy))
    let l: Double = luma(color)
    let band: Double = 0.2 + 0.27 * min((l * 4).rounded(.down), 3)
    let cell: Double = 0.018 * s
    let gridX: Double = (px + py) * 0.70710678 / cell
    let gridY: Double = (py - px) * 0.70710678 / cell
    let dx: Double = (fract(gridX) - 0.5) * cell
    let dy: Double = (fract(gridY) - 0.5) * cell
    let radius: Double = 0.6 * cell * max(0.7 - l, 0).squareRoot()
    let spot: Double = clamp(radius - hypot(dx, dy))
    var out = [Double](repeating: 0, count: 3)
    for k in 0..<3 {
      let vivid: Double = l + (color[k] - l) * 1.4
      let poster: Double = clamp(vivid * band / max(l, 0.04))
      let comic: Double = poster * (1 - 0.35 * spot) * (1 - 0.85 * ink)
      out[k] = color[k] + (comic - color[k]) * intensity
    }
    return out
  }
}

/// Highlights, shadows, vibrance and sharpening are drawn with a Metal kernel
/// on iOS and macOS, and with the same shader in GLSL on Android
/// (`AdjustVideoEffect`). This checks every pixel of the kernel against the
/// shader's formulas computed here on the CPU, for the whole frame and for a
/// tile Core Image renders on its own, so a change to the kernel that the
/// formulas here do not share fails, and so does a kernel that reads its
/// textures upside down or samples outside the region it asked for. No test
/// runs the Android copy: a change to it has to be made here as well.
final class AdjustVideoEffectTests: XCTestCase {
  private let width = 90
  private let height = 160

  func testDrawsWhatTheAndroidShaderDraws() {
    // Brightness ramps up the frame for the tone curve, with a
    // checkerboard in the bottom quarter for the sharpening; red runs ahead
    // of green and blue, so skin-like tones and saturated ones both occur.
    var rgb = [Double](repeating: 0, count: width * height * 3)
    for y in 0..<height {
      for x in 0..<width {
        let i = (y * width + x) * 3
        let fx = (Double(x) + 0.5) / Double(width), fy = (Double(y) + 0.5) / Double(height)
        let isLight = (x / 3 + y / 3) % 2 == 0
        let check: Double = y < 40 ? (isLight ? 0.08 : -0.08) : 0
        rgb[i] = min(max(fy + check, 0), 1)
        rgb[i + 1] = fy * (0.4 + 0.6 * fx)
        rgb[i + 2] = fy * fx * fx
      }
    }
    // A bitmap's first row is the top of the image, Core Image's y = 0 the bottom.
    var pixels = [Float](repeating: 1, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let s = (y * width + x) * 3, d = ((height - 1 - y) * width + x) * 4
        for k in 0..<3 { pixels[d + k] = Float(rgb[s + k]) }
      }
    }
    let frame = CIImage(
      bitmapData: Data(bytes: pixels, count: pixels.count * 4),
      bytesPerRow: width * 16,
      size: CGSize(width: width, height: height),
      format: .RGBAf,
      colorSpace: nil)
    let context = CIContext(options: [.workingColorSpace: NSNull()])

    // Params, and the values the shader draws them with: out of range ones
    // are clamped, as on Android.
    let cases: [([String: Any], (h: Double, s: Double, v: Double, k: Double))] = [
      (["highlights": -1.0], (-1, 0, 0, 0)),
      (["highlights": 1.0, "shadows": -1.0], (1, -1, 0, 0)),
      (["shadows": 1.0, "vibrance": 1.0], (0, 1, 1, 0)),
      (["vibrance": -1.0, "sharpen": 1.0], (0, 0, -1, 1)),
      (["highlights": -0.6, "shadows": 0.7, "vibrance": 0.5, "sharpen": 0.4], (-0.6, 0.7, 0.5, 0.4)),
      (["highlights": -3.0, "sharpen": -0.5], (-1, 0, 0, 0)),
      ([:], (0, 0, 0, 0)),
    ]
    let tile = CGRect(x: 20, y: 50, width: 31, height: 47)
    for (params, values) in cases {
      let output = AdjustVideoEffect(params: params)
        .render(frame, history: [], timeUs: 0, effectTimeUs: 0)
      XCTAssertEqual(output.extent, frame.extent)
      let expected = draw(rgb, values)
      for bounds in [frame.extent, tile] {
        let w = Int(bounds.width), h = Int(bounds.height)
        var drawn = [Float](repeating: 0, count: w * h * 4)
        drawn.withUnsafeMutableBytes {
          context.render(
            output.cropped(to: bounds), toBitmap: $0.baseAddress!, rowBytes: w * 16,
            bounds: bounds, format: .RGBAf, colorSpace: nil)
        }
        let left = Int(bounds.minX), bottom = Int(bounds.minY)
        var worst = 0.0
        for y in 0..<h {
          for x in 0..<w {
            for k in 0..<3 {
              let got = Double(drawn[((h - 1 - y) * w + x) * 4 + k])
              worst = max(worst, abs(got - expected[((y + bottom) * width + x + left) * 3 + k]))
            }
          }
        }
        // Half-float textures round to about 0.0005.
        XCTAssertLessThan(worst, 0.003, "\(params) in \(bounds)")
      }
    }
  }

  /// The shader on the CPU, for an RGB frame stored bottom row first.
  private func draw(_ rgb: [Double], _ v: (h: Double, s: Double, v: Double, k: Double))
    -> [Double]
  {
    let w = Double(width), h = Double(height)
    func tap(_ qx: Double, _ qy: Double) -> [Double] {
      let x = min(max(qx, 0.5), w - 0.5) - 0.5, y = min(max(qy, 0.5), h - 0.5) - 0.5
      let x0 = Int(x), y0 = Int(y), x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
      let fx = x - Double(x0), fy = y - Double(y0)
      return (0..<3).map { k in
        let row0 = rgb[(y0 * width + x0) * 3 + k] * (1 - fx) + rgb[(y0 * width + x1) * 3 + k] * fx
        let row1 = rgb[(y1 * width + x0) * 3 + k] * (1 - fx) + rgb[(y1 * width + x1) * 3 + k] * fx
        return row0 * (1 - fy) + row1 * fy
      }
    }
    func luma(_ c: [Double]) -> Double { c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722 }
    func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
    func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
      let t = unit((x - a) / (b - a))
      return t * t * (3 - 2 * t)
    }

    let r = max(1, 1.5 * min(w, h) / 1080)
    var out = [Double](repeating: 0, count: rgb.count)
    for yi in 0..<height {
      for xi in 0..<width {
        let px = Double(xi) + 0.5, py = Double(yi) + 0.5
        var color = tap(px, py)
        if v.k > 0 {
          let y = luma(color)
          let edges = [
            luma(tap(px + r, py)), luma(tap(px - r, py)),
            luma(tap(px, py + r)), luma(tap(px, py - r)),
          ]
          let corners = [
            luma(tap(px + r, py + r)), luma(tap(px - r, py + r)),
            luma(tap(px + r, py - r)), luma(tap(px - r, py - r)),
          ]
          let edgeSum: Double = edges.reduce(0, +)
          let cornerSum: Double = corners.reduce(0, +)
          let blur = (4 * y + 2 * edgeSum + cornerSum) / 16
          let around = edges + corners + [y]
          let sharp = min(max(y + 3 * v.k * (y - blur), around.min()!), around.max()!)
          color = color.map { unit($0 + sharp - y) }
        }
        let l = luma(color), dark = 1 - l
        let lows = l * dark * dark * dark * dark * 12.20703125
        let highs = l * l * l * l * dark * 12.20703125
        let shadowGain: Double = v.s > 0 ? 0.2 : 0.065
        let highlightGain: Double = v.h < 0 ? 0.2 : 0.065
        let toned = l + v.s * shadowGain * lows + v.h * highlightGain * highs
        color = color.map { unit(l > 0.0001 ? $0 * (toned / l) : $0 + (toned - l)) }
        if v.v != 0 {
          let chroma = color.max()! - color.min()!
          var skin = 0.0
          if color[0] >= color[1] && color[1] >= color[2] && chroma > 0.0001 {
            let hue = (color[1] - color[2]) / chroma
            let hueWeight = smoothstep(0.05, 0.25, hue) * (1 - smoothstep(0.6, 0.85, hue))
            let chromaWeight =
              smoothstep(0.02, 0.08, chroma) * (1 - smoothstep(0.5, 0.75, chroma))
            skin = hueWeight * chromaWeight
          }
          let keep = 1 - 0.85 * skin
          let amount: Double
          if v.v > 0 {
            amount = v.v * 1.25 * (1 - chroma) * (1 - chroma) * keep
          } else {
            amount = v.v * (0.4 + 0.6 * chroma) * keep
          }
          let grey = luma(color)
          color = color.map { unit(grey + ($0 - grey) * (1 + amount)) }
        }
        for k in 0..<3 { out[(yi * width + xi) * 3 + k] = color[k] }
      }
    }
    return out
  }
}
