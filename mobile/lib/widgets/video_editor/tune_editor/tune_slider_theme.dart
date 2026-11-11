// ABOUTME: The slider look of the Adjust bar, and a track that shows what a
// ABOUTME: Color section slider does to its band as a gradient.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The slider theme every slider in the Adjust bar shares.
SliderThemeData tuneSliderTheme(BuildContext context) =>
    SliderTheme.of(context).copyWith(
      trackHeight: 3,
      activeTrackColor: context.vineColors.accentPositive,
      inactiveTrackColor: context.vineColors.outlineMuted,
      thumbColor: context.vineColors.accentPositive,
      overlayColor: context.vineColors.accentPositive.withValues(alpha: 0.12),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      valueIndicatorColor: context.vineColors.surfaceContainer,
      valueIndicatorTextStyle: VineTheme.bodySmallFont(
        color: context.vineColors.primaryText,
      ),
    );

/// A rounded slider track filled with [colors] from its start to its end,
/// whatever the value, so it shows what each end does.
class TuneGradientTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  /// Creates a track running through [colors].
  const TuneGradientTrackShape(this.colors);

  /// The track's colours, from its start to its end.
  final List<Color> colors;

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required TextDirection textDirection,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final ordered = textDirection == .rtl ? colors.reversed.toList() : colors;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..shader = LinearGradient(colors: ordered).createShader(rect),
    );
  }
}
