// ABOUTME: Unit tests for VideoEventService force refresh behavior
// ABOUTME: Tests that force refresh preserves existing videos instead of clearing them

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class TestSubscriptionManager extends Mock implements SubscriptionManager {
  TestSubscriptionManager(this.eventStreamController);
  final StreamController<Event> eventStreamController;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    Function()? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    // Set up a stream listener that calls onEvent for each event
    eventStreamController.stream.listen(onEvent);
    return 'mock_sub_$name';
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    // No-op for tests
  }
}

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
  event.sig = 'sig_aaaabbbbccccddddeeeeffff1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff11112222333344445555666677778888';
  event.sources.add('wss://relay.divine.video');
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Force Refresh', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;
    late TestSubscriptionManager testSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        // Simulate EOSE immediately
        Future.microtask(() {
          final onEose =
              invocation.namedArguments[const Symbol('onEose')]
                  as void Function()?;
          onEose?.call();
        });
        return eventStreamController.stream;
      });

      testSubscriptionManager = TestSubscriptionManager(eventStreamController);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      eventStreamController.close();
      videoEventService.dispose();
    });

    test('force refresh should preserve existing videos, not clear them', () async {
      // Create mock video events with unique IDs
      final event1 = createVideoEvent(
        id: 'video1_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
        pubkey:
            '1111111111111111111111111111111111111111111111111111111111111111',
        content: 'First video',
        videoUrl: 'https://example.com/video1.mp4',
      );

      final event2 = createVideoEvent(
        id: 'video2_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
        pubkey:
            '2222222222222222222222222222222222222222222222222222222222222222',
        content: 'Second video',
        videoUrl: 'https://example.com/video2.mp4',
      );

      // Step 1: Initial subscription
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
        limit: 100,
      );

      // Add first video to the stream
      eventStreamController.add(event1);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify first video is in the list
      final videosAfterFirst = videoEventService.getVideos(
        SubscriptionType.popularNow,
      );
      expect(videosAfterFirst.length, 1);
      expect(
        videosAfterFirst[0].id,
        'video1_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
      );

      // Step 2: Force refresh (same subscription parameters)
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
        limit: 100,
        force: true, // Force refresh with same parameters
      );

      // Add second video to the stream after refresh
      eventStreamController.add(event2);
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 3: Verify BOTH videos are present (old video wasn't cleared)
      final videosAfterRefresh = videoEventService.getVideos(
        SubscriptionType.popularNow,
      );

      // This is the critical assertion: we should have BOTH videos
      // OLD BEHAVIOR (bug): videosAfterRefresh.length == 1 (only video2)
      // NEW BEHAVIOR (fix): videosAfterRefresh.length == 2 (both video1 and video2)
      expect(
        videosAfterRefresh.length,
        2,
        reason:
            'Force refresh should preserve existing videos and add new ones',
      );

      // Verify both videos are present
      final videoIds = videosAfterRefresh.map((v) => v.id).toList();
      expect(
        videoIds,
        contains(
          'video1_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
        ),
        reason: 'Original video should still be present after force refresh',
      );
      expect(
        videoIds,
        contains(
          'video2_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
        ),
        reason: 'New video should be added after force refresh',
      );
    });

    test('force refresh should not duplicate existing videos', () async {
      // Create mock video event
      final event1 = createVideoEvent(
        id: 'video1_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
        pubkey:
            '1111111111111111111111111111111111111111111111111111111111111111',
        content: 'Video content',
        videoUrl: 'https://example.com/video1.mp4',
      );

      // Step 1: Initial subscription
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
        limit: 100,
      );

      // Add video
      eventStreamController.add(event1);
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Force refresh
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
        limit: 100,
        force: true,
      );

      // Add same video again (simulating relay sending it again)
      eventStreamController.add(event1);
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 3: Verify video appears only ONCE (deduplication working)
      final videos = videoEventService.getVideos(SubscriptionType.popularNow);
      expect(
        videos.length,
        1,
        reason: 'Duplicate videos should be deduplicated',
      );
      expect(
        videos[0].id,
        'video1_aaaabbbbccccddddeeeeffffgggghhhhiiiijjjjkkkkllllmmmmnnnnoooopppp',
      );
    });
  });
}
