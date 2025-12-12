// ABOUTME: TDD test for SubscriptionManager logic - tests the event forwarding mechanism
// ABOUTME: This will fail first, then we fix the bug to make it pass

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

@GenerateNiceMocks([MockSpec<NostrClient>()])
import 'subscription_manager_tdd_test.mocks.dart';

void main() {
  group('SubscriptionManager TDD - Event Forwarding Bug', () {
    late MockNostrClient mockNostrService;
    late SubscriptionManager subscriptionManager;
    late StreamController<Event> testEventController;

    setUp(() {
      mockNostrService = MockNostrClient();
      testEventController = StreamController<Event>.broadcast();

      // Mock the NostrService to return our test stream
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => testEventController.stream);

      subscriptionManager = SubscriptionManager(mockNostrService);
    });

    tearDown(() {
      testEventController.close();
      subscriptionManager.dispose();
      reset(mockNostrService);
    });

    test(
      'TDD: SubscriptionManager should forward events from NostrService to callback - WILL FAIL FIRST',
      () async {
        Log.debug(
          '🔍 TDD: Testing if SubscriptionManager forwards events to callbacks...',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );

        // This test will FAIL initially - proving the bug exists!
        final receivedEvents = <Event>[];
        final completer = Completer<void>();

        // Create subscription
        final subscriptionId = await subscriptionManager.createSubscription(
          name: 'tdd_test',
          filters: [
            Filter(kinds: [22], limit: 3),
          ],
          onEvent: (event) {
            Log.info(
              '✅ TDD: Callback received event: ${event.id}',
              name: 'SubscriptionManagerTDDTest',
              category: LogCategory.system,
            );
            receivedEvents.add(event);
            if (receivedEvents.length >= 2) {
              completer.complete();
            }
          },
          onError: (error) {
            Log.error(
              '❌ TDD: Callback error: $error',
              name: 'SubscriptionManagerTDDTest',
              category: LogCategory.system,
            );
            completer.completeError(error);
          },
          onComplete: () {
            Log.debug(
              '🏁 TDD: Callback completed',
              name: 'SubscriptionManagerTDDTest',
              category: LogCategory.system,
            );
            if (!completer.isCompleted) completer.complete();
          },
        );

        Log.debug(
          '📡 TDD: Created subscription $subscriptionId',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );

        // Simulate events coming from the NostrService stream (using valid hex pubkeys)
        final testEvent1 = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          22,
          [
            ['url', 'https://example.com/video1.mp4'],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test video content 1',
        );

        final testEvent2 = Event(
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
          22,
          [
            ['url', 'https://example.com/video2.mp4'],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test video content 2',
        );

        // Send events through the stream (simulating real relay events)
        Log.debug(
          '📤 TDD: Sending test events through stream...',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );
        testEventController.add(testEvent1);
        await Future.delayed(Duration(milliseconds: 100));
        testEventController.add(testEvent2);

        // Wait for events to be forwarded to callback
        try {
          await completer.future.timeout(Duration(seconds: 5));
        } catch (e) {
          Log.warning(
            '⏰ TDD: Timeout - events were not forwarded to callback',
            name: 'SubscriptionManagerTDDTest',
            category: LogCategory.system,
          );
        }

        await subscriptionManager.cancelSubscription(subscriptionId);

        Log.debug(
          '📊 TDD: Received ${receivedEvents.length} events via callback',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );

        // This assertion will FAIL initially if SubscriptionManager has the bug
        expect(
          receivedEvents.length,
          equals(2),
          reason:
              'SubscriptionManager should forward events from stream to callback - THIS WILL FAIL FIRST (TDD Red phase)',
        );
      },
    );

    test(
      'TDD: Verify NostrService stream works correctly (control test)',
      () async {
        Log.debug(
          '🔍 TDD: Control test - verify our test setup works...',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );

        // This should pass - verifying our test setup is correct
        final receivedEvents = <Event>[];
        final completer = Completer<void>();

        // Listen directly to the stream (bypassing SubscriptionManager)
        final directStream = mockNostrService.subscribe([
          Filter(kinds: [22]),
        ]);
        final subscription = directStream.listen((event) {
          Log.info(
            '✅ TDD: Direct stream received: ${event.id}',
            name: 'SubscriptionManagerTDDTest',
            category: LogCategory.system,
          );
          receivedEvents.add(event);
          if (receivedEvents.length >= 2) {
            completer.complete();
          }
        });

        // Send the same test events (using valid hex pubkeys)
        final testEvent1 = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          22,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test 1',
        );
        final testEvent2 = Event(
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
          22,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test 2',
        );

        testEventController.add(testEvent1);
        await Future.delayed(Duration(milliseconds: 100));
        testEventController.add(testEvent2);

        await completer.future.timeout(Duration(seconds: 2));
        subscription.cancel();

        Log.debug(
          '📊 TDD: Direct stream received ${receivedEvents.length} events',
          name: 'SubscriptionManagerTDDTest',
          category: LogCategory.system,
        );

        // This should pass - proving our test setup works
        expect(
          receivedEvents.length,
          equals(2),
          reason:
              'Direct stream should receive events (proves test setup is correct)',
        );
      },
    );
  });
}
