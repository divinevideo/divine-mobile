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
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:unified_logger/unified_logger.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

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
    late int subscribeCallCount;
    late List<List<Filter>> subscribedFilters;
    late _MockRelayCapabilityService mockRelayCapabilityService;

    setUp(() {
      mockNostrService = MockNostrService();
      mockRelayCapabilityService = _MockRelayCapabilityService();
      eventStreamController = StreamController<Event>.broadcast();
      subscribeCallCount = 0;
      subscribedFilters = [];

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        subscribeCallCount++;
        subscribedFilters.add(
          invocation.positionalArguments.first as List<Filter>,
        );
        // Simulate EOSE immediately
        unawaited(
          Future.microtask(() {
            final onEose =
                invocation.namedArguments[const Symbol('onEose')]
                    as void Function()?;
            onEose?.call();
          }),
        );
        return eventStreamController.stream;
      });

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
        videoFilterBuilder: VideoFilterBuilder(mockRelayCapabilityService),
      );
    });

    tearDown(() async {
      // Unsubscribe before closing the stream, or the close schedules a
      // reconnection timer that outlives the test.
      await videoEventService.unsubscribeFromVideoFeed();
      await eventStreamController.close();
      videoEventService.dispose();
    });

    test('preserves existing events when called', () async {
      // Subscribe to discovery first
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      // Add a mock video event to the stream
      final event = createVideoEvent(
        id: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666777788889999aaaa',
        pubkey:
            '3333333333333333333333333333333333333333333333333333333333333333',
        content: 'Test video',
        videoUrl: 'https://example.com/video.mp4',
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      // Verify we have videos before reset
      expect(videoEventService.discoveryVideos, isNotEmpty);
      final videoCountBefore = videoEventService.discoveryVideos.length;

      // Reset and resubscribe
      await videoEventService.resetAndResubscribeAll();

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

    test('resubscribes to discovery with force', () async {
      // Subscribe with specific params
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 75,
      );

      final callsBefore = subscribeCallCount;

      await videoEventService.resetAndResubscribeAll();

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

      final callsBefore = subscribeCallCount;

      await videoEventService.resetAndResubscribeAll();

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

      final callsBefore = subscribeCallCount;
      // A counter that never moved would make the final assertion compare
      // 0 with 0, so pin that the live subscription happened (#8617).
      expect(callsBefore, greaterThan(0));

      // Dispose and close stream first (to avoid double-dispose in tearDown).
      // Unsubscribing first keeps the close from scheduling a reconnection.
      await videoEventService.unsubscribeFromVideoFeed();
      await eventStreamController.close();
      videoEventService.dispose();

      // Create a new stream controller for tearDown to close without error
      eventStreamController = StreamController<Event>.broadcast();

      // Should not throw and should not subscribe when called on disposed service
      await LogCaptureService().clearAllLogs();
      await videoEventService.resetAndResubscribeAll();

      expect(
        subscribeCallCount,
        equals(callsBefore),
        reason: 'Should not subscribe when disposed',
      );
      // The count alone stays equal even with the disposed check removed, so
      // pin the return itself: the method logs as its first act after it.
      expect(
        [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ],
        isNot(contains(contains('Relay set changed'))),
        reason: 'a disposed service must return before doing any reset work',
      );

      // Re-create service for tearDown
      videoEventService = VideoEventService(
        mockNostrService,
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

      final callsBefore = subscribeCallCount;
      expect(
        callsBefore,
        greaterThan(0),
        reason: 'the hashtag feed subscribed',
      );

      await videoEventService.resetAndResubscribeAll();

      // No new subscriptions since only hashtag was active (ephemeral)
      expect(
        subscribeCallCount,
        equals(callsBefore),
        reason: 'Should not resubscribe to ephemeral types like hashtag',
      );
    });

    test('resubscribes with the stored NIP-50 sort mode', () async {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
        nip50Sort: NIP50SortMode.hot,
      );
      expect(subscribedFilters.single.first.search, equals('sort:hot'));

      await videoEventService.resetAndResubscribeAll();

      expect(subscribedFilters, hasLength(2));
      expect(subscribedFilters.last.first.search, equals('sort:hot'));
    });

    test('resubscribes with the stored sort field', () async {
      when(() => mockNostrService.connectedRelays).thenReturn(const <String>[]);
      when(
        () => mockRelayCapabilityService.getRelayCapabilities(any()),
      ).thenAnswer(
        (invocation) async => RelayCapabilities(
          relayUrl: invocation.positionalArguments.single as String,
          rawData: const {},
          hasDivineExtensions: true,
          sortFields: [VideoSortField.loopCount.fieldName],
        ),
      );
      final sortSent = {'field': 'loop_count', 'dir': 'desc'};

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
        sortBy: VideoSortField.loopCount,
      );
      expect(subscribedFilters.single.first.toJson()['sort'], equals(sortSent));

      await videoEventService.resetAndResubscribeAll();

      expect(subscribedFilters, hasLength(2));
      expect(subscribedFilters.last.first.toJson()['sort'], equals(sortSent));
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

        final callsBefore = subscribeCallCount;

        await videoEventService.resetAndResubscribeAll();

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
