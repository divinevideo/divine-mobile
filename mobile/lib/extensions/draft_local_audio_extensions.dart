import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';

/// Extraction of draft-local audio file paths for draft-delete cleanup.
extension DraftLocalAudioPaths on DivineVideoDraft {
  /// Absolute file paths of draft-local audio referenced by this draft.
  ///
  /// Covers library-owned audio created by `LocalAudioImportService`, committed
  /// voice-over recordings, and audio extracted from the draft's own clips —
  /// all persisted as local [AudioEvent]s. Sweeps every history entry's audio
  /// metadata in
  /// [DivineVideoDraft.editorStateHistory], the completed-editor snapshot in
  /// [DivineVideoDraft.editorEditingParameters], plus the legacy
  /// [DivineVideoDraft.selectedSound], collecting [AudioEvent.localFilePath]
  /// for each [AudioEvent.isDraftLocalAudio] track. Used by draft deletion to
  /// remove audio files that would otherwise persist after the draft is gone.
  Set<String> get localAudioFilePaths {
    final paths = <String>{};

    void addIfLocal(AudioEvent event) {
      // localFilePath is non-null only for draft-local audio with a non-empty
      // url, so the null check alone covers the locality and emptiness guards.
      final path = event.localFilePath;
      if (path != null) {
        paths.add(path);
      }
    }

    void addFromMeta(Object? rawMeta) {
      if (rawMeta is! Map) return;
      final audio = rawMeta[VideoEditorConstants.audioStateHistoryKey];
      if (audio is! Iterable) return;
      for (final raw in audio) {
        if (raw is! Map) continue;
        try {
          addIfLocal(AudioEvent.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Skip malformed audio entries; cleanup must never throw.
        }
      }
    }

    final selected = selectedSound;
    if (selected != null) addIfLocal(selected);

    addFromMeta(editorEditingParameters['meta']);

    final history = editorStateHistory['history'];
    if (history is Iterable) {
      for (final item in history) {
        if (item is! Map) continue;
        addFromMeta(item['meta']);
      }
    }

    return paths;
  }
}
