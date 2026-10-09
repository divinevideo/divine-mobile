// ABOUTME: Snapshot of the editor's overlays (layers, filters, tune, effects, blur)
// ABOUTME: Windows them down to one clip's slice of the editor timeline

import 'dart:ui';

import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show CustomVideoEffect, VideoEffect;

/// The overlays sitting over the composition at one moment: captured layers
/// (text / stickers / drawings), colour filters, tune adjustments, video
/// effects and blur.
///
/// Overlay time windows are authored on the **editor timeline** — every clip at
/// its full playback length, `sum(clip.playbackDuration)` — which is the same
/// axis `TransitionTimelineMap` maps from. [windowedTo] slices that axis down to
/// a single clip so the clip can be rendered on its own with exactly the
/// overlays that were over it.
class EditorOverlaySnapshot {
  const EditorOverlaySnapshot({
    this.capturedLayers = const [],
    this.filterStates = const [],
    this.tuneAdjustments = const [],
    this.effects = const [],
    this.customEffects = const [],
    this.blur = 0,
    this.bodySize,
  });

  /// Overlay layers, each already rasterized to bytes.
  final List<ExportedLayer> capturedLayers;

  /// Colour filters (sepia, noir, …), each with its own time window.
  final List<FilterState> filterStates;

  /// Tune adjustments (brightness, contrast, …), each with its own window.
  final List<TuneAdjustmentMatrix> tuneAdjustments;

  /// Video effects (glitch, VHS, pixelate), each with its own window.
  final List<VideoEffect> effects;

  /// Effects Divine renders itself (the echo trail), each with its own window.
  final List<CustomVideoEffect> customEffects;

  /// Blur strength applied to the whole composition. Carries no time window.
  final double blur;

  /// The editor body size the layers were laid out against. Layer offsets are
  /// meaningless without it, so the render skips layers when it is `null`.
  final Size? bodySize;

  /// Whether there is nothing to bake, so the render can skip the overlay pass.
  bool get isEmpty =>
      capturedLayers.isEmpty &&
      filterStates.isEmpty &&
      tuneAdjustments.isEmpty &&
      effects.isEmpty &&
      customEffects.isEmpty &&
      blur == 0;

  /// A copy without the flashing effects (see [isFlashingVideoEffect]).
  EditorOverlaySnapshot withoutFlashingEffects() => EditorOverlaySnapshot(
    capturedLayers: capturedLayers,
    filterStates: filterStates,
    tuneAdjustments: tuneAdjustments,
    effects: [
      for (final effect in effects)
        if (!isFlashingVideoEffect(effect.type)) effect,
    ],
    customEffects: customEffects,
    blur: blur,
    bodySize: bodySize,
  );

  /// Returns the overlays visible between [start] and [end] on the editor
  /// timeline, rebased so the window starts at zero.
  ///
  /// Overlays that don't reach into the window are dropped; overlays that only
  /// partly cover it are clamped to it. A `null` start/end means "unbounded" —
  /// after windowing every bound is concrete, because an overlay that outlives
  /// the window still ends where the clip does.
  ///
  /// [blur] and [bodySize] carry through untouched: blur has no time window and
  /// body size is a layout constant, not a timeline value.
  EditorOverlaySnapshot windowedTo({
    required Duration start,
    required Duration end,
  }) {
    if (end <= start) {
      return EditorOverlaySnapshot(blur: blur, bodySize: bodySize);
    }

    return EditorOverlaySnapshot(
      capturedLayers: [
        for (final item in capturedLayers)
          if (_windowFor(item.layer.startTime, item.layer.endTime, start, end)
              case final w?)
            ExportedLayer(
              layer: _windowedLayer(item.layer, w, windowStart: start),
              bytes: item.bytes,
              logicalSize: item.logicalSize,
              highlightBytes: item.highlightBytes,
              revealBytes: item.revealBytes,
            ),
      ],
      filterStates: [
        for (final filter in filterStates)
          if (_windowFor(filter.startTime, filter.endTime, start, end)
              case final w?)
            filter.copyWith(startTime: w.start, endTime: w.end),
      ],
      tuneAdjustments: [
        for (final tune in tuneAdjustments)
          if (_windowFor(tune.startTime, tune.endTime, start, end)
              case final w?)
            tune.copyWith(startTime: w.start, endTime: w.end),
      ],
      // A saved clip is a video of its own, so an effect's animation starts
      // over with it.
      effects: [
        for (final effect in effects)
          if (_windowFor(effect.startTime, effect.endTime, start, end)
              case final w?)
            effect.copyWith(startTime: w.start, endTime: w.end),
      ],
      customEffects: [
        for (final effect in customEffects)
          if (_windowFor(effect.startTime, effect.endTime, start, end)
              case final w?)
            CustomVideoEffect(
              id: effect.id,
              params: effect.params,
              startTime: w.start,
              endTime: w.end,
            ),
      ],
      blur: blur,
      bodySize: bodySize,
    );
  }

  /// Copies [layer] onto its clip-local window [w], dropping any enter/leave
  /// animation whose edge was clamped away.
  ///
  /// The copy is safe even though `copyWith` on a concrete layer subtype
  /// (text/paint/…) returns that same subtype: the visual content already
  /// travels in the rasterized `bytes` (a text layer's lit words in
  /// `highlightBytes`, its reveal steps in `revealBytes`), and the render
  /// reads back only offset, time window, animations and a text layer's
  /// highlights. Copying rather than mutating
  /// matters because these fields are mutable and the source is the editor's
  /// live layer.
  ///
  /// A layer that reached past the window on a side sat steadily on screen
  /// there on the timeline — its enter (start clamped) or leave (end clamped)
  /// played *outside* this clip. Replaying it inside the saved clip would show
  /// motion that never happened over the clip, so the clamped-away phase (and
  /// the legacy fade synthesized from [Layer.enterDuration] /
  /// [Layer.exitDuration]) is dropped. A loop is kept and starts over with the
  /// clip, the way a video effect's animation does.
  ///
  /// [TextLayer.highlights] and [Layer.keyframes] count from the layer's
  /// start, so when that start moves relative to them — a caption that began
  /// before the clip — they are moved back by the same amount to stay on
  /// their words and their places on the clip.
  static Layer _windowedLayer(
    Layer layer,
    _OverlayWindow w, {
    required Duration windowStart,
  }) {
    final strip = w.startClamped || w.endClamped;
    final animations = layer.animations.isEmpty || !strip
        ? layer.animations
        : [
            for (final a in layer.animations)
              if (!_isClampedAway(a.phase, w)) a,
          ];

    // How much later the layer starts on the clip than it did on the
    // timeline, measured on the timeline.
    final startShift =
        w.start + windowStart - (layer.startTime ?? Duration.zero);
    final windowed = layer.copyWith(
      startTime: w.start,
      endTime: w.end,
      animations: animations,
      // Keyframes count from the layer's start, so they move back with it to
      // stay where they are on the clip.
      keyframes: [
        for (final keyframe in layer.keyframes)
          keyframe.copyWith(time: keyframe.time - startShift),
      ],
    );
    // copyWith can't null a Duration field (it null-coalesces to the old
    // value), so clear the legacy fade convenience on the fresh copy directly.
    if (w.startClamped) windowed.enterDuration = null;
    if (w.endClamped) windowed.exitDuration = null;

    if (windowed is TextLayer && startShift != Duration.zero) {
      windowed.highlights = [
        for (final highlight in windowed.highlights)
          highlight.copyWith(
            startTime: highlight.startTime - startShift,
            endTime: highlight.endTime - startShift,
          ),
      ];
    }
    return windowed;
  }

  /// Whether an animation of [phase] belongs to time outside the clip and so
  /// should be dropped. `animateInOut` spans both edges, so it only goes when
  /// *both* were clamped.
  static bool _isClampedAway(AnimationPhase phase, _OverlayWindow w) =>
      (w.startClamped && phase == AnimationPhase.animateIn) ||
      (w.endClamped && phase == AnimationPhase.animateOut) ||
      (w.startClamped && w.endClamped && phase == AnimationPhase.animateInOut);

  /// Intersects an overlay's `[from, to]` window (either side `null` for
  /// unbounded) with `[windowStart, windowEnd]`, rebased to the window's start.
  ///
  /// `startClamped` / `endClamped` report whether the overlay reached past that
  /// edge of the window (or was unbounded there) — i.e. its enter/leave belongs
  /// to time outside the clip.
  ///
  /// Returns `null` when the overlay never shows inside the window.
  static _OverlayWindow? _windowFor(
    Duration? from,
    Duration? to,
    Duration windowStart,
    Duration windowEnd,
  ) {
    final effectiveFrom = from ?? Duration.zero;
    // An unbounded end runs to the window's end by definition.
    final effectiveTo = to ?? windowEnd;

    // Touching the boundary is not overlapping: an overlay that ends exactly
    // where the clip starts was never over it.
    if (effectiveFrom >= windowEnd || effectiveTo <= windowStart) return null;

    final clampedFrom = effectiveFrom < windowStart
        ? windowStart
        : effectiveFrom;
    final clampedTo = effectiveTo > windowEnd ? windowEnd : effectiveTo;

    return (
      start: clampedFrom - windowStart,
      end: clampedTo - windowStart,
      startClamped: from == null || from < windowStart,
      endClamped: to == null || to > windowEnd,
    );
  }
}

/// A clip-local overlay window plus whether each edge was clamped from a wider
/// span (so an enter/leave animation on that edge played outside the clip).
typedef _OverlayWindow = ({
  Duration start,
  Duration end,
  bool startClamped,
  bool endClamped,
});
