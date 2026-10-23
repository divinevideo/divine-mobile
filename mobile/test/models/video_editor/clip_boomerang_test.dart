import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_boomerang.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, VideoSpeedRamp, VideoSpeedRampPoint;

void main() {
  group(ClipBoomerang, () {
    const record = ClipBoomerang(
      sourcePath: '/old/documents/take.mp4',
      sourceDuration: Duration(seconds: 8),
      sourceTrimStart: Duration(seconds: 2),
      sourceTrimEnd: Duration(milliseconds: 1500),
      sourceMinTrimStart: Duration(seconds: 1),
      sourceStartOffset: Duration(milliseconds: 500),
      sourceDerivedFrom: [
        C2paEditSource(path: '/old/documents/rec.mp4', recordingSha256: 'abc'),
      ],
    );

    final clip = DivineVideoClip(
      id: 'clip',
      video: EditorVideo.file('/old/documents/clip_boomerang.mp4'),
      duration: const Duration(milliseconds: 8933),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      boomerang: record,
    );

    group('JSON', () {
      test('survives a draft round trip under a moved documents folder', () {
        final restored = DivineVideoClip.fromJson(clip.toJson(), '/new');
        expect(
          restored.boomerang,
          const ClipBoomerang(
            sourcePath: '/new/take.mp4',
            sourceDuration: Duration(seconds: 8),
            sourceTrimStart: Duration(seconds: 2),
            sourceTrimEnd: Duration(milliseconds: 1500),
            sourceMinTrimStart: Duration(seconds: 1),
            sourceStartOffset: Duration(milliseconds: 500),
            sourceDerivedFrom: [
              C2paEditSource(path: '/new/rec.mp4', recordingSha256: 'abc'),
            ],
          ),
        );
      });

      test('reads as absent without the footage it was made from', () {
        expect(ClipBoomerang.fromJson({'sourceDurationUs': 0}, '/new'), isNull);
        expect(ClipBoomerang.fromJson('garbage', '/new'), isNull);
      });
    });

    group('copyWith', () {
      test('drops the record on a split or a duplicate', () {
        expect(clip.copyWith(id: 'copy').boomerang, isNull);
        expect(clip.copyWith(volume: 0.5).boomerang, record);
      });
    });

    group('sourceWindow', () {
      test('is the part of the footage between the trims', () {
        expect(record.sourceWindow, const Duration(milliseconds: 4500));
      });
    });

    group('bounceSpeedRamp', () {
      test('plays the curve forward, then mirrored on the way back', () {
        const ramp = VideoSpeedRamp([
          VideoSpeedRampPoint(position: 0.2, speed: 4),
          VideoSpeedRampPoint(position: 0.6, speed: 0.5),
        ]);

        final bounced = ClipBoomerang.bounceSpeedRamp(ramp, forwardShare: 0.5);

        expect(bounced.points, const [
          VideoSpeedRampPoint(position: 0.1, speed: 4),
          VideoSpeedRampPoint(position: 0.3, speed: 0.5),
          VideoSpeedRampPoint(position: 0.7, speed: 0.5),
          VideoSpeedRampPoint(position: 0.9, speed: 4),
        ]);
      });

      test('keeps one point where the curve ends on the turn', () {
        const ramp = VideoSpeedRamp([
          VideoSpeedRampPoint(position: 0, speed: 1),
          VideoSpeedRampPoint(position: 1, speed: 0.25),
        ]);

        final bounced = ClipBoomerang.bounceSpeedRamp(ramp, forwardShare: 0.6);

        expect(bounced.points.map((point) => point.speed), [1, 0.25, 1]);
        expect(bounced.points[1].position, closeTo(0.6, 1e-12));
        expect(bounced.points.last.position, 1);
      });
    });
  });
}
