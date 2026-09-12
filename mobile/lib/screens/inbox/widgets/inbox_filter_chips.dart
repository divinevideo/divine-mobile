// ABOUTME: All/Unread/Blocked filter chip row for the inbox Messages tab.
// ABOUTME: Narrows the conversation list, or swaps it for blocked chats.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Filter chip row shown above the conversation list.
///
/// [selected] marks the active chip; tapping an inactive chip calls
/// [onChanged]. Tapping the already-active chip is a no-op.
///
/// The Blocked chip renders only when [hasBlocked]. Most accounts have blocked
/// nobody, and a chip that can only ever open an empty list is noise — so the
/// row stays two chips wide until the first block exists.
class InboxFilterChips extends StatelessWidget {
  const InboxFilterChips({
    required this.selected,
    required this.onChanged,
    this.hasBlocked = false,
    super.key,
  });

  /// The currently active filter.
  final InboxFilter selected;

  /// Called with the new filter when the selection changes.
  final ValueChanged<InboxFilter> onChanged;

  /// Whether the viewer has blocked anyone, gating the Blocked chip.
  final bool hasBlocked;

  @override
  Widget build(BuildContext context) {
    // Deliberately no MediaQuery.withNoTextScaling: these are controls to read
    // and tap, not fixed overlay badges. The pinned header hosting this row
    // measures it rather than declaring an extent, so the row is free to grow
    // with the text scale (#7854).
    // Horizontally scrollable because the chips size to their intrinsic
    // width: `DivineButton`'s internal `Flexible` sits inside its own
    // MainAxisSize.min Row, so it can never yield width to a sibling, and a
    // third chip pushes long-label locales past a narrow viewport at default
    // text scale. Scrolling absorbs that instead of overflowing.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          _FilterChip(
            label: context.l10n.inboxFilterAll,
            selected: selected == InboxFilter.all,
            onTap: () => onChanged(InboxFilter.all),
          ),
          _FilterChip(
            label: context.l10n.inboxFilterUnread,
            selected: selected == InboxFilter.unread,
            onTap: () => onChanged(InboxFilter.unread),
          ),
          if (hasBlocked)
            _FilterChip(
              label: context.l10n.inboxFilterBlocked,
              selected: selected == InboxFilter.blocked,
              onTap: () => onChanged(InboxFilter.blocked),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // onPressed stays non-null on the selected chip so it keeps the enabled
    // visual style; the parent ignores redundant selections.
    return Semantics(
      selected: selected,
      child: DivineButton(
        label: label,
        type: selected
            ? DivineButtonType.secondary
            : DivineButtonType.ghostSecondary,
        size: DivineButtonSize.tiny,
        onPressed: onTap,
      ),
    );
  }
}
