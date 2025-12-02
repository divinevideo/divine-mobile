// ABOUTME: Integration test to verify classic vines and open feed subscriptions work correctly
// ABOUTME: Tests the fix for subscription duplicate checking bug

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class MockNostrService extends Mock implements INostrService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  test(
    'Classic vines -> Open feed -> Editor picks sequence works correctly',
    () async {
      // Setup mock NostrService
      final mockNostrService = MockNostrService();
      final streamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      // Track all subscription calls
      final subscriptionCalls = <Map<String, dynamic>>[];
      when(
        () =>
            mockNostrService.subscribeToEvents(filters: any(named: 'filters')),
      ).thenAnswer((invocation) {
        final filters =
            invocation.namedArguments[const Symbol('filters')] as List<Filter>;
        final filter = filters.first;

        // Extract subscription parameters
        subscriptionCalls.add({
          'authors': filter.authors,
          'kinds': filter.kinds,
          'limit': filter.limit,
          'call_number': subscriptionCalls.length + 1,
        });

        return streamController.stream;
      });

      // Create VideoEventService
      final mockSubscriptionManager = MockSubscriptionManager();
      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      // Step 1: Classic vines subscription
      Log.debug('📱 Step 1: Loading classic vines...');
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        authors: [
          '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856',
        ],
        limit: 100,
        replace: true,
      );

      // Step 2: Open feed subscription (this was being wrongly rejected before)
      Log.debug('📱 Step 2: Loading open feed...');
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 300,
        replace: false,
      );

      // Step 3: Editor picks subscription
      Log.debug('📱 Step 3: Loading editor picks...');
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        authors: [
          '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        ],
        limit: 50,
        replace: false,
      );

      // Verify all three subscriptions were created
      expect(
        subscriptionCalls.length,
        equals(3),
        reason: 'Should have created 3 separate subscriptions',
      );

      // Verify subscription 1: Classic vines
      expect(subscriptionCalls[0]['authors'], isNotNull);
      expect(subscriptionCalls[0]['authors']!.length, equals(1));
      expect(
        subscriptionCalls[0]['authors']![0],
        equals(
          '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856',
        ),
      );
      expect(subscriptionCalls[0]['limit'], equals(100));

      // Verify subscription 2: Open feed (no author filter)
      expect(
        subscriptionCalls[1]['authors'],
        isNull,
        reason: 'Open feed should have no author filter',
      );
      expect(subscriptionCalls[1]['limit'], equals(300));

      // Verify subscription 3: Editor picks
      expect(subscriptionCalls[2]['authors'], isNotNull);
      expect(subscriptionCalls[2]['authors']!.length, equals(1));
      expect(
        subscriptionCalls[2]['authors']![0],
        equals(
          '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        ),
      );
      expect(subscriptionCalls[2]['limit'], equals(50));

      Log.debug('✅ All subscriptions created correctly!');
      Log.debug('📊 Subscription summary:');
      Log.debug(
        '  1. Classic vines: ${subscriptionCalls[0]['authors']} (limit: ${subscriptionCalls[0]['limit']})',
      );
      Log.debug(
        '  2. Open feed: ALL videos (limit: ${subscriptionCalls[1]['limit']})',
      );
      Log.debug(
        '  3. Editor picks: ${subscriptionCalls[2]['authors']} (limit: ${subscriptionCalls[2]['limit']})',
      );

      // Cleanup
      await streamController.close();
      // Don't dispose - it calls unsubscribeFromVideoFeed which notifies listeners
    },
  );
}
