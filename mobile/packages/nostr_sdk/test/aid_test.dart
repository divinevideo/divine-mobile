// ABOUTME: Tests the legacy 34236 alias of a Kind 34235 video coordinate.

import 'package:nostr_sdk/aid.dart';
import 'package:test/test.dart';

void main() {
  const pubkey =
      'c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0';

  group('legacyVideoCoordinateFor', () {
    test('maps a Kind 34235 coordinate to its 34236 form', () {
      expect(
        legacyVideoCoordinateFor('34235:$pubkey:reel:with:colons'),
        equals('34236:$pubkey:reel:with:colons'),
      );
    });

    test('is null for a Kind 34236 coordinate', () {
      expect(legacyVideoCoordinateFor('34236:$pubkey:vine123'), isNull);
    });

    test('is null for a coordinate of another kind', () {
      expect(legacyVideoCoordinateFor('30023:$pubkey:article'), isNull);
    });

    test('is null for text that is not a coordinate', () {
      expect(legacyVideoCoordinateFor('34235:$pubkey'), isNull);
    });
  });
}
