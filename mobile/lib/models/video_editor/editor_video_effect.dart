// ABOUTME: A video effect placed on the editor timeline, with a stable id so
// ABOUTME: the timeline can move, trim, edit and delete it.

import 'package:equatable/equatable.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectType;

/// A [VideoEffect] on the editor timeline.
///
/// Its window, [VideoEffect.startTime] to [VideoEffect.endTime], is on the
/// editor axis the timeline draws; a `null` end reaches the end of the video.
/// Effects that overlap in time are combined, in list order.
class EditorVideoEffect extends Equatable {
  const EditorVideoEffect({
    required this.id,
    required this.effect,
    this.onBeat = false,
  });

  /// Reads an entry written by [toMap].
  ///
  /// An entry without an id, as a saved library clip carries, gets
  /// [fallbackId]. Throws when the effect itself cannot be read.
  factory EditorVideoEffect.fromMap(
    Map<String, dynamic> map, {
    required String fallbackId,
  }) {
    final id = map[idKey];
    return EditorVideoEffect(
      id: id is String && id.isNotEmpty ? id : fallbackId,
      effect: VideoEffect.fromMap(map),
      onBeat: map[onBeatKey] == true,
    );
  }

  /// The map key the id is stored under, next to the effect's own fields.
  static const idKey = 'id';

  /// The map key [onBeat] is stored under; left out when it is `false`.
  static const onBeatKey = 'onBeat';

  /// Identifies the effect on the timeline and across undo steps.
  final String id;

  /// The effect and its window.
  final VideoEffect effect;

  /// Whether the effect fires on the beats of the video's music instead of
  /// playing all through its window; see [videoEffectsOnOutput]. Only for a
  /// type that [canFireOnBeat].
  final bool onBeat;

  /// Returns a copy placed at [startTime] until [endTime].
  EditorVideoEffect retimed({
    required Duration startTime,
    required Duration endTime,
  }) {
    return EditorVideoEffect(
      id: id,
      effect: VideoEffect(
        type: effect.type,
        intensity: effect.intensity,
        startTime: startTime,
        endTime: endTime,
      ),
      onBeat: onBeat,
    );
  }

  /// Converts the entry into a map for the editor history.
  Map<String, dynamic> toMap() => {
    ...effect.toMap(),
    idKey: id,
    if (onBeat) onBeatKey: true,
  };

  @override
  List<Object?> get props => [id, effect, onBeat];
}

/// Whether an effect of [type] can fire on the beat: the effects with a clear
/// hit, such as a zoom punch, a glitch burst or a flash.
bool canFireOnBeat(VideoEffectType type) => switch (type) {
  VideoEffectType.zoomPulse ||
  VideoEffectType.pixelPulse ||
  VideoEffectType.rgbSplit ||
  VideoEffectType.glitch ||
  VideoEffectType.blockGlitch ||
  VideoEffectType.shake ||
  VideoEffectType.strobe ||
  VideoEffectType.negativeFlash => true,
  _ => false,
};

/// [effects] with their windows moved from the editor timeline onto the
/// exported video, which an overlap transition makes shorter.
///
/// A `null` start or end stays open, so a whole-video effect runs from the
/// first output frame. A flashing effect starts on [flashingEffectStartGrid]
/// instead, and is left out when no whole grid step fits before its end. When
/// the video flashes from its first frame, flashing effects also end on the
/// last grid step before the loop point.
///
/// An effect [EditorVideoEffect.onBeat] fires on the [beats], on the
/// exported video, that fall in its window, and is left out when none does.
/// A flashing one skips beats closer than [minimumFlashGap] to the one before,
/// so it flashes on every other beat of a song too fast for every one, and
/// drops the beats that would still put more than three flashes in one second
/// of the looping video, across its loop point too.
///
/// The export and the live preview both time effects this way, so the preview
/// shows what the file will.
List<VideoEffect> videoEffectsOnOutput(
  List<EditorVideoEffect> effects,
  TransitionTimelineMap timelineMap, {
  List<Duration> beats = const [],
}) {
  final result = <VideoEffect>[];
  for (final entry in effects) {
    final effect = entry.effect;
    var start = timelineMap.editorToOutputOrNull(effect.startTime);
    final end = timelineMap.editorToOutputOrNull(effect.endTime);
    if (entry.onBeat) {
      final from = start ?? Duration.zero;
      final inWindow = [
        for (final beat in beats)
          if (beat >= from && (end == null || beat < end)) beat,
      ];
      final triggers = isFlashingVideoEffect(effect.type)
          ? _spacedForFlashing(inWindow)
          : inWindow;
      if (triggers.isEmpty) continue;
      result.add(
        VideoEffect(
          type: effect.type,
          intensity: effect.intensity,
          startTime: start,
          endTime: end,
          triggers: triggers,
        ),
      );
      continue;
    }
    if (start != null && isFlashingVideoEffect(effect.type)) {
      start = _roundUp(start, flashingEffectStartGrid);
      if (end != null && start >= end) continue;
    }
    result.add(
      VideoEffect(
        type: effect.type,
        intensity: effect.intensity,
        startTime: start,
        endTime: end,
      ),
    );
  }
  // The posted video ends, and starts over, where the export is capped.
  final outputDuration = timelineMap.outputDuration;
  final loopPoint = outputDuration < VideoEditorConstants.maxDuration
      ? outputDuration
      : VideoEditorConstants.maxDuration;
  return _withinFlashLimit(
    _endFlashingBeforeLoopPoint(result, loopPoint: loopPoint),
    loopPoint: loopPoint,
  );
}

/// [effects] with every flashing effect that flashes on its own clock ended
/// on the last [flashingEffectStartGrid] step before [loopPoint], if the
/// video flashes from its first frame. Effects on the beat are left to
/// [_withinFlashLimit].
///
/// The grid keeps flashes in step within one pass, but a [loopPoint] off the
/// grid restarts them off it. A negative flash's echo a quarter second after
/// its last onset then lands right next to the first flashes of the next
/// pass: a 5.5 s video flashed at 5.0, 5.25, 5.5 and 5.75 s (#9873). Stopping
/// on the grid step before the loop point keeps both passes together at three
/// flashes a second or fewer.
List<VideoEffect> _endFlashingBeforeLoopPoint(
  List<VideoEffect> effects, {
  required Duration loopPoint,
}) {
  final lastStep = _roundDown(loopPoint, flashingEffectStartGrid);
  if (lastStep == loopPoint) return effects;
  final flashesFromStart = effects.any(
    (effect) =>
        _flashesOnItsOwnClock(effect) &&
        effect.intensity > 0 &&
        (effect.startTime ?? Duration.zero) == Duration.zero,
  );
  if (!flashesFromStart) return effects;
  return [
    for (final effect in effects)
      if (!_flashesOnItsOwnClock(effect))
        effect
      else if ((effect.startTime ?? Duration.zero) < lastStep)
        VideoEffect(
          type: effect.type,
          intensity: effect.intensity,
          startTime: effect.startTime,
          endTime: effect.endTime == null || effect.endTime! > lastStep
              ? lastStep
              : effect.endTime,
        ),
  ];
}

/// Whether [effect] flashes on its own clock rather than on the beat.
bool _flashesOnItsOwnClock(VideoEffect effect) =>
    isFlashingVideoEffect(effect.type) && effect.triggers.isEmpty;

/// The shortest gap between two flashes of an effect on the beat: three
/// flashes a second at most, the WCAG 2.3.1 limit.
const minimumFlashGap = Duration(microseconds: 1000000 ~/ 3);

/// [beats], sorted, without each beat closer than [minimumFlashGap] to the
/// last one kept.
List<Duration> _spacedForFlashing(List<Duration> beats) {
  final kept = <Duration>[];
  for (final beat in [...beats]..sort()) {
    if (kept.isEmpty || beat - kept.last >= minimumFlashGap) kept.add(beat);
  }
  return kept;
}

/// [effects] without the beats of flashing effects that would put more than
/// three flashes within one second of the video as it loops at [loopPoint].
///
/// Each flashing effect keeps its own beats [minimumFlashGap] apart, but a
/// neighbouring flashing effect, or the start of the next pass, can still
/// flash right next to them. This looks at the flashes the renderers will
/// show, so it holds whatever the effects' own timing: in each second that
/// has a fourth flash, the latest beat in it goes, until none has.
List<VideoEffect> _withinFlashLimit(
  List<VideoEffect> effects, {
  required Duration loopPoint,
}) {
  if (!effects.any(
    (e) => isFlashingVideoEffect(e.type) && e.triggers.isNotEmpty,
  )) {
    return effects;
  }
  var current = effects;
  while (true) {
    // The latest beat of a flashing effect within a crowded second.
    ({int effect, Duration beat})? latest;
    for (final crowded in _crowdedFlashSeconds(current, loopPoint)) {
      Duration? latestAt;
      for (var i = 0; i < current.length; i++) {
        final effect = current[i];
        if (!isFlashingVideoEffect(effect.type)) continue;
        for (final beat in effect.triggers) {
          // A short video may repeat several times within this second. Find
          // the last occurrence without expanding every repetition.
          final repeat =
              (crowded.inMicroseconds + 999999 - beat.inMicroseconds) ~/
              loopPoint.inMicroseconds;
          final at = beat + loopPoint * repeat;
          if (repeat >= 0 &&
              at >= crowded &&
              at < crowded + const Duration(seconds: 1) &&
              (latestAt == null || at > latestAt)) {
            latestAt = at;
            latest = (effect: i, beat: beat);
          }
        }
      }
      if (latest != null) break;
    }
    final drop = latest;
    if (drop == null) return current;
    final thinned = [
      for (final beat in current[drop.effect].triggers)
        if (beat != drop.beat) beat,
    ];
    current = [
      for (var i = 0; i < current.length; i++)
        if (i != drop.effect)
          current[i]
        else if (thinned.isNotEmpty)
          current[i].copyWith(triggers: thinned),
    ];
  }
}

/// Where the seconds of the looping video start that hold more than three
/// flashes, in order.
///
/// A flash starts where a frame turns white or negative, sampled at the rate
/// the renderers place beats at.
Iterable<Duration> _crowdedFlashSeconds(
  List<VideoEffect> effects,
  Duration loopPoint,
) sync* {
  final flashing = [
    for (final effect in effects)
      if (isFlashingVideoEffect(effect.type)) effect,
  ];
  const step = Duration(microseconds: 1000000 ~/ 120);
  bool flashes(Duration at) {
    final frame = VideoEffect.resolve(flashing, at);
    return frame.flash >= 0.5 || frame.invert >= 0.5;
  }

  final onsets = <Duration>[];
  final last = loopPoint - step;
  var wasOn = last > Duration.zero && flashes(last);
  for (var at = Duration.zero; at < loopPoint; at += step) {
    final on = flashes(at);
    if (on && !wasOn) onsets.add(at);
    wasOn = on;
  }
  for (final onset in onsets) {
    var inSecond = 0;
    for (final other in onsets) {
      final distance =
          (other - onset).inMicroseconds % loopPoint.inMicroseconds;
      if (distance < Duration.microsecondsPerSecond) {
        inSecond += 1 + (999999 - distance) ~/ loopPoint.inMicroseconds;
      }
    }
    if (inSecond > 3) yield onset;
  }
}

/// Where flashing effects may start in the exported video: on whole seconds.
///
/// An effect's animation starts with its window, and both flashing effects
/// flash at the start of each of their cycles, which are at most a second
/// long. A piece starting anywhere else would flash out of step with the one
/// before it: splitting a negative flash at 1.3 s would put flashes at 1.0,
/// 1.25, 1.3 and 1.55 s. On a shared grid, split pieces, the parts left
/// around a replacing effect and neighbouring flashing effects stay in step,
/// so together they flash no more than three times a second, the WCAG 2.3.1
/// limit, whatever an overlap transition does to their windows. Where the
/// video loops, [videoEffectsOnOutput] ends them on the grid as well.
const flashingEffectStartGrid = Duration(seconds: 1);

Duration _roundUp(Duration value, Duration step) {
  final micros = step.inMicroseconds;
  return Duration(
    microseconds: (value.inMicroseconds + micros - 1) ~/ micros * micros,
  );
}

Duration _roundDown(Duration value, Duration step) {
  final micros = step.inMicroseconds;
  return Duration(microseconds: value.inMicroseconds ~/ micros * micros);
}

/// Whether [type] flashes.
///
/// Each flashing effect stays below the three flashes a second that WCAG
/// 2.3.1 allows, but overlapping ones add their flashes up, so only one may
/// run at a time.
bool isFlashingVideoEffect(VideoEffectType type) =>
    type == VideoEffectType.strobe || type == VideoEffectType.negativeFlash;

/// The content warnings a video with [effects] must carry, whatever the
/// creator picks: [ContentLabel.flashingLights] when any of them flashes.
///
/// Derived from the effects every time rather than stored with the creator's
/// own picks, so the warning goes away again with the last flashing effect.
Set<ContentLabel> requiredContentLabelsForEffects(
  Iterable<VideoEffect> effects,
) => effects.any((e) => isFlashingVideoEffect(e.type) && e.intensity > 0)
    ? const {ContentLabel.flashingLights}
    : const {};

/// Pieces shorter than this are dropped when a flashing effect is cut, rather
/// than left as a sliver nobody could see or grab on the timeline.
const minimumVideoEffectPiece = Duration(milliseconds: 100);

/// Cuts every other flashing effect out of the window of the effect with
/// [keepId], so no two flashing effects overlap.
///
/// A cut effect keeps whatever lies before and after that window; the part
/// after it becomes a new effect, named by [createId], whose animation starts
/// over there. Returns `null` when [keepId] is not a flashing effect or
/// overlaps none.
List<EditorVideoEffect>? withoutFlashingOverlaps(
  List<EditorVideoEffect> effects, {
  required String keepId,
  required String Function() createId,
}) {
  final kept = effects.where((e) => e.id == keepId).firstOrNull;
  if (kept == null || !isFlashingVideoEffect(kept.effect.type)) return null;
  final keptStart = kept.effect.startTime ?? Duration.zero;
  final keptEnd = kept.effect.endTime;

  var changed = false;
  final result = <EditorVideoEffect>[];
  for (final entry in effects) {
    final effect = entry.effect;
    final start = effect.startTime ?? Duration.zero;
    final end = effect.endTime;
    final overlaps =
        entry.id != keepId &&
        isFlashingVideoEffect(effect.type) &&
        (keptEnd == null || start < keptEnd) &&
        (end == null || keptStart < end);
    if (!overlaps) {
      result.add(entry);
      continue;
    }
    changed = true;
    if (keptStart - start >= minimumVideoEffectPiece) {
      result.add(entry.retimed(startTime: start, endTime: keptStart));
    }
    if (keptEnd != null &&
        (end == null || end - keptEnd >= minimumVideoEffectPiece)) {
      result.add(
        EditorVideoEffect(
          id: createId(),
          effect: VideoEffect(
            type: effect.type,
            intensity: effect.intensity,
            startTime: keptEnd,
            endTime: end,
          ),
          onBeat: entry.onBeat,
        ),
      );
    }
  }
  return changed ? result : null;
}
