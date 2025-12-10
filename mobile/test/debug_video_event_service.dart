// ABOUTME: Debug test to investigate why VideoEventService isn't receiving events
// ABOUTME: This is a minimal test to trace the issue step by step

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

// Simple mock NostrService that we can control
class TestableNostrService extends NostrService {
  // Mark as initialized for testing

  TestableNostrService(super.keyManager);
  StreamController<Event>? _testStreamController;
  final bool _mockInitialized = true;

  @override
  bool get isInitialized => _mockInitialized;

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    Log.info(
      '🔍 TestableNostrService.subscribeToEvents called with ${filters.length} filters',
      name: 'TestableNostrService',
    );

    // Log filter details
    for (final filter in filters) {
      final filterJson = filter.toJson();
      Log.info('  - Filter: $filterJson', name: 'TestableNostrService');
    }

    // Create a test stream that we can control
    _testStreamController = StreamController<Event>.broadcast();

    // Simulate receiving some test events after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_testStreamController != null && !_testStreamController!.isClosed) {
        Log.info(
          '📨 Injecting test event into stream',
          name: 'TestableNostrService',
        );

        // Use a valid hex pubkey (64 hex chars)
        final testEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          22, // Kind 22 for video
          [
            ['url', 'https://example.com/test-video.mp4'],
            ['m', 'video/mp4'],
            ['title', 'Debug Test Video'],
            ['duration', '30'],
          ],
          'Debug test video content',
        );

        _testStreamController!.add(testEvent);
      }
    });

    return _testStreamController!.stream;
  }

  @override
  Future<void> dispose() async {
    _testStreamController?.close();
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Debug: Trace VideoEventService event handling', () async {
    // Enable maximum logging
    Log.setLogLevel(LogLevel.verbose);
    Log.enableCategories({
      LogCategory.system,
      LogCategory.relay,
      LogCategory.video,
      LogCategory.auth,
    });

    Log.info('🔍 Starting debug test for VideoEventService', name: 'DebugTest');

    // Create a simple key manager without SharedPreferences
    final keyManager = NostrKeyManager();
    // Skip initialization to avoid SharedPreferences

    // Create our testable service
    final nostrService = TestableNostrService(keyManager);

    // Set up the service state manually
    // This is a hack but allows us to test without SharedPreferences

    Log.info('📡 Creating VideoEventService', name: 'DebugTest');
    final subscriptionManager = SubscriptionManager(nostrService);
    final videoEventService = VideoEventService(
      nostrService,
      subscriptionManager: subscriptionManager,
    );

    // Note: VideoEventService no longer extends ChangeNotifier after refactor
    // Tracking state changes via periodic checks instead of listeners
    void logServiceState(String context) {
      Log.info('📊 VideoEventService state ($context):', name: 'DebugTest');
      Log.info(
        '  - Event count: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
        name: 'DebugTest',
      );
      Log.info(
        '  - Has events: ${videoEventService.hasEvents(SubscriptionType.discovery)}',
        name: 'DebugTest',
      );
      Log.info(
        '  - Is subscribed: ${videoEventService.isSubscribed(SubscriptionType.discovery)}',
        name: 'DebugTest',
      );
    }

    // Check initial state
    logServiceState('initial');

    // Subscribe to video feed
    Log.info('🚀 Calling subscribeToVideoFeed...', name: 'DebugTest');
    try {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );
      Log.info(
        '✅ subscribeToVideoFeed completed successfully',
        name: 'DebugTest',
      );
    } catch (e) {
      Log.error('❌ subscribeToVideoFeed failed: $e', name: 'DebugTest');
    }

    // Check state after subscription
    logServiceState('after subscription');
    Log.info('  - Error: ${videoEventService.error}', name: 'DebugTest');

    // Wait for events to arrive
    Log.info('⏳ Waiting for events...', name: 'DebugTest');
    await Future.delayed(const Duration(seconds: 2));

    // Final check
    logServiceState('final');
    Log.info(
      '  - Note: Change notifications no longer available after ChangeNotifier removal',
      name: 'DebugTest',
    );

    if (videoEventService.hasEvents(SubscriptionType.discovery)) {
      Log.info('📝 Events received:', name: 'DebugTest');
      for (final event in videoEventService.discoveryVideos) {
        Log.info(
          '  - Event: ${event.id} title="${event.title}"',
          name: 'DebugTest',
        );
      }
    } else {
      Log.error(
        '❌ No events received! This confirms the bug.',
        name: 'DebugTest',
      );
    }

    // The key assertion
    expect(
      videoEventService.hasEvents,
      true,
      reason:
          'VideoEventService should have received and processed the test event. '
          'If this fails, the bug is confirmed in the event handling chain.',
    );

    // Clean up
    videoEventService.dispose();
    nostrService.dispose();
  });
}
