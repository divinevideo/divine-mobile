// ABOUTME: Tests for VideoFeedBuilder helper class that encapsulates common feed logic
// ABOUTME: Validates debouncing, streaming return, and state management patterns

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

// Helper to create mock VideoEvent for testing
VideoEvent _createMockVideo({
  required String id,
  DateTime? createdAt,
  int loops = 0,
}) {
  final timestamp = createdAt ?? DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: timestamp,
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    originalLoops: loops,
  );
}

void main() {
  group('VideoFeedBuilder', () {
    late _MockVideoEventService mockService;
    late VideoFeedBuilder builder;

    setUp(() {
      mockService = _MockVideoEventService();
      builder = VideoFeedBuilder(mockService);
    });

    group('buildFeed', () {
      test(
        'should subscribe to video service with provided parameters',
        () async {
          // Arrange
          final config = VideoFeedConfig(
            subscriptionType: SubscriptionType.popularNow,
            subscribe: (service) async => service.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.popularNow,
              limit: 100,
            ),
            getVideos: (service) => [],
            sortVideos: (videos) {
              final sorted = List<VideoEvent>.from(videos);
              sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return sorted;
            },
          );

          when(
            () => mockService.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.popularNow,
              limit: 100,
            ),
          ).thenAnswer((_) async => Future.value());

          // Act
          await builder.buildFeed(config: config);

          // Assert
          verify(
            () => mockService.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.popularNow,
              limit: 100,
            ),
          ).called(1);
        },
      );

      test('should return immediately without waiting for stability', () {
        // Arrange - subscribe adds videos asynchronously but buildFeed
        // should NOT wait for them
        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.popularNow,
          subscribe: (service) async {},
          getVideos: (service) => [],
          sortVideos: (videos) => videos,
        );

        VideoFeedState? state;
        Object? error;

        fakeAsync((async) {
          // Act
          unawaited(
            builder
                .buildFeed(config: config)
                .then(
                  (value) => state = value,
                  onError: (Object e) => error = e,
                ),
          );
          // fakeAsync owns this future: flushMicrotasks drains it without
          // advancing the clock, so a reintroduced stability wait leaves
          // `state` null rather than merely slow.
          async.flushMicrotasks();

          // Assert - resolved with no elapsed time at all
          expect(error, isNull);
          expect(state, isNotNull, reason: 'buildFeed awaited a timer');
          expect(state!.videos, isEmpty);
          expect(state!.isInitialLoad, isTrue);
        });
      });

      test('should set isInitialLoad true when no videos available', () async {
        // Arrange
        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => [],
          sortVideos: (videos) => videos,
        );

        // Act
        final state = await builder.buildFeed(config: config);

        // Assert
        expect(state.videos, isEmpty);
        expect(state.isInitialLoad, isTrue);
      });

      test(
        'should set isInitialLoad false when videos are available',
        () async {
          // Arrange
          final videos = [_createMockVideo(id: 'v1')];
          final config = VideoFeedConfig(
            subscriptionType: SubscriptionType.discovery,
            subscribe: (service) async {},
            getVideos: (service) => videos,
            sortVideos: (videos) => videos,
          );

          // Act
          final state = await builder.buildFeed(config: config);

          // Assert
          expect(state.videos.length, 1);
          expect(state.isInitialLoad, isFalse);
        },
      );

      test('should sort videos using provided comparator', () async {
        // Arrange
        final video1 = _createMockVideo(id: 'v1', createdAt: DateTime(2025));
        final video2 = _createMockVideo(
          id: 'v2',
          createdAt: DateTime(2025, 1, 3),
        );
        final video3 = _createMockVideo(
          id: 'v3',
          createdAt: DateTime(2025, 1, 2),
        );
        final videos = [video1, video2, video3];

        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.popularNow,
          subscribe: (service) async {},
          getVideos: (service) => videos,
          sortVideos: (videos) {
            final sorted = List<VideoEvent>.from(videos);
            sorted.sort(
              (a, b) => b.timestamp.compareTo(a.timestamp),
            ); // Newest first
            return sorted;
          },
        );

        // Act
        final state = await builder.buildFeed(config: config);

        // Assert
        expect(state.videos.length, 3);
        expect(state.videos[0].id, 'v2'); // Newest
        expect(state.videos[1].id, 'v3'); // Middle
        expect(state.videos[2].id, 'v1'); // Oldest
      });

      test('should return empty state when no videos available', () async {
        // Arrange
        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => [],
          sortVideos: (videos) => videos,
        );

        // Act
        final state = await builder.buildFeed(config: config);

        // Assert
        expect(state.videos, isEmpty);
        expect(state.hasMoreContent, false);
        expect(state.isLoadingMore, false);
      });

      test('should set hasMoreContent true when videos >= 10', () async {
        // Arrange
        final videos = List.generate(15, (i) => _createMockVideo(id: 'v$i'));
        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => videos,
          sortVideos: (videos) => videos,
        );

        // Act
        final state = await builder.buildFeed(config: config);

        // Assert
        expect(state.videos.length, 15);
        expect(state.hasMoreContent, true);
      });
    });

    group('setupContinuousListener', () {
      test('should set up continuous listener on service', () {
        // Arrange
        var onUpdateCallCount = 0;

        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => [],
          sortVideos: (videos) => videos,
        );

        // Act
        builder.setupContinuousListener(
          config: config,
          onUpdate: (state) {
            onUpdateCallCount++;
          },
        );

        // Assert
        expect(onUpdateCallCount, isZero);

        // Verify that a listener was added to the service
        verify(() => mockService.addListener(any())).called(1);
      });

      test('should track last known video count', () {
        // Arrange
        final videos = [_createMockVideo(id: 'v1')];

        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => videos,
          sortVideos: (videos) => videos,
        );

        // Act
        builder.setupContinuousListener(config: config, onUpdate: (state) {});

        // Assert
        // Verify that the initial count was captured
        // (This is checked internally by the builder but we can't directly
        // test private fields)
        verify(() => mockService.addListener(any())).called(1);
      });
    });

    group('cleanup', () {
      test('should remove listener and cancel timers', () {
        // Arrange
        final config = VideoFeedConfig(
          subscriptionType: SubscriptionType.discovery,
          subscribe: (service) async {},
          getVideos: (service) => [],
          sortVideos: (videos) => videos,
        );

        builder.setupContinuousListener(config: config, onUpdate: (state) {});

        // Act
        builder.cleanup();

        // Assert
        verify(
          () => mockService.removeListener(any()),
        ).called(greaterThanOrEqualTo(1));
      });
    });
  });
}
