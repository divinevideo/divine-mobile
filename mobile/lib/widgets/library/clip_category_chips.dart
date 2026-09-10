// ABOUTME: Scrollable filter chip row above the clip library grid.
// ABOUTME: Offers the built-in All/Archive/Deleted filters plus user categories.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';

/// Filter chip row shown above the clip grid.
///
/// [selected] marks the active chip; tapping an inactive chip calls
/// [onSelected]. Tapping the already-active chip is a no-op.
///
/// All is always offered. Archive and Deleted only render when
/// [showBuiltInFilters] is true — the editor's clip picker leaves them off,
/// since a trashed clip cannot join a timeline and the picker is not where
/// the user goes looking through the archive.
class ClipCategoryChips extends StatelessWidget {
  const ClipCategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.showBuiltInFilters = true,
    this.onCreateCategory,
    this.onManageCategory,
    super.key,
  });

  /// The user's own categories, in chip-row order.
  final List<ClipCategory> categories;

  /// The currently active filter.
  final ClipLibraryFilter selected;

  /// Called with the new filter when the selection changes.
  final ValueChanged<ClipLibraryFilter> onSelected;

  /// Whether the Archive and Deleted chips are part of the row.
  final bool showBuiltInFilters;

  /// Called when the trailing "new category" chip is tapped. When null the
  /// chip is left out, which is what the clip picker wants — categories are
  /// managed in the library, not while picking clips for a timeline.
  final VoidCallback? onCreateCategory;

  /// Called when a category chip is long-pressed, to rename or delete it.
  /// When null, long-press does nothing.
  final ValueChanged<ClipCategory>? onManageCategory;

  @override
  Widget build(BuildContext context) {
    final active = selected;
    // Horizontally scrollable because the chips size to their intrinsic
    // width and the row grows with every category the user adds.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          _FilterChip(
            label: context.l10n.libraryFilterAll,
            selected: active is ClipLibraryAllFilter,
            onTap: () => onSelected(const ClipLibraryAllFilter()),
          ),
          if (showBuiltInFilters) ...[
            _FilterChip(
              label: context.l10n.libraryFilterArchive,
              selected: active is ClipLibraryArchiveFilter,
              onTap: () => onSelected(const ClipLibraryArchiveFilter()),
            ),
            _FilterChip(
              label: context.l10n.libraryFilterDeleted,
              selected: active is ClipLibraryTrashFilter,
              onTap: () => onSelected(const ClipLibraryTrashFilter()),
            ),
          ],
          for (final category in categories)
            _FilterChip(
              label: category.name,
              selected:
                  active is ClipLibraryCategoryFilter &&
                  active.categoryId == category.id,
              onTap: () => onSelected(ClipLibraryCategoryFilter(category.id)),
              onLongPress: onManageCategory == null
                  ? null
                  : () => onManageCategory!(category),
            ),
          if (onCreateCategory != null)
            DivineButton(
              label: context.l10n.libraryCategoryNewChipLabel,
              leadingIcon: DivineIconName.plus,
              type: DivineButtonType.ghostSecondary,
              size: DivineButtonSize.tiny,
              semanticLabel: context.l10n.libraryCategoryCreateSemanticLabel,
              onPressed: onCreateCategory,
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
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // onPressed stays non-null on the selected chip so it keeps the enabled
    // visual style; re-selecting the active filter is ignored by the bloc.
    final chip = Semantics(
      selected: selected,
      // Without this the rename/delete shortcut exists only as a raw long
      // press, which a screen reader has no way to surface or trigger.
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null
          ? null
          : context.l10n.libraryCategoryManageSemanticLabel,
      child: DivineButton(
        label: label,
        type: selected
            ? DivineButtonType.secondary
            : DivineButtonType.ghostSecondary,
        size: DivineButtonSize.tiny,
        onPressed: onTap,
      ),
    );

    if (onLongPress == null) return chip;
    // The button keeps taps; only the long press is claimed out here, which
    // is the rename/delete shortcut for a user category.
    return GestureDetector(onLongPress: onLongPress, child: chip);
  }
}
