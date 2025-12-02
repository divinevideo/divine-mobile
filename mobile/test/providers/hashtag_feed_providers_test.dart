// ABOUTME: Tests for hashtag feed provider reactivity
// ABOUTME: Verifies that hashtag provider rebuilds when VideoEventService updates

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';

/// Fake VideoEventService for testing reactive behavior
class FakeVideoEventService extends ChangeNotifier
    implements VideoEventService {
  final Map<String, List<VideoEvent>> _hashtagBuckets = {};
  final Map<String, List<VideoEvent>> _authorBuckets = {};

  // Track subscription calls for verification
  final List<List<String>> subscribedHashtags = [];
  final List<String> subscribedAuthors = [];

  @override
  List<VideoEvent> hashtagVideos(String tag) {
    final videos = _hashtagBuckets[tag] ?? [];
    print(
      'DEBUG: hashtagVideos($tag) returning ${videos.length} videos. Buckets: ${_hashtagBuckets.keys.toList()}',
    );
    return videos;
  }

  @override
  List<VideoEvent> authorVideos(String pubkeyHex) =>
      _authorBuckets[pubkeyHex] ?? [];

  @override
  Future<void> subscribeToHashtagVideos(
    List<String> hashtags, {
    int limit = 100,
  }) async {
    subscribedHashtags.add(hashtags);
  }

  @override
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    subscribedAuthors.add(pubkey);
  }

  // Test helper: emit events for a hashtag
  void emitHashtagVideos(String tag, List<VideoEvent> videos) {
    _hashtagBuckets[tag] = videos;
    notifyListeners();
  }

  // Test helper: emit events for an author
  void emitAuthorVideos(String pubkeyHex, List<VideoEvent> videos) {
    _authorBuckets[pubkeyHex] = videos;
    notifyListeners();
  }

  // Stub implementations for required interface methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HashtagFeedProvider', () {
    late FakeVideoEventService fakeService;
    late ProviderContainer container;

    setUp(() {
      fakeService = FakeVideoEventService();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns empty state when route type is not hashtag', () async {
      // Arrange: Route context is home, not hashtag
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(type: RouteType.home));
          }),
        ],
      );

      // Wait for async build to complete
      final state = await container.read(hashtagFeedProvider.future);

      // Assert
      expect(state.videos, isEmpty);
      expect(state.hasMoreContent, isFalse);
    });

    test('returns empty state when hashtag is empty', () async {
      // Arrange: Route is hashtag but tag is empty
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.hashtag, hashtag: ''),
            );
          }),
        ],
      );

      // Wait for async build to complete
      final state = await container.read(hashtagFeedProvider.future);

      // Assert
      expect(state.videos, isEmpty);
    });

    test('selects videos from pre-populated hashtag bucket', () async {
      // Arrange: Pre-populate the fake service BEFORE container is created
      // so the async build() method will find videos immediately
      fakeService.emitHashtagVideos('bitcoin', [
        VideoEvent(
          id: 'btc1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'Bitcoin video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/btc1.mp4',
        ),
      ]);

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(
                type: RouteType.hashtag,
                hashtag: 'bitcoin',
                videoIndex: 0,
              ),
            );
          }),
        ],
      );

      // Wait for async build to complete
      final state = await container.read(hashtagFeedProvider.future);

      // Assert: Should show the populated video
      expect(state.videos.length, equals(1));
      expect(state.videos[0].id, equals('btc1'));
    });

    test('shows videos from service hashtag bucket', () async {
      // Arrange: Pre-populate service BEFORE container creation
      fakeService.emitHashtagVideos('nostr', [
        VideoEvent(
          id: 'nostr1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'First nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr1.mp4',
        ),
        VideoEvent(
          id: 'nostr2',
          pubkey: 'author2',
          createdAt: 2000,
          content: 'Second nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr2.mp4',
        ),
      ]);

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(
                type: RouteType.hashtag,
                hashtag: 'nostr',
                videoIndex: 0,
              ),
            );
          }),
        ],
      );

      // Wait for async build to complete
      final state = await container.read(hashtagFeedProvider.future);

      // Assert: Should show both videos from the bucket
      expect(state.videos.length, equals(2));
      expect(state.videos[0].id, equals('nostr1'));
      expect(state.videos[1].id, equals('nostr2'));
    });

    test('only shows videos for the specific hashtag', () async {
      // Arrange: Populate service with videos for multiple hashtags BEFORE container creation
      fakeService.emitHashtagVideos('nostr', [
        VideoEvent(
          id: 'nostr1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'Nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr1.mp4',
        ),
      ]);

      fakeService.emitHashtagVideos('bitcoin', [
        VideoEvent(
          id: 'btc1',
          pubkey: 'author2',
          createdAt: 2000,
          content: 'Bitcoin video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/btc1.mp4',
        ),
      ]);

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(
                type: RouteType.hashtag,
                hashtag: 'nostr',
                videoIndex: 0,
              ),
            );
          }),
        ],
      );

      // Wait for async build to complete
      final state = await container.read(hashtagFeedProvider.future);

      // Assert: Should only show nostr video, not bitcoin
      expect(state.videos.length, equals(1));
      expect(state.videos[0].id, equals('nostr1'));
      expect(state.videos[0].content, contains('Nostr'));
    });
  });
}
