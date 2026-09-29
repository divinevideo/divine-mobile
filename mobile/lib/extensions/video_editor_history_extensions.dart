import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';

extension VideoEditorHistoryExtensions on StateManager {
  List<AudioEvent> get audioTracks {
    final raw = activeMeta[VideoEditorConstants.audioStateHistoryKey];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>().map(AudioEvent.fromJson).toList();
  }

  /// Restores the caption track from the current history metadata, or `null`
  /// when the session has no captions (or the stored value is malformed).
  CaptionTrack? get captionTrack {
    final raw = activeMeta[VideoEditorConstants.captionsStateHistoryKey];
    if (raw is! Map<Object?, Object?>) return null;
    try {
      return CaptionTrack.fromJson(raw);
    } on Object {
      // A stale or malformed draft must never crash editor loading. Normalize
      // every parse failure — FormatException, or a TypeError from a bad nested
      // cue/style cast — to "no captions".
      return null;
    }
  }

  /// Restores timeline marker positions from the current history metadata.
  List<Duration> get timelineMarkers {
    final raw = activeMeta[VideoEditorConstants.timelineMarkersStateHistoryKey];
    if (raw is! List) return [];

    return raw
        .whereType<num>()
        .map((value) => Duration(milliseconds: value.round()))
        .toList()
      ..sort();
  }

  /// Restores [DivineVideoClip] objects from the current history entry's
  /// metadata.
  ///
  /// [documentsPath] is required to resolve relative file paths stored in
  /// the serialized JSON back to absolute paths.
  /// The list order represents the clip playback order.
  List<DivineVideoClip> clipSnapshots(String documentsPath) {
    final raw = activeMeta[VideoEditorConstants.clipsStateHistoryKey];
    if (raw is! List) return [];
    return raw
        .cast<Map<String, dynamic>>()
        .map((json) => DivineVideoClip.fromJson(json, documentsPath))
        .toList();
  }

  /// Writes [keyed], the bakes of keys takes were recorded with, into every
  /// history entry that still holds the raw take.
  ///
  /// This makes the bake part of the session's starting state rather than an
  /// edit. Undo can never bring the raw take back, where an export would drop
  /// its key, and a session the user has not touched is not treated as
  /// edited. Everything else in an entry, such as a clip's trims, stays.
  ///
  /// Returns whether any entry changed.
  bool adoptCapturedChromaKeyBakes(
    List<DivineVideoClip> keyed,
    String documentsPath,
  ) {
    final bakesByRawFile = {
      for (final clip in keyed)
        if (clip.chromaKeySourcePath case final source?)
          (clip.id, p.basename(source)): clip,
    };
    var changed = false;
    for (var index = 0; index < stateHistory.length; index++) {
      final entry = stateHistory[index];
      final raw = entry.meta[VideoEditorConstants.clipsStateHistoryKey];
      if (raw is! List) continue;
      var entryChanged = false;
      final clips = <Map<String, dynamic>>[];
      for (final json in raw.cast<Map<String, dynamic>>()) {
        final isPending =
            json['chromaKey'] == null && json['captureChromaKey'] != null;
        final bake = isPending
            ? bakesByRawFile[(json['id'], json['filePath'])]
            : null;
        if (bake == null) {
          clips.add(json);
          continue;
        }
        entryChanged = true;
        clips.add(
          DivineVideoClip.fromJson(
            json,
            documentsPath,
          ).withCapturedChromaKeyBake(bake).toJson(),
        );
      }
      if (!entryChanged) continue;
      changed = true;
      replaceHistory(
        entry.copyWith(
          meta: {
            ...entry.meta,
            VideoEditorConstants.clipsStateHistoryKey: clips,
          },
        ),
        index: index,
        skipUpdateActiveItems: true,
      );
    }
    if (changed) updateActiveItems();
    return changed;
  }
}
