import XCTest
import WebKit
import divine_camera
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
