// ABOUTME: Real relay test for SubscriptionManager - NO MOCKING to prove it's broken
// ABOUTME: This test hits staging-relay.divine.video relay directly to show SubscriptionManager doesn't work

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
  // Initialize Flutter bindings for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences channel
  const MethodChannel prefsChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{}; // Return empty preferences
        }
        if (methodCall.method == 'setString' ||
            methodCall.method == 'setStringList') {
          return true; // Mock successful writes
        }
        return null;
      });

  // Mock connectivity channel
  const MethodChannel connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'check') {
          return ['wifi']; // Mock being online with correct type
        }
        return null;
      });

  // Mock flutter_secure_storage channel
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'write') {
          return null; // Mock successful writes
        }
        if (methodCall.method == 'read') {
          return null; // Mock empty reads
        }
        if (methodCall.method == 'readAll') {
          return <String, String>{}; // Mock empty storage
        }
        return null;
      });

  group('SubscriptionManager Real Relay Tests - NO MOCKING', () {
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late NostrKeyManager keyManager;

    setUpAll(() async {
      // Create and initialize key manager
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      // Create real NostrService that connects to actual relay
      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      // Add staging-relay.divine.video relay
      await nostrService.addRelay('wss://staging-relay.divine.video');

      // Wait for connection using proper async pattern
      final connectionCompleter = Completer<void>();
      Timer.periodic(Duration(milliseconds: 100), (timer) {
        if (nostrService.connectedRelays.isNotEmpty) {
          timer.cancel();
          connectionCompleter.complete();
        }
      });

      try {
        await connectionCompleter.future.timeout(Duration(seconds: 10));
      } catch (e) {
        Log.warning('Connection timeout, proceeding anyway: $e');
      }

      subscriptionManager = SubscriptionManager(nostrService);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    test(
      'SubscriptionManager should receive kind 22 events from staging-relay.divine.video - REAL RELAY',
      () async {
        Log.debug(
          '🔍 TEST: Starting SubscriptionManager real relay test...',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        final receivedEvents = <Event>[];
        final completer = Completer<void>();

        // Create subscription for kind 22 events - same as what VideoEventService does
        final subscriptionId = await subscriptionManager.createSubscription(
          name: 'test_video_feed',
          filters: [
            Filter(kinds: [22], limit: 5),
          ],
          onEvent: (event) {
            Log.info(
              '✅ SUBSCRIPTION_MANAGER: Received event via SubscriptionManager: kind=${event.kind}, id=${event.id}',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            receivedEvents.add(event);
            if (receivedEvents.length >= 3) {
              completer.complete();
            }
          },
          onError: (error) {
            Log.error(
              '❌ SUBSCRIPTION_MANAGER: Error: $error',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
          onComplete: () {
            Log.debug(
              '🏁 SUBSCRIPTION_MANAGER: Subscription completed',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        Log.debug(
          '📡 TEST: Created SubscriptionManager subscription ID: $subscriptionId',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        // Wait for events with timeout
        try {
          await completer.future.timeout(Duration(seconds: 15));
        } catch (e) {
          Log.warning(
            '⏰ TEST: Timeout waiting for SubscriptionManager events',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        }

        Log.debug(
          '📊 TEST: SubscriptionManager received ${receivedEvents.length} events',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        // Now test direct subscription for comparison
        Log.debug(
          '🔍 TEST: Now testing direct subscription for comparison...',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        final directEvents = <Event>[];
        final directCompleter = Completer<void>();

        final directStream = nostrService.subscribeToEvents(
          filters: [
            Filter(kinds: [22], limit: 5),
          ],
        );

        final directSub = directStream.listen(
          (event) {
            Log.info(
              '✅ DIRECT: Received event via direct subscription: kind=${event.kind}, id=${event.id}',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            directEvents.add(event);
            if (directEvents.length >= 3) {
              directCompleter.complete();
            }
          },
          onError: (error) {
            Log.error(
              '❌ DIRECT: Error: $error',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            if (!directCompleter.isCompleted) {
              directCompleter.completeError(error);
            }
          },
          onDone: () {
            Log.debug(
              '🏁 DIRECT: Direct subscription completed',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            if (!directCompleter.isCompleted) {
              directCompleter.complete();
            }
          },
        );

        try {
          await directCompleter.future.timeout(Duration(seconds: 15));
        } catch (e) {
          Log.warning(
            '⏰ TEST: Timeout waiting for direct subscription events',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        }

        directSub.cancel();

        Log.debug(
          '📊 TEST: Direct subscription received ${directEvents.length} events',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        // Print detailed comparison
        Log.debug(
          '🔍 COMPARISON RESULTS:',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  SubscriptionManager events: ${receivedEvents.length}',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  Direct subscription events: ${directEvents.length}',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        if (receivedEvents.isEmpty && directEvents.isNotEmpty) {
          Log.error(
            '💥 PROOF: SubscriptionManager is BROKEN - receives 0 events while direct gets ${directEvents.length}',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        } else if (receivedEvents.length == directEvents.length) {
          Log.info(
            '✅ Both methods work equally',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            '⚠️  Different event counts - needs investigation',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        }

        // The test assertion
        expect(
          receivedEvents.length,
          greaterThan(0),
          reason:
              'SubscriptionManager should receive events from staging-relay.divine.video relay like direct subscription does',
        );

        // Clean up
        await subscriptionManager.cancelSubscription(subscriptionId);
      },
    );

    test(
      'Direct comparison: Both should get same events from staging-relay.divine.video',
      () async {
        Log.debug(
          '🔍 TEST: Direct comparison test...',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        // Test SubscriptionManager
        final managedEvents = <Event>[];
        final managedCompleter = Completer<void>();

        final managedSubId = await subscriptionManager.createSubscription(
          name: 'comparison_managed',
          filters: [
            Filter(kinds: [22], limit: 3),
          ],
          onEvent: (event) {
            Log.debug(
              '📱 MANAGED: ${event.id}',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            managedEvents.add(event);
            if (managedEvents.length >= 3) managedCompleter.complete();
          },
          onError: (error) {
            if (!managedCompleter.isCompleted)
              managedCompleter.completeError(error);
          },
          onComplete: () {
            if (!managedCompleter.isCompleted) managedCompleter.complete();
          },
        );

        // Test direct subscription
        final directEvents = <Event>[];
        final directCompleter = Completer<void>();

        final directStream = nostrService.subscribeToEvents(
          filters: [
            Filter(kinds: [22], limit: 3),
          ],
        );

        final directSub = directStream.listen(
          (event) {
            Log.debug(
              '🔗 DIRECT: ${event.id}',
              name: 'SubscriptionManagerRealRelayTest',
              category: LogCategory.system,
            );
            directEvents.add(event);
            if (directEvents.length >= 3) directCompleter.complete();
          },
          onError: (error) {
            if (!directCompleter.isCompleted)
              directCompleter.completeError(error);
          },
          onDone: () {
            if (!directCompleter.isCompleted) directCompleter.complete();
          },
        );

        // Wait for both
        await Future.wait([
          managedCompleter.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {},
          ),
          directCompleter.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {},
          ),
        ]);

        directSub.cancel();
        await subscriptionManager.cancelSubscription(managedSubId);

        Log.debug(
          '📊 FINAL COMPARISON:',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  SubscriptionManager: ${managedEvents.length} events',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  Direct subscription: ${directEvents.length} events',
          name: 'SubscriptionManagerRealRelayTest',
          category: LogCategory.system,
        );

        if (managedEvents.isEmpty && directEvents.isNotEmpty) {
          Log.error(
            '💥 CONFIRMED: SubscriptionManager is completely broken!',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
          Log.error(
            '   Direct gets ${directEvents.length} events, SubscriptionManager gets 0',
            name: 'SubscriptionManagerRealRelayTest',
            category: LogCategory.system,
          );
        }

        // This will fail if SubscriptionManager is broken
        expect(
          managedEvents.length,
          equals(directEvents.length),
          reason:
              'SubscriptionManager should get same number of events as direct subscription',
        );
      },
    );
  });
}
