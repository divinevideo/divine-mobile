import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_loop_alignment.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  const record = ClipLoopAlignment(
    sourcePath: '/old/take.mp4',
    windowStart: Duration(seconds: 2),
    sourceDuration: Duration(seconds: 12),
    sourceMinTrimStart: Duration(seconds: 1),
    sourceStartOffset: Duration(milliseconds: 300),
    operationId: 'repair-1',
    sourceDerivedFrom: [C2paEditSource(path: '/old/capture.mp4')],
  );
  DivineVideoClip clip() => DivineVideoClip(
    id: 'clip',
    video: EditorVideo.file('/old/aligned.mp4'),
    duration: const Duration(seconds: 6),
    recordedAt: DateTime(2026),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
    loopAlignment: record,
  );

  group('ClipLoopAlignment serialization', () {
    test(
      'draft relocation retains the displayed bake and its source mapping',
      () {
        final restored = DivineVideoClip.fromJson(clip().toJson(), '/new');
        expect(restored.video?.file?.path, '/new/aligned.mp4');
        expect(restored.loopAlignment?.sourcePath, '/new/take.mp4');
        expect(restored.loopAlignment?.windowStart, const Duration(seconds: 2));
        expect(
          restored.loopAlignment?.sourceDuration,
          const Duration(seconds: 12),
        );
        expect(
          restored.loopAlignment?.sourceMinTrimStart,
          const Duration(seconds: 1),
        );
        expect(
          restored.loopAlignment?.sourceStartOffset,
          const Duration(milliseconds: 300),
        );
        expect(restored.loopAlignment?.operationId, 'repair-1');
        expect(
          restored.ownedFilePaths,
          containsAll([
            '/new/aligned.mp4',
            '/new/take.mp4',
            '/new/capture.mp4',
          ]),
        );
      },
    );

    test(
      'logical copies drop alignment while edits preserve current footage',
      () {
        expect(clip().copyWith(id: 'split').loopAlignment, isNull);
        expect(
          clip().copyWith(trimEnd: const Duration(seconds: 1)).loopAlignment,
          record,
        );
        expect(clip().copyWith(clearLoopAlignment: true).loopAlignment, isNull);
        expect(
          clip().copyWith(clearLoopAlignment: true).video?.file?.path,
          '/old/aligned.mp4',
        );
      },
    );

    test('malformed optional records cannot prevent draft recovery', () {
      for (final raw in [
        null,
        'bad',
        <String, dynamic>{},
        {'sourcePath': 3},
        {'sourcePath': 'take.mp4', 'sourceDurationUs': 'bad'},
        {'sourcePath': 'take.mp4', 'sourceDurationUs': -1},
      ]) {
        expect(ClipLoopAlignment.fromJson(raw, '/new'), isNull);
      }
      final json = clip().toJson()..['loopAlignment'] = {'sourcePath': 3};
      expect(DivineVideoClip.fromJson(json, '/new').loopAlignment, isNull);
    });
  });
}
