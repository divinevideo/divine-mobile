// ABOUTME: TDD test for SubscriptionManager hitting real OpenVine relay - NO MOCKING
// ABOUTME: This test will fail first, then we fix SubscriptionManager to make it pass

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  // Initialize Flutter bindings and mock platform dependencies for test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const MethodChannel prefsChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        if (methodCall.method == 'setString' ||
            methodCall.method == 'setStringList')
          return true;
        return null;
      });

  // Mock connectivity
  const MethodChannel connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'check') return ['wifi'];
        return null;
      });

  // Mock secure storage
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'write') return null;
        if (methodCall.method == 'read') return null;
        if (methodCall.method == 'readAll') return <String, String>{};
        return null;
      });

  group('SubscriptionManager TDD - Real Relay Tests', () {
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late NostrKeyManager keyManager;

    setUpAll(() async {
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(
        customRelays: ['wss://staging-relay.divine.video'],
      );

      // Wait for connection to stabilize
      await Future.delayed(Duration(seconds: 3));

      subscriptionManager = SubscriptionManager(nostrService);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    test(
      'SubscriptionManager should receive kind 22 events from OpenVine relay',
      () async {
        Log.debug(
          '🔍 TDD TEST: Testing SubscriptionManager with real OpenVine relay...',
          name: 'SubscriptionManagerTDDIntegrationTest',
          category: LogCategory.system,
        );

        // This test will FAIL initially - that's the point of TDD!
        final receivedEvents = <Event>[];
        final completer = Completer<void>();

        // Create subscription using SubscriptionManager
        final subscriptionId = await subscriptionManager.createSubscription(
          name: 'tdd_test_video_feed',
          filters: [
            Filter(kinds: [22], limit: 3),
          ],
          onEvent: (event) {
            Log.info(
              '✅ TDD: SubscriptionManager received event: kind=${event.kind}, id=${event.id}',
              name: 'SubscriptionManagerTDDIntegrationTest',
              category: LogCategory.system,
            );
            receivedEvents.add(event);
            if (receivedEvents.length >= 2) {
              completer.complete();
            }
          },
          onError: (error) {
            Log.error(
              '❌ TDD: SubscriptionManager error: $error',
              name: 'SubscriptionManagerTDDIntegrationTest',
              category: LogCategory.system,
            );
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
          onComplete: () {
            Log.debug(
              '🏁 TDD: SubscriptionManager subscription completed',
              name: 'SubscriptionManagerTDDIntegrationTest',
              category: LogCategory.system,
            );
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        Log.debug(
          '📡 TDD: Created subscription $subscriptionId, waiting for events...',
          name: 'SubscriptionManagerTDDIntegrationTest',
          category: LogCategory.system,
        );

        // Wait for events with reasonable timeout
        try {
          await completer.future.timeout(Duration(seconds: 15));
        } catch (e) {
          Log.warning(
            '⏰ TDD: Timeout waiting for events from SubscriptionManager',
            name: 'SubscriptionManagerTDDIntegrationTest',
            category: LogCategory.system,
          );
        }

        // Clean up
        await subscriptionManager.cancelSubscription(subscriptionId);

        Log.debug(
          '📊 TDD: SubscriptionManager received ${receivedEvents.length} events',
          name: 'SubscriptionManagerTDDIntegrationTest',
          category: LogCategory.system,
        );

        // This assertion will FAIL initially - proving SubscriptionManager is broken
        expect(
          receivedEvents.length,
          greaterThan(0),
          reason:
              'SubscriptionManager should receive events from OpenVine relay (we know events exist from nak verification)',
        );
      },
    );

    test(
      'Direct subscription should work for comparison (proves relay has events)',
      () async {
        Log.debug(
          '🔍 TDD: Testing direct subscription as control test...',
          name: 'SubscriptionManagerTDDIntegrationTest',
          category: LogCategory.system,
        );

        final directEvents = <Event>[];
        final directCompleter = Completer<void>();

        final directStream = nostrService.subscribeToEvents(
          filters: [
            Filter(kinds: [22], limit: 3),
          ],
        );

        final directSub = directStream.listen(
          (event) {
            Log.info(
              '✅ TDD: Direct subscription received event: kind=${event.kind}, id=${event.id}',
              name: 'SubscriptionManagerTDDIntegrationTest',
              category: LogCategory.system,
            );
            directEvents.add(event);
            if (directEvents.length >= 2) {
              directCompleter.complete();
            }
          },
          onError: (error) {
            Log.error(
              '❌ TDD: Direct subscription error: $error',
              name: 'SubscriptionManagerTDDIntegrationTest',
              category: LogCategory.system,
            );
            if (!directCompleter.isCompleted) {
              directCompleter.completeError(error);
            }
          },
        );

        try {
          await directCompleter.future.timeout(Duration(seconds: 15));
        } catch (e) {
          Log.warning(
            '⏰ TDD: Timeout waiting for direct events',
            name: 'SubscriptionManagerTDDIntegrationTest',
            category: LogCategory.system,
          );
        }

        directSub.cancel();

        Log.debug(
          '📊 TDD: Direct subscription received ${directEvents.length} events',
          name: 'SubscriptionManagerTDDIntegrationTest',
          category: LogCategory.system,
        );

        // This should pass - proving the relay has events and our test setup works
        expect(
          directEvents.length,
          greaterThan(0),
          reason:
              'Direct subscription should receive events (proves relay connectivity and events exist)',
        );
      },
    );
  });
}
