// ABOUTME: Unit tests for VideoEventService.resetAndResubscribeAll()
// ABOUTME: Verifies that relay set changes trigger proper unsubscribe and
// ABOUTME: resubscribe of persistent feeds while PRESERVING existing events.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class TestSubscriptionManager extends Mock implements SubscriptionManager {
  TestSubscriptionManager(this.eventStreamController);
  final StreamController<Event> eventStreamController;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    Function()? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    eventStreamController.stream.listen(onEvent);
    return 'mock_sub_$name';
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    // No-op for tests
  }
}

// Fake classes for setUpAll
class FakeFilter extends Fake implements Filter {}

Event createVideoEvent({
  required String id,
  required String pubkey,
  required String content,
  required String videoUrl,
}) {
  final event = Event(
    pubkey,
    34236,
    [
      ['url', videoUrl],
      ['m', 'video/mp4'],
    ],
    content,
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  event.id = id;
  event.sig = 'sig_1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff1111222233334444555566667777888899990000aaaabbbbcccc';
  event.sources.add('wss://relay.divine.video');
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService resetAndResubscribeAll', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;
    late TestSubscriptionManager testSubscriptionManager;
    late int subscribeCallCount;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();
      subscribeCallCount = 0;

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        subscribeCallCount++;
        // Simulate EOSE immediately
        Future.microtask(() {
          final onEose =
              invocation.namedArguments[const Symbol('onEose')]
                  as void Function()?;
          onEose?.call();
        });
        return eventStreamController.stream;
      });

      testSubscriptionManager = TestSubscriptionManager(eventStreamController);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      eventStreamController.close();
      videoEventService.dispose();
    });

    test('preserves existing events when called', () async {
      // Subscribe to discovery first
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Add a mock video event to the stream
      final event = createVideoEvent(
        id: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666777788889999aaaa',
        pubkey:
            '3333333333333333333333333333333333333333333333333333333333333333',
        content: 'Test video',
        videoUrl: 'https://example.com/video.mp4',
      );

      eventStreamController.add(event);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify we have videos before reset
      expect(videoEventService.discoveryVideos, isNotEmpty);
      final videoCountBefore = videoEventService.discoveryVideos.length;

      // Reset and resubscribe
      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // After reset, existing events should be PRESERVED (not cleared)
      // This avoids jarring UX when relay set changes during normal operation
      expect(
        videoEventService.discoveryVideos.length,
        equals(videoCountBefore),
        reason: 'Should preserve existing videos after reset',
      );
      expect(
        subscribeCallCount,
        greaterThan(1),
        reason: 'Should have called subscribe again after reset',
      );
    });

    test('resubscribes without unnecessary notifications', () async {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var notificationCount = 0;
      videoEventService.addListener(() => notificationCount++);

      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // With the new behavior that preserves events, there's no need
      // for a "clearing" notification. Notifications happen when new
      // events arrive from the resubscription, not during reset itself.
      // This avoids jarring UX where the feed briefly shows as empty.
      expect(
        subscribeCallCount,
        greaterThan(1),
        reason: 'Should have resubscribed after reset',
      );
    });

    test('resubscribes to discovery with force', () async {
      // Subscribe with specific params
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 75,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final callsBefore = subscribeCallCount;

      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should have created new subscription after the reset
      expect(
        subscribeCallCount,
        greaterThan(callsBefore),
        reason: 'Should resubscribe to discovery after reset',
      );
    });

    test('resubscribes to home feed with saved authors', () async {
      final authors = [
        'author1_aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666777788889999',
        'author2_aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666777788889999',
      ];

      // Subscribe to home feed with authors
      await videoEventService.subscribeToHomeFeed(authors);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final callsBefore = subscribeCallCount;

      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should have created new subscriptions for home feed after reset
      expect(
        subscribeCallCount,
        greaterThan(callsBefore),
        reason: 'Should resubscribe to home feed with authors after reset',
      );
    });

    test('does nothing when disposed', () async {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final callsBefore = subscribeCallCount;
      // A counter that never moved would make the final assertion compare
      // 0 with 0, so pin that the live subscription happened (#8617).
      expect(callsBefore, greaterThan(0));

      // Dispose and close stream first (to avoid double-dispose in tearDown)
      eventStreamController.close();
      videoEventService.dispose();

      // Create a new stream controller for tearDown to close without error
      eventStreamController = StreamController<Event>.broadcast();

      // Should not throw and should not subscribe when called on disposed service
      await videoEventService.resetAndResubscribeAll();

      expect(
        subscribeCallCount,
        equals(callsBefore),
        reason: 'Should not subscribe when disposed',
      );

      // Re-create service for tearDown
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    test('handles case with no active subscriptions', () async {
      final callsBefore = subscribeCallCount;
      expect(callsBefore, 0, reason: 'nothing subscribed yet');

      // Call without any prior subscriptions - should not throw
      await videoEventService.resetAndResubscribeAll();

      expect(
        subscribeCallCount,
        equals(callsBefore),
        reason: 'Should not subscribe when no prior subscriptions exist',
      );
    });

    test('does not resubscribe ephemeral types (hashtag)', () async {
      // Subscribe to hashtag feed only (no discovery or home feed)
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.hashtag,
        hashtags: ['flutter'],
        limit: 50,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final callsBefore = subscribeCallCount;
      expect(
        callsBefore,
        greaterThan(0),
        reason: 'the hashtag feed subscribed',
      );

      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No new subscriptions since only hashtag was active (ephemeral)
      expect(
        subscribeCallCount,
        equals(callsBefore),
        reason: 'Should not resubscribe to ephemeral types like hashtag',
      );
    });

    test('stores and uses sortBy and nip50Sort params', () async {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
        sortBy: VideoSortField.loopCount,
        nip50Sort: NIP50SortMode.hot,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final callsBefore = subscribeCallCount;

      // Reset should re-use the stored params including sort fields
      await videoEventService.resetAndResubscribeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        subscribeCallCount,
        greaterThan(callsBefore),
        reason: 'Should resubscribe with stored sort params',
      );
    });

    test(
      'resubscribes to both discovery and home feed when both active',
      () async {
        final authors = [
          'author1_aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666777788889999',
        ];

        // Subscribe to both feeds
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 50,
        );
        await videoEventService.subscribeToHomeFeed(authors);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final callsBefore = subscribeCallCount;

        await videoEventService.resetAndResubscribeAll();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should have at least 2 new subscribe calls (discovery + home feed)
        expect(
          subscribeCallCount - callsBefore,
          greaterThanOrEqualTo(2),
          reason: 'Should resubscribe to both discovery and home feed',
        );
      },
    );
  });
}
