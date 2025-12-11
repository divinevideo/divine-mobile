// ABOUTME: Tests for profile feed provider reactivity
// ABOUTME: Verifies that profile provider rebuilds when VideoEventService updates

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/services/video_prewarmer.dart';

/// Fake VideoEventService for testing reactive behavior
class FakeVideoEventService extends ChangeNotifier
    implements VideoEventService {
  final Map<String, List<VideoEvent>> _hashtagBuckets = {};
  final Map<String, List<VideoEvent>> _authorBuckets = {};

  // Track subscription calls for verification
  final List<List<String>> subscribedHashtags = [];
  final List<String> subscribedAuthors = [];

  @override
  List<VideoEvent> hashtagVideos(String tag) => _hashtagBuckets[tag] ?? [];

  @override
  List<VideoEvent> authorVideos(String pubkeyHex) {
    final videos = _authorBuckets[pubkeyHex] ?? [];
    print(
      'DEBUG: authorVideos($pubkeyHex) returning ${videos.length} videos. Buckets: ${_authorBuckets.keys.toList()}',
    );
    return videos;
  }

  @override
  Future<void> subscribeToHashtagVideos(
    List<String> hashtags, {
    int limit = 100,
    bool force = false,
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
  group('ProfileFeedProvider', () {
    late FakeVideoEventService fakeService;
    late ProviderContainer container;

    // Real Nostr user from staging-relay.divine.video - @BJFrankowski
    const testHex =
        '1363966ad89a17df0711e270658153c2dbe5e163e06cdd6f9dba36b616846ee0';
    late String testNpub;

    setUp(() {
      fakeService = FakeVideoEventService();
      testNpub = NostrKeyUtils.encodePubKey(testHex);
    });

    tearDown(() {
      container.dispose();
    });

    test('returns empty state when route type is not profile', () {
      // Arrange: Route context is home, not profile
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(type: RouteType.home));
          }),
        ],
      );

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Assert
      expect(result.hasValue, isTrue);
      expect(result.value!.videos, isEmpty);
      expect(result.value!.hasMoreContent, isFalse);
    });

    test('returns empty state when npub is empty', () {
      // Arrange: Route is profile but npub is empty
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.profile, npub: ''),
            );
          }),
        ],
      );

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Assert
      expect(result.hasValue, isTrue);
      expect(result.value!.videos, isEmpty);
    });

    test('returns empty state when npub is invalid', () {
      // Arrange: Route has invalid npub
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.profile, npub: 'invalid-npub'),
            );
          }),
        ],
      );

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Assert
      expect(result.hasValue, isTrue);
      expect(result.value!.videos, isEmpty);
    });

    test('selects videos from pre-populated author bucket', () async {
      // Arrange: Create container first
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/profile/$testNpub/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForProfileRouteProvider,
        (_, __) {},
      );

      // Populate service AFTER listener is established
      fakeService.emitAuthorVideos(testHex, [
        VideoEvent(
          id: 'video1',
          pubkey: testHex,
          createdAt: 1000,
          content: 'Author video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video1.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act: Read provider (selects from populated bucket)
      final result = container.read(videosForProfileRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should show the populated video
      expect(result.hasValue, isTrue);
      expect(result.value!.videos.length, equals(1));
      expect(result.value!.videos[0].id, equals('video1'));
      expect(result.value!.videos[0].pubkey, equals(testHex));
    });

    test('shows videos from service author bucket', () async {
      // Arrange: Create container first
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/profile/$testNpub/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForProfileRouteProvider,
        (_, __) {},
      );

      // Populate service AFTER listener is established
      fakeService.emitAuthorVideos(testHex, [
        VideoEvent(
          id: 'video1',
          pubkey: testHex,
          createdAt: 1000,
          content: 'First video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video1.mp4',
        ),
        VideoEvent(
          id: 'video2',
          pubkey: testHex,
          createdAt: 2000,
          content: 'Second video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video2.mp4',
        ),
        VideoEvent(
          id: 'video3',
          pubkey: testHex,
          createdAt: 3000,
          content: 'Third video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video3.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should show all videos from the author bucket
      expect(result.hasValue, isTrue);
      expect(result.value!.videos.length, equals(3));
      expect(result.value!.videos[0].id, equals('video1'));
      expect(result.value!.videos[1].id, equals('video2'));
      expect(result.value!.videos[2].id, equals('video3'));
    });

    test('only shows videos for the specific author', () async {
      // Arrange: Create container first
      // Route is /profile/:testNpub
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/profile/$testNpub/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForProfileRouteProvider,
        (_, __) {},
      );

      // Populate service with multiple authors AFTER listener is established
      const otherHex = 'other_author_hex_1234567890abcdef';

      fakeService.emitAuthorVideos(testHex, [
        VideoEvent(
          id: 'target_video',
          pubkey: testHex,
          createdAt: 1000,
          content: 'Target author video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/target.mp4',
        ),
      ]);

      fakeService.emitAuthorVideos(otherHex, [
        VideoEvent(
          id: 'other_video',
          pubkey: otherHex,
          createdAt: 2000,
          content: 'Other author video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/other.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should only show target author's video
      expect(result.value!.videos.length, equals(1));
      expect(result.value!.videos[0].id, equals('target_video'));
      expect(result.value!.videos[0].pubkey, equals(testHex));
    });

    test('queries author bucket with hex key (npub converted)', () async {
      // Arrange: Create container first
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              RouteContext(
                type: RouteType.profile,
                npub: testNpub, // Provider receives npub
              ),
            );
          }),
        ],
      );

      // Wait for streams to emit
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForProfileRouteProvider,
        (_, __) {},
      );

      // Populate service AFTER listener is established
      fakeService.emitAuthorVideos(testHex, [
        VideoEvent(
          id: 'video1',
          pubkey: testHex,
          createdAt: 1000,
          content: 'Test',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video1.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act
      final result = container.read(videosForProfileRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should query bucket with hex key (npub was converted)
      expect(result.value!.videos.length, equals(1));
      expect(result.value!.videos[0].pubkey, equals(testHex));
    });
  });
}
