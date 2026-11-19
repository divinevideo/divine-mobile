// ABOUTME: Looped animated preview of a caption CaptionStyle (font + colors
// ABOUTME: + outline and shadow + animation), cycling two cues so the
// ABOUTME: enter→leave→next transition is visible, shared by the preset grid,
// ABOUTME: custom editor and saved styles.

import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_preview_cues.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/video_editor/text_effects_preview_text.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Loops two sample [cues] through [style]'s enter and leave animations, so
/// the preview shows the whole transition — one cue animates in, holds,
/// animates out, the next takes over, then it restarts. A word-highlighting
/// style lights up the words of each cue in turn instead.
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
    this.cues = CaptionPreviewCues.fallback,
    super.key,
  });

  /// The style to render.
  final CaptionStyle style;

  /// The two cues the loop shows, one after the other.
  final CaptionPreviewCues cues;

  /// Space kept between the cue and the tile's edges.
  static const _inset = 6.0;

  /// Current loop position, 0..1.
  final double loopValue;

  /// Loop length in milliseconds; animation durations are relative to it.
  final int loopMs;

  /// Preview width.
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
    final text = firstHalf ? cues.first : cues.second;
    final local = (firstHalf ? loopValue : loopValue - 0.5) / 0.5;
    final windowMs = loopMs / 2;
    final (:opacity, :scale) = _transform(local, windowMs);

    final hasPill = style.colorMode != LayerBackgroundMode.onlyColor;
    final textStyle = style.font(
      fontSize:
          VideoEditorConstants.baseFontSize * style.fontScale * fontSizeFactor,
      color: style.color,
    );
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
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            // The cue wraps at the tile's width the way a caption layer wraps
            // at the video's, and a cue taller than the tile shrinks to fit:
            // it is always shown whole, as the editor shows it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width - 2 * _inset),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Container(
                      padding: hasPill
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            )
                          : EdgeInsets.zero,
                      decoration: hasPill
                          ? BoxDecoration(
                              color: style.background,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: TextEffectsPreviewText(
                        text,
                        textAlign: TextAlign.center,
                        effects: style.effects,
                        style: textStyle,
                        highlightRange: _litWord(text, local),
                        highlightColor: style.highlightColor,
                      ),
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

  /// The word of [text] lit at [local] (0..1 within its cue window) by a
  /// word-highlighting style: the words take turns across the window, the
  /// way evenly spoken words would. `null` for a style without highlights.
  TextRange? _litWord(String text, double local) {
    if (style.highlightColor == null) return null;
    final words = _wordPattern.allMatches(text).toList();
    if (words.isEmpty) return null;
    final lit =
        words[(local * words.length).floor().clamp(0, words.length - 1)];
    return TextRange(start: lit.start, end: lit.end);
  }

  static final _wordPattern = RegExp(r'\S+');

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
      final progress = flutterCurveFor(animation.curve)
          .transform((local / frac).clamp(0.0, 1.0));
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
      final progress = flutterCurveFor(animation.curve)
          .transform(((local - start) / frac).clamp(0.0, 1.0));
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
