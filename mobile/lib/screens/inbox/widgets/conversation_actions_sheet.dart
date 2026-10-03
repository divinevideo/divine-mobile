// ABOUTME: Bottom sheet with long-press actions for DM conversations.
// ABOUTME: Provides contextual Report, Block, and Remove actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Actions available from the conversation long-press sheet.
enum ConversationAction {
  /// Report the other participant.
  report,

  /// Block the other participant.
  block,

  /// Remove (delete) the conversation locally.
  remove,
}

/// Shows a bottom sheet with contextual actions for a DM conversation.
///
/// Matches the Figma "conversation list - long press" design (node 10183:132451),
/// minus its Mute row: muting had no effect on delivery, badges or
/// notifications, so the toggle is withheld until it does (#7379).
/// Returns the chosen [ConversationAction] or `null` if dismissed.
class ConversationActionsSheet {
  /// Whether the sheet would offer any action for a conversation.
  ///
  /// Report and Block are withheld from a group and Remove from a
  /// removal-protected thread, so a group holding a protected member has
  /// none. Callers check this before [show] rather than open an empty sheet.
  static bool hasActions({required bool isGroup, required bool canRemove}) =>
      !isGroup || canRemove;

  static Future<ConversationAction?> show(
    BuildContext context, {
    required String displayName,
    required bool isVanished,
    required bool isBlocked,
    required bool isGroup,
    bool canRemove = true,
  }) {
    // A vanished peer can publish again under the same key, and their DMs
    // remain in the recipient's history. Keep Report and Block available for
    // safety, but do not turn the deleted-state label into an identity.
    return VineBottomSheet.show<ConversationAction>(
      context: context,
      scrollable: false,
      expanded: false,
      // Route through the root Navigator so the sheet sits above the
      // tab shell's nested Navigator and covers the bottom nav bar —
      // matches the home-feed Comments / Report sheet behavior.
      useRootNavigator: true,
      body: Semantics(
        label: context.l10n.inboxConversationActionsSheetLabel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Report and Block act on ONE account, and a group sheet has no
            // way to say which — it would act on the arbitrary peer the row
            // names while reading as though it dealt with the thread. Remove
            // is conversation-scoped and means what it says. An individual is
            // still blockable from their profile in the thread.
            if (!isGroup) ...[
              _ActionTile(
                icon: DivineIconName.flag,
                label: isVanished
                    ? context.l10n.inboxActionReportVanishedAccount
                    : context.l10n.inboxActionReport(displayName),
                result: ConversationAction.report,
              ),
              _ActionTile(
                icon: DivineIconName.eyeSlash,
                label: switch ((isBlocked, isVanished)) {
                  (true, true) =>
                    context.l10n.inboxActionUnblockVanishedAccount,
                  (true, false) => context.l10n.inboxActionUnblock(displayName),
                  (false, true) => context.l10n.inboxActionBlockVanishedAccount,
                  (false, false) => context.l10n.inboxActionBlock(displayName),
                },
                isDestructive: !isBlocked,
                // Block becomes the last row when Remove is withdrawn, so it
                // owns the missing divider rather than leaving a trailing rule.
                showDivider: canRemove,
                result: ConversationAction.block,
              ),
            ],
            // Withdrawn for a Divine Moderation thread: removal is permanent
            // and the notice is the user's only copy of why they were actioned
            // (#8391). The repository refuses it either way; not offering it
            // beats a dead-end refusal.
            if (canRemove)
              _ActionTile(
                icon: DivineIconName.trash,
                label: context.l10n.inboxActionRemove,
                isDestructive: true,
                showDivider: false,
                result: ConversationAction.remove,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.result,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final DivineIconName icon;
  final String label;
  final ConversationAction result;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? VineTheme.error
        : context.vineColors.onSurface;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(result),
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: context.vineColors.outlineDisabled,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              spacing: 16,
              children: [
                DivineIcon(icon: icon, color: color),
                Expanded(
                  child: Text(
                    label,
                    style: VineTheme.titleMediumFont(color: color),
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
