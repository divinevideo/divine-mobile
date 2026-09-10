// ABOUTME: Native-platform stub for the web iframe sandbox screen.
// ABOUTME: Conditional import keeps package:web / dart:ui_web off non-web builds.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

class WebIframeSandboxScreen extends StatelessWidget {
  const WebIframeSandboxScreen({required this.app, super.key});

  static const String routeName = 'web-iframe-sandbox';
  static const String path = '/apps/:appId/web-sandbox';

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/web-sandbox';

  final NostrAppDirectoryEntry app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      body: Center(
        child: Text(
          'WebIframeSandboxScreen is web-only',
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
      ),
    );
  }
}
