// ABOUTME: Frosted backdrop shared by chrome that floats over video:
// ABOUTME: the playback toggles pill and the closed-caption pill.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Blurred, tinted backdrop for chrome drawn over video.
///
/// Every surface built on this widget blurs what is behind it by the same
/// sigma. The tint defaults to scrim-30 in dark mode and the light
/// media-chrome surface in light mode; [color] overrides it.
class MediaChromeBackdrop extends StatelessWidget {
  /// Creates a backdrop clipped to [borderRadius] behind [child].
  const MediaChromeBackdrop({
    required this.borderRadius,
    required this.child,
    this.color,
    this.border,
    this.boxShadow,
    super.key,
  });

  /// Gaussian blur sigma applied to whatever sits behind the backdrop.
  static const blurSigma = 4.0;

  /// Corner radius of the clip and the tint.
  final BorderRadius borderRadius;

  /// Tint painted over the blur, in place of the theme's media chrome.
  final Color? color;

  /// Optional outline painted on top of the tint.
  final BoxBorder? border;

  /// Optional shadow painted with the tint.
  final List<BoxShadow>? boxShadow;

  /// Content drawn on the backdrop.
  final Widget child;

  /// Default tint painted over the blurred backdrop.
  static Color backgroundOf(BuildContext context) =>
      _isLightOf(context) ? context.vineColors.mediaChrome : VineTheme.scrim30;

  /// Ink for icons and text drawn on the default tint.
  static Color foregroundOf(BuildContext context) => _isLightOf(context)
      ? context.vineColors.mediaChromeForeground
      : VineTheme.onSurface;

  static bool _isLightOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? backgroundOf(context),
            borderRadius: borderRadius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
