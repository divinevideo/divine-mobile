// ABOUTME: Looped animated preview of a caption CaptionStyle (font + colors
// ABOUTME: + animation), cycling two cues so the enter→leave→next transition
// ABOUTME: is visible, shared by the preset grid and custom editor.

import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Loops two sample cues ([_cueA], then the app name) through [style]'s enter
/// and leave animations, so the preview shows the whole transition — one word
/// animates in, holds, animates out, the next takes over, then it restarts.
///
/// Composes fade (opacity) and scale the same way the export renderer and
/// `LayerTimelineVisibility` combine per-layer animations, so the preview
/// matches the burned-in result. Captions never slide (see
/// `CaptionAnimationStyle`), so no translation is composed here.
class CaptionStylePreview extends StatelessWidget {
  /// Creates a preview at [loopValue] (0..1) of a [loopMs] loop.
  const CaptionStylePreview({
    required this.style,
    required this.loopValue,
    required this.loopMs,
    required this.width,
    required this.height,
    this.fontSizeFactor = 0.62,
    super.key,
  });

  /// The two-beat sample caption. Deliberately English everywhere: a Vine
  /// wordplay tagline not user content, so it never goes through l10n.
  static const _cueA = 'Do It For';

  /// The style to render.
  final CaptionStyle style;

  /// Current loop position, 0..1.
  final double loopValue;

  /// Loop length in milliseconds; animation durations are relative to it.
  final int loopMs;

  /// Preview size; slide animations travel across it.
  final double width;

  /// Preview height.
  final double height;

  /// Multiplier on the editor base font size (tiles use a smaller preview
  /// than the large custom-editor preview).
  final double fontSizeFactor;

  @override
  Widget build(BuildContext context) {
    // The loop is two back-to-back cue windows; only the active cue renders.
    final firstHalf = loopValue < 0.5;
    final text = firstHalf ? _cueA : AppConfig.appName;
    final local = (firstHalf ? loopValue : loopValue - 0.5) / 0.5;
    final windowMs = loopMs / 2;
    final (:opacity, :scale) = _transform(local, windowMs);

    final hasPill = style.colorMode != LayerBackgroundMode.onlyColor;
    return ClipRRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VineTheme.primaryDarkGreen, VineTheme.surfaceBackground],
          ),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  padding: hasPill
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : EdgeInsets.zero,
                  decoration: hasPill
                      ? BoxDecoration(
                          color: style.background,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: style.font(
                      fontSize:
                          VideoEditorConstants.baseFontSize *
                          style.fontScale *
                          fontSizeFactor,
                      color: style.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Visual transform of the active cue at [local] (0..1 within its window of
  /// [windowMs]): enter animations play at the start, leave animations at the
  /// end, with a hold in between.
  ({double opacity, double scale}) _transform(double local, double windowMs) {
    var opacity = 1.0;
    var scale = 1.0;

    for (final animation in style.enter) {
      // Cap the enter window so a cue always has a hold before it leaves.
      final frac = (animation.duration.inMilliseconds / windowMs).clamp(
        0.0,
        0.45,
      );
      if (frac <= 0) continue;
      final progress = flutterCurveFor(
        animation.curve,
      ).transform((local / frac).clamp(0.0, 1.0));
      switch (animation.type.name) {
        case 'fade':
          opacity *= progress;
        case 'scale':
          scale *= lerpDouble(animation.scaleFrom ?? 0.5, 1, progress) ?? 1;
      }
    }

    for (final animation in style.leave) {
      final frac = (animation.duration.inMilliseconds / windowMs).clamp(
        0.0,
        0.45,
      );
      if (frac <= 0) continue;
      final start = 1 - frac;
      if (local <= start) continue;
      final progress = flutterCurveFor(
        animation.curve,
      ).transform(((local - start) / frac).clamp(0.0, 1.0));
      switch (animation.type.name) {
        case 'fade':
          opacity *= 1 - progress;
        case 'scale':
          scale *= lerpDouble(1, animation.scaleFrom ?? 0.5, progress) ?? 1;
      }
    }

    return (opacity: opacity, scale: scale);
  }
}
