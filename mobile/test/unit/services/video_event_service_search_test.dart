// ABOUTME: Unit tests for VideoEventService NIP-50 search functionality
// ABOUTME: Tests search capabilities including text queries, filters, and result processing

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import 'video_event_service_search_test.mocks.dart';

@GenerateNiceMocks([MockSpec<NostrClient>(), MockSpec<SubscriptionManager>()])
void main() {
  group('VideoEventService Search Tests', () {
    late VideoEventService videoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup basic mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test_pubkey');

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      videoEventService.dispose();
      reset(mockNostrService);
      reset(mockSubscriptionManager);
    });

    group('Search Method Tests', () {
      test('should call searchVideos and handle empty query', () {
        final searchQuery = '';

        expect(
          () => videoEventService.searchVideos(searchQuery),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should call searchVideosByHashtag with valid hashtag', () async {
        // Mock the nostr service to return an empty stream
        when(
          mockNostrService.searchVideos(
            any,
            authors: anyNamed('authors'),
            since: anyNamed('since'),
            until: anyNamed('until'),
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) => Stream<Event>.empty());

        final hashtag = '#bitcoin';

        // Should not throw and should complete successfully
        await videoEventService.searchVideosByHashtag(hashtag);

        // Verify the service was called with the correct search query
        verify(
          mockNostrService.searchVideos(
            '#bitcoin',
            authors: anyNamed('authors'),
            since: anyNamed('since'),
            until: anyNamed('until'),
            limit: anyNamed('limit'),
          ),
        ).called(1);
      });

      test(
        'should call searchVideosWithFilters with correct parameters',
        () async {
          // Mock the nostr service to return an empty stream
          when(
            mockNostrService.searchVideos(
              any,
              authors: anyNamed('authors'),
              since: anyNamed('since'),
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).thenAnswer((_) => Stream<Event>.empty());

          final searchQuery = 'nostr';
          final authors = ['author1', 'author2'];

          await videoEventService.searchVideosWithFilters(
            query: searchQuery,
            authors: authors,
          );

          // Verify the service was called with correct parameters
          verify(
            mockNostrService.searchVideos(
              searchQuery,
              authors: authors,
              since: anyNamed('since'),
              until: anyNamed('until'),
              limit: anyNamed('limit'),
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
            mockNostrService.searchVideos(
              any,
              authors: anyNamed('authors'),
              since: anyNamed('since'),
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).thenAnswer((_) => Stream<Event>.empty());

          final searchQuery = 'bitcoin';
          final since = DateTime.now().subtract(Duration(days: 7));
          final until = DateTime.now();

          await videoEventService.searchVideosWithTimeRange(
            query: searchQuery,
            since: since,
            until: until,
          );

          // Verify the underlying search was called with time parameters
          verify(
            mockNostrService.searchVideos(
              searchQuery,
              authors: anyNamed('authors'),
              since: since,
              until: until,
              limit: anyNamed('limit'),
            ),
          ).called(1);
        },
      );

      test(
        'should call searchVideosWithExtensions with query extensions',
        () async {
          // Mock the nostr service to return an empty stream
          when(
            mockNostrService.searchVideos(
              any,
              authors: anyNamed('authors'),
              since: anyNamed('since'),
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).thenAnswer((_) => Stream<Event>.empty());

          final searchQuery = 'music language:en nsfw:false';

          await videoEventService.searchVideosWithExtensions(searchQuery);

          // Verify the search was called with the extensions query
          verify(
            mockNostrService.searchVideos(
              searchQuery,
              authors: anyNamed('authors'),
              since: anyNamed('since'),
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).called(1);
        },
      );
    });
  });
}
