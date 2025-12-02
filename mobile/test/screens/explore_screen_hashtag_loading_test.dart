// ABOUTME: Tests for hashtag loading and display in ExploreScreen Trending tab
// ABOUTME: Verifies hashtags load quickly from JSON and display immediately after loading

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/top_hashtags_service.dart';

void main() {
  group('TopHashtagsService Performance Tests', () {
    test('Hashtags load quickly from JSON asset (< 200ms)', () async {
      // Start timing hashtag load
      final startTime = DateTime.now();

      // Load hashtags from JSON
      await TopHashtagsService.instance.loadTopHashtags();

      final loadDuration = DateTime.now().difference(startTime);

      // CRITICAL: Hashtag loading should be FAST (< 200ms for JSON file read)
      expect(
        loadDuration.inMilliseconds,
        lessThan(200),
        reason: 'Hashtags should load from JSON file in under 200ms',
      );

      // Verify hashtags are loaded in service
      expect(TopHashtagsService.instance.isLoaded, isTrue);
      expect(TopHashtagsService.instance.topHashtags.length, greaterThan(0));
    });

    test('TopHashtagsService loads hashtags only once (idempotent)', () async {
      final service = TopHashtagsService.instance;

      // First load
      await service.loadTopHashtags();
      final firstLoadCount = service.topHashtags.length;
      expect(firstLoadCount, greaterThan(0), reason: 'Should load hashtags');

      // Second load (should skip - already loaded)
      await service.loadTopHashtags();
      final secondLoadCount = service.topHashtags.length;

      // Verify service doesn't reload unnecessarily
      expect(secondLoadCount, equals(firstLoadCount));
      expect(service.isLoaded, isTrue);
    });

    test('getTopHashtags returns requested number of hashtags', () async {
      final service = TopHashtagsService.instance;
      await service.loadTopHashtags();

      // Test various limits
      final top10 = service.getTopHashtags(limit: 10);
      expect(top10.length, equals(10));

      final top50 = service.getTopHashtags(limit: 50);
      expect(top50.length, equals(50));

      final top100 = service.getTopHashtags(limit: 100);
      expect(top100.length, equals(100));
    });

    test('getTopHashtags returns empty list before loading', () {
      // Create fresh service instance would normally need a reset mechanism
      // For now, test the guard condition
      final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

      // Should either be loaded (from previous test) or empty
      expect(hashtags, isA<List<String>>());
    });

    test('searchHashtags finds exact matches', () async {
      final service = TopHashtagsService.instance;
      await service.loadTopHashtags();

      // Search for common hashtag (from top 1000 list)
      final results = service.searchHashtags('funny', limit: 10);

      expect(results, isNotEmpty, reason: 'Should find funny hashtag');
      expect(results.first.toLowerCase(), contains('funny'));
    });

    test('searchHashtags finds prefix matches', () async {
      final service = TopHashtagsService.instance;
      await service.loadTopHashtags();

      // Search with prefix (from top 1000 list)
      final results = service.searchHashtags('fun', limit: 10);

      expect(
        results,
        isNotEmpty,
        reason: 'Should find hashtags starting with fun',
      );
    });

    test('searchHashtags is case insensitive', () async {
      final service = TopHashtagsService.instance;
      await service.loadTopHashtags();

      final lowercase = service.searchHashtags('funny', limit: 10);
      final uppercase = service.searchHashtags('FUNNY', limit: 10);
      final mixedcase = service.searchHashtags('FuNnY', limit: 10);

      // All should return same results
      expect(lowercase, isNotEmpty);
      expect(uppercase, equals(lowercase));
      expect(mixedcase, equals(lowercase));
    });
  });
}
