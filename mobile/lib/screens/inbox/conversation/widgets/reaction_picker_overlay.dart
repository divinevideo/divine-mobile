// ABOUTME: Combined long-press overlay for a DM bubble: quick reaction
// ABOUTME: row above the message actions. Single gesture, single surface.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_actions_sheet.dart';

/// Default emoji set for the quick-row. Excludes 🙏 per user-memory
/// rule "Swap 🙏 → 🫶 always" — 🔥 takes its place because it reads
/// especially well on short-form video content.
const List<String> kDefaultDmReactionEmojis = [
  '❤️',
  '😂',
  '🔥',
  '😮',
  '😢',
  '👍',
];

/// Outcome of a [ReactionPickerOverlay] dismissal.
class ReactionPickerResult {
  /// Construct an outcome.
  const ReactionPickerResult({
    this.emoji,
    this.openFullPicker = false,
    this.action,
  });

  /// Emoji the user selected from the quick row. `null` when the user
  /// instead chose an action or tapped the "+" expander.
  final String? emoji;

  /// The user tapped "+" to open the full picker. The caller is
  /// responsible for opening the picker; this overlay is dismissed.
  final bool openFullPicker;

  /// The user selected one of the carry-over actions (Copy, Delete, etc.).
  final MessageAction? action;
}

/// Shows the combined picker + actions overlay anchored on screen.
///
/// Returns a [ReactionPickerResult] describing the user's choice, or
/// `null` if dismissed without selection.
class ReactionPickerOverlay {
  /// Show the overlay and await user selection. Triggers a medium
  /// haptic on open.
  static Future<ReactionPickerResult?> show({
    required BuildContext context,
    required bool isSent,
    bool showPicker = true,
    bool showDelete = true,
    bool deleteForEveryone = true,
    bool isVideoShare = false,
    List<String> emojis = kDefaultDmReactionEmojis,
  }) async {
    unawaited(HapticFeedback.mediumImpact());
    final l10n = context.l10n;

    return showModalBottomSheet<ReactionPickerResult>(
      context: context,
      backgroundColor: context.vineColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPicker)
                  _QuickRow(
                    emojis: emojis,
                    openLabel: l10n.dmReactionAddCustomA11yLabel,
                    onEmojiTap: (emoji) => sheetContext.popModalIfMounted(
                      ReactionPickerResult(emoji: emoji),
                    ),
                    onMoreTap: () => sheetContext.popModalIfMounted(
                      const ReactionPickerResult(openFullPicker: true),
                    ),
                  ),
                if (showPicker) const SizedBox(height: 8),
                _ActionList(
                  isSent: isSent,
                  showDelete: showDelete,
                  deleteForEveryone: deleteForEveryone,
                  isVideoShare: isVideoShare,
                  onSelected: (action) => sheetContext.popModalIfMounted(
                    ReactionPickerResult(action: action),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.emojis,
    required this.openLabel,
    required this.onEmojiTap,
    required this.onMoreTap,
  });

  final List<String> emojis;
  final String openLabel;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in emojis)
            _EmojiButton(
              emoji: emoji,
              onTap: () => onEmojiTap(emoji),
            ),
          _MoreButton(label: openLabel, onTap: onMoreTap),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: emoji,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: DivineHeartText(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 48×48 tap target, but a smaller (32) visible circle + 18px glyph so the
    // "+" sits in proportion with the bare 28px emoji glyphs beside it
    // (mirrors the in-player reply bar's picker button).
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.vineColors.iconButton,
              ),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.plus,
                    color: context.vineColors.onSurfaceMuted,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.isSent,
    required this.showDelete,
    required this.deleteForEveryone,
    required this.isVideoShare,
    required this.onSelected,
  });

  final bool isSent;

  /// Whether "Delete for everyone" is offered on an own message. False on a
  /// closed thread, where the kind-5 cannot be published and the tile would
  /// only drop the local copy.
  final bool showDelete;
  final bool deleteForEveryone;
  final bool isVideoShare;
  final ValueChanged<MessageAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = <Widget>[
      _ActionTile(
        icon: DivineIconName.copy,
        label: l10n.dmMessageActionCopyText,
        onTap: () => onSelected(MessageAction.copy),
      ),
      if (isVideoShare)
        _ActionTile(
          icon: DivineIconName.linkSimple,
          label: l10n.dmMessageActionCopyVideoUrl,
          onTap: () => onSelected(MessageAction.copyVideoUrl),
        ),
      if (isVideoShare)
        _ActionTile(
          icon: DivineIconName.downloadSimple,
          label: l10n.shareSheetSaveVideo,
          onTap: () => onSelected(MessageAction.saveVideo),
        ),
      if (isSent && showDelete)
        _ActionTile(
          icon: DivineIconName.trash,
          label: deleteForEveryone
              ? l10n.dmMessageActionDeleteForEveryone
              : l10n.dmMessageActionCancelSend,
          onTap: () => onSelected(MessageAction.delete),
          color: VineTheme.error,
        ),
      if (!isSent)
        _ActionTile(
          icon: DivineIconName.flag,
          label: l10n.dmMessageActionReport,
          onTap: () => onSelected(MessageAction.report),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tiles,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DivineIcon(
        icon: icon,
        color: color ?? context.vineColors.onSurface,
      ),
      title: Text(
        label,
        style: VineTheme.bodyLargeFont(
          color: color ?? context.vineColors.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
