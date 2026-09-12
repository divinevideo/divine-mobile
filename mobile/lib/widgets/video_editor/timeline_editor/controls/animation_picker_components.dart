// ABOUTME: Shared building blocks for the clip-transition and layer-animation
// ABOUTME: pickers: selectable chips, the easing-curve glyph + curve row.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationCurve;

/// Maps a pro_video_editor [AnimationCurve] onto the matching Flutter [Curve].
Curve flutterCurveFor(AnimationCurve curve) => switch (curve) {
  AnimationCurve.linear => Curves.linear,
  AnimationCurve.easeIn => Curves.easeIn,
  AnimationCurve.easeOut => Curves.easeOut,
  AnimationCurve.easeInOut => Curves.easeInOut,
  AnimationCurve.easeInCubic => Curves.easeInCubic,
  AnimationCurve.easeOutCubic => Curves.easeOutCubic,
  AnimationCurve.easeInOutCubic => Curves.easeInOutCubic,
  AnimationCurve.bounceIn => Curves.bounceIn,
  AnimationCurve.bounceOut => Curves.bounceOut,
  AnimationCurve.bounceInOut => Curves.bounceInOut,
  AnimationCurve.elasticIn => Curves.elasticIn,
  AnimationCurve.elasticOut => Curves.elasticOut,
  AnimationCurve.elasticInOut => Curves.elasticInOut,
};

/// Small section label used above picker control groups.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: VineTheme.labelSmallFont(color: context.vineColors.secondaryText),
  );
}

/// Selectable pill used for curve and direction options. The glyph/icon it
/// holds carries no text, so [semanticLabel] names the option for screen
/// readers and [selected] is surfaced as the semantic selected state.
class AnimationPickerChip extends StatelessWidget {
  const AnimationPickerChip({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    super.key,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          // 48dp min keeps the tap target at the accessibility floor on both
          // axes: the wider curve glyphs already clear 48dp via padding, but
          // the 18dp direction icons (18+14+14 = 46dp) need the minWidth.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.controlSelectedFill : colors.controlFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? colors.accentBrand : colors.controlOutline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrap of every easing-[AnimationCurve], each drawn as a glyph. The selected
/// curve is highlighted; [onChanged] fires with the tapped curve.
class CurvePickerRow extends StatelessWidget {
  const CurvePickerRow({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AnimationCurve selected;
  final ValueChanged<AnimationCurve> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < AnimationCurve.values.length; i++)
          AnimationPickerChip(
            selected: AnimationCurve.values[i] == selected,
            onTap: () => onChanged(AnimationCurve.values[i]),
            semanticLabel: l10n.videoEditorTransitionCurveOptionSemanticLabel(
              i + 1,
            ),
            child: SizedBox(
              width: 28,
              height: 18,
              child: CustomPaint(
                painter: CurveGlyphPainter(
                  curve: flutterCurveFor(AnimationCurve.values[i]),
                  color: AnimationCurve.values[i] == selected
                      ? context.vineColors.accentBrand
                      : context.vineColors.secondaryText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws the shape of an easing [curve] so it needs no localized label.
class CurveGlyphPainter extends CustomPainter {
  CurveGlyphPainter({required this.curve, required this.color});

  final Curve curve;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const steps = 24;
    final samples = <double>[
      for (var i = 0; i <= steps; i++) curve.transform(i / steps),
    ];
    // Normalize each curve into the glyph box so overshooting curves
    // (bounce/elastic) stay visible instead of clipping at the edges.
    final minY = samples.reduce(math.min);
    final maxY = samples.reduce(math.max);
    final span = (maxY - minY).abs() < 1e-3 ? 1.0 : maxY - minY;
    const inset = 2.0;
    final drawHeight = size.height - inset * 2;

    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final x = (i / steps) * size.width;
      final norm = (samples[i] - minY) / span;
      final y = inset + (1 - norm) * drawHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurveGlyphPainter old) =>
      old.curve != curve || old.color != color;
}
