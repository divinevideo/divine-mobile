// ABOUTME: Progress indicators that honor the platform reduced-motion setting.
// ABOUTME: Prevents perpetual animations from blocking UI automation.

import 'package:flutter/material.dart';

/// A circular Material progress indicator that becomes static when motion is
/// disabled by the platform.
///
/// Flutter's indeterminate [CircularProgressIndicator] repeats forever and
/// does not consult [MediaQueryData.disableAnimations]. That is both an
/// accessibility problem and enough to keep XCUITest hierarchy requests from
/// reaching quiescence. A caller-supplied [value] remains unchanged; only an
/// otherwise indeterminate indicator becomes a complete, static ring.
class DivineCircularProgressIndicator extends StatelessWidget {
  /// Creates a reduced-motion-aware circular progress indicator.
  const DivineCircularProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.strokeWidth,
    this.strokeAlign,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeCap,
    this.constraints,
    this.trackGap,
    this.padding,
  });

  /// The progress value, or null for indeterminate progress.
  final double? value;

  /// The color of the track behind the indicator.
  final Color? backgroundColor;

  /// The indicator color.
  final Color? color;

  /// An animation supplying the indicator color.
  final Animation<Color?>? valueColor;

  /// The width of the circular stroke.
  final double? strokeWidth;

  /// The stroke position relative to the indicator path.
  final double? strokeAlign;

  /// The accessibility label for the indicator.
  final String? semanticsLabel;

  /// The accessibility value for determinate progress.
  final String? semanticsValue;

  /// The shape used at the ends of the progress arc.
  final StrokeCap? strokeCap;

  /// Optional size constraints for the indicator.
  final BoxConstraints? constraints;

  /// The gap between the indicator and its track.
  final double? trackGap;

  /// Padding around the indicator.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      value: value ?? (MediaQuery.disableAnimationsOf(context) ? 1 : null),
      backgroundColor: backgroundColor,
      color: color,
      valueColor: valueColor,
      strokeWidth: strokeWidth ?? 4,
      strokeAlign: strokeAlign ?? CircularProgressIndicator.strokeAlignInside,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      strokeCap: strokeCap,
      constraints: constraints,
      trackGap: trackGap,
      padding: padding,
    );
  }
}

/// A linear Material progress indicator that becomes static when motion is
/// disabled by the platform.
class DivineLinearProgressIndicator extends StatelessWidget {
  /// Creates a reduced-motion-aware linear progress indicator.
  const DivineLinearProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
    this.borderRadius,
    this.stopIndicatorColor,
    this.stopIndicatorRadius,
    this.trackGap,
  });

  /// The progress value, or null for indeterminate progress.
  final double? value;

  /// The color of the track behind the indicator.
  final Color? backgroundColor;

  /// The indicator color.
  final Color? color;

  /// An animation supplying the indicator color.
  final Animation<Color?>? valueColor;

  /// The minimum height of the progress line.
  final double? minHeight;

  /// The accessibility label for the indicator.
  final String? semanticsLabel;

  /// The accessibility value for determinate progress.
  final String? semanticsValue;

  /// The border radius of the indicator and track.
  final BorderRadiusGeometry? borderRadius;

  /// The stop-indicator color.
  final Color? stopIndicatorColor;

  /// The stop-indicator radius.
  final double? stopIndicatorRadius;

  /// The gap between the indicator and its track.
  final double? trackGap;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value ?? (MediaQuery.disableAnimationsOf(context) ? 1 : null),
      backgroundColor: backgroundColor,
      color: color,
      valueColor: valueColor,
      minHeight: minHeight,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      borderRadius: borderRadius,
      stopIndicatorColor: stopIndicatorColor,
      stopIndicatorRadius: stopIndicatorRadius,
      trackGap: trackGap,
    );
  }
}
