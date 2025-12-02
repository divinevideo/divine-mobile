import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/blurhash_service.dart';

void main() {
  group('BlurhashService', () {
    test('generates deterministic blurhash from image bytes', () async {
      // Use real thumbnail image from test fixtures
      final thumbnailFile = File('test/fixtures/test_thumbnail.jpg');
      if (!thumbnailFile.existsSync()) {
        fail(
          'Test thumbnail not found at test/fixtures/test_thumbnail.jpg. Run test/fixtures/generate_test_blurhash.dart to generate it.',
        );
      }
      final testBytes = await thumbnailFile.readAsBytes();

      final blurhash1 = await BlurhashService.generateBlurhash(testBytes);
      final blurhash2 = await BlurhashService.generateBlurhash(testBytes);

      expect(blurhash1, isNotNull);
      expect(blurhash1, equals(blurhash2)); // Should be deterministic
      expect(blurhash1!.startsWith('L'), isTrue);
    });

    test('decodes blurhash to color data', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();

      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.blurhash, equals(testBlurhash));
      expect(data.colors, isNotEmpty);
      expect(data.width, equals(32));
      expect(data.height, equals(32));
    });

    test('provides content-specific blurhashes', () {
      final comedyBlurhash = BlurhashService.getBlurhashForContentType(
        VineContentType.comedy,
      );
      final natureBlurhash = BlurhashService.getBlurhashForContentType(
        VineContentType.nature,
      );

      expect(comedyBlurhash, isNotEmpty);
      expect(natureBlurhash, isNotEmpty);
      expect(comedyBlurhash, isNot(equals(natureBlurhash)));
    });

    test('validates blurhash format', () {
      expect(
        BlurhashService.decodeBlurhash('L6Pj0^jE.AyE_3t7t7R**0o#DgR4'),
        isNotNull,
      );
      expect(BlurhashService.decodeBlurhash('invalid'), isNull);
      expect(BlurhashService.decodeBlurhash(''), isNull);
      expect(BlurhashService.decodeBlurhash('short'), isNull);
    });

    test('blurhash data provides gradient', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.gradient, isNotNull);
    });

    test('blurhash data tracks validity', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.isValid, isTrue);
    });
  });

  group('BlurhashCache', () {
    late BlurhashCache cache;

    setUp(() {
      cache = BlurhashCache();
    });

    test('stores and retrieves blurhash data', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache.put('test_key', data);
      final retrieved = cache.get('test_key');

      expect(retrieved, isNotNull);
      expect(retrieved!.blurhash, equals(data.blurhash));
    });

    test('returns null for non-existent keys', () {
      final retrieved = cache.get('non_existent');
      expect(retrieved, isNull);
    });

    test('removes entries', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache.put('test_key', data);
      expect(cache.get('test_key'), isNotNull);

      cache.remove('test_key');
      expect(cache.get('test_key'), isNull);
    });

    test('clears all entries', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache.put('key1', data);
      cache.put('key2', data);
      expect(cache.get('key1'), isNotNull);
      expect(cache.get('key2'), isNotNull);

      cache.clear();
      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNull);
    });

    test('provides cache statistics', () {
      final stats = cache.getStats();

      expect(stats, containsPair('size', 0));
      expect(stats, containsPair('maxSize', BlurhashCache.maxCacheSize));
    });
  });
}
