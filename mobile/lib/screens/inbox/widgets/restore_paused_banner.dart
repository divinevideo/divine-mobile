// ABOUTME: Inbox banner shown when DM history recovery stopped before it
// ABOUTME: finished, so conversations that would appear as message requests
// ABOUTME: are still hidden. Offers the retry that re-arms the drain.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Banner shown at the top of the conversation list while the #5304 recovery
/// gate is hiding would-be message requests.
///
/// Deliberately static rather than a progress bar. The gate stays shut on
/// every drain exit that is not a clean exhaustion — page cap, exception, no
/// connected relay — and on those paths nothing is running, so animating
/// would claim progress that is not happening. `_RestoringHistoryIndicator`
/// remains the surface for a drain that genuinely is in flight.
class RestorePausedBanner extends StatelessWidget {
  const RestorePausedBanner({required this.onRetry, super.key});

  /// Called when the user taps Retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.vineColors.outlineDisabled),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            DivineIcon(
              icon: DivineIconName.info,
              color: context.vineColors.secondaryText,
            ),
            Expanded(
              child: Text(
                l10n.inboxRestorePausedTitle,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
            DivineButton(
              label: l10n.inboxRestoreRetryAction,
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
