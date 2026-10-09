import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show CustomVideoEffect, VideoEffect;

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

  /// Restores the video effects from the current history metadata, with the
  /// ids the timeline addresses them by; empty when the session has none. An
  /// entry that cannot be read is skipped.
  List<EditorVideoEffect> get videoEffectEntries => videoEffectEntriesFromMeta(
    activeMeta[VideoEditorConstants.effectsStateHistoryKey],
  );

  /// The effects of [videoEffectEntries] Divine renders itself.
  List<CustomVideoEffect> get customVideoEffects => [
    for (final entry in videoEffectEntries) ?entry.custom,
  ];

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

/// Reads the video effects stored under
/// [VideoEditorConstants.effectsStateHistoryKey].
///
/// A draft written by a newer app can carry an effect type this build does
/// not know; that entry is skipped rather than failing the whole list.
List<VideoEffect> videoEffectsFromMeta(Object? raw) => [
  for (final entry in videoEffectEntriesFromMeta(raw)) ?entry.effect,
];

/// The effects Divine renders itself, like [videoEffectsFromMeta] does for
/// the built-in ones.
List<CustomVideoEffect> customVideoEffectsFromMeta(Object? raw) => [
  for (final entry in videoEffectEntriesFromMeta(raw)) ?entry.custom,
];

/// Like [videoEffectsFromMeta], with each effect's timeline id. An entry
/// stored without one is named after its position.
List<EditorVideoEffect> videoEffectEntriesFromMeta(Object? raw) {
  if (raw is! List) return const [];
  final effects = <EditorVideoEffect>[];
  for (final (index, entry) in raw.indexed) {
    if (entry is! Map) continue;
    try {
      effects.add(
        EditorVideoEffect.fromMap(
          Map<String, dynamic>.from(entry),
          fallbackId: 'effect_$index',
        ),
      );
    } on Object {
      // Unknown or malformed entry; skip it.
      continue;
    }
  }
  return effects;
}
