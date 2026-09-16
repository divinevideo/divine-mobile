// ABOUTME: Captures recognizable source-post context when a sound is saved.
// ABOUTME: Parses only embedded captions and never requests transcription.

import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/subtitle_service.dart';

class SavedSoundContextBuilder {
  const SavedSoundContextBuilder();

  SavedSoundSourceContext fromVideo(
    VideoEvent video, {
    String? creatorName,
  }) {
    return SavedSoundSourceContext(
      videoEventId: video.id,
      creatorPubkey: video.pubkey,
      creatorName: _nonBlank(creatorName),
      title: _nonBlank(video.displayTitle),
      description: _nonBlank(video.displayContent),
      thumbnailUrl: _nonBlank(video.effectiveThumbnailUrl),
      transcript: _transcript(video.textTrackContent),
    );
  }

  String? _transcript(String? vtt) {
    if (vtt == null || vtt.trim().isEmpty) return null;

    final lines = <String>[];
    for (final cue in SubtitleService.parseVtt(vtt)) {
      final text = cue.text.trim();
      if (text.isNotEmpty && (lines.isEmpty || lines.last != text)) {
        lines.add(text);
      }
    }
    return lines.isEmpty ? null : lines.join(' ');
  }

  String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
