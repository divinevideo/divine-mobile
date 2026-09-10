import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A custom range slider matching the Divine design system.
///
/// Wraps a Material [RangeSlider] with the same themed track (pill-shaped,
/// uniform height) and tall rectangular thumb indicators as `DivineSlider`.
/// The active portion between the thumbs uses the primary color and the
/// inactive portions follow the `disabled` color of the active appearance
/// mode.
class DivineRangeSlider extends StatelessWidget {
  /// Creates a [DivineRangeSlider].
  ///
  /// [values] must lie between [min] and [max].
  const DivineRangeSlider({
    required this.values,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.trackHeight = 8,
    this.thumbWidth = 4,
    this.thumbHeight = 32,
    this.activeColor = VineTheme.primary,
    this.inactiveColor,
    this.thumbColor,
    this.labels,
    super.key,
  }) : assert(min <= max, 'min must be <= max'),
       assert(divisions == null || divisions > 0, 'divisions must be > 0'),
       assert(trackHeight >= 0, 'trackHeight must be >= 0'),
       assert(thumbWidth > 0, 'thumbWidth must be > 0'),
       assert(thumbHeight > 0, 'thumbHeight must be > 0');

  /// The currently selected start/end values.
  final RangeValues values;

  /// Called when the user changes either thumb.
  final ValueChanged<RangeValues>? onChanged;

  /// Called with the final values when the user stops dragging (finger up).
  ///
  /// Use this to commit an expensive side effect once, instead of on every
  /// [onChanged] tick during the drag.
  final ValueChanged<RangeValues>? onChangeEnd;

  /// The minimum value. Defaults to `0`.
  final double min;

  /// The maximum value. Defaults to `1`.
  final double max;

  /// Number of discrete divisions. When set, the thumbs snap to
  /// equally-spaced division points. Defaults to `null` (continuous).
  final int? divisions;

  /// Height of the track in logical pixels. Defaults to `8`.
  final double trackHeight;

  /// Width of each thumb indicator. Defaults to `4`.
  final double thumbWidth;

  /// Height of each thumb indicator. Defaults to `32`.
  final double thumbHeight;

  /// Color of the filled (active) track portion between the thumbs.
  final Color activeColor;

  /// Color of the unfilled (inactive) track portions.
  ///
  /// Defaults to the `disabled` color of the active appearance mode.
  final Color? inactiveColor;

  /// Color of the thumb indicators.
  ///
  /// Defaults to the `onSurface` color of the active appearance mode. Pass
  /// [VineTheme.onSurface] explicitly for sliders that sit on a scrim over
  /// media, where the thumbs must stay light in both modes.
  final Color? thumbColor;

  /// Optional accessibility labels for the two thumbs. Passed to
  /// [RangeSlider.labels] so screen readers announce them alongside the
  /// values; no visible bubbles render because the theme sets
  /// [ShowValueIndicator.never].
  final RangeLabels? labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return SliderTheme(
      data: SliderThemeData(
        padding: EdgeInsets.zero,
        activeTrackColor: activeColor,
        inactiveTrackColor: inactiveColor ?? colors.disabled,
        trackHeight: trackHeight,
        rangeTrackShape: DivineRangeSliderTrackShape(trackHeight: trackHeight),
        thumbColor: thumbColor ?? colors.onSurface,
        rangeThumbShape: DivineRangeSliderThumbShape(
          width: thumbWidth,
          height: thumbHeight,
        ),
        overlayShape: SliderComponentShape.noOverlay,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: RangeSlider(
        values: RangeValues(
          values.start.clamp(min, max),
          values.end.clamp(min, max),
        ),
        min: min,
        max: max,
        divisions: divisions,
        labels: labels,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// Uniform-height range track with pill-shaped (fully rounded) ends.
///
/// The inactive track spans the full width; the active portion between the
/// two thumbs is painted on top with rounded ends so it never pokes out of
/// the pill background at the extremes.
@visibleForTesting
class DivineRangeSliderTrackShape extends RangeSliderTrackShape {
  /// Creates a uniform range track shape with the given [trackHeight].
  const DivineRangeSliderTrackShape({this.trackHeight = 8});

  /// Height of the track.
  final double trackHeight;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    required TextDirection textDirection,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRadius = Radius.circular(trackHeight / 2);
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackBottom = trackTop + trackHeight;
    final trackLeft = offset.dx;
    final trackRight = offset.dx + parentBox.size.width;

    final canvas = context.canvas;

    // Inactive track — full width, painted first as the background.
    final inactiveRect = RRect.fromLTRBR(
      trackLeft,
      trackTop,
      trackRight,
      trackBottom,
      trackRadius,
    );
    canvas.drawRRect(
      inactiveRect,
      // Fallback is unreachable when used via DivineRangeSlider (always sets
      // SliderThemeData.inactiveTrackColor), kept for standalone usage.
      Paint()
        ..color = sliderTheme.inactiveTrackColor ?? VineTheme.onSurfaceDisabled,
    );

    // Active track — between the thumbs. RangeSlider already orders the
    // thumb centers for the text direction, so min/max keeps this RTL-safe.
    final activeLeft = startThumbCenter.dx < endThumbCenter.dx
        ? startThumbCenter.dx
        : endThumbCenter.dx;
    final activeRight = startThumbCenter.dx < endThumbCenter.dx
        ? endThumbCenter.dx
        : startThumbCenter.dx;
    canvas.drawRRect(
      RRect.fromLTRBR(
        activeLeft,
        trackTop,
        activeRight,
        trackBottom,
        trackRadius,
      ),
      // Fallback is unreachable when used via DivineRangeSlider (always sets
      // SliderThemeData.activeTrackColor), kept for standalone usage.
      Paint()..color = sliderTheme.activeTrackColor ?? VineTheme.primary,
    );
  }
}

/// Tall capsule-shaped thumb indicator for the Divine range slider.
///
/// Same look as `DivineSliderThumbShape`, implemented against the
/// [RangeSliderThumbShape] interface Material's [RangeSlider] requires.
@visibleForTesting
class DivineRangeSliderThumbShape extends RangeSliderThumbShape {
  /// Creates a thumb shape with the given [width] and [height].
  const DivineRangeSliderThumbShape({
    this.width = 4,
    this.height = 32,
  });

  /// Width of the thumb.
  final double width;

  /// Height of the thumb.
  final double height;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required SliderThemeData sliderTheme,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      // Fallback is unreachable when used via DivineRangeSlider (always sets
      // SliderThemeData.thumbColor), kept for standalone usage.
      Paint()..color = sliderTheme.thumbColor ?? VineTheme.onSurface,
    );
  }
}
