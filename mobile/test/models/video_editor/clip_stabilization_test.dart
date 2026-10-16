import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_stabilization.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  group(ClipStabilization, () {
    const record = ClipStabilization(
      rawSourcePath: '/old/documents/take.mp4',
      windowStart: Duration(milliseconds: 1700),
      sourceDuration: Duration(seconds: 20),
      sourceMinTrimStart: Duration(seconds: 1),
      sourceStartOffset: Duration(milliseconds: 500),
      sourceDerivedFrom: [
        C2paEditSource(path: '/old/documents/rec.mp4', recordingSha256: 'abc'),
      ],
    );

    final clip = DivineVideoClip(
      id: 'clip',
      video: EditorVideo.file('/old/documents/clip_stabilized.mp4'),
      duration: const Duration(milliseconds: 18300),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      stabilization: record,
    );

    test('survives a draft round trip under a moved documents folder', () {
      final restored = DivineVideoClip.fromJson(clip.toJson(), '/new');
      expect(
        restored.stabilization,
        const ClipStabilization(
          rawSourcePath: '/new/take.mp4',
          windowStart: Duration(milliseconds: 1700),
          sourceDuration: Duration(seconds: 20),
          sourceMinTrimStart: Duration(seconds: 1),
          sourceStartOffset: Duration(milliseconds: 500),
          sourceDerivedFrom: [
            C2paEditSource(path: '/new/rec.mp4', recordingSha256: 'abc'),
          ],
        ),
      );
    });

    test('is dropped by a split or a duplicate', () {
      expect(clip.copyWith(id: 'copy').stabilization, isNull);
      expect(clip.copyWith(volume: 0.5).stabilization, record);
    });

    test('reads as absent without its unstabilized footage', () {
      expect(ClipStabilization.fromJson({'windowStartUs': 0}, '/new'), isNull);
      expect(ClipStabilization.fromJson('garbage', '/new'), isNull);
    });

    test('drops sources it cannot read instead of the whole record', () {
      final restored = ClipStabilization.fromJson({
        'rawSourcePath': 'take.mp4',
        'sourceDurationUs': 3000000,
        'sourceDerivedFrom': [
          {'kind': 'video'},
        ],
      }, '/new');
      expect(restored?.rawSourcePath, '/new/take.mp4');
      expect(restored?.sourceDerivedFrom, isNull);
    });
  });
}
