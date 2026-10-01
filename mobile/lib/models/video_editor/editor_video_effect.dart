// ABOUTME: A video effect placed on the editor timeline, with a stable id so
// ABOUTME: the timeline can move, trim, edit and delete it.

import 'package:equatable/equatable.dart';
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
  const EditorVideoEffect({required this.id, required this.effect});

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
    );
  }

  /// The map key the id is stored under, next to the effect's own fields.
  static const idKey = 'id';

  /// Identifies the effect on the timeline and across undo steps.
  final String id;

  /// The effect and its window.
  final VideoEffect effect;

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
    );
  }

  /// Converts the entry into a map for the editor history.
  Map<String, dynamic> toMap() => {...effect.toMap(), idKey: id};

  @override
  List<Object?> get props => [id, effect];
}

/// [effects] with their windows moved from the editor timeline onto the
/// exported video, which an overlap transition makes shorter.
///
/// A `null` start or end stays open, so a whole-video effect runs from the
/// first output frame. The export and the live preview both time effects this
/// way, so the preview shows what the file will.
List<VideoEffect> videoEffectsOnOutput(
  List<VideoEffect> effects,
  TransitionTimelineMap timelineMap,
) {
  return [
    for (final effect in effects)
      VideoEffect(
        type: effect.type,
        intensity: effect.intensity,
        startTime: timelineMap.editorToOutputOrNull(effect.startTime),
        endTime: timelineMap.editorToOutputOrNull(effect.endTime),
      ),
  ];
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
        ),
      );
    }
  }
  return changed ? result : null;
}
