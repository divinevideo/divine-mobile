import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

    Future<img.Image> compose(Offset center) async {
      final result = await composeDualCameraThumbnail(
        mainThumbnailPath: mainPath,
        secondaryThumbnailPath: secondPath,
        pipCenter: center,
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

    test('writes nothing when a thumbnail is missing', () async {
      final result = await composeDualCameraThumbnail(
        mainThumbnailPath: mainPath,
        secondaryThumbnailPath: p.join(dir.path, 'missing.jpg'),
        pipCenter: SecondaryCameraTake.defaultPipCenter,
        outputPath: outputPath,
      );

      expect(result, isNull);
      expect(File(outputPath).existsSync(), isFalse);
    });
  });
}
