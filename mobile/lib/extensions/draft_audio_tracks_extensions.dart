// ABOUTME: Reads the audio tracks a draft's finished edit mixes into the
// ABOUTME: video, for crediting sounds that never became the selected sound.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';

/// The audio tracks of a draft's finished edit.
extension DraftAudioTracks on DivineVideoDraft {
  /// The audio tracks the editor's last finished state mixes into the video,
  /// from [DivineVideoDraft.editorEditingParameters], in timeline order.
  ///
  /// A sound added through the editor's music picker lives only here: it
  /// becomes [DivineVideoDraft.selectedSound] only when it has a Nostr event
  /// to reference, so a shipped sound or a provider sound never does.
  /// Malformed entries are skipped.
  List<AudioEvent> get editorAudioTracks {
    final meta = editorEditingParameters['meta'];
    if (meta is! Map) return const [];
    final audio = meta[VideoEditorConstants.audioStateHistoryKey];
    if (audio is! Iterable) return const [];
    return [
      for (final raw in audio)
        if (raw is Map) ?_audioEventOrNull(Map<String, dynamic>.from(raw)),
    ];
  }
}

AudioEvent? _audioEventOrNull(Map<String, dynamic> json) {
  try {
    return AudioEvent.fromJson(json);
  } on Object {
    // A track this build cannot read credits nothing; the rest still count.
    return null;
  }
}
