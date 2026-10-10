// ABOUTME: Pure geometry for clip transitions — how much of each adjacent clip
// ABOUTME: a transition consumes, the no-overlap clamp, and the rendered output
// ABOUTME: timeline. Shared by the render pipeline, seam preview, picker and the
// ABOUTME: timeline header so all of them agree on the same budget.

import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType;
import 'package:unified_logger/unified_logger.dart';

const _logName = 'TransitionGeometry';

bool _isDip(ClipTransitionType type) =>
    type == ClipTransitionType.fadeToBlack ||
    type == ClipTransitionType.fadeToWhite;

/// Whether a transition shortens the timeline. Overlaps
/// (dissolve/slide/push/wipe) blend both clips at once, so the blend duration
/// is removed from the total. Dips (fadeToBlack/White) fade out then in
/// without overlapping, so the duration is unchanged.
bool _shortensTimeline(ClipTransitionType type) => !_isDip(type);

/// Per-side playback duration a [transition] consumes at the boundary between
/// clips of playback durations [a] and [b].
///
/// An overlap (dissolve/slide/push/wipe) blends both clips at once and consumes
/// 2× its duration per side; a dip (fadeToBlack/White) fades out then in,
/// consuming half its duration per side. Clamped to the shorter clip so a
/// transition can never overrun a clip.
Duration transitionConsumedPerSide(
  Duration a,
  Duration b,
  ClipTransition transition,
) {
  final shorter = a < b ? a : b;
  final requested = _isDip(transition.type)
      ? Duration(microseconds: transition.duration.inMicroseconds ~/ 2)
      : transition.duration * 2;
  return requested < shorter ? requested : shorter;
}

/// Inverse of [transitionConsumedPerSide]: the longest transition duration of
/// [type] whose per-side consumption fits in [consumed]. Returns
/// [Duration.zero] when there is no room.
Duration transitionDurationForConsumed(
  Duration consumed,
  ClipTransitionType type,
) {
  if (consumed <= Duration.zero) return Duration.zero;
  return _isDip(type)
      ? consumed * 2
      : Duration(microseconds: consumed.inMicroseconds ~/ 2);
}

/// Maps each clip id to its outgoing transition, clamped so that **no clip is
/// consumed by transitions on both sides at once**. A clip's head (consumed by
/// the incoming boundary) plus its tail (consumed by the outgoing boundary)
/// can never exceed its playback length — the native compositor cannot render
/// two fully-overlapping dips of different colors, so overlap is prevented
/// rather than blended.
///
/// When the requested transitions would over-consume a shared clip, both
/// boundaries touching it are scaled down proportionally to their demand, so
/// each keeps a fair share and the clip is split between them (e.g. two 2s
/// dips on a 1s middle clip each render as 1s, the first half fading one way
/// and the second half the other). A single transition on a clip is never
/// reduced.
///
/// The **last clip's transition is the loop-restart wrap** (`pro_video_editor`
/// ≥ 2.5): it blends the last clip's tail into the first clip's head so a
/// looping player restarts seamlessly. It is clamped against the room left on
/// the last clip's tail and the first clip's head after their own internal
/// transitions — and, on a single clip that is both first and last, so its head
/// and tail together leave a middle body.
///
/// Returns `null` for any boundary (internal or wrap) with no room. Keyed by
/// clip id rather than index so it stays correct even if the render pipeline
/// reorders clips.
Map<String, ClipTransition?> clampTransitions(List<DivineVideoClip> clips) {
  final n = clips.length;
  if (n == 0) return const {};

  // Per-boundary requested per-side consumption. demand[i] is the internal
  // boundary between clip i and clip i+1 (clip i's outgoing transition); the
  // last clip has no internal boundary. loopDemand is the wrap boundary between
  // the last clip's tail and the first clip's head (the same clip when n == 1).
  final demand = List<Duration>.filled(n, Duration.zero);
  for (var i = 0; i < n - 1; i++) {
    final transition = clips[i].transition;
    if (transition != null) {
      demand[i] = transitionConsumedPerSide(
        clips[i].playbackDuration,
        clips[i + 1].playbackDuration,
        transition,
      );
    }
  }
  final loopTransition = clips[n - 1].transition;
  final loopDemand = loopTransition == null
      ? Duration.zero
      : transitionConsumedPerSide(
          clips[n - 1].playbackDuration,
          clips[0].playbackDuration,
          loopTransition,
        );

  // Per-clip scale so the head + tail consumption fits the clip's playback
  // length. The wrap consumes the first clip's head and the last clip's tail;
  // on a single clip it consumes both ends of that one clip. A clip touched by
  // only one transition (or none) keeps scale 1.
  final scale = List<double>.filled(n, 1);
  for (var i = 0; i < n; i++) {
    final head = i == 0 ? loopDemand : demand[i - 1];
    final tail = i == n - 1 ? loopDemand : demand[i];
    final total = head + tail;
    final playback = clips[i].playbackDuration;
    if (total > playback && total > Duration.zero) {
      scale[i] = playback.inMicroseconds / total.inMicroseconds;
    }
  }

  // Each boundary is bounded by the tighter scale of the two clips it touches,
  // so neither clip is over-consumed.
  final clamped = <String, ClipTransition?>{};
  for (var i = 0; i < n - 1; i++) {
    clamped[clips[i].id] = _clampBoundary(
      transition: clips[i].transition,
      demand: demand[i],
      scale: scale[i] < scale[i + 1] ? scale[i] : scale[i + 1],
    );
  }
  clamped[clips[n - 1].id] = _clampBoundary(
    transition: loopTransition,
    demand: loopDemand,
    scale: scale[n - 1] < scale[0] ? scale[n - 1] : scale[0],
  );
  return clamped;
}

/// Clamps [transition]'s duration to the room its boundary keeps after [scale]
/// is applied to the requested per-side [demand], logging when it shrinks.
/// Returns `null` when the boundary has no transition or no room.
ClipTransition? _clampBoundary({
  required ClipTransition? transition,
  required Duration demand,
  required double scale,
}) {
  if (transition == null || demand <= Duration.zero) return null;
  final finalConsumed = Duration(
    microseconds: (demand.inMicroseconds * scale).round(),
  );
  if (finalConsumed <= Duration.zero) return null;
  final clampedDuration = transitionDurationForConsumed(
    finalConsumed,
    transition.type,
  );
  if (clampedDuration < transition.duration) {
    Log.debug(
      '✂️ Clamping transition ${transition.duration.inMilliseconds}ms '
      'to ${clampedDuration.inMilliseconds}ms (avoids overlap on a '
      'shared clip)',
      name: _logName,
      category: .video,
    );
    return transition.copyWith(duration: clampedDuration);
  }
  return transition;
}

/// The per-side playback room the loop-restart wrap may consume at the seam
/// between the last clip's tail and the first clip's head, after those clips'
/// own internal transitions have taken their share.
///
/// On a single clip the wrap carves its head and tail from the *same* clip, so
/// the two sides split the clip and each may use at most half its playback.
/// With multiple clips it is the tighter of the last clip's remaining tail and
/// the first clip's remaining head. Feeds the loop picker's duration ceiling,
/// mirroring the internal picker's room calculation.
Duration loopTransitionRoomPerSide(List<DivineVideoClip> clips) {
  final n = clips.length;
  if (n == 0) return Duration.zero;
  final first = clips[0];
  final last = clips[n - 1];
  if (n == 1) {
    return Duration(microseconds: first.playbackDuration.inMicroseconds ~/ 2);
  }

  // The last clip's head is consumed by its incoming internal transition,
  // leaving the rest of its tail for the wrap.
  var tailRoom = last.playbackDuration;
  final incoming = clips[n - 2].transition;
  if (incoming != null) {
    tailRoom -= transitionConsumedPerSide(
      clips[n - 2].playbackDuration,
      last.playbackDuration,
      incoming,
    );
  }

  // The first clip's tail is consumed by its outgoing internal transition,
  // leaving the rest of its head for the wrap.
  var headRoom = first.playbackDuration;
  final outgoing = first.transition;
  if (outgoing != null) {
    headRoom -= transitionConsumedPerSide(
      first.playbackDuration,
      clips[1].playbackDuration,
      outgoing,
    );
  }

  final room = tailRoom < headRoom ? tailRoom : headRoom;
  return room.isNegative ? Duration.zero : room;
}

/// Display geometry of the loop-restart wrap — the single source of truth the
/// timeline strip, the preview player plan and the [SeamTimeline] mapping all
/// share, so they agree on the same axis.
///
/// A loop wrap moves content: the first clip's head and the last clip's tail
/// live inside the rendered blend seam at the loop point instead of at their
/// original positions. The timeline therefore draws the first clip starting
/// [consumedPerSide] later and the last clip ending [consumedPerSide] earlier,
/// with a [seamDuration]-long blend region appended at the end — making
/// timeline, preview and export line up 1:1.
///
/// Mirrors `TransitionSeamRenderService.computeSeamSpans`: per side an overlap
/// consumes 2× its duration (solo lead-in/out around the blend) and its seam
/// plays 1.5× the consumed span; a dip consumes half its duration per side and
/// its seam plays the full 2× consumed span (dips don't shorten).
class LoopWrapDisplay {
  const LoopWrapDisplay._({
    required this.consumedPerSide,
    required this.seamDuration,
  });

  /// No wrap: nothing consumed, no seam region.
  static const none = LoopWrapDisplay._(
    consumedPerSide: Duration.zero,
    seamDuration: Duration.zero,
  );

  factory LoopWrapDisplay.fromClips(List<DivineVideoClip> clips) {
    if (clips.isEmpty) return none;
    return LoopWrapDisplay.fromClamped(
      clips,
      clampTransitions(clips)[clips.last.id],
    );
  }

  /// Like [LoopWrapDisplay.fromClips], but takes the already-clamped [wrap]
  /// (`clampTransitions(clips)[clips.last.id]`) so callers that hold the
  /// clamped map don't run [clampTransitions] a second time.
  factory LoopWrapDisplay.fromClamped(
    List<DivineVideoClip> clips,
    ClipTransition? wrap,
  ) {
    if (clips.isEmpty || wrap == null) return none;
    final consumed = transitionConsumedPerSide(
      clips.last.playbackDuration,
      clips.first.playbackDuration,
      wrap,
    );
    if (consumed <= Duration.zero) return none;
    final blend = _isDip(wrap.type)
        ? Duration.zero
        : Duration(microseconds: consumed.inMicroseconds ~/ 2);
    return LoopWrapDisplay._(
      consumedPerSide: consumed,
      seamDuration: consumed * 2 - blend,
    );
  }

  /// Wall-clock (playback) span the wrap consumes from the first clip's head
  /// and, equally, from the last clip's tail.
  final Duration consumedPerSide;

  /// Playback length of the blend seam region appended at the end of the
  /// timeline (the loop point).
  final Duration seamDuration;

  bool get isActive => consumedPerSide > Duration.zero;

  /// The span [clip] contributes to the display axis: its playback duration
  /// minus what the wrap consumed from its head (first clip) and/or tail (last
  /// clip — the same clip on a single-clip timeline).
  Duration displayDuration(
    DivineVideoClip clip, {
    required bool isFirst,
    required bool isLast,
  }) {
    var d = clip.playbackDuration;
    if (isFirst) d -= consumedPerSide;
    if (isLast) d -= consumedPerSide;
    return d.isNegative ? Duration.zero : d;
  }

  /// Total display-axis duration: shortened clips plus the seam region. The
  /// wrap is fully reflected (an overlap wrap shortens the total by its blend,
  /// a dip doesn't); interior overlaps keep their editor-axis length here,
  /// exactly as the strip draws them.
  Duration displayTotal(List<DivineVideoClip> clips) {
    var total = Duration.zero;
    for (var i = 0; i < clips.length; i++) {
      total += displayDuration(
        clips[i],
        isFirst: i == 0,
        isLast: i == clips.length - 1,
      );
    }
    return total + seamDuration;
  }
}

/// One overlap blend on the editor axis: the region
/// `[editorStart, editorStart + 2×blend]` (clips at full length) compresses to
/// `blend` of output. Dips are excluded — they don't shorten the timeline.
class _Blend {
  const _Blend({required this.editorStart, required this.blend});

  final Duration editorStart;
  final Duration blend;
}

/// Precomputed piecewise-linear map between the editor timeline (clips at full
/// length) and the rendered output timeline. Build once with
/// [TransitionTimelineMap.fromClips], then map any number of positions in
/// either direction without re-running [clampTransitions] per call — the
/// timeline ruler maps every visible tick on each scroll frame.
///
/// Each overlap boundary blends both clips for its duration, so the
/// `2×duration`-wide editor region around the boundary compresses to
/// `duration` of output; positions outside any blend map 1:1. The no-overlap
/// clamp guarantees adjacent blend regions never touch, so the mapping is
/// strictly monotonic and invertible.
///
/// The loop-restart wrap (the last clip's transition) adds **no blend region**
/// to the position mapping: its blend sits at the loop point, past the last
/// clip, so the editor timeline stays the editing space (clips at full length)
/// and the ruler/playhead map exactly as without a wrap. Like any overlap it
/// does shorten the export, so [outputDuration] subtracts its blend.
class TransitionTimelineMap {
  TransitionTimelineMap._(
    this._blends, {
    required this.editorDuration,
    required this.outputDuration,
  });

  factory TransitionTimelineMap.fromClips(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    var editorTotal = Duration.zero;
    for (final clip in clips) {
      editorTotal += clip.playbackDuration;
    }

    final blends = <_Blend>[];
    var boundary = Duration.zero;
    var removed = Duration.zero;
    for (var i = 0; i < clips.length - 1; i++) {
      boundary += clips[i].playbackDuration;
      final transition = clamped[clips[i].id];
      if (transition == null || !_shortensTimeline(transition.type)) continue;
      final blend = transition.duration;
      blends.add(_Blend(editorStart: boundary - blend, blend: blend));
      removed += blend;
    }

    // The loop-restart wrap's blend plays at the loop point, past the last
    // clip, so it shortens the output without adding a blend region to the
    // position mapping.
    if (clips.isNotEmpty) {
      final wrap = clamped[clips.last.id];
      if (wrap != null && _shortensTimeline(wrap.type)) {
        removed += wrap.duration;
      }
    }

    return TransitionTimelineMap._(
      blends,
      editorDuration: editorTotal,
      outputDuration: editorTotal - removed,
    );
  }

  /// Length of the editor timeline — clips laid out at full length.
  final Duration editorDuration;

  /// Length of the rendered output — [editorDuration] minus every overlap
  /// blend, including the loop-restart wrap's. This is what the final export
  /// lasts.
  final Duration outputDuration;

  final List<_Blend> _blends;

  /// Editor times at which the editor-to-output clock changes speed.
  ///
  /// Linear motions can be split here without changing their placement so
  /// interpolation remains linear within each affine piece of the clock.
  /// The loop-restart wrap does not change the position mapping.
  List<Duration> get clockBoundaries => {
    for (final blend in _blends) ...[
      blend.editorStart,
      blend.editorStart + blend.blend * 2,
    ],
  }.toList()..sort();

  /// Null-safe [editorToOutput]: maps [position] onto the output axis, or
  /// returns `null` when [position] is `null` (a layer/effect with no explicit
  /// time anchor — e.g. one that spans the whole video).
  Duration? editorToOutputOrNull(Duration? position) =>
      position == null ? null : editorToOutput(position);

  /// Maps an editor-axis [position] onto the output axis.
  Duration editorToOutput(Duration position) {
    var removed = Duration.zero;
    for (final b in _blends) {
      final blendEnd = b.editorStart + b.blend * 2;
      if (position >= blendEnd) {
        removed += b.blend;
      } else if (position > b.editorStart) {
        // Linear inside the 2×blend-wide region → removes half the offset.
        removed += Duration(
          microseconds: (position - b.editorStart).inMicroseconds ~/ 2,
        );
      }
    }
    final output = position - removed;
    return output.isNegative ? Duration.zero : output;
  }

  /// Inverse of [editorToOutput]: maps an output-axis [position] back to the
  /// editor axis. Inside a blend the editor advances at twice the output rate.
  Duration outputToEditor(Duration position) {
    if (position.isNegative) return Duration.zero;
    var removed = Duration.zero;
    for (final b in _blends) {
      final outBlendStart = b.editorStart - removed;
      final outBlendEnd = outBlendStart + b.blend;
      if (position >= outBlendEnd) {
        removed += b.blend;
      } else if (position > outBlendStart) {
        return b.editorStart + (position - outBlendStart) * 2;
      } else {
        return position + removed;
      }
    }
    return position + removed;
  }
}

/// The duration of the rendered output for [clips] — the sum of clip playback
/// lengths minus the blend each overlap transition removes (after the
/// no-overlap clamp), including the loop-restart wrap's. Dips don't shorten
/// the timeline, so they don't count.
///
/// This is what the final export lasts, which differs from the editor
/// timeline length (`ClipEditorState.totalDuration`, clips at full length)
/// whenever an overlap transition is used.
Duration renderedOutputDuration(List<DivineVideoClip> clips) =>
    TransitionTimelineMap.fromClips(clips).outputDuration;

/// Maps an editor-timeline [position] (clips at full length) onto the rendered
/// output timeline. Lets the header show where the playhead sits in the final
/// video, not the editor.
Duration editorToOutputPosition(
  List<DivineVideoClip> clips,
  Duration position,
) => TransitionTimelineMap.fromClips(clips).editorToOutput(position);

/// Inverse of [editorToOutputPosition]: maps an output-timeline [position] back
/// onto the editor axis. Lets the ruler place an output-time tick at the editor
/// pixel where the clips actually sit, so it stays aligned with the strip.
Duration outputToEditorPosition(
  List<DivineVideoClip> clips,
  Duration position,
) => TransitionTimelineMap.fromClips(clips).outputToEditor(position);
