// ABOUTME: Integration tests for profile update functionality and event handling
// ABOUTME: Tests the fixed timestamp comparison logic and profile refresh flow

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';

@GenerateMocks([NostrClient, SubscriptionManager])
import 'profile_update_test.mocks.dart';

void main() {
  group('UserProfileService - Profile Update Tests', () {
    late UserProfileService service;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      when(mockNostrService.isInitialized).thenReturn(true);

      service = UserProfileService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    test('should accept profile update with different event ID', () async {
      // Given
      final pubkey = 'a' * 64; // Valid 64-char hex pubkey
      final oldEventId = 'old_event_123';
      final newEventId = 'new_event_456';
      final timestamp = DateTime.now();

      // Create old profile event
      final oldEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Old Name","about":"Old bio"}',
        createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
      );
      oldEvent.id = oldEventId;
      oldEvent.sig = 'sig1';

      // Create new profile event with same timestamp but different ID
      final newEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"New Name","about":"New bio"}',
        createdAt: timestamp.millisecondsSinceEpoch ~/ 1000, // Same timestamp
      );
      newEvent.id = newEventId;
      newEvent.sig = 'sig2';

      // Initialize service
      await service.initialize();

      // Process old event first
      service.handleProfileEventForTesting(oldEvent);

      // Verify old profile is cached
      var cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Old Name'));
      expect(cachedProfile.eventId, equals(oldEventId));

      // Process new event with different ID
      service.handleProfileEventForTesting(newEvent);

      // Verify new profile replaced the old one
      cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('New Name'));
      expect(cachedProfile.eventId, equals(newEventId));
    });

    test('should accept profile update with newer timestamp', () async {
      // Given
      final pubkey = 'b' * 64; // Valid 64-char hex pubkey
      final eventId1 = 'event_1';
      final eventId2 = 'event_2';
      final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 5));
      final newTimestamp = DateTime.now();

      // Create old profile event
      final oldEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Original","picture":"https://old.jpg"}',
        createdAt: oldTimestamp.millisecondsSinceEpoch ~/ 1000,
      );
      oldEvent.id = eventId1;
      oldEvent.sig = 'sig1';

      // Create new profile event with newer timestamp
      final newEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Updated","picture":"https://new.jpg"}',
        createdAt: newTimestamp.millisecondsSinceEpoch ~/ 1000,
      );
      newEvent.id = eventId2;
      newEvent.sig = 'sig2';

      // Initialize service
      await service.initialize();

      // Process old event
      service.handleProfileEventForTesting(oldEvent);

      // Verify old profile
      var cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Original'));
      expect(cachedProfile.picture, equals('https://old.jpg'));

      // Process newer event
      service.handleProfileEventForTesting(newEvent);

      // Verify profile was updated
      cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Updated'));
      expect(cachedProfile.picture, equals('https://new.jpg'));
    });

    test('should reject older profile events with same event ID', () async {
      // Given
      final pubkey = 'c' * 64; // Valid 64-char hex pubkey
      final eventId = 'same_event'; // Same event ID for both
      final newerTimestamp = DateTime.now();
      final olderTimestamp = DateTime.now().subtract(const Duration(hours: 1));

      // Create newer profile event
      final newerEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Current Name","about":"Current bio"}',
        createdAt: newerTimestamp.millisecondsSinceEpoch ~/ 1000,
      );
      newerEvent.id = eventId;
      newerEvent.sig = 'sig1';

      // Create older profile event with SAME event ID (simulating a replay)
      final olderEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Old Name","about":"Old bio"}',
        createdAt: olderTimestamp.millisecondsSinceEpoch ~/ 1000,
      );
      olderEvent.id = eventId; // Same event ID
      olderEvent.sig = 'sig2';

      // Initialize service
      await service.initialize();

      // Process newer event first
      service.handleProfileEventForTesting(newerEvent);

      // Verify newer profile is cached
      var cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Current Name'));
      expect(cachedProfile.eventId, equals(eventId));

      // Try to process older event with same ID
      service.handleProfileEventForTesting(olderEvent);

      // Verify newer profile is still cached (older was rejected)
      cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Current Name'));
      expect(cachedProfile.eventId, equals(eventId));
    });

    test('should handle same-second profile updates', () async {
      // Given
      final pubkey = 'd' * 64; // Valid 64-char hex pubkey
      final eventId1 = 'first_event';
      final eventId2 = 'second_event';
      final timestamp = DateTime.now();
      final timestampSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;

      // Create first profile event
      final firstEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"First Update","about":"First bio"}',
        createdAt: timestampSeconds,
      );
      firstEvent.id = eventId1;
      firstEvent.sig = 'sig1';

      // Create second profile event with same timestamp but different ID
      final secondEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Second Update","about":"Second bio"}',
        createdAt: timestampSeconds, // Exact same timestamp
      );
      secondEvent.id = eventId2;
      secondEvent.sig = 'sig2';

      // Initialize service
      await service.initialize();

      // Process first event
      service.handleProfileEventForTesting(firstEvent);

      // Verify first profile
      var cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('First Update'));

      // Process second event with same timestamp
      service.handleProfileEventForTesting(secondEvent);

      // Verify second profile was accepted (different event ID)
      cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Second Update'));
      expect(cachedProfile.eventId, equals(eventId2));
    });

    test('should force refresh profile with forceRefresh parameter', () async {
      // Given
      final pubkey = 'e' * 64; // Valid 64-char hex pubkey
      final eventId = 'event_123';

      // Create profile event
      final profileEvent = Event(
        pubkey,
        0, // kind
        [],
        '{"name":"Test User","about":"Test bio"}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      profileEvent.id = eventId;
      profileEvent.sig = 'sig1';

      // Setup mock subscription manager
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      ).thenAnswer((_) async => 'sub_123');

      // Initialize service
      await service.initialize();

      // Cache initial profile
      service.handleProfileEventForTesting(profileEvent);

      // Verify profile is cached
      var cachedProfile = service.getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Test User'));

      // Force refresh should clear cache and create new subscription
      await service.fetchProfile(pubkey, forceRefresh: true);

      // Verify subscription was created
      verify(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      ).called(1);
    });
  });
}
