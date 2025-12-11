// ABOUTME: Factory helper for creating service instances in tests with proper dependencies
// ABOUTME: Provides consistent setup for VideoEventService, SocialService, and UserProfileService

import 'package:mockito/mockito.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';

/// Creates a VideoEventService with mocked dependencies for testing
VideoEventService createTestVideoEventService({
  required NostrClient mockNostrService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  when(mockNostrService.isInitialized).thenReturn(true);
  when(mockNostrService.connectedRelayCount).thenReturn(1);
  // Skip mocking subscribeToEvents for simplicity

  return VideoEventService(
    mockNostrService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Creates a SocialService with mocked dependencies for testing
SocialService createTestSocialService({
  required NostrClient mockNostrService,
  required AuthService mockAuthService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  // Skip mocking subscribeToEvents for simplicity
  when(mockAuthService.isAuthenticated).thenReturn(false);

  return SocialService(
    mockNostrService,
    mockAuthService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Creates a UserProfileService with mocked dependencies for testing
UserProfileService createTestUserProfileService({
  required NostrClient mockNostrService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  when(mockNostrService.isInitialized).thenReturn(true);
  // Skip mocking subscribeToEvents for simplicity

  return UserProfileService(
    mockNostrService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Sets up common mock behaviors for SubscriptionManager
void setupMockSubscriptionManager(SubscriptionManager mockSubscriptionManager) {
  // Skip complex mocking of createSubscription for simplicity

  // Skip mocking cancelSubscription for simplicity
}
