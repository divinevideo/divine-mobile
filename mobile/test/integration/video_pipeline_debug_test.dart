// ABOUTME: Integration test to debug the complete video pipeline from subscription to UI
// ABOUTME: Tests the real flow: VideoEventsProvider -> VideoEventService -> SubscriptionManager -> Relay

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Use existing mocks
import '../unit/subscription_manager_tdd_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Pipeline Debug - Complete Flow', () {
    late MockINostrService mockNostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late StreamController<Event> testEventController;
    late ProviderContainer container;

    setUp(() {
      mockNostrService = MockINostrService();
      testEventController = StreamController<Event>.broadcast();

      // Mock NostrService
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        mockNostrService.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
        ),
      ).thenAnswer((_) => testEventController.stream);

      subscriptionManager = SubscriptionManager(mockNostrService);
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
      );

      // Create provider container with overrides
      container = ProviderContainer(
        overrides: [
          videoEventsNostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventsSubscriptionManagerProvider.overrideWithValue(
            subscriptionManager,
          ),
        ],
      );
    });

    tearDown(() {
      testEventController.close();
      videoEventService.dispose();
      subscriptionManager.dispose();
      container.dispose();
    });

    test(
      'Complete video pipeline: VideoEventsProvider -> VideoEventService -> SubscriptionManager',
      () async {
        Log.info(
          '🔍 Testing complete video pipeline...',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );

        // Step 1: Create VideoEventsProvider and trigger build
        Log.info(
          '📡 Step 1: Creating VideoEventsProvider...',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        final eventsProvider = videoEventsProvider;

        // Create a manual stream to control the flow
        final videoEvents = <VideoEvent>[];
        final eventsCompleter = Completer<List<VideoEvent>>();

        // Listen to the provider
        final subscription = container.listen(eventsProvider, (previous, next) {
          if (next.hasValue) {
            final events = next.value!;
            Log.info(
              '✅ VideoEventsProvider received ${events.length} events',
              name: 'VideoPipelineTest',
              category: LogCategory.system,
            );
            videoEvents.addAll(events);
            if (events.isNotEmpty && !eventsCompleter.isCompleted) {
              eventsCompleter.complete(events);
            }
          } else if (next.hasError) {
            Log.error(
              '❌ VideoEventsProvider error: ${next.error}',
              name: 'VideoPipelineTest',
              category: LogCategory.system,
            );
            if (!eventsCompleter.isCompleted) {
              eventsCompleter.completeError(next.error!);
            }
          } else {
            Log.debug(
              '⏳ VideoEventsProvider loading...',
              name: 'VideoPipelineTest',
              category: LogCategory.system,
            );
          }
        });

        // Step 2: Read the provider to trigger build
        Log.info(
          '📡 Step 2: Reading VideoEventsProvider (triggers build)...',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        final initialState = container.read(eventsProvider);
        Log.debug(
          '📡 Initial state: $initialState',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );

        // Step 3: Wait a moment for subscription to be created
        await Future.delayed(Duration(milliseconds: 100));

        // Step 4: Send test event through the stream
        Log.info(
          '📡 Step 3: Sending test kind 22 event...',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        final testEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          22,
          [
            ["url", "https://api.openvine.co/media/test-video-123"],
            ["m", "video/mp4"],
            ["title", "Test Video"],
            ["t", "test"],
          ],
          'Test video content',
        );

        testEventController.add(testEvent);

        // Step 5: Wait for event to flow through the pipeline
        Log.info(
          '📡 Step 4: Waiting for event to flow through pipeline...',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        try {
          final events = await eventsCompleter.future.timeout(
            Duration(seconds: 5),
          );
          Log.info(
            '✅ Pipeline complete! Received ${events.length} events',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );

          expect(
            events.length,
            greaterThan(0),
            reason: 'Should receive events through complete pipeline',
          );
          expect(
            events.first.hasVideo,
            true,
            reason: 'Event should have video URL',
          );
          expect(
            events.first.videoUrl,
            'https://api.openvine.co/media/test-video-123',
          );
        } catch (e) {
          Log.error(
            '❌ Pipeline failed with timeout or error: $e',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );

          // Debug information
          Log.debug(
            '🔍 Debug info:',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );
          Log.debug(
            '  - VideoEventService isSubscribed: ${videoEventService.isSubscribed}',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );
          Log.debug(
            '  - VideoEventService discovery events: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );
          Log.debug(
            '  - VideoEventService hasEvents: ${videoEventService.hasEvents}',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );
          Log.debug(
            '  - SubscriptionManager exists: true',
            name: 'VideoPipelineTest',
            category: LogCategory.system,
          );

          // Fail the test with debug info
          fail(
            'Pipeline did not complete within timeout. Debug info printed above.',
          );
        } finally {
          // Close the subscription listener to prevent leaks
          subscription.close();
        }
      },
    );

    test('Direct VideoEventService test for comparison', () async {
      Log.info(
        '🔍 Testing VideoEventService directly...',
        name: 'VideoPipelineTest',
        category: LogCategory.system,
      );

      final receivedEvents = <VideoEvent>[];
      final completer = Completer<void>();

      // Listen to VideoEventService changes
      void onVideoEventChange() {
        final events = videoEventService.discoveryVideos;
        Log.info(
          '✅ VideoEventService updated: ${events.length} events',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        if (events.isNotEmpty) {
          receivedEvents.addAll(events);
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      }

      // Note: VideoEventService no longer extends ChangeNotifier after refactor
      // Using polling approach to check for new events
      Timer? eventPollingTimer;
      eventPollingTimer = Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) {
        onVideoEventChange();
      });

      // Subscribe directly
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 3,
      );

      // Send test event
      final testEvent = Event(
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        22,
        [
          ["url", "https://api.openvine.co/media/direct-test-456"],
          ["m", "video/mp4"],
          ["title", "Direct Test Video"],
        ],
        'Direct test content',
      );

      testEventController.add(testEvent);

      // Wait for event
      try {
        await completer.future.timeout(Duration(seconds: 3));
        Log.info(
          '✅ Direct test complete! Received ${receivedEvents.length} events',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );

        expect(receivedEvents.length, greaterThan(0));
        expect(receivedEvents.first.hasVideo, true);
      } catch (e) {
        Log.error(
          '❌ Direct test failed: $e',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  - VideoEventService isSubscribed: ${videoEventService.isSubscribed}',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        Log.debug(
          '  - VideoEventService discovery events: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
          name: 'VideoPipelineTest',
          category: LogCategory.system,
        );
        rethrow;
      } finally {
        eventPollingTimer.cancel();
      }
    });
  });
}
