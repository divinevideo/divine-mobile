// ABOUTME: Tests for VideoFeedBuilder streaming behavior (Change 2 of EOSE fix)
// ABOUTME: Validates buildFeed returns immediately and progressive updates work

import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

VideoEvent _createMockVideo({required String id, DateTime? createdAt}) {
  final timestamp = createdAt ?? DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: timestamp,
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
  );
}

void main() {
  group('VideoFeedBuilder streaming', () {
    late _MockVideoEventService mockService;
    late VideoFeedBuilder builder;

    setUp(() {
      mockService = _MockVideoEventService();
      builder = VideoFeedBuilder(mockService);
    });

    test('buildFeed returns immediately with available videos', () {
      final videos = [_createMockVideo(id: 'v1'), _createMockVideo(id: 'v2')];
      final config = VideoFeedConfig(
        subscriptionType: SubscriptionType.discovery,
        subscribe: (service) async {},
        getVideos: (service) => videos,
        sortVideos: (videos) => videos,
      );

      VideoFeedState? state;

      fakeAsync((async) {
        // fakeAsync owns completion; flushMicrotasks below runs this callback.
        unawaited(
          builder.buildFeed(config: config).then((value) => state = value),
        );
        // Drains microtasks without advancing the clock, so a reintroduced
        // stability wait leaves `state` null rather than merely slow.
        async.flushMicrotasks();

        expect(state, isNotNull, reason: 'buildFeed awaited a timer');
        expect(state!.videos.length, 2);
        expect(state!.isInitialLoad, isFalse);
      });
    });

    test('buildFeed returns isInitialLoad state when no videos yet', () async {
      final config = VideoFeedConfig(
        subscriptionType: SubscriptionType.discovery,
        subscribe: (service) async {},
        getVideos: (service) => <VideoEvent>[],
        sortVideos: (videos) => videos,
      );

      final state = await builder.buildFeed(config: config);

      expect(state.videos, isEmpty);
      expect(state.isInitialLoad, isTrue);
      expect(state.hasMoreContent, isFalse);
    });

    test('buildFeed returns even when subscribe never completes', () async {
      final subscribeCompleter = Completer<void>();
      addTearDown(() {
        if (!subscribeCompleter.isCompleted) {
          subscribeCompleter.complete();
        }
      });

      final config = VideoFeedConfig(
        subscriptionType: SubscriptionType.discovery,
        subscribe: (service) => subscribeCompleter.future,
        getVideos: (service) => <VideoEvent>[],
        sortVideos: (videos) => videos,
      );

      final state = await builder
          .buildFeed(config: config)
          .timeout(const Duration(milliseconds: 100));

      expect(state.videos, isEmpty);
      expect(state.isInitialLoad, isTrue);
    });

    test('continuous listener updates state as videos arrive', () async {
      final videos = <VideoEvent>[];
      final stateUpdates = <int>[];
      VoidCallback? capturedListener;

      when(() => mockService.addListener(any())).thenAnswer((invocation) {
        capturedListener = invocation.positionalArguments[0] as VoidCallback;
      });

      final config = VideoFeedConfig(
        subscriptionType: SubscriptionType.discovery,
        subscribe: (service) async {},
        getVideos: (service) => videos,
        sortVideos: (videos) => videos,
      );

      builder.setupContinuousListener(
        config: config,
        onUpdate: (state) {
          stateUpdates.add(state.videos.length);
        },
      );

      // Simulate videos arriving progressively
      videos.add(_createMockVideo(id: 'v1'));
      capturedListener?.call();

      // Wait for debounce (500ms)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(stateUpdates, contains(1));

      // More videos arrive
      videos.add(_createMockVideo(id: 'v2'));
      capturedListener?.call();

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(stateUpdates, contains(2));
    });
  });
}
