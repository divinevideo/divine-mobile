import 'dart:math' as math;
import 'dart:ui' show Size;

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
      test('round-trips the clip and the window placement', () {
        final take = SecondaryCameraTake(
          clip: secondClip(),
          pipCenter: const Offset(0.25, 0.75),
          pipScale: 1.4,
          pipRotation: -0.3,
          pipAspectRatio: model.AspectRatio.square,
        );

        final restored = SecondaryCameraTake.fromJson(
          take.toJson(),
          documentsPath,
        );

        expect(restored, isNotNull);
        expect(restored!.pipCenter, equals(const Offset(0.25, 0.75)));
        expect(restored.pipScale, equals(1.4));
        expect(restored.pipRotation, equals(-0.3));
        expect(restored.pipAspectRatio, equals(model.AspectRatio.square));
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

      test('reads a take stored before the window could be pinched as '
          'upright and portrait at its default size', () {
        final json = SecondaryCameraTake(clip: secondClip()).toJson()
          ..remove('pipScale')
          ..remove('pipRotation')
          ..remove('pipAspectRatio');

        final restored = SecondaryCameraTake.fromJson(json, documentsPath);

        expect(restored?.pipScale, equals(1));
        expect(restored?.pipRotation, equals(0));
        expect(restored?.pipAspectRatio, equals(model.AspectRatio.vertical));
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

    group('fittingPipScale', () {
      // The default window on a vertical take 300 wide: 90 by 160.
      const unscaled = Size(90, 160);
      const kept = Size(300, 533);

      test('keeps a pinch between the smallest and the largest window', () {
        double fit(double scale) => SecondaryCameraTake.fittingPipScale(
          scale: scale,
          unscaledSize: unscaled,
          rotation: 0,
          area: kept,
        );

        expect(fit(0.1), equals(SecondaryCameraTake.pipMinScale));
        expect(fit(1.3), equals(1.3));
        expect(fit(5), equals(SecondaryCameraTake.pipMaxScale));
      });

      test('shrinks a turned window that would no longer fit', () {
        final scale = SecondaryCameraTake.fittingPipScale(
          scale: SecondaryCameraTake.pipMaxScale,
          unscaledSize: unscaled,
          rotation: math.pi / 4,
          area: kept,
        );

        final bounds = SecondaryCameraTake.turnedPipBounds(
          unscaled * scale,
          math.pi / 4,
        );
        expect(scale, lessThan(SecondaryCameraTake.pipMaxScale));
        expect(bounds.width, closeTo(kept.width, 1e-9));
      });
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
