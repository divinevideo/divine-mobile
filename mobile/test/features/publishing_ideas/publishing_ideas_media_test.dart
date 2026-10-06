import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_media.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class Captions extends Fake implements CaptionGenerationService {}

class VideoEditor extends ProVideoEditor {
  ThumbnailConfigs? request;
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    request = value;
    return [Uint8List(1), Uint8List(1), Uint8List(1)];
  }
}

void main() {
  late ProVideoEditor original;
  setUp(() => original = ProVideoEditor.instance);
  tearDown(() => ProVideoEditor.instance = original);
  group('frames', () {
    test(
      'samples the supplied render at 10, 50 and 90 percent without export',
      () async {
        final plugin = VideoEditor();
        ProVideoEditor.instance = plugin;
        final video = EditorVideo.file('/documents/rendered-current-edit.mp4');
        final clip = DivineVideoClip(
          id: 'rendered-current-edit',
          duration: const Duration(seconds: 10),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          video: video,
        );
        final media = PublishingIdeasMedia(captions: Captions());
        expect(await media.frames(clip), hasLength(3));
        expect(plugin.request!.video, same(video));
        expect(plugin.request!.timestamps, [
          const Duration(seconds: 1),
          const Duration(seconds: 5),
          const Duration(seconds: 9),
        ]);
      },
    );
  });
}
