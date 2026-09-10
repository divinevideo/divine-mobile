import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:material_ui/material_ui.dart';

/// Gradient configuration for [DiVineAppBar] background.
///
/// Use this when the app bar needs to overlay content with a
/// gradient fade effect, such as on video detail screens.
///
/// Example usage:
/// ```dart
/// DiVineAppBar(
///   title: 'Video',
///   backgroundMode: DiVineAppBarBackgroundMode.gradient,
///   gradient: DiVineAppBarGradient.videoOverlay,
/// )
/// ```
@immutable
class DiVineAppBarGradient extends Equatable {
  /// Creates a gradient configuration.
  const DiVineAppBarGradient({
    required this.colors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.stops,
  });

  /// The colors of the gradient.
  ///
  /// Must have at least two colors.
  final List<Color> colors;

  /// The starting alignment of the gradient.
  ///
  /// Defaults to [Alignment.topCenter].
  final AlignmentGeometry begin;

  /// The ending alignment of the gradient.
  ///
  /// Defaults to [Alignment.bottomCenter].
  final AlignmentGeometry end;

  /// The stops for each color in the gradient.
  ///
  /// If null, colors are evenly distributed.
  final List<double>? stops;

  /// Standard gradient for video overlay screens.
  ///
  /// Fades from semi-transparent black at the top to fully
  /// transparent at the bottom.
  static DiVineAppBarGradient videoOverlay = DiVineAppBarGradient(
    colors: [
      VineTheme.backgroundColor.withValues(alpha: 0.7),
      VineTheme.transparent,
    ],
  );

  /// Creates a subtle gradient for overlay screens.
  ///
  /// Lighter fade than [videoOverlay] for less contrast.
  static DiVineAppBarGradient subtleOverlay = DiVineAppBarGradient(
    colors: [
      VineTheme.backgroundColor.withValues(alpha: 0.4),
      VineTheme.transparent,
    ],
  );

  /// Converts this configuration to a [LinearGradient].
  LinearGradient toLinearGradient() {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: stops,
    );
  }

  @override
  List<Object?> get props => [colors, begin, end, stops];
}
