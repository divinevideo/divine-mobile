// ABOUTME: Factory helper for creating service instances in tests with proper dependencies
// ABOUTME: Provides consistent setup for VideoEventService

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

/// Creates a VideoEventService with mocked dependencies for testing
VideoEventService createTestVideoEventService({
  required NostrClient mockNostrService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  when(() => mockNostrService.isInitialized).thenReturn(true);
  when(() => mockNostrService.connectedRelayCount).thenReturn(1);
  // Skip mocking subscribeToEvents for simplicity

  return VideoEventService(
    mockNostrService,
    subscriptionManager: mockSubscriptionManager,
    crashReporter: const SilentCrashReporter(),
  );
}

/// Sets up common mock behaviors for SubscriptionManager
void setupMockSubscriptionManager(SubscriptionManager mockSubscriptionManager) {
  // Skip complex mocking of createSubscription for simplicity

  // Skip mocking cancelSubscription for simplicity
}
