import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(SecondaryCameraTake, () {
    const documentsPath = '/docs';

    DivineVideoClip secondClip() => DivineVideoClip(
      id: 'clip_1_second',
      video: EditorVideo.file('/docs/VID_1_second.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime.utc(2026, 11, 17),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      volume: 0,
    );

    group('toJson / fromJson', () {
      test('round-trips the clip and the window position', () {
        final take = SecondaryCameraTake(
          clip: secondClip(),
          pipCenter: const Offset(0.25, 0.75),
        );

        final restored = SecondaryCameraTake.fromJson(
          take.toJson(),
          documentsPath,
        );

        expect(restored, isNotNull);
        expect(restored!.pipCenter, equals(const Offset(0.25, 0.75)));
        expect(restored.clip.id, equals('clip_1_second'));
        expect(
          restored.clip.video?.file?.path,
          equals('/docs/VID_1_second.mp4'),
        );
        expect(restored.clip.volume, equals(0));
      });

      test('stores the composite thumbnail by name, like the clip files', () {
        final take = SecondaryCameraTake(
          clip: secondClip(),
          compositeThumbnailPath: '/old/container/thumbnail_1_dual.jpg',
        );

        final json = take.toJson();
        final restored = SecondaryCameraTake.fromJson(json, documentsPath);

        expect(json['compositeThumbnailPath'], 'thumbnail_1_dual.jpg');
        expect(
          restored?.compositeThumbnailPath,
          '/docs/thumbnail_1_dual.jpg',
        );
      });

      test('restores a take stored before it had a composite', () {
        final json = SecondaryCameraTake(clip: secondClip()).toJson();

        final restored = SecondaryCameraTake.fromJson(json, documentsPath);

        expect(json.containsKey('compositeThumbnailPath'), isFalse);
        expect(restored?.compositeThumbnailPath, isNull);
      });

      test('falls back to the default position when none is stored', () {
        final json = SecondaryCameraTake(clip: secondClip()).toJson()
          ..remove('pipCenterX');

        final restored = SecondaryCameraTake.fromJson(json, documentsPath);

        expect(
          restored?.pipCenter,
          equals(SecondaryCameraTake.defaultPipCenter),
        );
      });

      test('returns null for anything but a take', () {
        expect(SecondaryCameraTake.fromJson(null, documentsPath), isNull);
        expect(
          SecondaryCameraTake.fromJson({'clip': 'nope'}, documentsPath),
          isNull,
        );
      });

      test('returns null for a damaged clip instead of throwing', () {
        expect(
          SecondaryCameraTake.fromJson({
            'clip': {'id': 'clip_1_second'},
          }, documentsPath),
          isNull,
        );
      });
    });

    test('owns the files of its clip and its composite thumbnail', () {
      final take = SecondaryCameraTake(
        clip: secondClip(),
        compositeThumbnailPath: '/docs/thumbnail_1_dual.jpg',
      );

      expect(
        take.ownedFilePaths,
        containsAll(['/docs/VID_1_second.mp4', '/docs/thumbnail_1_dual.jpg']),
      );
    });

    test('copyWith replaces the window position and keeps the clip', () {
      final take = SecondaryCameraTake(clip: secondClip());

      final moved = take.copyWith(pipCenter: const Offset(0.1, 0.1));

      expect(moved.pipCenter, equals(const Offset(0.1, 0.1)));
      expect(moved.clip, same(take.clip));
    });

    test('copyWith keeps the composite thumbnail when the clip changes', () {
      final take = SecondaryCameraTake(
        clip: secondClip(),
        compositeThumbnailPath: '/docs/thumbnail_1_dual.jpg',
      );

      final proved = take.copyWith(
        clip: secondClip().copyWith(recordingSha256: 'hash'),
      );

      expect(proved.compositeThumbnailPath, '/docs/thumbnail_1_dual.jpg');
    });
  });
}
