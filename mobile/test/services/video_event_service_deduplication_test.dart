import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Subscription Deduplication', () {
    final author1 = '1' * 64;
    final author2 = '2' * 64;
    final author3 = '3' * 64;
    final author4 = '4' * 64;
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late List<StreamController<Event>> streams;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      streams = [];

      // Setup mock NostrService
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) {
        final controller = StreamController<Event>();
        streams.add(controller);
        return controller.stream;
      });
      // Home-feed backfill is separate from the persistent subscription.
      when(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(
            named: 'subscriptionId',
            that: startsWith('seed_home_'),
          ),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await videoEventService.unsubscribeFromVideoFeed();
      videoEventService.dispose();
      for (final controller in streams) {
        await controller.close();
      }
    });

    test('reuses a live subscription for identical parameters', () async {
      await videoEventService.subscribeToDiscovery();
      expect(streams.single.hasListener, isTrue);

      await videoEventService.subscribeToDiscovery();

      verify(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).called(1);
      expect(streams.single.hasListener, isTrue);
    });

    test(
      'keeps different subscription types active independently',
      () async {
        // Subscribe to discovery
        await videoEventService.subscribeToDiscovery();

        // Subscribe to home feed with same limit
        await videoEventService.subscribeToHomeFeed([author1]);

        // Both should create separate subscriptions
        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(2);
        expect(streams.every((stream) => stream.hasListener), isTrue);
      },
    );

    test('replaces the subscription when authors change', () async {
      // Subscribe with first set of authors
      await videoEventService.subscribeToHomeFeed([author1, author2]);

      // Subscribe with different authors
      await videoEventService.subscribeToHomeFeed([author3, author4]);

      // Both should create separate subscriptions
      verify(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).called(2);
      expect(streams.first.hasListener, isFalse);
      expect(streams.last.hasListener, isTrue);
    });

    test(
      'reuses the same ID for reordered authors without replacement',
      () async {
        // Subscribe with authors in one order
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: [author1, author2, author3],
          replace: false,
        );
        expect(streams.single.hasListener, isTrue);

        // Keep the existing subscription so this reaches ID-based reuse rather
        // than the default replacement path's order-sensitive parameter check.
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: [author3, author1, author2],
          replace: false,
        );

        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
        expect(streams.single.hasListener, isTrue);
      },
    );

    test('replaces the subscription when hashtags change', () async {
      // Subscribe with first hashtag
      await videoEventService.subscribeToHashtagVideos(['funny']);

      // Subscribe with different hashtag
      await videoEventService.subscribeToHashtagVideos(['music']);

      // Both should create separate subscriptions
      verify(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).called(2);
      expect(streams.first.hasListener, isFalse);
      expect(streams.last.hasListener, isTrue);
    });

    test('should not create duplicate subscriptions for rapid calls', () async {
      // Simulate rapid subscription calls (like from multiple UI components)
      final futures = <Future>[];

      for (int i = 0; i < 5; i++) {
        futures.add(videoEventService.subscribeToDiscovery());
      }

      await Future.wait(futures);

      // Should only create one subscription despite 5 calls
      verify(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).called(1);
    });

    test('subscription count should stay reasonable', () async {
      // Create various subscription types
      await videoEventService.subscribeToDiscovery();
      await videoEventService.subscribeToHomeFeed([author1]);
      await videoEventService.subscribeToHashtagVideos(['funny']);

      // Get connection status to check subscription count
      final status = videoEventService.getConnectionStatus();
      final activeSubscriptions = status['activeSubscriptions'] as List;

      // Should have 3 active subscription types
      expect(activeSubscriptions.length, equals(3));
      expect(activeSubscriptions, contains('discovery'));
      expect(activeSubscriptions, contains('homeFeed'));
      expect(activeSubscriptions, contains('hashtag'));
    });

    test('should handle subscription replacement correctly', () async {
      // First subscription
      await videoEventService.subscribeToDiscovery(limit: 50);

      // Replace with different parameters
      await videoEventService.subscribeToDiscovery();

      // Should create two subscriptions (old one cancelled, new one created)
      verify(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).called(2);
      expect(streams.first.hasListener, isFalse);
      expect(streams.last.hasListener, isTrue);

      // But only one should be active
      final status = videoEventService.getConnectionStatus();
      final activeSubscriptions = status['activeSubscriptions'] as List;
      expect(activeSubscriptions.length, equals(1));
    });
  });
}
