// ABOUTME: The small controls the sticker sheets share: a kind tile, a note
// ABOUTME: line, a choice tile, a row of chips, a choice chip and the footer.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// A short line of help or status under a control.
class StickerSheetNote extends StatelessWidget {
  const StickerSheetNote({
    required this.text,
    this.warning = false,
    super.key,
  });

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Text(
        text,
        style: VineTheme.bodySmallFont(
          color: warning
              ? context.vineColors.accentWarning
              : context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

/// A bordered tile to pick, marked when [selected].
class StickerChoiceTile extends StatelessWidget {
  const StickerChoiceTile({
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    required this.child,
    this.dark = false,
    super.key,
  });

  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// Whether the tile shows a sticker on the dark ground of a video.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? VineTheme.surfaceBackground
                : context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: SizedBox(
            width: 112,
            child: Padding(
              padding: const .all(12),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips in one line that scrolls sideways, lined up with the sheet's
/// margins.
class StickerChipRow extends StatelessWidget {
  const StickerChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .symmetric(horizontal: 16),
      child: Row(spacing: 8, children: children),
    );
  }
}

/// A small pill with a label, after [leading] when there is one, to pick;
/// marked when [selected].
class StickerChoiceChip extends StatelessWidget {
  const StickerChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? context.vineColors.accentPositive
                    : context.vineColors.outlineMuted,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 16, vertical: 12),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: .min,
                  spacing: 8,
                  children: [
                    ?leading,
                    Text(
                      label,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A kind of sticker in the sticker sheet: a sample of it on a dark ground,
/// and its [label].
class StickerKindTile extends StatelessWidget {
  const StickerKindTile({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// The sample, scaled down to fit the tile.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: 104,
          child: Column(
            spacing: 8,
            children: [
              SizedBox(
                height: 76,
                width: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const .all(10),
                    child: FittedBox(child: child),
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: .ellipsis,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The foot of a sticker sheet that holds its button: as far from a raised
/// keyboard as from the options above it, and clear of the system bar when
/// the keyboard is down.
class StickerSheetFooter extends StatelessWidget {
  const StickerSheetFooter({required this.child, super.key});

  /// The gap above the button, and below it while the keyboard is up.
  static const double _gap = 12;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The system bar sits under a raised keyboard, so only the keyboard
    // counts then; `padding` is already zero there.
    final bottom = keyboard > 0
        ? keyboard + _gap
        : MediaQuery.paddingOf(context).bottom + 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, _gap, 16, bottom),
      child: child,
    );
  }
}
