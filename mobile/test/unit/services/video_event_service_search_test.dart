// ABOUTME: Unit tests for VideoEventService NIP-50 search functionality
// ABOUTME: Tests search capabilities including text queries, filters, and result processing

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('VideoEventService Search Tests', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();

      // Setup basic mocks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.hasKeys).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('test_pubkey');

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      videoEventService.dispose();
      reset(mockNostrService);
    });

    group('Search Method Tests', () {
      test('should call searchVideos and handle empty query', () {
        const searchQuery = '';

        expect(
          () => videoEventService.searchVideos(searchQuery),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should call searchVideosByHashtag with valid hashtag', () async {
        // Mock the nostr service to return an empty stream
        when(
          () => mockNostrService.searchVideos(
            any(),
            authors: any(named: 'authors'),
            since: any(named: 'since'),
            until: any(named: 'until'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => const Stream<Event>.empty());

        const hashtag = '#bitcoin';

        // Should not throw and should complete successfully
        await videoEventService.searchVideosByHashtag(hashtag);

        // Verify the service was called with the correct search query
        verify(
          () => mockNostrService.searchVideos(
            '#bitcoin',
            authors: any(named: 'authors'),
            since: any(named: 'since'),
            until: any(named: 'until'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      test(
        'should call searchVideosWithFilters with correct parameters',
        () async {
          // Mock the nostr service to return an empty stream
          when(
            () => mockNostrService.searchVideos(
              any(),
              authors: any(named: 'authors'),
              since: any(named: 'since'),
              until: any(named: 'until'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          const searchQuery = 'nostr';
          final authors = ['author1', 'author2'];

          await videoEventService.searchVideosWithFilters(
            query: searchQuery,
            authors: authors,
          );

          // Verify the service was called with correct parameters
          verify(
            () => mockNostrService.searchVideos(
              searchQuery,
              authors: authors,
              since: any(named: 'since'),
              until: any(named: 'until'),
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );
    });

    group('Search State Management', () {
      test('should have initial search state properties', () {
        // Initial state should be empty/false
        expect(videoEventService.searchResults, isEmpty);
      });

      test('should clear search results and reset state', () {
        // Call clearSearchResults method
        videoEventService.clearSearchResults();

        // Verify state is cleared
        expect(videoEventService.searchResults, isEmpty);
      });
    });

    group('Search Event Processing', () {
      test('should process empty search results', () {
        final mockEvents = <Event>[];

        final results = videoEventService.processSearchResults(mockEvents);

        expect(results, isEmpty);
      });

      test('should deduplicate empty search results', () {
        final mockVideoEvents = <VideoEvent>[];

        final results = videoEventService.deduplicateSearchResults(
          mockVideoEvents,
        );

        expect(results, isEmpty);
      });
    });

    group('Advanced Search Features', () {
      test(
        'should call searchVideosWithTimeRange with correct parameters',
        () async {
          // Mock the nostr service to return an empty stream
          when(
            () => mockNostrService.searchVideos(
              any(),
              authors: any(named: 'authors'),
              since: any(named: 'since'),
              until: any(named: 'until'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          const searchQuery = 'bitcoin';
          final since = DateTime.now().subtract(const Duration(days: 7));
          final until = DateTime.now();

          await videoEventService.searchVideosWithTimeRange(
            query: searchQuery,
            since: since,
            until: until,
          );

          // Verify the underlying search was called with time parameters
          verify(
            () => mockNostrService.searchVideos(
              searchQuery,
              authors: any(named: 'authors'),
              since: since,
              until: until,
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      test(
        'should call searchVideosWithExtensions with query extensions',
        () async {
          // Mock the nostr service to return an empty stream
          when(
            () => mockNostrService.searchVideos(
              any(),
              authors: any(named: 'authors'),
              since: any(named: 'since'),
              until: any(named: 'until'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          const searchQuery = 'music language:en nsfw:false';

          await videoEventService.searchVideosWithExtensions(searchQuery);

          // Verify the search was called with the extensions query
          verify(
            () => mockNostrService.searchVideos(
              searchQuery,
              authors: any(named: 'authors'),
              since: any(named: 'since'),
              until: any(named: 'until'),
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );
    });

    group('Search Blocklist Filtering (Issue #948)', () {
      // Valid 64-character hex pubkeys for testing
      const blockedPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const normalPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const otherBlockedPubkey =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      test('should filter blocked user videos from search results', () async {
        // Create a real blocklist service and block a user
        final blocklistRepository = ContentBlocklistRepository();
        blocklistRepository.blockUser(blockedPubkey);

        // Set the blocklist service on the video event service
        videoEventService.setBlocklistRepository(blocklistRepository);

        // Create a mock video event from the blocked user (NIP-71 kind 34236)
        // Event constructor: Event(pubkey, kind, tags, content, {createdAt})
        final blockedUserEvent = Event(
          blockedPubkey,
          34236, // NIP-71 short-form video
          [
            ['d', 'video-identifier'],
            ['url', 'https://example.com/video.mp4'],
            ['m', 'video/mp4'],
          ],
          'Test video from blocked user',
        );

        // Process the event through the search handler
        videoEventService.handleEventForTesting(
          blockedUserEvent,
          SubscriptionType.search,
        );

        // Verify the blocked user's video is NOT in search results
        final searchResults = videoEventService.searchResults;
        expect(
          searchResults.any((v) => v.pubkey == blockedPubkey),
          isFalse,
          reason: 'Blocked user videos should be filtered from search results',
        );
      });

      test(
        'should include non-blocked user videos in search results',
        () async {
          // Create a real blocklist service
          final blocklistRepository = ContentBlocklistRepository();

          // Block a different user (not normalPubkey)
          blocklistRepository.blockUser(otherBlockedPubkey);

          // Set the blocklist service on the video event service
          videoEventService.setBlocklistRepository(blocklistRepository);

          // Create a mock video event from a non-blocked user
          // Event constructor: Event(pubkey, kind, tags, content, {createdAt})
          final normalUserEvent = Event(
            normalPubkey,
            34236, // NIP-71 short-form video
            [
              ['d', 'video-identifier-2'],
              ['url', 'https://example.com/video2.mp4'],
              ['m', 'video/mp4'],
            ],
            'Test video from normal user',
          );

          // Process the event through the search handler
          videoEventService.handleEventForTesting(
            normalUserEvent,
            SubscriptionType.search,
          );

          // Verify the non-blocked user's video IS in search results
          final searchResults = videoEventService.searchResults;
          expect(
            searchResults.any((v) => v.pubkey == normalPubkey),
            isTrue,
            reason: 'Non-blocked user videos should appear in search results',
          );
        },
      );
    });
  });
}
