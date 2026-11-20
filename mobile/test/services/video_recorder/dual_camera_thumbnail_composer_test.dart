import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/services/video_recorder/dual_camera_thumbnail_composer.dart';
import 'package:path/path.dart' as p;

void main() {
  group('composeDualCameraThumbnail', () {
    late Directory dir;
    late String mainPath;
    late String secondPath;
    late String outputPath;

    // Large, flat areas: JPEG blurs only a pixel or two at an edge.
    const frameWidth = 400;
    const frameHeight = 800;

    String writeJpeg(String name, int width, int height, img.Color color) {
      final image = img.Image(width: width, height: height)..clear(color);
      final path = p.join(dir.path, name);
      File(path).writeAsBytesSync(img.encodeJpg(image));
      return path;
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dual_thumbnail');
      mainPath = writeJpeg(
        'main.jpg',
        frameWidth,
        frameHeight,
        img.ColorRgb8(0, 0, 255),
      );
      secondPath = writeJpeg('second.jpg', 90, 160, img.ColorRgb8(255, 0, 0));
      outputPath = p.join(dir.path, 'main_dual.jpg');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    /// [targetAspectRatio] defaults to the frame's own: the take keeps it
    /// whole.
    Future<img.Image> compose(
      Offset center, {
      double targetAspectRatio = frameWidth / frameHeight,
      double scale = 1,
      double rotation = 0,
      model.AspectRatio shape = model.AspectRatio.vertical,
    }) async {
      final result = await composeDualCameraThumbnail(
        mainThumbnailPath: mainPath,
        secondaryThumbnailPath: secondPath,
        pipCenter: center,
        pipScale: scale,
        pipRotation: rotation,
        pipAspectRatio: shape,
        targetAspectRatio: targetAspectRatio,
        outputPath: outputPath,
      );
      expect(result, outputPath);
      return img.decodeJpg(File(outputPath).readAsBytesSync())!;
    }

    bool isRed(img.Pixel pixel) => pixel.r > 200 && pixel.b < 60;
    bool isBlue(img.Pixel pixel) => pixel.b > 200 && pixel.r < 60;

    test(
      "keeps the take's picture and draws the window where it was",
      () async {
        final composite = await compose(const Offset(0.25, 0.5));

        expect(composite.width, frameWidth);
        expect(composite.height, frameHeight);
        expect(isRed(composite.getPixel(100, 400)), isTrue);
        expect(isBlue(composite.getPixel(300, 400)), isTrue);
        expect(isBlue(composite.getPixel(100, 100)), isTrue);
      },
    );

    test(
      'sizes the window like the viewfinder, in the second picture shape',
      () async {
        final composite = await compose(const Offset(0.5, 0.5));

        const width = frameWidth * SecondaryCameraTake.pipWidthFraction;
        const height = width * 160 / 90;
        const left = (frameWidth - width) / 2;
        const top = (frameHeight - height) / 2;
        // Just inside and just outside each edge, away from the corners.
        expect(isRed(composite.getPixel(left.round() + 4, 400)), isTrue);
        expect(isBlue(composite.getPixel(left.round() - 4, 400)), isTrue);
        expect(isRed(composite.getPixel(200, top.round() + 4)), isTrue);
        expect(isBlue(composite.getPixel(200, top.round() - 4)), isTrue);
      },
    );

    test(
      'draws a pinched and turned window as the viewfinder showed it',
      () async {
        final composite = await compose(
          const Offset(0.5, 0.5),
          scale: 1.5,
          rotation: math.pi / 2,
        );

        // 180 by 320 upright, so lying on its side it reaches 160 left and
        // right of the centre and only 90 up and down.
        expect(isRed(composite.getPixel(350, 400)), isTrue);
        expect(isBlue(composite.getPixel(380, 400)), isTrue);
        expect(isBlue(composite.getPixel(200, 530)), isTrue);
      },
    );

    test(
      'draws a square window from the middle of the second picture',
      () async {
        // Green above and below the middle square of the 90 by 160 picture.
        final banded = img.Image(width: 90, height: 160)
          ..clear(img.ColorRgb8(255, 0, 0));
        img.fillRect(
          banded,
          x1: 0,
          y1: 0,
          x2: 89,
          y2: 34,
          color: img.ColorRgb8(0, 255, 0),
        );
        img.fillRect(
          banded,
          x1: 0,
          y1: 125,
          x2: 89,
          y2: 159,
          color: img.ColorRgb8(0, 255, 0),
        );
        File(secondPath).writeAsBytesSync(img.encodeJpg(banded));

        final composite = await compose(
          const Offset(0.5, 0.5),
          shape: model.AspectRatio.square,
        );

        // 120 wide, so 60 above and below the centre instead of 107.
        expect(isRed(composite.getPixel(200, 400 + 50)), isTrue);
        expect(isBlue(composite.getPixel(200, 400 + 75)), isTrue);
        // Cut from the middle, not squeezed: no green at its top and bottom.
        expect(isRed(composite.getPixel(200, 400 - 52)), isTrue);
        expect(isRed(composite.getPixel(200, 400 + 52)), isTrue);
      },
    );

    test('rounds the corners like the viewfinder window', () async {
      final composite = await compose(const Offset(0.5, 0.5));

      const width = frameWidth * SecondaryCameraTake.pipWidthFraction;
      const height = width * 160 / 90;
      final left = ((frameWidth - width) / 2).round();
      final top = ((frameHeight - height) / 2).round();
      const radius = width / 2 * SecondaryCameraTake.pipCornerRadius;

      expect(isBlue(composite.getPixel(left + 1, top + 1)), isTrue);
      final inset = (radius + 2).round();
      expect(isRed(composite.getPixel(left + inset, top + inset)), isTrue);
    });

    test(
      'keeps a window dragged to the edge whole inside the picture',
      () async {
        final composite = await compose(const Offset(1, 1));

        const width = frameWidth * SecondaryCameraTake.pipWidthFraction;
        const radius = width / 2 * SecondaryCameraTake.pipCornerRadius;
        final inset = (radius + 2).round();
        expect(
          isRed(composite.getPixel(frameWidth - inset, frameHeight - inset)),
          isTrue,
        );
      },
    );

    test(
      'measures a square take against the middle square it keeps',
      () async {
        // The viewfinder of a square take shows the middle square, 200 to
        // 600 here, and measured the window against it.
        final composite = await compose(
          const Offset(0.5, 0.3),
          targetAspectRatio: 1,
        );

        const height =
            frameWidth * SecondaryCameraTake.pipWidthFraction * 160 / 90;
        const center = 200 + 0.3 * frameWidth;
        expect(isRed(composite.getPixel(200, center.round())), isTrue);
        expect(
          isBlue(composite.getPixel(200, (center - height / 2).round() - 6)),
          isTrue,
          reason: 'measured against the whole frame, the window sat higher',
        );
        expect(
          isRed(composite.getPixel(200, (center + height / 2).round() - 6)),
          isTrue,
        );
      },
    );

    test('writes nothing when a thumbnail is missing', () async {
      final result = await composeDualCameraThumbnail(
        mainThumbnailPath: mainPath,
        secondaryThumbnailPath: p.join(dir.path, 'missing.jpg'),
        pipCenter: SecondaryCameraTake.defaultPipCenter,
        targetAspectRatio: 9 / 16,
        outputPath: outputPath,
      );

      expect(result, isNull);
      expect(File(outputPath).existsSync(), isFalse);
    });
  });
}
