// ABOUTME: Bottom sheet with long-press actions for DM conversations.
// ABOUTME: Provides contextual Mute, Report, Block, and Remove actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Actions available from the conversation long-press sheet.
enum ConversationAction {
  /// Toggle mute notifications for this conversation.
  toggleMute,

  /// Report the other participant.
  report,

  /// Block the other participant.
  block,

  /// Remove (delete) the conversation locally.
  remove,
}

/// Shows a bottom sheet with contextual actions for a DM conversation.
///
/// Matches the Figma "conversation list - long press" design (node 10183:132451).
/// Returns the chosen [ConversationAction] or `null` if dismissed.
class ConversationActionsSheet {
  static Future<ConversationAction?> show(
    BuildContext context, {
    required String displayName,
    required bool isVanished,
    required bool isMuted,
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
            _MuteActionTile(
              isMuted: isMuted,
              showDivider: !isGroup || canRemove,
            ),
            // Report and Block act on ONE account, and a group sheet has no
            // way to say which — it would act on the arbitrary peer the row
            // names while reading as though it dealt with the thread. Mute and
            // Remove are conversation-scoped and mean what they say. An
            // individual is still blockable from their profile in the thread.
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

class _MuteActionTile extends StatelessWidget {
  const _MuteActionTile({required this.isMuted, this.showDivider = true});

  final bool isMuted;

  /// False when Mute is the only row left — a group thread that also carries a
  /// removal-protected member withdraws Report, Block AND Remove, and a rule
  /// under the last row reads as a missing action rather than a separator.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: isMuted,
      label: context.l10n.inboxActionMute,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: context.vineColors.outlineDisabled),
                )
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            value: isMuted,
            activeThumbColor: context.vineColors.primaryText,
            activeTrackColor: VineTheme.primary,
            inactiveThumbColor: context.vineColors.disabled,
            inactiveTrackColor: context.vineColors.surfaceContainer,
            onChanged: (_) =>
                Navigator.of(context).pop(ConversationAction.toggleMute),
            title: Text(
              context.l10n.inboxActionMute,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            secondary: DivineIcon(
              icon: DivineIconName.bellSimple,
              color: context.vineColors.onSurface,
            ),
          ),
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
