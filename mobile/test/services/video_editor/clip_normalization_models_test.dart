// ABOUTME: Tests the crop geometry that decides whether a clip needs
// ABOUTME: normalizing, and the analysis that picks per-clip vs global cropping

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_normalization_models.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  ClipAnalysisEntry entry(String id, Size resolution) => ClipAnalysisEntry(
    clip: DivineVideoClip(
      id: id,
      video: EditorVideo.file('/tmp/$id.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    ),
    resolution: resolution,
    cropParams: CropParameters.forAspectRatio(
      resolution: resolution,
      aspectRatio: model.AspectRatio.vertical,
    ),
  );

  group('CropParameters', () {
    group('forAspectRatio', () {
      test('centers a square crop on the shorter side', () {
        final crop = CropParameters.forAspectRatio(
          resolution: const Size(1920, 1080),
          aspectRatio: model.AspectRatio.square,
        );

        expect(crop.width, 1080);
        expect(crop.height, 1080);
        expect(crop.x, 420);
        expect(crop.y, 0);
      });

      test('crops width when the source is wider than 9:16', () {
        final crop = CropParameters.forAspectRatio(
          resolution: const Size(1920, 1080),
          aspectRatio: model.AspectRatio.vertical,
        );

        expect(crop.height, 1080);
        expect(crop.width, 608);
        expect(crop.x, 656);
        expect(crop.y, 0);
      });

      test('crops height when the source is taller than 9:16', () {
        final crop = CropParameters.forAspectRatio(
          resolution: const Size(1080, 2400),
          aspectRatio: model.AspectRatio.vertical,
        );

        expect(crop.width, 1080);
        expect(crop.height, 1920);
        expect(crop.x, 0);
        expect(crop.y, 240);
      });
    });

    group('needsCropping', () {
      test('is false for a source that already matches the target', () {
        const resolution = Size(1080, 1920);
        final crop = CropParameters.forAspectRatio(
          resolution: resolution,
          aspectRatio: model.AspectRatio.vertical,
        );

        expect(crop.needsCropping(resolution), isFalse);
      });

      test('is true for a source that must be cropped', () {
        const resolution = Size(1920, 1080);
        final crop = CropParameters.forAspectRatio(
          resolution: resolution,
          aspectRatio: model.AspectRatio.vertical,
        );

        expect(crop.needsCropping(resolution), isTrue);
      });
    });

    group('toExportTransform', () {
      test('carries the crop rectangle onto the export transform', () {
        const crop = CropParameters(x: 1, y: 2, width: 3, height: 4);

        final transform = crop.toExportTransform();

        expect(transform.x, 1);
        expect(transform.y, 2);
        expect(transform.width, 3);
        expect(transform.height, 4);
      });
    });
  });

  group('ClipAnalysis', () {
    group('allSameCropParams', () {
      test('is true when every clip crops to the same rectangle', () {
        final analysis = ClipAnalysis(
          entries: [
            entry('a', const Size(1920, 1080)),
            entry('b', const Size(1920, 1080)),
          ],
        );

        expect(analysis.allSameCropParams, isTrue);
      });

      test('is false when resolutions crop differently, which is what puts '
          'the export on the per-clip normalization path', () {
        final analysis = ClipAnalysis(
          entries: [
            entry('a', const Size(1920, 1080)),
            entry('b', const Size(1280, 720)),
          ],
        );

        expect(analysis.allSameCropParams, isFalse);
      });

      test('is true for no clips at all', () {
        expect(const ClipAnalysis(entries: []).allSameCropParams, isTrue);
      });
    });
  });
}
