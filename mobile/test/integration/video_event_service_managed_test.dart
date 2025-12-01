// ABOUTME: Test to verify VideoEventService properly uses SubscriptionManager instead of direct workaround
// ABOUTME: This verifies the TDD fix - SubscriptionManager should now handle main video feed

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

// Use existing mocks from unit test
import '../unit/subscription_manager_tdd_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEventService SubscriptionManager Integration', () {
    late MockINostrService mockNostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late StreamController<Event> testEventController;

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
    });

    tearDown(() {
      testEventController.close();
      videoEventService.dispose();
      subscriptionManager.dispose();
    });

    test(
      'VideoEventService should use SubscriptionManager for main video feed',
      () async {
        Log.debug(
          '🔍 Testing VideoEventService uses SubscriptionManager...',
          name: 'VideoEventServiceManagedTest',
          category: LogCategory.system,
        );

        // Subscribe to video feed - this should use SubscriptionManager now
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 3,
        );

        // Verify subscription was created
        expect(
          videoEventService.isSubscribed(SubscriptionType.discovery),
          true,
        );

        // Send a test event
        final testEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          22,
          [
            ['url', 'https://example.com/test.mp4'],
          ],
          'Test video',
        );

        testEventController.add(testEvent);
        await Future.delayed(Duration(milliseconds: 100));

        // VideoEventService should have received the event through SubscriptionManager
        expect(videoEventService.hasEvents(SubscriptionType.discovery), true);
        expect(
          videoEventService.getEventCount(SubscriptionType.discovery),
          greaterThan(0),
        );

        Log.info(
          '✅ VideoEventService successfully uses SubscriptionManager',
          name: 'VideoEventServiceManagedTest',
          category: LogCategory.system,
        );
      },
    );
  });
}
