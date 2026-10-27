// ABOUTME: Banner widget for message requests shown at top of inbox.
// ABOUTME: Shows "Message requests" label with unread badge and chevron.
// ABOUTME: InboxView decides when it shows; a zero count hides the badge.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Banner row displayed at the top of the conversation list when there are
/// message requests from non-followed users.
///
/// Displays "Message requests" text, a red unread-count badge, and a
/// right chevron. Tapping navigates to the message requests inbox.
class MessageRequestsBanner extends StatelessWidget {
  const MessageRequestsBanner({
    required this.requestCount,
    required this.onTap,
    super.key,
  });

  /// Number of unread live message requests, shown by the badge and
  /// announced by the semantics label. Dismissed requests, and read requests
  /// still awaiting a decision, are not counted.
  final int requestCount;

  /// Called when the banner is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The label already carries the title and the count, so the visible text
    // is excluded to keep screen readers from announcing it a second time.
    // Excluding the subtree also drops the GestureDetector's tap action, so
    // the action is re-declared here.
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: context.l10n.inboxMessageRequestsUnreadSemanticLabel(
        requestCount,
      ),
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.inboxMessageRequestsTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
                if (requestCount > 0) _RequestCountBadge(count: requestCount),
                const SizedBox(width: 8),
                DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: context.vineColors.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCountBadge extends StatelessWidget {
  const _RequestCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Center(
        child: Text(
          label,
          style: VineTheme.labelSmallFont(color: context.vineColors.onSurface),
        ),
      ),
    );
  }
}
