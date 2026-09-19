// ABOUTME: Tests for SubscribedListVideoCache service
// ABOUTME: Verifies caching of videos from subscribed curated lists

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/video_event_service.dart';

import '../builders/test_video_event_builder.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockCuratedListService extends Mock implements CuratedListService {}

void main() {
  late SubscribedListVideoCache cache;
  late _MockNostrClient mockNostrService;
  late _MockVideoEventService mockVideoEventService;
  late _MockCuratedListService mockCuratedListService;

  setUpAll(() {
    registerFallbackValue(<dynamic>[]);
  });

  setUp(() {
    mockNostrService = _MockNostrClient();
    mockVideoEventService = _MockVideoEventService();
    mockCuratedListService = _MockCuratedListService();

    // Setup default mock behaviors
    when(() => mockNostrService.isInitialized).thenReturn(true);
    when(() => mockCuratedListService.subscribedListIds).thenReturn({});
    when(() => mockCuratedListService.subscribedLists).thenReturn([]);

    // Setup VideoEventService cache getters
    when(() => mockVideoEventService.discoveryVideos).thenReturn([]);
    when(() => mockVideoEventService.homeFeedVideos).thenReturn([]);
    when(() => mockVideoEventService.profileVideos).thenReturn([]);

    cache = SubscribedListVideoCache(
      nostrService: mockNostrService,
      videoEventService: mockVideoEventService,
      curatedListService: mockCuratedListService,
    );
  });

  tearDown(() {
    cache.dispose();
  });

  group('SubscribedListVideoCache', () {
    group('getVideos', () {
      test('returns empty list when no videos are cached', () {
        final videos = cache.getVideos();
        expect(videos, isEmpty);
      });

      test('returns all cached videos', () async {
        // Use valid 64-char hex IDs for tests
        const video1Id =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const video2Id =
            '2222222222222222222222222222222222222222222222222222222222222222';

        // Setup: Create test videos with valid hex IDs
        final video1 = TestVideoEventBuilder.create(
          id: video1Id,
          pubkey: 'author1',
          title: 'Video 1',
        );
        final video2 = TestVideoEventBuilder.create(
          id: video2Id,
          pubkey: 'author2',
          title: 'Video 2',
        );

        // Mock VideoEventService to return videos from cache
        when(
          () => mockVideoEventService.getVideoById(video1Id),
        ).thenReturn(video1);
        when(
          () => mockVideoEventService.getVideoById(video2Id),
        ).thenReturn(video2);

        // Mock Nostr service to not need relay fetch (all cached)
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        // Sync list with these video IDs
        await cache.syncList('list1', [video1Id, video2Id]);

        final videos = cache.getVideos();
        expect(videos.length, 2);
        expect(videos.any((v) => v.id == video1Id), isTrue);
        expect(videos.any((v) => v.id == video2Id), isTrue);
      });
    });

    group('getListsForVideo', () {
      test('returns empty set for unknown video', () {
        final lists = cache.getListsForVideo('unknown_video');
        expect(lists, isEmpty);
      });

      test('returns list IDs that contain the video', () async {
        const video1Id =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        final video1 = TestVideoEventBuilder.create(
          id: video1Id,
          pubkey: 'author1',
        );

        when(
          () => mockVideoEventService.getVideoById(video1Id),
        ).thenReturn(video1);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        // Add video to two different lists
        await cache.syncList('list1', [video1Id]);
        await cache.syncList('list2', [video1Id]);

        final lists = cache.getListsForVideo(video1Id);
        expect(lists.length, 2);
        expect(lists.contains('list1'), isTrue);
        expect(lists.contains('list2'), isTrue);
      });
    });

    group('syncList', () {
      test(
        'checks VideoEventService cache first before fetching from relays',
        () async {
          const cachedVideoId =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

          final cachedVideo = TestVideoEventBuilder.create(
            id: cachedVideoId,
            pubkey: 'author1',
          );

          // Video is in cache
          when(
            () => mockVideoEventService.getVideoById(cachedVideoId),
          ).thenReturn(cachedVideo);

          // Subscribe should still be called but for empty list
          when(
            () => mockNostrService.subscribe(any(), closeOnEose: true),
          ).thenAnswer((_) => const Stream<Event>.empty());

          await cache.syncList('list1', [cachedVideoId]);

          // Verify cache was checked
          verify(
            () => mockVideoEventService.getVideoById(cachedVideoId),
          ).called(1);

          // Video should be in cache
          final videos = cache.getVideos();
          expect(videos.length, 1);
          expect(videos.first.id, cachedVideo.id);
        },
      );

      test('fetches missing videos from relays', () async {
        const missingVideoId =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

        // Video not in cache
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);

        // Use valid 64-char hex pubkey for Nostr event
        const validPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

        // Create a mock Nostr event using positional args (pubkey, kind, tags, content)
        final mockEvent = Event(
          validPubkey, // pubkey (must be 64-char hex)
          34236, // kind
          [
            ['url', 'https://example.com/video.mp4'],
            ['title', 'Test Video'],
            ['d', 'test-d-tag'],
          ], // tags
          'Test content', // content
        );

        // Setup stream to emit the event
        final controller = StreamController<Event>();
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) {
          // A single-subscription controller buffers these events until the
          // cache subscribes, so no timer ownership is needed.
          controller.add(mockEvent);
          unawaited(controller.close());
          return controller.stream;
        });

        await cache.syncList('list1', [missingVideoId]);

        // Verify subscribe was called
        verify(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).called(1);
      });

      test('a refused relay read does not escape syncList', () async {
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer(
          (_) => Stream<Event>.error(
            const RelaySubscriptionRefusedException(
              'error: too many subscriptions',
            ),
          ),
        );

        const missingVideoId =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

        // syncAllSubscribedLists runs from an unawaited microtask, so an
        // escaping error would land in the zone as an uncaught async error.
        await expectLater(
          cache.syncList('list1', [missingVideoId]),
          completes,
        );
      });

      test('separates event IDs from addressable coordinates', () async {
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        const eventId =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        const addressableCoord = '34236:pubkey123:d-tag-value';

        await cache.syncList('list1', [eventId, addressableCoord]);

        // Verify subscribe was called - should handle both types
        verify(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).called(1);
      });

      test('notifies listeners after sync', () async {
        const videoId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

        final video = TestVideoEventBuilder.create(
          id: videoId,
          pubkey: 'author1',
        );

        when(
          () => mockVideoEventService.getVideoById(videoId),
        ).thenReturn(video);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        var notified = false;
        cache.addListener(() {
          notified = true;
        });

        await cache.syncList('list1', [videoId]);

        expect(notified, isTrue);
      });
    });

    group('syncAllSubscribedLists', () {
      test('syncs all subscribed lists from CuratedListService', () async {
        const video1Id =
            'f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1';
        const video2Id =
            'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2';

        // Setup subscribed lists
        final list1 = CuratedList(
          id: 'list1',
          name: 'List 1',
          videoEventIds: const [video1Id],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final list2 = CuratedList(
          id: 'list2',
          name: 'List 2',
          videoEventIds: const [video2Id],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockCuratedListService.subscribedLists,
        ).thenReturn([list1, list2]);

        final video1 = TestVideoEventBuilder.create(id: video1Id);
        final video2 = TestVideoEventBuilder.create(id: video2Id);

        when(
          () => mockVideoEventService.getVideoById(video1Id),
        ).thenReturn(video1);
        when(
          () => mockVideoEventService.getVideoById(video2Id),
        ).thenReturn(video2);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        await cache.syncAllSubscribedLists();

        // Should have both videos
        final videos = cache.getVideos();
        expect(videos.length, 2);
      });
    });

    group('removeList', () {
      test('removes list from cache on unsubscribe', () async {
        const video1Id =
            'abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd';
        const video2Id =
            'dcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcbadcba';

        final video1 = TestVideoEventBuilder.create(
          id: video1Id,
          pubkey: 'author1',
        );
        final video2 = TestVideoEventBuilder.create(
          id: video2Id,
          pubkey: 'author2',
        );

        when(
          () => mockVideoEventService.getVideoById(video1Id),
        ).thenReturn(video1);
        when(
          () => mockVideoEventService.getVideoById(video2Id),
        ).thenReturn(video2);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        // Sync two lists
        await cache.syncList('list1', [video1Id]);
        await cache.syncList('list2', [video2Id]);

        expect(cache.getVideos().length, 2);

        // Remove list1
        cache.removeList('list1');

        // video1 should no longer be associated with list1
        expect(cache.getListsForVideo(video1Id), isEmpty);

        // video1 should be removed from cache since it's only in list1
        final remainingVideos = cache.getVideos();
        expect(remainingVideos.length, 1);
        expect(remainingVideos.first.id, video2Id);
      });

      test(
        'keeps video if it exists in other lists after removing one list',
        () async {
          const videoId =
              'ababababababababababababababababababababababababababababababab00';

          final video1 = TestVideoEventBuilder.create(
            id: videoId,
            pubkey: 'author1',
          );

          when(
            () => mockVideoEventService.getVideoById(videoId),
          ).thenReturn(video1);
          when(
            () => mockNostrService.subscribe(any(), closeOnEose: true),
          ).thenAnswer((_) => const Stream<Event>.empty());

          // Add video1 to both lists
          await cache.syncList('list1', [videoId]);
          await cache.syncList('list2', [videoId]);

          expect(cache.getListsForVideo(videoId).length, 2);

          // Remove list1
          cache.removeList('list1');

          // video1 should still be in cache (associated with list2)
          expect(cache.getListsForVideo(videoId).length, 1);
          expect(cache.getListsForVideo(videoId).contains('list2'), isTrue);
          expect(cache.getVideos().length, 1);
        },
      );

      test('notifies listeners after removeList', () async {
        const videoId =
            'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';

        final video = TestVideoEventBuilder.create(id: videoId);
        when(
          () => mockVideoEventService.getVideoById(videoId),
        ).thenReturn(video);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        await cache.syncList('list1', [videoId]);

        var notified = false;
        cache.addListener(() {
          notified = true;
        });

        cache.removeList('list1');

        expect(notified, isTrue);
      });
    });

    group('deduplication', () {
      test('same video in multiple lists is only stored once', () async {
        const sharedVideoId =
            'dededededededededededededededededededededededededededededededede';

        final video1 = TestVideoEventBuilder.create(
          id: sharedVideoId,
          pubkey: 'author1',
        );

        when(
          () => mockVideoEventService.getVideoById(sharedVideoId),
        ).thenReturn(video1);
        when(
          () => mockNostrService.subscribe(any(), closeOnEose: true),
        ).thenAnswer((_) => const Stream<Event>.empty());

        // Add same video to three lists
        await cache.syncList('list1', [sharedVideoId]);
        await cache.syncList('list2', [sharedVideoId]);
        await cache.syncList('list3', [sharedVideoId]);

        // Should only have one video
        final videos = cache.getVideos();
        expect(videos.length, 1);
        expect(videos.first.id, sharedVideoId);

        // But video should be associated with all three lists
        final lists = cache.getListsForVideo(sharedVideoId);
        expect(lists.length, 3);
        expect(lists.containsAll(['list1', 'list2', 'list3']), isTrue);
      });
    });
  });
}
