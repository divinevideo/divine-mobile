import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/display_aspect_ratio.dart';

void main() {
  group('displayAspectRatio', () {
    test('lays a legacy 16:9 derivative of a square source out square', () {
      expect(
        displayAspectRatio(
          decodedAspectRatio: 1280 / 720,
          declaredWidth: 480,
          declaredHeight: 480,
        ),
        equals(1.0),
      );
    });

    test('lays a legacy 16:9 derivative of a portrait source out portrait', () {
      expect(
        displayAspectRatio(
          decodedAspectRatio: 854 / 480,
          declaredWidth: 810,
          declaredHeight: 1440,
        ),
        closeTo(810 / 1440, 1e-9),
      );
    });

    test('keeps the decoded ratio when the declared ratio matches it', () {
      expect(
        displayAspectRatio(
          decodedAspectRatio: 1280 / 720,
          declaredWidth: 1920,
          declaredHeight: 1080,
        ),
        equals(1280 / 720),
      );
    });

    test('keeps the decoded ratio for any non-16:9 file', () {
      expect(
        displayAspectRatio(
          decodedAspectRatio: 9 / 16,
          declaredWidth: 480,
          declaredHeight: 480,
        ),
        equals(9 / 16),
      );
    });

    test('keeps the decoded ratio when the event declares no usable dim', () {
      for (final (width, height) in [(null, null), (480, null), (0, 480)]) {
        expect(
          displayAspectRatio(
            decodedAspectRatio: 16 / 9,
            declaredWidth: width,
            declaredHeight: height,
          ),
          equals(16 / 9),
        );
      }
    });

    test('passes an unknown decoded ratio through unchanged', () {
      expect(
        displayAspectRatio(
          decodedAspectRatio: 0,
          declaredWidth: 480,
          declaredHeight: 480,
        ),
        equals(0),
      );
    });
  });
}
