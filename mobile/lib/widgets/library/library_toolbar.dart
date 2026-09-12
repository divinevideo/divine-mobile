// ABOUTME: Toolbar for the library screen with navigation and clip actions
// ABOUTME: Collapses clip actions into an overflow menu when the row is narrow

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// One trailing clip action of [LibraryToolbar].
///
/// The same description renders either as a row button or as a row of the
/// overflow menu, so an action that moves out of the row keeps its icon, its
/// callback and its disabled state.
@immutable
class _ClipAction {
  const _ClipAction({
    required this.icon,
    required this.menuLabel,
    required this.onPressed,
    this.chipLabel,
    this.semanticLabel,
    this.isDestructive = false,
  });

  /// Icon shown in the overflow menu, and in the row when [chipLabel] is null.
  final DivineIconName icon;

  /// Visible label in the row. Null renders an icon-only button.
  final String? chipLabel;

  /// Visible label of this action's overflow-menu row.
  ///
  /// Always spelled out — a menu row has room for words an icon button in the
  /// toolbar does not.
  final String menuLabel;

  /// Announced name of the row button. Required for an icon-only action;
  /// null on a chip whose visible label already reads as the action.
  final String? semanticLabel;

  /// Null disables the action in the row and in the menu.
  final VoidCallback? onPressed;

  final bool isDestructive;
}

class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    required this.isLibrarySelectionMode,
    required this.canExitSelectionMode,
    required this.isClipsTabActive,
    required this.onLeadingPressed,
    required this.onOpenSortMenu,
    required this.onEnterSelectionMode,
    this.isTrashFilterActive = false,
    this.onEmptyTrash,
    this.onManageActiveCategory,
    this.onMoveSelectedClips,
    this.onDeleteSelectedClips,
    super.key,
  });

  final bool isLibrarySelectionMode;
  final bool canExitSelectionMode;
  final bool isClipsTabActive;
  final VoidCallback onLeadingPressed;
  final VoidCallback onOpenSortMenu;
  final VoidCallback onEnterSelectionMode;

  /// Whether the clip grid is currently showing the trash bin. Sorting and
  /// selecting do not apply there, so those actions step aside.
  final bool isTrashFilterActive;

  /// Empties the trash. Null when the bin is empty or not being shown.
  final VoidCallback? onEmptyTrash;

  /// Renames or deletes the category the grid is filtered to. Null unless a
  /// user category is the active filter.
  final VoidCallback? onManageActiveCategory;

  /// Files the selected clips into a category. Null when nothing is selected.
  final VoidCallback? onMoveSelectedClips;

  final VoidCallback? onDeleteSelectedClips;

  /// Gap between row children.
  static const _spacing = 8.0;

  /// Inset the title carries on each side inside its slot.
  static const _titlePadding = 8.0;

  /// Narrowest title worth keeping in the row, before [_titlePadding].
  ///
  /// Around four characters and an ellipsis at the default text scale. Below
  /// that the title is ellipsis with no word left to read, which is the state
  /// #7165 reported at 320-360dp.
  ///
  /// Reserving it grows on [DivineIcon]'s capped curve rather than the raw
  /// text scaler: the title is the one row child whose full text nobody needs
  /// to read — every locale says the same word — while the actions beside it
  /// are the reason the screen is open. Left uncapped, a 2x scale would spend
  /// 160px holding four characters and push a button into the menu on a
  /// phone wide enough to show it.
  static const _minTitleWidth = 72.0;

  /// Outer width of a `small` [DivineIconButton] — its pill centred in a 48px
  /// tap target. Scales with the text scaler, on [DivineIcon]'s capped curve,
  /// exactly as the button itself does.
  ///
  /// Type-independent: at `small` that tap-target box is what fixes the outer
  /// bounds, so a bordered button and a destructive one occupy the same 48px
  /// whatever their pills measure. `library_toolbar_test` pins that, like
  /// [_chipChrome].
  static const _iconButtonWidth = 48.0;

  /// Width a `small` [DivineButton] adds around its label: 4px outer padding,
  /// 2px border and 14px inner padding, on each side.
  ///
  /// Estimating the row's width needs a number here because the collapse has
  /// to be decided while building, before anything is laid out.
  /// `library_toolbar_test` pins it against a real button so a change in
  /// `divine_ui`'s geometry fails loudly rather than silently overflowing.
  static const _chipChrome = 40.0;

  /// Trailing clip actions, least important first.
  ///
  /// The overflow menu takes them from the front, so the primary action is
  /// the last one to leave the row.
  List<_ClipAction> _clipActions(BuildContext context) {
    if (!isClipsTabActive) return const [];
    final l10n = context.l10n;

    // The bin is its own mode: nothing in it can be sorted, selected or
    // filed, so emptying it is the only action on offer.
    if (isTrashFilterActive) {
      return [
        if (onEmptyTrash != null)
          _ClipAction(
            icon: .trash,
            chipLabel: l10n.libraryTrashEmptyAllLabel,
            menuLabel: l10n.libraryTrashEmptyAllLabel,
            onPressed: onEmptyTrash,
            isDestructive: true,
          ),
      ];
    }

    return [
      if (!isLibrarySelectionMode && onManageActiveCategory != null)
        _ClipAction(
          icon: .pencilSimple,
          menuLabel: l10n.libraryCategoryManageSemanticLabel,
          semanticLabel: l10n.libraryCategoryManageSemanticLabel,
          onPressed: onManageActiveCategory,
        ),
      _ClipAction(
        icon: .funnelSimple,
        // #7129 put the grid-size control in this same menu, so the label
        // names both jobs — and names them the same way in the row as in the
        // menu, rather than assembling a sentence out of two keys.
        menuLabel: l10n.libraryDisplayOptionsLabel,
        semanticLabel: l10n.libraryDisplayOptionsLabel,
        onPressed: onOpenSortMenu,
      ),
      if (!isLibrarySelectionMode)
        _ClipAction(
          icon: .selection,
          chipLabel: l10n.librarySelect,
          menuLabel: l10n.librarySelectClipsSemanticLabel,
          semanticLabel: l10n.librarySelectClipsSemanticLabel,
          onPressed: onEnterSelectionMode,
        ),
      if (isLibrarySelectionMode) ...[
        _ClipAction(
          icon: .folderOpen,
          menuLabel: l10n.libraryMoveSelectedClipsTooltip,
          semanticLabel: l10n.libraryMoveSelectedClipsTooltip,
          onPressed: onMoveSelectedClips,
        ),
        _ClipAction(
          icon: .trash,
          menuLabel: l10n.libraryDeleteSelectedClipsTooltip,
          semanticLabel: l10n.libraryDeleteSelectedClipsTooltip,
          onPressed: onDeleteSelectedClips,
          isDestructive: true,
        ),
      ],
    ];
  }

  double _iconButtonExtent(BuildContext context) =>
      DivineIcon.scaleSize(context, _iconButtonWidth);

  double _actionExtent(BuildContext context, _ClipAction action) {
    final chipLabel = action.chipLabel;
    if (chipLabel == null) return _iconButtonExtent(context);

    // Measured, never painted — it carries a color at all because
    // `check_implicit_font_color_ceiling` freezes color-less
    // `VineTheme.*Font(` calls at zero (#6404), and the chip's own is the
    // honest one to name.
    final painter = TextPainter(
      text: TextSpan(
        text: chipLabel,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelWidth = painter.width;
    painter.dispose();

    return math.max(_iconButtonExtent(context), labelWidth + _chipChrome);
  }

  /// How many actions, counted from the front, do not fit and move into the
  /// overflow menu.
  ///
  /// Never all of them: the primary action stays in the row at every width.
  int _overflowCount(
    BuildContext context,
    List<_ClipAction> actions,
    double maxWidth,
  ) {
    if (actions.isEmpty) return 0;

    final iconButtonExtent = _iconButtonExtent(context);
    final titleExtent =
        DivineIcon.scaleSize(context, _minTitleWidth) + _titlePadding * 2;
    final extents = [
      for (final action in actions) _actionExtent(context, action),
    ];

    // The first collapse swaps the front action for a more button, so it only
    // narrows the row by whatever that action is wider than one. An icon-only
    // action is exactly as wide, which makes collapsing it alone a pure loss:
    // same row, one extra tap to reach it. There the row starts narrowing at
    // the second collapse, and the first is skipped.
    final firstUsefulOverflow = extents.first > iconButtonExtent ? 1 : 2;

    for (var overflow = 0; overflow < actions.length; overflow++) {
      if (overflow > 0 && overflow < firstUsefulOverflow) continue;
      // Leading button and title.
      var width = iconButtonExtent + titleExtent;
      var children = 2;
      if (overflow > 0) {
        width += iconButtonExtent;
        children++;
      }
      for (var i = overflow; i < actions.length; i++) {
        width += extents[i];
        children++;
      }
      if (width + _spacing * (children - 1) <= maxWidth) return overflow;
    }

    // Nothing fits: collapse everything the row can spare and keep the
    // primary action anyway. It is capped instead — see [_primaryMaxWidth].
    final most = actions.length - 1;
    return most < firstUsefulOverflow ? 0 : most;
  }

  /// Width left for the primary action once every other row child has taken
  /// its own.
  ///
  /// The primary action never moves into the menu, so in the tightest rows it
  /// is the one child that has to give. Capping it lets its label ellipsize
  /// rather than push the row past the screen. The title is not reserved for
  /// here on purpose: at that width the title yields first.
  double _primaryMaxWidth(
    BuildContext context,
    List<_ClipAction> visible, {
    required bool hasOverflow,
    required double maxWidth,
  }) {
    if (visible.isEmpty) return 0;

    // Leading button, title, and the primary action itself.
    var width = _iconButtonExtent(context);
    var children = 3;
    if (hasOverflow) {
      width += _iconButtonExtent(context);
      children++;
    }
    for (final action in visible.take(visible.length - 1)) {
      width += _actionExtent(context, action);
      children++;
    }
    return math.max(0, maxWidth - width - _spacing * (children - 1));
  }

  Future<void> _openOverflowMenu(
    BuildContext context,
    List<_ClipAction> actions,
  ) {
    return VineBottomSheetActionMenu.show(
      context: context,
      options: [
        // Most important first: the menu leads with the action the row would
        // have shown last.
        for (final action in actions.reversed)
          VineBottomSheetActionData(
            iconPath: action.icon.assetPath,
            label: action.menuLabel,
            isDestructive: action.isDestructive,
            onTap: action.onPressed,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showsSelectionExit =
        isClipsTabActive && isLibrarySelectionMode && canExitSelectionMode;
    final actions = _clipActions(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflowCount = _overflowCount(
            context,
            actions,
            constraints.maxWidth,
          );
          final visible = actions.sublist(overflowCount);
          final primaryMaxWidth = _primaryMaxWidth(
            context,
            visible,
            hasOverflow: overflowCount > 0,
            maxWidth: constraints.maxWidth,
          );
          return Row(
            spacing: _spacing,
            children: [
              DivineIconButton(
                size: .small,
                type: .secondary,
                icon: showsSelectionExit ? .x : .caretLeft,
                semanticLabel: showsSelectionExit
                    ? context.l10n.libraryStopSelectingClipsSemanticLabel
                    : context.l10n.libraryCloseSemanticLabel,
                onPressed: onLeadingPressed,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _titlePadding,
                  ),
                  child: Text(
                    context.l10n.profileMyLibraryLabel,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (overflowCount > 0)
                DivineIconButton(
                  size: .small,
                  type: .secondary,
                  icon: .dotsThree,
                  semanticLabel: context.l10n.libraryMoreActionsSemanticLabel,
                  onPressed: () => _openOverflowMenu(
                    context,
                    actions.sublist(0, overflowCount),
                  ),
                ),
              for (final (index, action) in visible.indexed)
                if (index == visible.length - 1)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: primaryMaxWidth),
                    child: _ClipActionButton(action: action),
                  )
                else
                  _ClipActionButton(action: action),
            ],
          );
        },
      ),
    );
  }
}

class _ClipActionButton extends StatelessWidget {
  const _ClipActionButton({required this.action});

  final _ClipAction action;

  @override
  Widget build(BuildContext context) {
    final chipLabel = action.chipLabel;
    if (chipLabel != null) {
      return DivineButton(
        size: .small,
        type: action.isDestructive ? .error : .secondary,
        label: chipLabel,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      );
    }
    return DivineIconButton(
      size: .small,
      type: action.isDestructive ? .error : .secondary,
      icon: action.icon,
      semanticLabel: action.semanticLabel,
      onPressed: action.onPressed,
    );
  }
}
