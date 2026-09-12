// ABOUTME: Error state widget for the inbox Messages tab.
// ABOUTME: Distinct from the empty state so a failed load never reads as
// ABOUTME: "no messages"; offers a retry action.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Error state shown when the conversation list fails to load.
///
/// Renders an explanation plus a retry button so the failure is
/// recoverable in place — unlike [InboxEmptyState], which tells the user
/// they simply have no messages yet.
class InboxErrorState extends StatelessWidget {
  const InboxErrorState({required this.onRetry, super.key});

  /// Called when the user taps the retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              context.l10n.inboxLoadErrorTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              context.l10n.inboxLoadErrorSubtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            DivineButton(
              label: context.l10n.commonRetry,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
