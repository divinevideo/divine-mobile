import 'dart:typed_data';
import 'dart:ui';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Reads the existing render; never triggers another video export.
class PublishingIdeasMedia {
  PublishingIdeasMedia({required CaptionGenerationService captions})
    : _captions = captions;
  final CaptionGenerationService _captions;

  Future<List<Uint8List>> frames(DivineVideoClip clip) async {
    final video = clip.video;
    if (video == null) return [];
    return ProVideoEditor.instance.getThumbnails(
      ThumbnailConfigs(
        video: video,
        outputSize: const Size.square(512),
        jpegQuality: 75,
        timestamps: [
          for (final fraction in [0.1, 0.5, 0.9])
            Duration(
              microseconds: (clip.duration.inMicroseconds * fraction).round(),
            ),
        ],
      ),
    );
  }

  Future<String> transcript(DivineVideoClip clip, String language) async {
    final result = await _captions.generateForClips(
      clips: [clip],
      localeIdentifier: language,
    );
    return switch (result) {
      CaptionsGenerated(:final cues) => cues.map((cue) => cue.text).join(' '),
      _ => '',
    };
  }
}
