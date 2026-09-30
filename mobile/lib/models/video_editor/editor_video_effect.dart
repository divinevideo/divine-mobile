// ABOUTME: A video effect placed on the editor timeline, with a stable id so
// ABOUTME: the timeline can move, trim, edit and delete it.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffect;

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
