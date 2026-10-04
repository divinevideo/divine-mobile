// ABOUTME: Tests for video pagination and relay loading in VideoEventService
// ABOUTME: Verifies that the service properly loads videos from relays when scrolling

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Pagination', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();

      // Setup basic mock responses
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      videoEventService.dispose();
    });

    Future<void> queryCompleted() {
      final completed = Completer<void>();
      void listener() {
        final state = videoEventService
            .getPaginationStatesForTesting()[SubscriptionType.discovery]!;
        if (!state.isLoading && !completed.isCompleted) {
          completed.complete();
        }
      }

      videoEventService.addListener(listener);
      addTearDown(() => videoEventService.removeListener(listener));
      // Liveness bound: fail fast instead of waiting out the 10-minute default.
      return completed.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'the discovery query never finished loading',
        ),
      );
    }

    test(
      'should reset pagination when hasMore is false but few videos exist',
      () async {
        // Arrange - simulate a state where pagination thinks there's no more content
        // First, set up initial state with some videos
        videoEventService.resetPaginationState(SubscriptionType.discovery);

        // Create a stream controller
        final streamController = StreamController<Event>.broadcast();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => streamController.stream);

        // Act - First load should work
        final firstCompleted = queryCompleted();
        final firstLoad = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 10,
        );

        // Emit fewer events than requested to trigger hasMore = false
        streamController.add(
          _createTestVideoEvent(
            'test1',
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        await streamController.close();

        await firstLoad;
        await firstCompleted;
        expect(videoEventService.discoveryVideos, hasLength(1));

        // Now try to load more - it should reset and allow loading
        final secondController = StreamController<Event>.broadcast();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => secondController.stream);

        final secondCompleted = queryCompleted();
        final secondLoad = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        await secondController.close();
        await secondLoad;
        await secondCompleted;

        // Assert - should have made two subscription calls
        verify(() => mockNostrService.subscribe(any())).called(2);
      },
    );

    test('should handle empty responses from relay gracefully', () async {
      // Arrange
      final streamController = StreamController<Event>.broadcast();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => streamController.stream);

      // Act
      final completed = queryCompleted();
      final loadMoreFuture = videoEventService.loadMoreEvents(
        SubscriptionType.discovery,
        limit: 50,
      );

      // Close stream immediately without emitting events
      await streamController.close();

      // Should complete without error
      await expectLater(loadMoreFuture, completes);
      await completed;
      expect(videoEventService.discoveryVideos, isEmpty);
    });
  });
}

// Helper function to create test video events
Event _createTestVideoEvent(String id, int timestamp) {
  // Event constructor: Event(pubkey, kind, tags, content, {createdAt})
  return Event(
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // 64-char hex pubkey
    34236, // kind
    [
      ['d', 'video_$id'],
      ['url', 'https://example.com/video_$id.mp4'],
      ['thumb', 'https://example.com/thumb_$id.jpg'],
    ], // tags
    'Test video $id', // content
    createdAt: timestamp,
  );
}
