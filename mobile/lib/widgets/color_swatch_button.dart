// ABOUTME: The round colour swatch shared by every colour picker in the app.
// ABOUTME: Fills its parent's box, ringing and badging itself when selected.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// A tappable colour swatch.
///
/// Sizes itself to the box the parent gives it, so grids and wraps both work —
/// the parent decides the dimension, this decides how the colour reads.
///
/// Selection is drawn as a ring *outside* the fill plus a tick in the corner,
/// which is why the widget needs room to overflow its own bounds. Parents must
/// not clip it.
class ColorSwatchButton extends StatelessWidget {
  /// Creates a colour swatch.
  const ColorSwatchButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.semanticLabel,
    this.child,
    this.borderColor,
    this.borderWidth = 1,
    super.key,
  });

  /// The colour this swatch stands for, painted as its fill.
  final Color color;

  /// Whether this is the swatch currently in use.
  final bool isSelected;

  /// Called when the swatch is tapped.
  final VoidCallback onTap;

  /// What a screen reader announces. Callers name the colour, since only they
  /// know whether it has a name, a role, or only an RGB triplet.
  final String semanticLabel;

  /// Drawn centred on the fill — a glyph for swatches that stand for an action
  /// rather than a colour.
  final Widget? child;

  /// Outlines the unselected fill, so a swatch close to the sheet's own colour
  /// still reads as a distinct target. Null leaves it unoutlined; the ring
  /// replaces it once selected.
  final Color? borderColor;

  /// Thickness of [borderColor].
  final double borderWidth;

  /// Radius of the fill. The ring around it is drawn one step rounder.
  static const double fillRadius = 20;

  /// Width of the ring marking the selected swatch.
  static const double ringWidth = 4;

  /// Gap between the fill and the ring around it.
  static const double _ringGap = 2;

  /// Side of the tick badge on the selected swatch.
  static const double _badgeSize = 20;

  /// Announces [color] as its RGB triplet, for callers whose swatches carry an
  /// arbitrary color with no human-readable name.
  static String rgbSemanticLabel(BuildContext context, Color color) {
    return context.l10n.rgbColorSemanticLabel(
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: isSelected,
      // Carried here because [ExcludeSemantics] drops the gesture detector's
      // own tap action — without it the swatch announces a button that
      // activating does nothing to.
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            // The ring sits outside the fill and the badge overhangs it.
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(fillRadius + _ringGap),
                  border: isSelected
                      ? Border.all(
                          strokeAlign: BorderSide.strokeAlignOutside,
                          color: VineTheme.primary,
                          width: ringWidth,
                        )
                      : null,
                ),
                child: Padding(
                  padding: isSelected
                      ? const EdgeInsets.all(_ringGap)
                      : EdgeInsets.zero,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(fillRadius),
                      border: isSelected || borderColor == null
                          ? null
                          : Border.all(color: borderColor!, width: borderWidth),
                    ),
                    child: child == null ? null : Center(child: child),
                  ),
                ),
              ),
              if (isSelected)
                const Positioned(bottom: -4, right: -4, child: _CheckBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tick marking the swatch in use.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: ColorSwatchButton._badgeSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: VineTheme.primary,
          shape: OvalBorder(),
        ),
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.check,
            color: VineTheme.whiteText,
            size: 15,
          ),
        ),
      ),
    );
  }
}
