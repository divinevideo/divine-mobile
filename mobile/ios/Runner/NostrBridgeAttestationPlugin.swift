import Flutter
import WebKit
import webview_flutter_wkwebview

/// Thin native plugin that replaces the pigeon-managed WKScriptMessageHandler
/// for `divineSandboxBridge` with one that includes WKScriptMessage.frameInfo,
/// and streams attested messages (with isMainFrame) back to Dart via an
/// EventChannel. Optionally installs a document-start WKUserScript so the
/// Dart layer does not need to import private webview_flutter_wkwebview src
/// types to do that itself.
///
/// The pigeon layer exposes WKScriptMessage.name and .body only; .frameInfo is
/// absent from the pigeon definition, so this plugin is required to surface it.
///
/// Lifecycle is single-instance: only one sandbox WebView may be attached at
/// a time. Attempting to attach a second WebView while another is still
/// attached returns ALREADY_ATTACHED so the Dart layer can log the degraded
/// security posture and fall back to nonce-only enforcement instead of
/// silently overwriting the previous sink.
///
/// Dart drives lifecycle via two calls:
///   attach(webViewId, bootstrapScript?) — replaces the handler, optionally
///                                         installs a document-start script
///   detach(webViewId)                   — removes the handler
///
/// The EventChannel delivers maps:
///   { "message": String, "isMainFrame": Bool }
final class NostrBridgeAttestationPlugin: NSObject, FlutterStreamHandler {
  static let methodChannelName = "co.openvine/nostr_bridge_attestation"
  static let eventChannelName = "co.openvine/nostr_bridge_attestation/events"
  static let bridgeChannelName = "divineSandboxBridge"
  private static let logTag = "[NostrBridgeAttestation]"

  // Process-lifetime, not engine-lifetime: nothing ever clears this. Anything
  // it transitively holds must stay weak or engine-free (see pluginRegistry).
  private static var shared: NostrBridgeAttestationPlugin?

  /// Weak on purpose: on iOS this registry *is* the `FlutterEngine`
  /// (`FlutterImplicitEngineBridgeImpl.pluginRegistry` returns `_engine`).
  /// Held strongly from the `shared` static above it pinned the engine for the
  /// process lifetime, and `-[FlutterEngine dealloc]` is the only non-test
  /// place Flutter dispatches `detachFromEngineForRegistrar:` — so the pin
  /// disabled `detachFromEngine(for:)` for every plugin in the app (#9393).
  private weak var pluginRegistry: FlutterPluginRegistry?
  private let policy = NostrBridgeAttestationPolicy()
  private var handler: FrameAttestingScriptMessageHandler?
  private var eventSink: FlutterEventSink?

  private init(pluginRegistry: FlutterPluginRegistry) {
    self.pluginRegistry = pluginRegistry
  }

  // MARK: - Registration (called from AppDelegate)

  static func setup(
    messenger: FlutterBinaryMessenger,
    pluginRegistry: FlutterPluginRegistry
  ) {
    let plugin = NostrBridgeAttestationPlugin(pluginRegistry: pluginRegistry)
    shared = plugin

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak plugin] call, result in
      plugin?.handle(call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(plugin)
  }

  // MARK: - Method channel handler

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let webViewId = args["webViewId"] as? Int64
    else {
      NSLog("\(Self.logTag) attach/detach called without Int64 webViewId")
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "webViewId (Int64) required",
        details: nil
      ))
      return
    }

    switch call.method {
    case "attach":
      let bootstrapScript = args["bootstrapScript"] as? String
      attachHandler(
        webViewId: webViewId,
        bootstrapScript: bootstrapScript,
        result: result
      )
    case "detach":
      detachHandler(webViewId: webViewId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(
    withArguments _: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - Private

  /// Resolves webview-flutter's `WKWebView` for [webViewId], or nil once the
  /// engine is gone — `pluginRegistry` is weak, so a torn-down engine reads
  /// nil here. Both callers already treat a missing WebView as a recoverable
  /// miss, so a dead engine takes the same path as a stale identifier.
  private func resolveWebView(webViewId: Int64) -> WKWebView? {
    guard let pluginRegistry else { return nil }
    return FWFWebViewFlutterWKWebViewExternalAPI.webView(
      forIdentifier: webViewId,
      withPluginRegistry: pluginRegistry
    )
  }

  private func attachHandler(
    webViewId: Int64,
    bootstrapScript: String?,
    result: FlutterResult
  ) {
    switch policy.attach(webViewId: webViewId) {
    case .noOp:
      result(nil)
      return
    case .alreadyAttached(let existing):
      NSLog(
        "\(Self.logTag) attach refused: already attached to \(existing); requested \(webViewId). Dart will fall back to nonce-only enforcement."
      )
      result(FlutterError(
        code: "ALREADY_ATTACHED",
        message: "Sandbox attestation already attached to webView \(existing)",
        details: nil
      ))
      return
    case .ok:
      break
    }

    guard let webView = resolveWebView(webViewId: webViewId) else {
      // Roll back the policy state since the actual attach failed.
      _ = policy.detach(webViewId: webViewId)
      NSLog(
        "\(Self.logTag) attach failed: no WKWebView found for identifier \(webViewId). Dart will fall back to nonce-only enforcement."
      )
      result(FlutterError(
        code: "WEBVIEW_NOT_FOUND",
        message: "No WKWebView found for identifier \(webViewId)",
        details: nil
      ))
      return
    }

    let contentController = webView.configuration.userContentController

    // Remove the pigeon-managed handler installed by addJavaScriptChannel.
    // The WKUserScript that creates window.divineSandboxBridge as an alias
    // for webkit.messageHandlers.divineSandboxBridge remains intact and
    // continues to route postMessage() calls to whichever handler owns the
    // name — now ours.
    contentController.removeScriptMessageHandler(
      forName: NostrBridgeAttestationPlugin.bridgeChannelName
    )

    let attestingHandler = FrameAttestingScriptMessageHandler { [weak self] event in
      self?.eventSink?(event)
    }
    contentController.add(
      attestingHandler,
      name: NostrBridgeAttestationPlugin.bridgeChannelName
    )
    handler = attestingHandler

    if let bootstrapScript, !bootstrapScript.isEmpty {
      let userScript = WKUserScript(
        source: bootstrapScript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      )
      contentController.addUserScript(userScript)
    }

    result(nil)
  }

  private func detachHandler(webViewId: Int64) {
    guard policy.detach(webViewId: webViewId) else { return }

    // The WKWebView may already be deallocated by the time Dart tears down,
    // so a missing lookup here is expected and not an error worth logging.
    if let webView = resolveWebView(webViewId: webViewId) {
      webView.configuration.userContentController
        .removeScriptMessageHandler(forName: NostrBridgeAttestationPlugin.bridgeChannelName)
    }
    handler = nil
  }
}

// MARK: - NostrBridgeAttestationPolicy

/// Pure state machine for single-instance attestation lifecycle. Extracted so
/// the attach/detach decisions can be unit tested without a real WKWebView or
/// plugin registry.
final class NostrBridgeAttestationPolicy {
  enum AttachResult: Equatable {
    /// Newly attached the given webViewId.
    case ok
    /// Idempotent re-attach to the same webViewId; nothing to do.
    case noOp
    /// A different webViewId is already attached; the request must be refused.
    case alreadyAttached(existing: Int64)
  }

  private(set) var attachedWebViewId: Int64?

  func attach(webViewId: Int64) -> AttachResult {
    if let existing = attachedWebViewId {
      if existing == webViewId { return .noOp }
      return .alreadyAttached(existing: existing)
    }
    attachedWebViewId = webViewId
    return .ok
  }

  /// Returns true when the call cleared a matching attachment, false when the
  /// id was not attached (so the caller can skip teardown work).
  func detach(webViewId: Int64) -> Bool {
    guard attachedWebViewId == webViewId else { return false }
    attachedWebViewId = nil
    return true
  }
}

// MARK: - FrameAttestingScriptMessageHandler

final class FrameAttestingScriptMessageHandler: NSObject, WKScriptMessageHandler {
  private let deliver: ([String: Any]) -> Void

  init(deliver: @escaping ([String: Any]) -> Void) {
    self.deliver = deliver
  }

  func userContentController(
    _: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    deliver(Self.eventPayload(
      messageBody: message.body as? String ?? "",
      isMainFrame: message.frameInfo.isMainFrame
    ))
  }

  /// Pure translation from the security-relevant fields of WKScriptMessage to
  /// the Dart event payload. Extracted so the dictionary shape is testable
  /// without constructing a real WKScriptMessage.
  static func eventPayload(messageBody: String, isMainFrame: Bool) -> [String: Any] {
    return [
      "message": messageBody,
      "isMainFrame": isMainFrame,
    ]
  }
}
