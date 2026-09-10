// ABOUTME: Empty state widget shown when there are no notifications.
// ABOUTME: Displays a centered icon, title, and descriptive message.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Centered empty state for the notifications list.
///
/// Shown when the user has no notifications yet.
class NotificationEmptyState extends StatelessWidget {
  /// Creates a notification empty state widget.
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DivineIcon(
              icon: DivineIconName.bellSimple,
              size: 48,
              color: context.vineColors.mutedText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.notificationsEmptyTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsEmptySubtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
