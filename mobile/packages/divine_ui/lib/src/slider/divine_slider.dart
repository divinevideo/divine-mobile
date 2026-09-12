import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A custom slider matching the Divine design system.
///
/// Wraps a Material [Slider] with a themed track (pill-shaped, uniform
/// height) and a tall rectangular thumb indicator. The active portion uses
/// the primary color and the inactive portion follows the `disabled` color
/// of the active appearance mode.
class DivineSlider extends StatelessWidget {
  /// Creates a [DivineSlider].
  ///
  /// [value] must be between [min] and [max].
  const DivineSlider({
    required this.value,
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
    this.semanticLabel,
    super.key,
  }) : assert(min <= max, 'min must be <= max'),
       assert(divisions == null || divisions > 0, 'divisions must be > 0'),
       assert(trackHeight >= 0, 'trackHeight must be >= 0'),
       assert(thumbWidth > 0, 'thumbWidth must be > 0'),
       assert(thumbHeight > 0, 'thumbHeight must be > 0');

  /// The current value of the slider.
  final double value;

  /// Called when the user changes the slider value.
  final ValueChanged<double>? onChanged;

  /// Called with the final value when the user stops dragging (finger up).
  ///
  /// Use this to commit an expensive side effect once, instead of on every
  /// [onChanged] tick during the drag.
  final ValueChanged<double>? onChangeEnd;

  /// The minimum value. Defaults to `0`.
  final double min;

  /// The maximum value. Defaults to `1`.
  final double max;

  /// Height of the track in logical pixels. Defaults to `8`.
  final double trackHeight;

  /// Width of the thumb indicator. Defaults to `4`.
  final double thumbWidth;

  /// Height of the thumb indicator. Defaults to `32`.
  final double thumbHeight;

  /// Color of the filled (active) track portion.
  final Color activeColor;

  /// Number of discrete divisions. When set, the slider snaps to
  /// equally-spaced division points. Defaults to `null` (continuous).
  final int? divisions;

  /// Color of the unfilled (inactive) track portion.
  ///
  /// Defaults to the `disabled` color of the active appearance mode.
  final Color? inactiveColor;

  /// Color of the thumb indicator.
  ///
  /// Defaults to the `onSurface` color of the active appearance mode. Pass
  /// [VineTheme.onSurface] explicitly for sliders that sit on a scrim over
  /// media, where the thumb must stay light in both modes.
  final Color? thumbColor;

  /// Optional accessibility label describing what the slider controls (e.g.
  /// "Volume"). Passed to the Material [Slider.label] so it lands on the
  /// slider's own semantics node (a [Slider] marks itself a semantics
  /// boundary, so a wrapping `Semantics(label:)` would not label that node).
  /// Screen readers announce it alongside the value. It renders no visible
  /// value bubble because the theme sets [ShowValueIndicator.never].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return SliderTheme(
      data: SliderThemeData(
        padding: EdgeInsets.zero,
        activeTrackColor: activeColor,
        inactiveTrackColor: inactiveColor ?? colors.disabled,
        trackHeight: trackHeight,
        trackShape: DivineSliderTrackShape(trackHeight: trackHeight),
        thumbColor: thumbColor ?? colors.onSurface,
        thumbShape: DivineSliderThumbShape(
          width: thumbWidth,
          height: thumbHeight,
        ),
        overlayShape: SliderComponentShape.noOverlay,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        // Lands on the slider's own semantics boundary node; renders no
        // visible bubble under ShowValueIndicator.never.
        label: semanticLabel,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// Uniform-height track with pill-shaped (fully rounded) ends.
///
/// Both the active and inactive portions share the same height, unlike
/// the default [RoundedRectSliderTrackShape].
@visibleForTesting
class DivineSliderTrackShape extends SliderTrackShape {
  /// Creates a uniform track shape with the given [trackHeight].
  const DivineSliderTrackShape({this.trackHeight = 8});

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
    required Offset thumbCenter,
    required TextDirection textDirection,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackRadius = Radius.circular(trackHeight / 2);
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackBottom = trackTop + trackHeight;
    final trackLeft = offset.dx;
    final trackRight = offset.dx + parentBox.size.width;

    final canvas = context.canvas;
    final isLtr = textDirection == TextDirection.ltr;

    // Inactive track — full width, painted first as the background
    final inactiveRect = RRect.fromLTRBAndCorners(
      trackLeft,
      trackTop,
      trackRight,
      trackBottom,
      topLeft: trackRadius,
      bottomLeft: trackRadius,
      topRight: trackRadius,
      bottomRight: trackRadius,
    );
    canvas.drawRRect(
      inactiveRect,
      // Fallback is unreachable when used via DivineSlider (always sets
      // SliderThemeData.inactiveTrackColor), kept for standalone usage.
      Paint()
        ..color = sliderTheme.inactiveTrackColor ?? VineTheme.onSurfaceDisabled,
    );

    // Active track — painted on top, covering from the start edge to thumb
    final activeRect = RRect.fromLTRBAndCorners(
      isLtr ? trackLeft : thumbCenter.dx,
      trackTop,
      isLtr ? thumbCenter.dx : trackRight,
      trackBottom,
      topLeft: isLtr ? trackRadius : Radius.zero,
      bottomLeft: isLtr ? trackRadius : Radius.zero,
      topRight: isLtr ? Radius.zero : trackRadius,
      bottomRight: isLtr ? Radius.zero : trackRadius,
    );
    canvas.drawRRect(
      activeRect,
      // Fallback is unreachable when used via DivineSlider (always sets
      // SliderThemeData.activeTrackColor), kept for standalone usage.
      Paint()..color = sliderTheme.activeTrackColor ?? VineTheme.primary,
    );
  }
}

/// Tall capsule-shaped thumb indicator for the Divine slider.
///
/// The short ends are fully rounded (pill shape) while the height
/// creates a tall, narrow indicator.
@visibleForTesting
class DivineSliderThumbShape extends SliderComponentShape {
  /// Creates a thumb shape with the given [width] and [height].
  const DivineSliderThumbShape({
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
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      // Fallback is unreachable when used via DivineSlider (always sets
      // SliderThemeData.thumbColor), kept for standalone usage.
      Paint()..color = sliderTheme.thumbColor ?? VineTheme.onSurface,
    );
  }
}
