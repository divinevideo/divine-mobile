// ABOUTME: Flutter web iframe screen that hosts a first-party Divine integrated
// ABOUTME: app (verifier.divine.video, badges.divine.video) inline. The embedded
// ABOUTME: app's window.nostr is proxied to Divine's WebSigner via postMessage,
// ABOUTME: so users don't have to log in twice.

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/web_iframe_nostr_bridge.dart';
import 'package:web/web.dart' as web;

/// Hosts a first-party Divine integrated app in an `<iframe>` on Flutter
/// web. The iframe's window.nostr is fulfilled by [WebIframeNostrBridge]
/// against the host's [WebAuthService] signer, so the embedded app uses
/// the user's existing Divine session over postMessage and skips its
/// own login flow.
class WebIframeSandboxScreen extends ConsumerStatefulWidget {
  const WebIframeSandboxScreen({required this.app, super.key});

  static const String routeName = 'web-iframe-sandbox';
  static const String path = '/apps/:appId/web-sandbox';

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/web-sandbox';

  final NostrAppDirectoryEntry app;

  @override
  ConsumerState<WebIframeSandboxScreen> createState() =>
      _WebIframeSandboxScreenState();
}

class _WebIframeSandboxScreenState
    extends ConsumerState<WebIframeSandboxScreen> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final WebIframeNostrBridge _bridge;

  @override
  void initState() {
    super.initState();
    _viewType = 'divine-iframe-sandbox-${widget.app.id}-${_nextViewId++}';
    _bridge = WebIframeNostrBridge(
      app: widget.app,
      authService: ref.read(webAuthServiceProvider),
    );
    _registerViewFactory();
    _bridge.start();
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.app.launchUrl
        ..style.setProperty('border', 'none')
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..allow = 'clipboard-read; clipboard-write';
      // Wire the bridge's reply path to this specific iframe's contentWindow
      // so replies don't leak to other frames on the page.
      _bridge.postReplyOverride = (message, targetOrigin) {
        final target = iframe.contentWindow;
        if (target != null) {
          target.postMessage(message.jsify() as JSAny?, targetOrigin.toJS);
        }
      };
      return iframe;
    });
  }

  @override
  void dispose() {
    _bridge.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: widget.app.name,
        backgroundMode: DiVineAppBarBackgroundMode.transparent,
        showBackButton: true,
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}
