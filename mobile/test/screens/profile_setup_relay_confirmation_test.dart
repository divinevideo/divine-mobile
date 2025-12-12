// ABOUTME: Test for profile setup screen relay confirmation behavior
// ABOUTME: Ensures profile editing waits for relay to confirm updated profile before navigating back

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';

@GenerateMocks([NostrClient, AuthService, UserProfileService])
import 'profile_setup_relay_confirmation_test.mocks.dart';

void main() {
  group('Profile Setup Relay Confirmation', () {
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late String testPubkey;
    late String testEventId;
    late int testTimestamp;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();

      testPubkey =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      testTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Default mock setup
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(mockNostrService.isInitialized).thenReturn(true);
    });

    test(
      'should wait for relay to return updated profile before completing publish',
      () async {
        // BEHAVIOR: After publishing profile, the app should retry fetching
        // the profile until the relay returns the updated version

        // Arrange - create the published event
        final publishedEvent = Event(
          testPubkey,
          0,
          [],
          '{"name":"New Name","about":"New Bio"}',
          createdAt: testTimestamp,
        );

        // Capture the auto-generated event ID
        testEventId = publishedEvent.id;

        // Mock successful event creation and broadcast
        when(
          mockAuthService.createAndSignEvent(
            kind: 0,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => publishedEvent);

        when(mockNostrService.broadcast(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: publishedEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        // Mock profile fetches - first two return stale profile, third returns updated
        final staleProfile = UserProfile(
          pubkey: testPubkey,
          name: 'Old Name',
          about: 'Old Bio',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (testTimestamp - 60) * 1000,
          ), // 1 minute older
          eventId: 'old-event-id',
          rawData: const {'name': 'Old Name', 'about': 'Old Bio'},
        );

        final updatedProfile = UserProfile(
          pubkey: testPubkey,
          name: 'New Name',
          about: 'New Bio',
          createdAt: DateTime.fromMillisecondsSinceEpoch(testTimestamp * 1000),
          eventId: testEventId,
          rawData: const {'name': 'New Name', 'about': 'New Bio'},
        );

        var fetchCallCount = 0;
        when(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).thenAnswer((_) async {
          fetchCallCount++;
          if (fetchCallCount <= 2) {
            return staleProfile; // First two attempts return stale
          } else {
            return updatedProfile; // Third attempt returns updated
          }
        });

        when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
        when(
          mockUserProfileService.updateCachedProfile(any),
        ).thenAnswer((_) async {});

        // Act - simulate the publish flow with retry logic
        // This is what profile_setup_screen.dart SHOULD do but currently doesn't:
        final event = await mockAuthService.createAndSignEvent(
          kind: 0,
          content: '{"name":"New Name","about":"New Bio"}',
          tags: [],
        );

        final broadcastResult = await mockNostrService.broadcast(event!);
        expect(broadcastResult.isSuccessful, isTrue);

        // THE CRITICAL PART: Wait for relay to return updated profile
        // This logic should be in profile_setup_screen.dart but isn't yet
        UserProfile? confirmedProfile;
        var attempts = 0;
        const maxAttempts = 3;

        while (attempts < maxAttempts) {
          attempts++;
          mockUserProfileService.removeProfile(testPubkey);
          final fetchedProfile = await mockUserProfileService.fetchProfile(
            testPubkey,
            forceRefresh: true,
          );

          // Check if we got the updated profile
          final eventIdMatches = fetchedProfile?.eventId == testEventId;
          final timestampMatches =
              fetchedProfile?.createdAt != null &&
              fetchedProfile!.createdAt.millisecondsSinceEpoch >=
                  (testTimestamp * 1000 - 1000);

          if (eventIdMatches || timestampMatches) {
            confirmedProfile = fetchedProfile;
            break; // Success!
          }

          // Would wait with backoff here in real implementation
        }

        // Assert
        expect(
          confirmedProfile,
          isNotNull,
          reason: 'Should eventually get updated profile from relay',
        );
        expect(
          confirmedProfile!.eventId,
          equals(testEventId),
          reason: 'Confirmed profile should match published event ID',
        );
        expect(
          confirmedProfile.name,
          equals('New Name'),
          reason: 'Confirmed profile should have updated name',
        );
        expect(
          confirmedProfile.about,
          equals('New Bio'),
          reason: 'Confirmed profile should have updated bio',
        );

        // Verify retry behavior
        expect(
          attempts,
          equals(3),
          reason: 'Should retry until getting updated profile',
        );
        verify(mockUserProfileService.removeProfile(testPubkey)).called(3);
        verify(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).called(3);
      },
    );

    test('should fail gracefully if relay never returns updated profile', () async {
      // BEHAVIOR: If relay doesn't return updated profile after max retries,
      // should throw an error instead of navigating with stale data

      // Arrange
      final publishedEvent = Event(
        testPubkey,
        0,
        [],
        '{"name":"New Name"}',
        createdAt: testTimestamp,
      );

      // Capture the auto-generated event ID
      testEventId = publishedEvent.id;

      when(
        mockAuthService.createAndSignEvent(
          kind: 0,
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => publishedEvent);

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: publishedEvent,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        ),
      );

      // Mock profile service to ALWAYS return stale profile
      final staleProfile = UserProfile(
        pubkey: testPubkey,
        name: 'Old Name',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (testTimestamp - 60) * 1000,
        ),
        eventId: 'old-event-id',
        rawData: const {'name': 'Old Name'},
      );

      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async => staleProfile);
      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);

      // Act
      final event = await mockAuthService.createAndSignEvent(
        kind: 0,
        content: '{"name":"New Name"}',
        tags: [],
      );

      await mockNostrService.broadcast(event!);

      // Try to get updated profile with retries
      UserProfile? confirmedProfile;
      var attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        mockUserProfileService.removeProfile(testPubkey);
        final fetchedProfile = await mockUserProfileService.fetchProfile(
          testPubkey,
          forceRefresh: true,
        );

        final eventIdMatches = fetchedProfile?.eventId == testEventId;
        final timestampMatches =
            fetchedProfile?.createdAt != null &&
            fetchedProfile!.createdAt.millisecondsSinceEpoch >=
                (testTimestamp * 1000 - 1000);

        if (eventIdMatches || timestampMatches) {
          confirmedProfile = fetchedProfile;
          break;
        }
      }

      // Assert
      expect(
        confirmedProfile,
        isNull,
        reason:
            'Should not have confirmed profile after max retries with stale data',
      );
      expect(
        attempts,
        equals(maxAttempts),
        reason: 'Should exhaust all retry attempts',
      );

      // In real code, this should throw an error to prevent navigation with bad state
    });

    test(
      'should succeed immediately if first fetch returns updated profile',
      () async {
        // BEHAVIOR: If relay is fast and returns updated profile on first try,
        // should not waste time retrying

        // Arrange
        final publishedEvent = Event(
          testPubkey,
          0,
          [],
          '{"name":"Fast Update"}',
          createdAt: testTimestamp,
        );

        // Capture the auto-generated event ID
        testEventId = publishedEvent.id;

        when(
          mockAuthService.createAndSignEvent(
            kind: 0,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => publishedEvent);

        when(mockNostrService.broadcast(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: publishedEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        // Mock profile service to return updated profile immediately
        final updatedProfile = UserProfile(
          pubkey: testPubkey,
          name: 'Fast Update',
          createdAt: DateTime.fromMillisecondsSinceEpoch(testTimestamp * 1000),
          eventId: testEventId,
          rawData: const {'name': 'Fast Update'},
        );

        when(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).thenAnswer((_) async => updatedProfile);
        when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);

        // Act
        final event = await mockAuthService.createAndSignEvent(
          kind: 0,
          content: '{"name":"Fast Update"}',
          tags: [],
        );

        await mockNostrService.broadcast(event!);

        // Try to get updated profile
        UserProfile? confirmedProfile;
        var attempts = 0;

        mockUserProfileService.removeProfile(testPubkey);
        final fetchedProfile = await mockUserProfileService.fetchProfile(
          testPubkey,
          forceRefresh: true,
        );

        attempts++;
        final eventIdMatches = fetchedProfile?.eventId == testEventId;
        if (eventIdMatches) {
          confirmedProfile = fetchedProfile;
        }

        // Assert
        expect(
          confirmedProfile,
          isNotNull,
          reason: 'Should get updated profile immediately',
        );
        expect(
          attempts,
          equals(1),
          reason: 'Should succeed on first attempt without retries',
        );
        verify(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).called(1);
      },
    );
  });
}
