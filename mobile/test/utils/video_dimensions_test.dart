import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/utils/video_dimensions.dart';

void main() {
  group('getDimensionTag', () {
    test('returns correct dimensions for square 1080p', () {
      final result = getDimensionTag(AspectRatio.square, 1080);
      expect(result, equals('1080x1080'));
    });

    test('returns correct dimensions for vertical 1080p', () {
      final result = getDimensionTag(AspectRatio.vertical, 1080);
      expect(result, equals('607x1080'));
    });

    test('returns correct dimensions for square 720p', () {
      final result = getDimensionTag(AspectRatio.square, 720);
      expect(result, equals('720x720'));
    });

    test('returns correct dimensions for vertical 720p', () {
      final result = getDimensionTag(AspectRatio.vertical, 720);
      expect(result, equals('405x720'));
    });

    test('vertical width rounds correctly', () {
      // 1080 * 9/16 = 607.5, should round to 607
      final result = getDimensionTag(AspectRatio.vertical, 1080);
      expect(result, equals('607x1080'));
    });
  });
}
