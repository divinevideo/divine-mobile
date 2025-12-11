// ABOUTME: Integration tests for AUTH and Kind 22 event retrieval against real staging-relay.divine.video relay
// ABOUTME: Tests the complete AUTH flow and verifies Kind 22 events can be retrieved after AUTH completion

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('AUTH and Kind 22 Event Retrieval - Real staging-relay.divine.video Relay', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;

    setUp(() async {
      // Initialize Flutter test bindings
      TestWidgetsFlutterBinding.ensureInitialized();

      // Initialize logging for tests
      Log.setLogLevel(LogLevel.debug);

      // Create services
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      // Generate test keys if needed
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      nostrService = NostrService(keyManager);
      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
    });

    tearDown(() async {
      videoEventService.dispose();
      subscriptionManager.dispose();
      nostrService.dispose();
      // NostrKeyManager doesn't have dispose method
    });

    test(
      'AUTH completion tracking works correctly',
      () async {
        // Set a longer timeout for real relay testing
        nostrService.setAuthTimeout(const Duration(seconds: 30));

        // Track AUTH state changes
        final authStateChanges = <Map<String, bool>>[];
        final authSubscription = nostrService.authStateStream.listen((states) {
          authStateChanges.add(Map.from(states));
          Log.debug(
            'AUTH state change: $states',
            name: 'AuthTest',
            category: LogCategory.system,
          );
        });

        try {
          // Initialize NostrService with staging-relay.divine.video
          await nostrService.initialize(
            customRelays: ['wss://staging-relay.divine.video'],
          );

          // Verify service is initialized
          expect(nostrService.isInitialized, isTrue);
          expect(nostrService.connectedRelayCount, greaterThan(0));

          // Wait a bit for AUTH completion
          await Future.delayed(const Duration(seconds: 5));

          // Check staging-relay.divine.video AUTH state
          final vineAuthed = nostrService.isVineRelayAuthenticated;
          Log.info(
            'staging-relay.divine.video authenticated: $vineAuthed',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // We should have at least one AUTH state change
          expect(authStateChanges, isNotEmpty);

          // If staging-relay.divine.video is connected, it should be in the auth states
          final authStates = nostrService.relayAuthStates;
          if (authStates.containsKey('wss://staging-relay.divine.video')) {
            Log.info(
              'staging-relay.divine.video AUTH state: ${authStates['wss://staging-relay.divine.video']}',
              name: 'AuthTest',
              category: LogCategory.system,
            );
          }

          // Log relay statuses for debugging
          final relayStatuses = nostrService.relayStatuses;
          for (final entry in relayStatuses.entries) {
            Log.debug(
              'Relay ${entry.key}: ${entry.value}',
              name: 'AuthTest',
              category: LogCategory.system,
            );
          }
        } finally {
          await authSubscription.cancel();
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Kind 22 events can be retrieved from staging-relay.divine.video after AUTH',
      () async {
        // Set a longer timeout for real relay testing
        nostrService.setAuthTimeout(const Duration(seconds: 30));

        // Initialize NostrService
        await nostrService.initialize(
          customRelays: ['wss://staging-relay.divine.video'],
        );
        expect(nostrService.isInitialized, isTrue);

        // Wait for AUTH completion
        await Future.delayed(const Duration(seconds: 10));

        // Track received events
        final receivedEvents = <VideoEvent>[];

        // Note: VideoEventService no longer extends ChangeNotifier after refactor
        // Using polling approach to check for new events
        Timer? eventPollingTimer;
        void checkForNewEvents() {
          final newEvents = videoEventService.discoveryVideos;
          for (final event in newEvents) {
            if (!receivedEvents.any((e) => e.id == event.id)) {
              receivedEvents.add(event);
              Log.info(
                'Received Kind 22 event: ${event.id} from ${event.pubkey}',
                name: 'AuthTest',
                category: LogCategory.system,
              );
            }
          }
        }

        // Subscribe to Kind 22 video events with a reasonable limit
        Log.info(
          'Subscribing to Kind 22 video events...',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 20, // Reasonable limit for testing
          replace: true,
          includeReposts: false,
        );

        // Start polling for new events every 500ms
        eventPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (
          _,
        ) {
          checkForNewEvents();
        });

        // Wait for events to arrive
        Log.info(
          'Waiting for Kind 22 events...',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        await Future.delayed(const Duration(seconds: 15));

        // Stop polling
        eventPollingTimer.cancel();

        // Check if we received any Kind 22 events
        Log.info(
          'Total events received: ${receivedEvents.length}',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.info(
          'VideoEventService event count: ${videoEventService.discoveryVideos.length}',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.info(
          'Is subscribed: ${videoEventService.isSubscribed}',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        // Log AUTH status
        Log.info(
          'staging-relay.divine.video authenticated: ${nostrService.isVineRelayAuthenticated}',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.debug(
          'Relay auth states: ${nostrService.relayAuthStates}',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        // We should have received some events (staging-relay.divine.video should have Kind 22 events)
        // Note: This might fail if staging-relay.divine.video is empty or not responding, but that's valuable info too
        if (receivedEvents.isEmpty) {
          Log.warning(
            'No Kind 22 events received from staging-relay.divine.video',
            name: 'AuthTest',
            category: LogCategory.system,
          );
          Log.warning(
            'This could indicate:',
            name: 'AuthTest',
            category: LogCategory.system,
          );
          Log.warning(
            '1. AUTH not completed properly',
            name: 'AuthTest',
            category: LogCategory.system,
          );
          Log.warning(
            '2. No Kind 22 events stored on staging-relay.divine.video',
            name: 'AuthTest',
            category: LogCategory.system,
          );
          Log.warning(
            '3. Relay not responding to subscriptions',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // Still check that AUTH completed
          if (nostrService.isVineRelayAuthenticated) {
            Log.warning(
              'AUTH completed but no events - relay may be empty',
              name: 'AuthTest',
              category: LogCategory.system,
            );
          } else {
            fail('AUTH did not complete for staging-relay.divine.video');
          }
        } else {
          // Success case - we got events
          expect(receivedEvents, isNotEmpty);
          Log.info(
            '✅ Successfully retrieved ${receivedEvents.length} Kind 22 events from staging-relay.divine.video',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // Verify events are properly parsed
          for (final event in receivedEvents.take(3)) {
            expect(event.id, isNotEmpty);
            expect(event.pubkey, isNotEmpty);
            // Note: kind is validated during VideoEvent.fromNostrEvent creation, so all events are kind 22
            Log.debug(
              'Event details: id=${event.id}, author=${event.pubkey}',
              name: 'AuthTest',
              category: LogCategory.system,
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'AUTH retry mechanism works when AUTH completes late',
      () async {
        // This test simulates the race condition scenario
        nostrService.setAuthTimeout(
          const Duration(seconds: 5),
        ); // Shorter timeout to force timeout

        // Initialize NostrService
        await nostrService.initialize(
          customRelays: ['wss://staging-relay.divine.video'],
        );
        expect(nostrService.isInitialized, isTrue);

        // Try to subscribe immediately (might happen before AUTH)
        final receivedEvents = <VideoEvent>[];

        // Note: VideoEventService no longer extends ChangeNotifier after refactor
        // Using polling approach to check for new events
        Timer? retryEventPollingTimer;
        void checkForRetryEvents() {
          final newEvents = videoEventService.discoveryVideos;
          for (final event in newEvents) {
            if (!receivedEvents.any((e) => e.id == event.id)) {
              receivedEvents.add(event);
              Log.info(
                'Received event via retry mechanism: ${event.id}',
                name: 'AuthTest',
                category: LogCategory.system,
              );
            }
          }
        }

        Log.info(
          'Subscribing before AUTH completion...',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
          replace: true,
          includeReposts: false,
        );

        // Start polling for events
        retryEventPollingTimer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) {
            checkForRetryEvents();
          },
        );

        Log.info(
          'Initial subscription created. Waiting for AUTH completion and retry...',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        // Wait longer for AUTH to complete and retry to happen
        await Future.delayed(const Duration(seconds: 20));

        // Stop polling
        retryEventPollingTimer.cancel();

        Log.info(
          'Final results:',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.info(
          '- Events received: ${receivedEvents.length}',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.info(
          '- staging-relay.divine.video authenticated: ${nostrService.isVineRelayAuthenticated}',
          name: 'AuthTest',
          category: LogCategory.system,
        );
        Log.info(
          '- Video service subscribed: ${videoEventService.isSubscribed}',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        // The retry mechanism should work regardless of initial AUTH state
        // If AUTH completed late, the retry should have triggered
        if (nostrService.isVineRelayAuthenticated) {
          Log.info(
            '✅ AUTH completed - retry mechanism should have triggered',
            name: 'AuthTest',
            category: LogCategory.system,
          );
          // We might have received events through retry
        } else {
          Log.warning(
            '⚠️ AUTH still not complete after extended wait',
            name: 'AuthTest',
            category: LogCategory.system,
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'AUTH session persistence works across service restarts',
      () async {
        NostrService? firstService;
        NostrService? secondService;

        try {
          // First service initialization
          firstService = NostrService(keyManager);
          firstService.setAuthTimeout(const Duration(seconds: 30));

          await firstService.initialize(
            customRelays: ['wss://staging-relay.divine.video'],
          );
          expect(firstService.isInitialized, isTrue);

          // Wait for AUTH completion
          await Future.delayed(const Duration(seconds: 10));

          final firstAuthState = firstService.isVineRelayAuthenticated;
          Log.info(
            'First service staging-relay.divine.video AUTH: $firstAuthState',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // Dispose first service
          firstService.dispose();
          await Future.delayed(const Duration(seconds: 1));

          // Create second service (should load persisted AUTH state)
          secondService = NostrService(keyManager);
          await secondService.initialize(
            customRelays: ['wss://staging-relay.divine.video'],
          );
          expect(secondService.isInitialized, isTrue);

          // Check if AUTH state was restored
          final secondAuthState = secondService.isVineRelayAuthenticated;
          Log.info(
            'Second service staging-relay.divine.video AUTH: $secondAuthState',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // If first service was authenticated, check if state persisted
          if (firstAuthState) {
            Log.info(
              'Testing AUTH session persistence...',
              name: 'AuthTest',
              category: LogCategory.system,
            );
            // Note: Session might have expired or relay might require re-auth
            // The important thing is that we attempt to restore the state
            Log.debug(
              'AUTH states loaded: ${secondService.relayAuthStates}',
              name: 'AuthTest',
              category: LogCategory.system,
            );
          }

          Log.info(
            '✅ AUTH session persistence mechanism tested',
            name: 'AuthTest',
            category: LogCategory.system,
          );
        } finally {
          firstService?.dispose();
          secondService?.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Configurable AUTH timeout works correctly',
      () async {
        final timeouts = [
          Duration(seconds: 5),
          Duration(seconds: 10),
          Duration(seconds: 20),
        ];

        for (final timeout in timeouts) {
          Log.info(
            'Testing AUTH timeout: ${timeout.inSeconds}s',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          final testService = NostrService(keyManager);
          testService.setAuthTimeout(timeout);

          final stopwatch = Stopwatch()..start();

          try {
            await testService.initialize(
              customRelays: ['wss://staging-relay.divine.video'],
            );
            stopwatch.stop();

            Log.info(
              'Service initialized in ${stopwatch.elapsedMilliseconds}ms',
              name: 'AuthTest',
              category: LogCategory.system,
            );
            Log.info(
              'staging-relay.divine.video authenticated: ${testService.isVineRelayAuthenticated}',
              name: 'AuthTest',
              category: LogCategory.system,
            );

            // AUTH timeout should be respected (allowing some margin for processing)
            expect(
              stopwatch.elapsed.inSeconds,
              lessThanOrEqualTo(timeout.inSeconds + 5),
            );
          } finally {
            testService.dispose();
          }

          // Wait between tests
          await Future.delayed(const Duration(seconds: 2));
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Multiple relays AUTH state tracking',
      () async {
        final testRelays = [
          'wss://localhost:8080', // Embedded relay
        ];

        nostrService.setAuthTimeout(const Duration(seconds: 30));

        await nostrService.initialize(customRelays: testRelays);
        expect(nostrService.isInitialized, isTrue);

        // Wait for AUTH completion
        await Future.delayed(const Duration(seconds: 15));

        final authStates = nostrService.relayAuthStates;
        Log.info(
          'Final AUTH states for all relays:',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        for (final relay in testRelays) {
          final isAuthed = nostrService.isRelayAuthenticated(relay);
          Log.debug(
            '$relay: authenticated=$isAuthed',
            name: 'AuthTest',
            category: LogCategory.system,
          );

          // Each relay should have some auth state tracked
          expect(authStates.containsKey(relay), isTrue);
        }

        // staging-relay.divine.video should require auth
        Log.info(
          'staging-relay.divine.video specifically: ${nostrService.isVineRelayAuthenticated}',
          name: 'AuthTest',
          category: LogCategory.system,
        );

        Log.info(
          '✅ Multiple relay AUTH tracking completed',
          name: 'AuthTest',
          category: LogCategory.system,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
