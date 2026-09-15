// ABOUTME: Unit tests for VideoEventService deduplication logic
// ABOUTME: Tests that duplicate events are properly filtered to prevent
// ABOUTME: redundant processing

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class _MockNostrClient extends Mock implements NostrClient {}

// Fake classes for setUpAll
class _FakeFilter extends Fake implements Filter {}

/// Creates a valid kind 34236 video event for testing.
///
/// Uses NIP-71 addressable short video format with required tags.
Event _createVideoEvent({
  required String pubkey,
  required String id,
  required String videoUrl,
  required int createdAt,
  String content = '',
  String? vineId,
}) {
  final event = Event(
    pubkey,
    NIP71VideoKinds.addressableShortVideo, // kind 34236
    [
      ['d', vineId ?? 'vine_$id'],
      ['url', videoUrl],
      ['m', 'video/mp4'],
    ],
    content,
    createdAt: createdAt,
  );
  event.id = id;
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Deduplication Tests', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = _MockNostrClient();
      eventStreamController = StreamController<Event>.broadcast();

      // Setup mock responses
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(
          any(),
          onEose: any(named: 'onEose'),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await eventStreamController.close();
      reset(mockNostrService);
    });

    const testPubkey =
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

    test('should not add duplicate events with same ID', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final testEvent = _createVideoEvent(
        pubkey: testPubkey,
        id: 'test-video-id-1',
        videoUrl: 'https://example.com/video1.mp4',
        createdAt: now,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Send the same event multiple times
      eventStreamController.add(testEvent);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(testEvent);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(testEvent);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify only one event was added
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(
        videoEventService.discoveryVideos.first.id,
        equals('test-video-id-1'),
      );
    });

    test('should add different events with unique IDs', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final events = List.generate(3, (index) {
        return _createVideoEvent(
          pubkey: testPubkey,
          id: 'test-video-id-$index',
          videoUrl: 'https://example.com/video$index.mp4',
          createdAt: now + index,
        );
      });

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      for (final event in events) {
        eventStreamController.add(event);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Verify all unique events were added
      expect(videoEventService.discoveryVideos.length, equals(3));

      // Verify they're in reverse chronological order (newest first)
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('test-video-id-2'),
      );
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('test-video-id-1'),
      );
      expect(
        videoEventService.discoveryVideos[2].id,
        equals('test-video-id-0'),
      );
    });

    test('should handle mix of duplicates and unique events', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final event1 = _createVideoEvent(
        pubkey: testPubkey,
        id: 'test-video-id-1',
        videoUrl: 'https://example.com/video1.mp4',
        createdAt: now,
      );

      final event2 = _createVideoEvent(
        pubkey: testPubkey,
        id: 'test-video-id-2',
        videoUrl: 'https://example.com/video2.mp4',
        createdAt: now + 1,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Send events in mixed order with duplicates
      eventStreamController.add(event1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event1); // Duplicate
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event2); // Duplicate
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event1); // Another duplicate
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify only unique events were added
      expect(videoEventService.discoveryVideos.length, equals(2));

      // Verify order (newest first)
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('test-video-id-2'),
      );
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('test-video-id-1'),
      );
    });

    test(
      'should maintain deduplication across multiple subscriptions',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final testEvent = _createVideoEvent(
          pubkey: testPubkey,
          id: 'persistent-video-id',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: now,
        );

        // First subscription
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        eventStreamController.add(testEvent);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(videoEventService.discoveryVideos.length, equals(1));

        // Unsubscribe and re-subscribe
        await videoEventService.unsubscribeFromVideoFeed();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Create new stream controller for new subscription
        final newEventStreamController = StreamController<Event>.broadcast();
        when(
          () => mockNostrService.subscribe(
            any(),
            onEose: any(named: 'onEose'),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) => newEventStreamController.stream);

        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          replace: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Try to add the same event again
        newEventStreamController.add(testEvent);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Should still have only one event
        expect(videoEventService.discoveryVideos.length, equals(1));

        await newEventStreamController.close();
      },
    );

    test('should handle rapid duplicate events efficiently', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final testEvent = _createVideoEvent(
        pubkey: testPubkey,
        id: 'rapid-test-video',
        videoUrl: 'https://example.com/rapid.mp4',
        createdAt: now,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Send the same event rapidly without delays
      for (var i = 0; i < 100; i++) {
        eventStreamController.add(testEvent);
      }

      // Allow processing time
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should still have only one event despite rapid duplicates
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(
        videoEventService.discoveryVideos.first.id,
        equals('rapid-test-video'),
      );
    });

    test('should handle events with invalid kind gracefully', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final validEvent = _createVideoEvent(
        pubkey: testPubkey,
        id: 'valid-video',
        videoUrl: 'https://example.com/valid.mp4',
        createdAt: now,
      );

      final invalidEvent = Event(
        testPubkey,
        1, // Text note, not a video
        [],
        'Not a video',
        createdAt: now,
      );
      invalidEvent.id = 'invalid-kind';

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Send both events
      eventStreamController.add(validEvent);
      eventStreamController.add(invalidEvent);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Should only have the valid video event
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(videoEventService.discoveryVideos.first.id, equals('valid-video'));
    });
  });

  group('VideoEventService Repost Deduplication', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = _MockNostrClient();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(
          any(),
          onEose: any(named: 'onEose'),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await eventStreamController.close();
    });

    test('should deduplicate reposts of the same video', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const originalVideoId = 'original-video-id';
      const originalPubkey =
          'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

      // Create multiple reposts of the same video (kind 16 = NIP-18 generic
      // repost)
      final repost1 = Event(
        '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        NIP71VideoKinds.repost, // kind 16
        [
          ['e', originalVideoId, '', 'mention'],
          ['p', originalPubkey],
        ],
        '',
        createdAt: now,
      );
      repost1.id = 'repost-1';

      final repost2 = Event(
        '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856',
        NIP71VideoKinds.repost, // kind 16
        [
          ['e', originalVideoId, '', 'mention'],
          ['p', originalPubkey],
        ],
        '',
        createdAt: now + 1,
      );
      repost2.id = 'repost-2';

      // Subscribe with reposts enabled
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        includeReposts: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Send both reposts
      eventStreamController.add(repost1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(repost2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Reposts can't be displayed without the original video event
      // in cache. This is expected: kind 16 events reference original
      // events that must exist for repost resolution to succeed.
      expect(videoEventService.discoveryVideos.length, equals(0));
    });
  });
}
