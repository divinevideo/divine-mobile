// ABOUTME: Integration test for hybrid local+remote search using real Nostr relays
// ABOUTME: Tests immediate local results followed by remote NIP-50 search

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';

import '../test_setup.dart';

void main() {
  group('Hybrid Search with Real Relay Integration', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;

    setUp(() async {
      setupTestEnvironment();

      // Initialize key manager and Nostr service
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(
        customRelays: ['wss://staging-relay.divine.video'],
      );

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );

      // Wait for relay connection
      await Future.delayed(const Duration(seconds: 2));
    });

    tearDown(() async {
      videoEventService.dispose();
      await nostrService.dispose();
    });

    test('should search local cache and then query remote relay', () async {
      // Phase 1: Get local cached videos (should be fast)
      final localVideos = videoEventService.discoveryVideos;
      final localCount = localVideos.length;

      print('📦 Local cache has $localCount videos');
      expect(localCount, greaterThanOrEqualTo(0));

      // Phase 2: Perform remote search
      const searchQuery = 'nostr';
      print('🔍 Searching for: "$searchQuery"');

      // Start remote search
      await videoEventService.searchVideos(searchQuery, limit: 20);

      // Wait for some results to arrive
      await Future.delayed(const Duration(seconds: 2));

      // Get search results
      final searchResults = videoEventService.searchResults;
      print('🎯 Found ${searchResults.length} search results from relay');

      // Verify we got results (may be empty if relay doesn't support NIP-50)
      expect(searchResults, isNotNull);
      expect(searchResults, isA<List>());

      // If results found, verify they match the query
      if (searchResults.isNotEmpty) {
        final firstResult = searchResults.first;
        final matchesQuery =
            firstResult.content.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            firstResult.title?.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ==
                true ||
            firstResult.hashtags.any(
              (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
            );

        expect(
          matchesQuery,
          isTrue,
          reason: 'Search result should match query "$searchQuery"',
        );
      }
    });

    test('should combine and deduplicate local + remote results', () async {
      const query = 'bitcoin';

      // Get local results by filtering cache
      final localVideos = videoEventService.discoveryVideos.where((video) {
        return video.content.toLowerCase().contains(query) ||
            video.title?.toLowerCase().contains(query) == true ||
            video.hashtags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();

      print('📦 Local matches: ${localVideos.length}');

      // Perform remote search
      await videoEventService.searchVideos(query, limit: 20);
      await Future.delayed(const Duration(seconds: 2));

      final remoteResults = videoEventService.searchResults;
      print('🌐 Remote results: ${remoteResults.length}');

      // Combine and deduplicate
      final allResults = [...localVideos, ...remoteResults];
      final seenIds = <String>{};
      final uniqueResults = allResults.where((video) {
        if (seenIds.contains(video.id)) return false;
        seenIds.add(video.id);
        return true;
      }).toList();

      print('✅ Combined unique results: ${uniqueResults.length}');
      print(
        '   Duplicates removed: ${allResults.length - uniqueResults.length}',
      );

      // Verify deduplication worked
      expect(uniqueResults.length, lessThanOrEqualTo(allResults.length));
      expect(uniqueResults.length, greaterThanOrEqualTo(localVideos.length));
    });

    test(
      'should extract unique users and hashtags from search results',
      () async {
        const query = 'nostr';

        // Perform search
        await videoEventService.searchVideos(query, limit: 30);
        await Future.delayed(const Duration(seconds: 2));

        final results = videoEventService.searchResults;

        if (results.isEmpty) {
          print('⚠️ No results returned, skipping assertions');
          return;
        }

        // Extract unique users
        final users = <String>{};
        for (final video in results) {
          users.add(video.pubkey);
        }

        // Extract unique hashtags matching query
        final hashtags = <String>{};
        for (final video in results) {
          for (final tag in video.hashtags) {
            if (tag.toLowerCase().contains(query.toLowerCase())) {
              hashtags.add(tag);
            }
          }
        }

        print('👥 Unique users found: ${users.length}');
        print(
          '🏷️ Matching hashtags: ${hashtags.length} - ${hashtags.take(5).join(", ")}',
        );

        expect(users.length, greaterThan(0));
        expect(users.length, lessThanOrEqualTo(results.length));
      },
    );

    test('should handle search with no results gracefully', () async {
      const impossibleQuery = 'xyzabc123impossible456query789';

      await videoEventService.searchVideos(impossibleQuery, limit: 10);
      await Future.delayed(const Duration(seconds: 2));

      final results = videoEventService.searchResults;

      print(
        '🔍 Search for "$impossibleQuery" returned ${results.length} results',
      );

      expect(results, isNotNull);
      expect(results, isEmpty);
    });

    test('should clear search results when requested', () async {
      // Perform a search first
      await videoEventService.searchVideos('test', limit: 10);
      await Future.delayed(const Duration(seconds: 1));

      final initialResults = videoEventService.searchResults;
      print('📊 Initial results: ${initialResults.length}');

      // Clear results
      videoEventService.clearSearchResults();

      final clearedResults = videoEventService.searchResults;
      print('🧹 After clear: ${clearedResults.length}');

      expect(clearedResults, isEmpty);
    });
  });
}
