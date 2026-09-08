// ABOUTME: Dedicated integration container for approved third-party apps
// ABOUTME: Blocks navigation outside approved origins before bridge injection is added

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_bridge.dart';
import 'package:openvine/widgets/apps/nostr_app_permission_prompt_sheet.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

typedef SandboxViewBuilder = Widget Function(
  void Function(Uri uri) onNavigationAttempt,
);
typedef SandboxJavaScriptRunner = Future<void> Function(String script);
typedef SandboxImageMetadataStripper = Future<File> Function(File imageFile);

const _bridgePayloadObjectMessage = 'Bridge payload must be a JSON object';
const _bridgeMethodRequiredMessage = 'Bridge method is required';
const _bridgeArgsObjectMessage = 'Bridge args must be an object';
const Set<String> _safeBridgeFormatMessages = {
  _bridgePayloadObjectMessage,
  _bridgeMethodRequiredMessage,
  _bridgeArgsObjectMessage,
};

class NostrAppSandboxScreen extends ConsumerStatefulWidget {
  static const routeName = 'nostr-app-sandbox';
  static const path = '/apps/:appId/sandbox';
  static const bridgeChannelName = 'divineSandboxBridge';

  const NostrAppSandboxScreen({
    required this.app,
    this.sandboxBuilder,
    this.onNavigationHandlerReady,
    this.bridgeServiceOverride,
    this.bootstrapHttpClientOverride,
    this.javaScriptRunnerOverride,
    this.onBridgeMessageHandlerReady,
    this.onAttestedEventHandlerReady,
    this.currentUserPubkeyOverride,
    this.bridgeNonceOverride,
    super.key,
  });

  final NostrAppDirectoryEntry app;
  final SandboxViewBuilder? sandboxBuilder;
  final ValueChanged<void Function(Uri uri)>? onNavigationHandlerReady;
  final NostrAppBridgeService? bridgeServiceOverride;
  final http.Client? bootstrapHttpClientOverride;
  final SandboxJavaScriptRunner? javaScriptRunnerOverride;
  final ValueChanged<Future<void> Function(String message)>?
  onBridgeMessageHandlerReady;
  @visibleForTesting
  final ValueChanged<void Function(dynamic event)>? onAttestedEventHandlerReady;
  @visibleForTesting
  final String? currentUserPubkeyOverride;
  @visibleForTesting
  final String? bridgeNonceOverride;

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/sandbox';

  @override
  ConsumerState<NostrAppSandboxScreen> createState() =>
      _NostrAppSandboxScreenState();
}

class _NostrAppSandboxScreenState extends ConsumerState<NostrAppSandboxScreen> {
  // iOS/Android frame attestation channels.
  static const MethodChannel _attestationMethodChannel = MethodChannel(
    'co.openvine/nostr_bridge_attestation',
  );
  static const EventChannel _attestationEventChannel = EventChannel(
    'co.openvine/nostr_bridge_attestation/events',
  );

  WebViewController? _webViewController;
  bool _isLoading = true;
  Uri? _blockedUri;
  Uri? _currentPageUri;
  http.Client? _ownedBootstrapHttpClient;
  late final String _bridgeNonce;
  bool _isNativeAttestationActive = false;
  StreamSubscription<dynamic>? _attestedMessageSubscription;

  String? get _currentUserPubkey =>
      widget.currentUserPubkeyOverride ??
      ref.read(authServiceProvider).currentPublicKeyHex;

  @override
  void initState() {
    super.initState();
    _currentPageUri = Uri.parse(widget.app.launchUrl);
    _bridgeNonce = widget.bridgeNonceOverride ?? _generateBridgeNonce();
    widget.onNavigationHandlerReady?.call(_handleNavigationAttempt);
    widget.onBridgeMessageHandlerReady?.call(_handleBridgeMessage);
    widget.onAttestedEventHandlerReady?.call(_handleAttestedEvent);

    if (widget.sandboxBuilder != null) {
      return;
    }

    final launchUri = Uri.parse(widget.app.launchUrl);
    final controller = _createWebViewController();
    _webViewController = controller;
    unawaited(_configureAndLoadController(controller, launchUri));
  }

  @override
  void dispose() {
    _attestedMessageSubscription?.cancel();
    if (_isNativeAttestationActive) {
      final webViewId = _attestationWebViewId();
      if (webViewId != null) {
        unawaited(
          _attestationMethodChannel.invokeMethod<void>(
            'detach',
            {'webViewId': webViewId},
          ),
        );
      }
    }
    _ownedBootstrapHttpClient?.close();
    super.dispose();
  }

  /// The native WebView identifier for the active controller, on whichever
  /// platform exposes one. Used to address attach/detach to the right WebView.
  int? _attestationWebViewId() {
    final platformController = _webViewController?.platform;
    return switch (platformController) {
      WebKitWebViewController() => platformController.webViewIdentifier,
      AndroidWebViewController() => platformController.webViewIdentifier,
      _ => null,
    };
  }

  bool _handleNavigationAttempt(Uri uri) {
    if (_isAllowedNavigationOrigin(uri)) {
      if (_blockedUri != null && mounted) {
        setState(() {
          _blockedUri = null;
        });
      }
      return true;
    }

    if (!mounted) return false;
    setState(() {
      _blockedUri = uri;
      _isLoading = false;
    });
    return false;
  }

  bool _isAllowedNavigationOrigin(Uri uri) {
    return _isAllowedOrigin(uri, [
      ...widget.app.allowedOrigins,
      ...widget.app.allowedNavigationOrigins,
    ]);
  }

  bool _isAllowedBridgeOrigin(Uri uri) {
    return _isAllowedOrigin(uri, widget.app.allowedOrigins);
  }

  bool _isAllowedOrigin(Uri uri, List<String> allowedOrigins) {
    return allowedOrigins.any((allowedOrigin) {
      final parsedAllowed = Uri.tryParse(allowedOrigin);
      return parsedAllowed != null && parsedAllowed.origin == uri.origin;
    });
  }

  static String _generateBridgeNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  NostrAppBridgeService get _bridgeService =>
      widget.bridgeServiceOverride ?? ref.read(nostrAppBridgeServiceProvider);

  http.Client get _bootstrapHttpClient =>
      widget.bootstrapHttpClientOverride ??
      (_ownedBootstrapHttpClient ??= http.Client());

  WebViewController _createWebViewController() {
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params =
          WebKitWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
            params,
          );
    }

    return WebViewController.fromPlatformCreationParams(params);
  }

  Future<void> _configureAndLoadController(
    WebViewController controller,
    Uri launchUri,
  ) async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      // Read after the first await: this runs from initState, and
      // Theme.of() is illegal until initState has returned.
      if (!mounted) return;
      await controller.setBackgroundColor(context.vineColors.background);
    }

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          _currentPageUri = Uri.tryParse(url) ?? _currentPageUri;
          if (!mounted) return;
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (url) async {
          _currentPageUri = Uri.tryParse(url) ?? _currentPageUri;
          await _injectBridge();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (_) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) {
            return NavigationDecision.prevent;
          }

          if (!_handleNavigationAttempt(uri)) {
            return NavigationDecision.prevent;
          }

          if (_shouldBootstrapNavigation(request, uri)) {
            unawaited(_loadSandboxPage(uri));
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    await controller.addJavaScriptChannel(
      NostrAppSandboxScreen.bridgeChannelName,
      onMessageReceived: (message) {
        // On iOS, the native attesting handler replaces this pigeon handler
        // after attach() completes. This guard prevents double-handling during
        // the brief setup window before replacement.
        if (!_isNativeAttestationActive) {
          unawaited(_handleBridgeMessage(message.message));
        }
      },
    );

    // Without this, `webview_flutter` silently ignores HTML file inputs on
    // Android, so image uploads inside sandboxed apps (e.g. badges) do nothing.
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      final imagePicker = ImagePicker();
      await platformController.setOnShowFileSelector(
        (params) => sandboxAndroidFileSelector(params, imagePicker),
      );
      // The picker hands back a file:// URI; the WebView can only read it with
      // file access enabled, which defaults to false on Android 11+. Without
      // this the file is chosen but never populates the <input> (0-byte read).
      // The https sandbox document still can't script-read local file
      // contents: same-origin policy blocks fetch/XHR to file://, and canvas
      // tainting blocks reading back <img src="file://…"> pixels. (The
      // setAllow*FileURLs knobs govern file://-origin documents, which we
      // never load, so they stay at their safe defaults.)
      await platformController.setAllowFileAccess(true);
    }

    // Replace the pigeon message channel with the native frame-attesting one
    // (iOS: WKScriptMessageHandler reading frameInfo; Android: WebMessageListener
    // reporting isMainFrame). Must run before the page loads so the native
    // handler is in place when the bridge fires its first postMessage.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await _activateNativeAttestation(controller);
    }

    await _loadSandboxPage(launchUri);
  }

  bool _shouldBootstrapNavigation(NavigationRequest request, Uri uri) {
    return defaultTargetPlatform == TargetPlatform.android &&
        request.isMainFrame &&
        _isAllowedBridgeOrigin(uri);
  }

  /// Activates platform-level frame attestation by replacing the pigeon-managed
  /// message channel with a native one that surfaces the platform-attested main-
  /// frame signal. Attested messages then arrive via the EventChannel instead of
  /// the `addJavaScriptChannel` callback.
  ///
  /// - iOS: swaps the `WKScriptMessageHandler` for one that reads
  ///   `WKScriptMessage.frameInfo.isMainFrame`, and hands off the document-start
  ///   bootstrap script to the native plugin as a `WKUserScript`.
  /// - Android: swaps the `divineSandboxBridge` JS interface for a
  ///   `WebViewCompat.addWebMessageListener` whose listener reports `isMainFrame`,
  ///   scoped to the app's allowed origins. The bootstrap is still injected via
  ///   the HTML-rewrite path; the listener's injected JS object exposes the same
  ///   `.postMessage` API the bootstrap already calls.
  ///
  /// Falls back to nonce-only enforcement when the native plugin is unavailable
  /// (tests that don't configure the channel; a previous sandbox still attached;
  /// `WEB_MESSAGE_LISTENER` unsupported; no resolvable allowed origins). Logs a
  /// warning so the degraded security posture is visible in unified logs.
  Future<void> _activateNativeAttestation(WebViewController controller) async {
    final platformController = controller.platform;
    final Map<String, Object?> attachArgs;
    if (platformController is WebKitWebViewController) {
      attachArgs = {
        'webViewId': platformController.webViewIdentifier,
        'bootstrapScript': buildBridgeBootstrapScript(
          nonce: _bridgeNonce,
          pubkey: _currentUserPubkey,
          autoLoginScript: widget.app.autoLoginScript,
        ),
      };
    } else if (platformController is AndroidWebViewController) {
      final allowedOriginRules = webMessageAllowedOriginRules(
        widget.app.allowedOrigins,
      );
      if (allowedOriginRules.isEmpty) {
        // No resolvable origins to scope the listener to. Keep the nonce-only
        // JS-channel path rather than removing it for a listener that would
        // never be injected into any frame.
        return;
      }
      attachArgs = {
        'webViewId': platformController.webViewIdentifier,
        'allowedOriginRules': allowedOriginRules,
      };
    } else {
      return;
    }

    try {
      await _attestationMethodChannel.invokeMethod<void>('attach', attachArgs);
      _isNativeAttestationActive = true;
      _attestedMessageSubscription = _attestationEventChannel
          .receiveBroadcastStream()
          .listen(_handleAttestedEvent);
    } on PlatformException catch (error) {
      Log.warning(
        'Native frame attestation unavailable (${error.code}); '
        'falling back to nonce-only enforcement.',
        name: 'NostrAppSandboxScreen',
        category: LogCategory.system,
      );
    } on MissingPluginException catch (_) {
      // Channel is not registered (tests, simulator/emulator without the plugin
      // set up). Nonce gate remains the only defence in this case.
    }
  }

  /// Handles a message delivered by the native frame-attesting handler.
  ///
  /// Rejects non-main-frame messages before the nonce check: the platform
  /// itself reports isMainFrame, so no JS can spoof this value.
  void _handleAttestedEvent(dynamic event) {
    if (event is! Map) {
      Log.warning(
        'Unexpected attestation event shape: ${event.runtimeType}',
        name: 'NostrAppSandboxScreen',
        category: LogCategory.system,
      );
      return;
    }
    final message = event['message'] as String? ?? '';
    final isMainFrame = event['isMainFrame'] as bool? ?? false;

    if (!isMainFrame) {
      String responseId = 'unknown';
      try {
        final payload = jsonDecode(message);
        if (payload is Map) {
          responseId = payload['id']?.toString() ?? 'unknown';
        }
      } on FormatException {
        // Best-effort id extraction; subframe rejection is unconditional
        // regardless of payload validity. Real invariant bugs (StateError,
        // TypeError) are intentionally not swallowed here.
      }
      unawaited(
        _emitBridgeResponse(
          id: responseId,
          result: const BridgeResult.error('subframe_rejected'),
        ),
      );
      return;
    }

    unawaited(_handleBridgeMessage(message));
  }

  Future<void> _loadSandboxPage(Uri uri) async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _blockedUri = null;
      });
    }

    final bootstrap = await _prepareBootstrapHtml(uri);
    if (bootstrap != null) {
      _currentPageUri = bootstrap.baseUri;
      await controller.loadHtmlString(
        bootstrap.html,
        baseUrl: bootstrap.baseUri.toString(),
      );
      return;
    }

    _currentPageUri = uri;
    await controller.loadRequest(uri);
  }

  Future<_BootstrappedSandboxPage?> _prepareBootstrapHtml(Uri uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final response = await _bootstrapHttpClient.get(
        uri,
        headers: const {'accept': 'text/html,application/xhtml+xml'},
      );
      if (response.body.isEmpty || !_isBootstrappableHtml(response)) {
        return null;
      }

      final resolvedUri = response.request?.url ?? uri;
      if (!_isAllowedBridgeOrigin(resolvedUri)) {
        return null;
      }

      return _BootstrappedSandboxPage(
        baseUri: resolvedUri,
        html: injectBridgeBootstrapIntoHtml(
          response.body,
          nonce: _bridgeNonce,
          pubkey: _currentUserPubkey,
          autoLoginScript: widget.app.autoLoginScript,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _injectBridge() async {
    final origin = _currentPageUri;
    if (origin == null || !_isAllowedBridgeOrigin(origin)) {
      return;
    }

    final fullScript = buildBridgeBootstrapScript(
      nonce: _bridgeNonce,
      pubkey: _currentUserPubkey,
      autoLoginScript: widget.app.autoLoginScript,
    );
    await _runJavaScript(fullScript);
  }

  bool _isBootstrappableHtml(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return true;
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final bodyStart = response.body.trimLeft().toLowerCase();
    final looksLikeHtml =
        contentType.contains('text/html') ||
        bodyStart.startsWith('<!doctype html') ||
        bodyStart.startsWith('<html');
    return statusCode == 404 && looksLikeHtml;
  }

  Future<void> _handleBridgeMessage(String message) async {
    String responseId = 'unknown';

    try {
      final payload = jsonDecode(message);
      if (payload is! Map) {
        throw const FormatException(_bridgePayloadObjectMessage);
      }

      final request = payload.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      responseId = request['id']?.toString() ?? 'unknown';
      final nonce = request['nonce']?.toString();
      if (nonce == null || nonce != _bridgeNonce) {
        // Bridge message arrived without (or with the wrong) per-mount
        // nonce — most likely an iframe calling the JS channel directly,
        // bypassing the bootstrap script. Refuse before evaluating.
        await _emitBridgeResponse(
          id: responseId,
          result: const BridgeResult.error('subframe_or_unauthorized'),
        );
        return;
      }
      final method = request['method']?.toString();
      final args = request['args'];

      if (method == null || method.isEmpty) {
        throw const FormatException(_bridgeMethodRequiredMessage);
      }
      if (args is! Map) {
        throw const FormatException(_bridgeArgsObjectMessage);
      }

      final origin = _currentPageUri ?? Uri.parse(widget.app.launchUrl);
      final result = await _bridgeService.handleRequest(
        app: widget.app,
        origin: origin,
        method: method,
        args: args.map((key, value) => MapEntry(key.toString(), value)),
        promptForPermission: _showPermissionPrompt,
      );

      await _emitBridgeResponse(id: responseId, result: result);
    } catch (error) {
      await _emitBridgeResponse(
        id: responseId,
        result: BridgeResult.error(
          'invalid_request',
          errorMessage: _safeBridgeErrorMessage(error),
        ),
      );
    }
  }

  String? _safeBridgeErrorMessage(Object error) {
    final message = error is FormatException ? error.message : null;
    return _safeBridgeFormatMessages.contains(message) ? message : null;
  }

  Future<bool> _showPermissionPrompt(BridgePermissionRequest request) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: VineTheme.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: NostrAppPermissionPromptSheet(
            appName: request.app.name,
            origin: request.origin.origin,
            method: request.method,
            capability: request.capability,
            eventKind: request.eventKind,
            onAllow: () => bottomSheetContext.popModalIfMounted(true),
            onCancel: () => bottomSheetContext.popModalIfMounted(false),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _emitBridgeResponse({
    required String id,
    required BridgeResult result,
  }) async {
    final payload = {
      'id': id,
      'success': result.success,
      if (result.success) 'result': result.data,
      if (!result.success)
        'error': {
          'code': result.errorCode ?? 'bridge_error',
          if (result.errorMessage != null) 'message': result.errorMessage,
        },
    };

    final encodedPayload = jsonEncode(payload);
    await _runJavaScript(
      'window.__divineNostrBridge?.handleResponse($encodedPayload);',
    );
  }

  Future<void> _runJavaScript(String script) async {
    final overrideRunner = widget.javaScriptRunnerOverride;
    if (overrideRunner != null) {
      await overrideRunner(script);
      return;
    }

    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    await controller.runJavaScript(script);
  }

  Future<void> _handleBackPressed() async {
    final controller = _webViewController;
    if (controller != null) {
      final canGoBack = await controller.canGoBack();
      if (canGoBack) {
        await controller.goBack();
        return;
      }
    }

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: widget.app.name,
        showBackButton: true,
        onBackPressed: () {
          unawaited(_handleBackPressed());
        },
      ),
      backgroundColor: context.vineColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildSandboxBody()),
          if (_blockedUri != null)
            Positioned.fill(
              child: _SandboxStatusCard(
                title: context.l10n.appsSandboxBlockedTitle,
                subtitle: context.l10n.appsSandboxBlockedSubtitle(
                  _blockedUri!.toString(),
                ),
              ),
            )
          else if (_isLoading)
            Positioned.fill(
              child: _SandboxStatusCard(
                title: context.l10n.appsSandboxLoadingTitle,
                subtitle: context.l10n.appsSandboxLoadingSubtitle,
                showSpinner: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSandboxBody() {
    if (widget.sandboxBuilder != null) {
      return widget.sandboxBuilder!(_handleNavigationAttempt);
    }

    final controller = _webViewController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return WebViewWidget(controller: controller);
  }
}

class _SandboxStatusCard extends StatelessWidget {
  const _SandboxStatusCard({
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  final String title;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.vineColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.vineColors.outlineMuted),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSpinner) ...[
                  // [title] below already announces the wait.
                  const ExcludeSemantics(
                    child: BrandedLoadingIndicator(size: 60),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  DivineIcon(
                    icon: DivineIconName.shieldCheck,
                    color: context.vineColors.accentPositive,
                    size: 28,
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: VineTheme.headlineSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: VineTheme.bodyLargeFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrappedSandboxPage {
  const _BootstrappedSandboxPage({required this.baseUri, required this.html});

  final Uri baseUri;
  final String html;
}

/// Resolves an Android WebView file-chooser request into `file://` URIs the
/// WebView can read back into the HTML `<input type="file">`.
///
/// This intentionally narrows Android sandbox uploads to images for now:
/// camera when the input requests capture, gallery otherwise. Picked files are
/// stripped of metadata before being exposed to the sandbox so third-party apps
/// do not receive GPS or device EXIF. Returns an empty list when the input wants
/// a non-image type, save mode, or the user cancels, which the WebView treats as
/// "no file selected".
@visibleForTesting
Future<List<String>> sandboxAndroidFileSelector(
  FileSelectorParams params,
  ImagePicker picker, {
  SandboxImageMetadataStripper? metadataStripper,
}) async {
  if (!_acceptsImages(params.acceptTypes)) {
    return const <String>[];
  }

  if (params.mode == FileSelectorMode.save) {
    return const <String>[];
  }

  final stripMetadata =
      metadataStripper ?? ImageMetadataStripper.stripMetadataInPlace;

  try {
    if (params.mode == FileSelectorMode.openMultiple) {
      if (params.isCaptureEnabled) {
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file == null) {
          return const <String>[];
        }
        return await _strippedFileUris([file], stripMetadata);
      }
      final files = await picker.pickMultiImage();
      return await _strippedFileUris(files, stripMetadata);
    }

    final source = params.isCaptureEnabled
        ? ImageSource.camera
        : ImageSource.gallery;
    final file = await picker.pickImage(source: source);
    if (file == null) {
      return const <String>[];
    }
    return await _strippedFileUris([file], stripMetadata);
  } catch (error, stackTrace) {
    // Expected, user-driven paths land here too (e.g. denying the camera
    // permission throws PlatformException), so log at warning, not error.
    Log.log(
      'Sandbox WebView file selection failed: $error',
      name: 'NostrAppSandboxScreen',
      category: LogCategory.ui,
      level: LogLevel.warning,
      error: error,
      stackTrace: stackTrace,
    );
    return const <String>[];
  }
}

Future<List<String>> _strippedFileUris(
  List<XFile> files,
  SandboxImageMetadataStripper stripMetadata,
) async {
  final strippedFiles = <String>[];
  for (final file in files) {
    final strippedFile = await stripMetadata(File(file.path));
    strippedFiles.add(Uri.file(strippedFile.path).toString());
  }
  return strippedFiles;
}

/// Whether the `<input accept="…">` tokens permit an image.
///
/// An empty list and every "any file" spelling fall through to the image
/// picker. Android delivers a plain `<input type="file">` (no accept attr) as
/// `['']`, not `[]`, so `''` counts as accept-anything alongside `*` and
/// `*/*`. Otherwise the input must explicitly allow an image MIME type
/// (`image/*`, `image/png`, …) or a listed bare extension.
bool _acceptsImages(List<String> acceptTypes) {
  if (acceptTypes.isEmpty) {
    return true;
  }
  return acceptTypes.any(
    (type) => _isAnyFileToken(type) || _acceptsImageType(type),
  );
}

bool _isAnyFileToken(String type) {
  final normalized = type.trim().toLowerCase();
  return normalized.isEmpty || normalized == '*' || normalized == '*/*';
}

bool _acceptsImageType(String type) {
  final normalized = type.trim().toLowerCase();
  return normalized.startsWith('image/') ||
      const {
        '.avif',
        '.bmp',
        '.gif',
        '.heic',
        '.heif',
        '.jpg',
        '.jpeg',
        '.png',
        '.tif',
        '.tiff',
        '.webp',
      }.contains(normalized);
}
