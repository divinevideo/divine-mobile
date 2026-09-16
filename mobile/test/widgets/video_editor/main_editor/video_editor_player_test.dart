import 'dart:convert';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

void main() {
  group('stop-motion preview', () {
    // 1x1 transparent PNG.
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
    );

    late Directory tempDir;
    late List<StopMotionClipFrame> frames;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('video_editor_player_test');
      frames = [
        for (final name in ['a', 'b', 'c'])
          StopMotionClipFrame(
            path: (File(
              '${tempDir.path}/$name.png',
            )..writeAsBytesSync(pngBytes)).path,
            duration: const Duration(milliseconds: 100),
          ),
      ];
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    testWidgets('drives the StopMotionPlayer from stopMotionPosition', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 400,
              child: VideoEditorPlayer(
                controller: null,
                targetAspectRatio: model.AspectRatio.vertical,
                videoAspectRatio: 9 / 16,
                bodySize: const Size(200, 400),
                renderSize: const Size(200, 400),
                stopMotionFrames: frames,
                // 150ms → the second frame's window [100,200).
                stopMotionPosition: const Duration(milliseconds: 150),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StopMotionPlayer), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      // The editor bounds the decode size, so the provider is a ResizeImage
      // wrapping the FileImage.
      final provider = image.image;
      final fileImage = provider is ResizeImage
          ? provider.imageProvider as FileImage
          : provider as FileImage;
      expect(fileImage.file.path, frames[1].path);
    });
  });

  group('video surface', () {
    // The canvas hands the player a box shaped like the recording (9:16 at
    // 225×400) inside an 800-tall body, with a square composition.
    const widgetSize = Size(225, 400);
    const bodySize = Size(400, 800);

    Future<void> pumpPlayer(
      WidgetTester tester, {
      required double videoAspectRatio,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: SizedBox.fromSize(
                size: widgetSize,
                child: VideoEditorPlayer(
                  controller: null,
                  targetAspectRatio: model.AspectRatio.square,
                  videoAspectRatio: videoAspectRatio,
                  bodySize: bodySize,
                  renderSize: widgetSize,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Rect surfaceRect(WidgetTester tester) =>
        tester.getRect(find.byType(DivineVideoPlayer));

    testWidgets('a file shaped like the recording fills the box as before', (
      tester,
    ) async {
      await pumpPlayer(tester, videoAspectRatio: 9 / 16);

      expect(surfaceRect(tester).size, widgetSize);
    });

    testWidgets('a file the transform reshaped is laid out at its own ratio', (
      tester,
    ) async {
      // The square crop of a 9:16 recording: 1:1 frames over the 1:1 target
      // rect, centred, rather than stretched to the 9:16 box (#9229).
      await pumpPlayer(tester, videoAspectRatio: 1);

      final rect = surfaceRect(tester);
      final box = tester.getRect(find.byType(VideoEditorPlayer));
      expect(rect.size, const Size(225, 225));
      expect(rect.center, box.center);
      expect(find.byType(VideoEditorThumbnail), findsOneWidget);
    });

    testWidgets('a file wider than the box covers the target rect', (
      tester,
    ) async {
      // A 16:9 import: as tall as the square rect, overflowing it sideways so
      // the export's centre crop and the preview show the same slice.
      await pumpPlayer(tester, videoAspectRatio: 16 / 9);

      final rect = surfaceRect(tester);
      final box = tester.getRect(find.byType(VideoEditorPlayer));
      expect(rect.height, 225);
      expect(rect.width, closeTo(225 * 16 / 9, 0.01));
      expect(rect.center, box.center);
    });
  });

  group(computeSurfaceSize, () {
    const bodySize = Size(400, 800);

    test("is the widget box when the file has the box's own ratio", () {
      for (final (widgetSize, target) in [
        (const Size(219, 390), 1.0),
        (const Size(219, 390), 9 / 16),
        (const Size(390, 390), 9 / 16),
        (const Size(292, 390), 9 / 16),
      ]) {
        expect(
          computeSurfaceSize(
            widgetSize: widgetSize,
            bodySize: bodySize,
            targetAspectRatio: target,
            videoAspectRatio: widgetSize.aspectRatio,
          ),
          widgetSize,
          reason: '$widgetSize at target $target',
        );
      }
    });

    test('covers the target rect with a narrower file', () {
      // 9:16 frames over a 1:1 rect in a square box: full width, taller.
      final size = computeSurfaceSize(
        widgetSize: const Size(300, 300),
        bodySize: bodySize,
        targetAspectRatio: 1,
        videoAspectRatio: 9 / 16,
      );
      expect(size.width, 300);
      expect(size.height, closeTo(300 * 16 / 9, 0.01));
    });

    test('covers the target rect with a wider file', () {
      // 1:1 frames over a 9:16 rect: full height, wider than the rect.
      final size = computeSurfaceSize(
        widgetSize: const Size(225, 400),
        bodySize: bodySize,
        targetAspectRatio: 9 / 16,
        videoAspectRatio: 1,
      );
      expect(size.height, 400);
      expect(size.width, 400);
    });
  });

  group(computeClipSize, () {
    group('square (1:1) target', () {
      test('clips tall widget to square using width as shortest side', () {
        // 9:16 video rendered at 219×390
        final result = computeClipSize(
          widgetSize: const Size(219, 390),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(219));
        expect(result.height, equals(219));
      });

      test('clips wide widget to square using height as shortest side', () {
        // 16:9 video rendered at 640×360
        final result = computeClipSize(
          widgetSize: const Size(640, 360),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(360));
        expect(result.height, equals(360));
      });

      test('returns same size when widget is already square', () {
        final result = computeClipSize(
          widgetSize: const Size(300, 300),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(300));
        expect(result.height, equals(300));
      });
    });

    group('vertical (9:16) target', () {
      test('clips to 9:16 when widget matches aspect ratio', () {
        final result = computeClipSize(
          widgetSize: const Size(225, 400),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(225, 0.01));
        expect(result.height, equals(400));
      });

      test('constrains width for wider-than-target widget', () {
        // Widget is wider than 9:16
        final result = computeClipSize(
          widgetSize: const Size(400, 400),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(400 * 9 / 16, 0.01));
        expect(result.height, equals(400));
      });
    });

    group('fullscreen mode', () {
      test('returns target-aspect constrained size from widget bounds', () {
        final result = computeClipSize(
          widgetSize: const Size(219, 390),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(219, 1));
        expect(result.height, closeTo(390, 1));
      });
    });

    group('clip is centered', () {
      test('square clip from tall widget is centered vertically', () {
        const widgetSize = Size(200, 400);
        final clipSize = computeClipSize(
          widgetSize: widgetSize,
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        // Verify shortest side is used
        expect(clipSize.width, equals(200));
        expect(clipSize.height, equals(200));

        // Rect.fromCenter would place this at (0, 100) → (200, 300)
        final rect = Rect.fromCenter(
          center: Offset(widgetSize.width / 2, widgetSize.height / 2),
          width: clipSize.width,
          height: clipSize.height,
        );
        expect(rect.left, equals(0));
        expect(rect.top, equals(100));
        expect(rect.right, equals(200));
        expect(rect.bottom, equals(300));
      });
    });
  });
}
