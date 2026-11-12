// ABOUTME: Tests the deterministic preparation step of the DivineSticker
// ABOUTME: tool: residue clearing, subject crop with padding, and resizing.

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tools/process_divine_sticker.dart';

/// A transparent canvas with an opaque red rectangle at the given place.
img.Image _canvas({
  required int width,
  required int height,
  required int left,
  required int top,
  required int subjectWidth,
  required int subjectHeight,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = top; y < top + subjectHeight; y++) {
    for (var x = left; x < left + subjectWidth; x++) {
      image.setPixelRgba(x, y, 255, 0, 0, 255);
    }
  }
  return image;
}

void main() {
  group('prepareSticker', () {
    test('crops to the subject with a 2% margin on its long side', () {
      final source = _canvas(
        width: 400,
        height: 400,
        left: 100,
        top: 150,
        subjectWidth: 200,
        subjectHeight: 100,
      );

      final result = prepareSticker(source);

      expect(
        result.crop,
        equals((left: 96, top: 146, width: 208, height: 108, padding: 4)),
      );
      expect(result.image.width, equals(208));
      expect(result.image.height, equals(108));
    });

    test('keeps a margin of at least $minPadding px around a tiny subject', () {
      final source = _canvas(
        width: 50,
        height: 50,
        left: 20,
        top: 20,
        subjectWidth: 10,
        subjectHeight: 10,
      );

      final result = prepareSticker(source);

      expect(result.crop.padding, equals(minPadding));
      expect(result.image.width, equals(10 + 2 * minPadding));
      expect(result.image.getPixel(0, 0).a, equals(0));
      expect(result.image.getPixel(minPadding, minPadding).a, equals(255));
    });

    test('clears residue below the alpha floor before cropping', () {
      final source = _canvas(
        width: 300,
        height: 300,
        left: 100,
        top: 100,
        subjectWidth: 100,
        subjectHeight: 100,
      )..setPixelRgba(5, 5, 0, 255, 0, alphaFloor - 1);

      final result = prepareSticker(source);

      expect(result.crop.left, equals(98));
      for (final pixel in result.image) {
        expect(pixel.a == 0 || pixel.a == 255, isTrue);
      }
    });

    test('ignores faint pixels when sizing the crop', () {
      final source = _canvas(
        width: 300,
        height: 300,
        left: 100,
        top: 100,
        subjectWidth: 100,
        subjectHeight: 100,
      )..setPixelRgba(5, 5, 0, 255, 0, subjectAlpha);

      final result = prepareSticker(source);

      expect(result.crop.left, equals(98));
      expect(result.crop.width, equals(104));
    });

    test('scales a large subject down to $maxLongEdge px on its long edge', () {
      final source = _canvas(
        width: 1200,
        height: 1200,
        left: 100,
        top: 300,
        subjectWidth: 1000,
        subjectHeight: 500,
      );

      final result = prepareSticker(source);

      // The 20 px margin makes the crop 1040 x 540, scaled by 512 / 1040.
      expect(result.crop.width, equals(1040));
      expect(result.image.width, equals(maxLongEdge));
      expect(result.image.height, equals(266));
    });

    test('never upscales a subject smaller than $maxLongEdge px', () {
      final source = _canvas(
        width: 300,
        height: 300,
        left: 50,
        top: 50,
        subjectWidth: 150,
        subjectHeight: 120,
      );

      final result = prepareSticker(source);

      expect(result.image.width, equals(result.crop.width));
      expect(result.image.height, equals(result.crop.height));
    });

    test('keeps the colour of semi-transparent edges after resizing', () {
      final source = img.Image(width: 1100, height: 1100, numChannels: 4);
      for (var y = 0; y < 1100; y++) {
        for (var x = 0; x < 1100; x++) {
          source.setPixelRgba(x, y, 0, 0, 255, x < 550 ? 255 : 128);
        }
      }

      final result = prepareSticker(source);

      for (final pixel in result.image) {
        if (pixel.a > 0) {
          expect(pixel.b, equals(255));
          expect(pixel.r, equals(0));
        }
      }
    });

    test('throws when nothing is opaque enough to be a subject', () {
      final source = img.Image(width: 20, height: 20, numChannels: 4)
        ..setPixelRgba(10, 10, 255, 255, 255, subjectAlpha);

      expect(() => prepareSticker(source), throwsStateError);
    });
  });
}
