// ABOUTME: Looped animated preview of a TitleStyle: sample text in the
// ABOUTME: style's font, colors and pill, entering, holding and leaving with
// ABOUTME: its animations — fade, scale and slide composed like the export.

import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show LayerAnimation, LayerAnimationType, SlideDirection;

/// Plays [text] through [style]'s enter and leave animations once per loop:
/// it animates in at the start of the loop, holds, and animates out at the
/// end, so a row in the saved styles sheet shows the whole treatment.
///
/// Fade, scale and slide are composed the way the export renderer and the
/// in-editor `LayerTimelineVisibility` combine per-layer animations. A slide
/// travels the width or height of the preview — far enough to leave it —
/// from the edge its direction names, or along the line a custom point makes
/// with the resting place.
class TitleStylePreview extends StatelessWidget {
  /// Creates a preview driven by [loop] (0..1) over a [loopMs] loop.
  const TitleStylePreview({
    required this.style,
    required this.text,
    required this.loop,
    required this.loopMs,
    required this.width,
    required this.height,
    super.key,
  });

  /// The style to render.
  final TitleStyle style;

  /// The sample text, usually the selected layer's own — what the user will
  /// actually see restyled.
  final String text;

  /// Drives the loop; its value is the current position, 0..1.
  ///
  /// Named for the loop rather than the animation because this file's other
  /// `animation` is a [LayerAnimation] — one of the style's own.
  final Animation<double> loop;

  /// Loop length in milliseconds; animation durations are relative to it.
  final int loopMs;

  /// Preview width; horizontal slides travel across it.
  final double width;

  /// Preview height; vertical slides travel across it.
  final double height;

  /// Loop position at which the text is fully on screen; the frame to hold
  /// under reduced motion.
  static const double holdValue = 0.5;

  /// Font size the smallest and largest [TitleStyle.fontScale] map to.
  ///
  /// The canvas size does not fit a row: the editor's default scale alone
  /// renders at 54 px, which fills the tile and ellipsizes any real title.
  /// A linear map keeps the ordering — a bigger style still previews bigger
  /// — while every size stays legible and inside the tile.
  static const double minFontSize = 11;
  static const double maxFontSize = 22;

  /// Longest share of the loop one phase may take, so the text always holds
  /// between entering and leaving.
  static const double _maxPhaseFraction = 0.4;

  @override
  Widget build(BuildContext context) {
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
            // The loop runs for as long as the sheet is open, so keep its
            // repaints off the row, the reorderable list and the sheet.
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, child) {
                  final (:opacity, :scale, :translation) = _transform(
                    loop.value,
                  );
                  return Transform.translate(
                    offset: translation,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  );
                },
                // Only the transform changes between frames. The pill and its
                // text are hoisted out of the builder because resolving the
                // font is not free: `style.font` is a google_fonts call, and
                // every invocation allocates a load future and registers it in
                // the package's global pending-font set. Built inside the
                // builder it ran once per row per frame, for the whole time the
                // sheet was open.
                child: _StyledSample(
                  style: style,
                  text: text,
                  fontSize: _fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The style's font scale mapped onto [minFontSize]..[maxFontSize].
  double get _fontSize {
    const min = VideoEditorConstants.minFontScale;
    const max = VideoEditorConstants.maxFontScale;
    final t = ((style.fontScale - min) / (max - min)).clamp(0.0, 1.0);
    return lerpDouble(minFontSize, maxFontSize, t) ?? minFontSize;
  }

  /// Visual transform of the text at [local] (0..1 within the loop): enter
  /// animations play at the start, leave animations at the end, with a hold
  /// in between.
  ({double opacity, double scale, Offset translation}) _transform(
    double local,
  ) {
    var opacity = 1.0;
    var scale = 1.0;
    var translation = Offset.zero;

    for (final animation in style.enter) {
      final frac = _phaseFraction(animation);
      if (frac <= 0) continue;
      final progress = flutterCurveFor(
        animation.curve,
      ).transform((local / frac).clamp(0.0, 1.0));
      switch (animation.type) {
        case LayerAnimationType.fade:
          opacity *= progress;
        case LayerAnimationType.scale:
          scale *= lerpDouble(animation.scaleFrom ?? 0, 1, progress) ?? 1;
        case LayerAnimationType.slide:
          translation +=
              _slideOffset(animation, style.enterPoint) * (1 - progress);
      }
    }

    for (final animation in style.leave) {
      final frac = _phaseFraction(animation);
      if (frac <= 0) continue;
      final start = 1 - frac;
      if (local <= start) continue;
      final progress = flutterCurveFor(
        animation.curve,
      ).transform(((local - start) / frac).clamp(0.0, 1.0));
      switch (animation.type) {
        case LayerAnimationType.fade:
          opacity *= 1 - progress;
        case LayerAnimationType.scale:
          scale *= lerpDouble(1, animation.scaleFrom ?? 0, progress) ?? 1;
        case LayerAnimationType.slide:
          translation += _slideOffset(animation, style.leavePoint) * progress;
      }
    }

    return (opacity: opacity, scale: scale, translation: translation);
  }

  /// The share of the loop [animation] plays over, capped so the text holds.
  double _phaseFraction(LayerAnimation animation) =>
      (animation.duration.inMilliseconds / loopMs).clamp(
        0.0,
        _maxPhaseFraction,
      );

  /// Where the text sits when fully away: past the edge [animation]'s
  /// direction names, or out along the line towards [point], a canvas
  /// fraction measured from the centre — the same origin the text rests at.
  Offset _slideOffset(LayerAnimation animation, Offset? point) {
    if (point != null && point.distance > 0) {
      return point / point.distance * width;
    }
    return switch (animation.slideDirection) {
      SlideDirection.left => Offset(-width, 0),
      SlideDirection.right => Offset(width, 0),
      SlideDirection.top => Offset(0, -height),
      SlideDirection.bottom => Offset(0, height),
      null => Offset.zero,
    };
  }
}

/// The sample text in [style]'s font, colors and pill — everything about a
/// preview frame that does not change as the loop runs.
class _StyledSample extends StatelessWidget {
  const _StyledSample({
    required this.style,
    required this.text,
    required this.fontSize,
  });

  final TitleStyle style;
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: style.hasBackground
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : EdgeInsets.zero,
      decoration: style.hasBackground
          ? BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: style.align,
        style: style.font(fontSize: fontSize, color: style.color),
      ),
    );
  }
}
