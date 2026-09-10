// ABOUTME: Fallback screen shown when a sandbox app ID cannot be
// ABOUTME: resolved from the approved-integrations directory.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';

class MissingSandboxAppScreen extends StatelessWidget {
  const MissingSandboxAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appsSandboxUnavailableTitle,
        showBackButton: true,
        // Reachable by direct URL, where the matched stack has a single
        // entry and a raw pop throws GoError (#6112).
        onBackPressed: () =>
            context.safePop(fallback: AppsDirectoryScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.appsSandboxUnavailableBody,
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
