// ABOUTME: Stops a stretched button's text from growing once the widest word
// ABOUTME: of its label would no longer fit across the button.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Stops a button's text from growing once the widest word of its [label]
/// would no longer fit across the button.
///
/// A label too long for its button wraps when the button allows more than one
/// line, but a word wider than the button is still cut wherever it reaches the
/// edge, since Flutter does not hyphenate: at the largest iOS size Spanish
/// "automáticamente" broke in two on a row to itself. Below that point the
/// button follows the system text size; it never shrinks under the normal one.
///
/// Made for a [DivineButton] of size small or base stretched across [width]
/// (`expanded`, or given a tight width by its parent), which is when its label
/// gets the narrow inner padding measured here. The button draws its own
/// label, so `DivineWordFitText` cannot be used for it.
class WholeWordButtonTextScale extends StatelessWidget {
  /// Clamps [child]'s text scale so the widest word of [label] fits.
  const WholeWordButtonTextScale({
    required this.label,
    required this.child,
    this.width,
    this.hasLeadingIcon = false,
    super.key,
  });

  /// What a stretched small or base [DivineButton] spends across its width on
  /// anything but its content: 12px on each side, the small button's 4px tap
  /// halo plus 8px inner padding, or the base button's 12px inner padding.
  static const double _buttonChrome = 24;

  /// A [DivineButton]'s leading icon before text scaling, and the gap it
  /// leaves before the label.
  static const double _iconSize = 24;
  static const double _iconGap = 8;

  /// The button's label, as it draws it.
  final String label;

  /// The width the button is laid out at. When null it is taken from the
  /// incoming constraints, so this must then sit where the button gets its
  /// width from its parent, not inside a widget that measures intrinsics.
  final double? width;

  /// Whether the button shows a leading icon beside the label.
  final bool hasLeadingIcon;

  /// The button.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = this.width;
    if (width != null) return _clamped(context, width);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _clamped(context, constraints.maxWidth),
    );
  }

  Widget _clamped(BuildContext context, double width) {
    if (!width.isFinite) return child;

    // The style a small or base DivineButton draws its label in. Only its
    // metrics are read; the colour is never painted.
    var style = VineTheme.titleMediumFont(color: context.vineColors.onSurface);
    // Text switches to bold when the platform asks for Bold Text.
    if (MediaQuery.boldTextOf(context)) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    // The widest run the line breaker will not split, by its own rules:
    // Chinese and Japanese break between characters, while "Auto-detect" does
    // not break at its hyphen and so counts as one word.
    final widestWord = painter.minIntrinsicWidth;
    painter.dispose();
    if (widestWord <= 0) return child;

    final iconSlot = hasLeadingIcon
        ? DivineIcon.scaleSize(context, _iconSize) + _iconGap
        : 0.0;
    final labelWidth = width - _buttonChrome - iconSlot;
    // Text grows a little slower than its scale, since letter spacing does
    // not scale, so the ratio at the normal size is a safe bound. The pixel
    // of slack keeps rounding from putting the word a hair over.
    final maxScaleFactor = math.max(1, (labelWidth - 1) / widestWord);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxScaleFactor.toDouble(),
      child: child,
    );
  }
}
