// ABOUTME: Unit tests for profile editing race condition fix using AsyncUtils.retryWithBackoff
// ABOUTME: Tests the retry logic that waits for relay to process profile updates before refreshing cache

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/async_utils.dart';

import 'profile_editing_race_condition_test.mocks.dart';

@GenerateMocks([UserProfileService])
void main() {
  group('Profile Editing Race Condition Fix', () {
    late MockUserProfileService mockUserProfileService;
    late String testPubkey;
    late String testEventId;
    late int testTimestamp;
    late UserProfile updatedProfile;
    late UserProfile staleProfile;

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      testPubkey =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      testEventId = 'test-event-id-123';
      testTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create updated profile that matches the event
      updatedProfile = UserProfile.fromJson({
        'pubkey': testPubkey,
        'name': 'updated-name',
        'about': 'updated-bio',
        'event_id': testEventId,
        'created_at': testTimestamp * 1000, // Convert to milliseconds
      });

      // Create stale profile (older timestamp)
      staleProfile = UserProfile.fromJson({
        'pubkey': testPubkey,
        'name': 'old-name',
        'about': 'old-bio',
        'event_id': 'old-event-id',
        'created_at': (testTimestamp - 60) * 1000, // 1 minute older
      });
    });

    test('should retry until updated profile is fetched', () async {
      // Setup: Use a call counter to return different results
      var callCount = 0;
      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount <= 2) {
          return staleProfile; // First two attempts return stale
        } else {
          return updatedProfile; // Third attempt returns updated
        }
      });

      // Execute the retry logic
      final result = await AsyncUtils.retryWithBackoff(
        operation: () async {
          mockUserProfileService.removeProfile(testPubkey);
          final profile = await mockUserProfileService.fetchProfile(
            testPubkey,
            forceRefresh: true,
          );

          // Same validation logic as in the actual code
          final eventIdMatches = profile?.eventId == testEventId;
          final timestampMatches =
              profile?.createdAt != null &&
              profile!.createdAt.millisecondsSinceEpoch >=
                  (testTimestamp * 1000 - 1000);

          if (eventIdMatches || timestampMatches) {
            return profile;
          }
          throw Exception('Profile not yet updated on relay - retrying...');
        },
        maxRetries: 3,
        baseDelay: const Duration(milliseconds: 100), // Faster for tests
        debugName: 'test-profile-refresh',
      );

      // Verify
      expect(result, equals(updatedProfile));
      expect(result?.eventId, equals(testEventId));
      expect(result?.name, equals('updated-name'));

      // Verify retry calls
      verify(mockUserProfileService.removeProfile(testPubkey)).called(3);
      verify(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).called(3);
    });

    test(
      'should succeed immediately if first fetch returns updated profile',
      () async {
        // Setup: First attempt returns updated profile
        when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
        when(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).thenAnswer((_) async => updatedProfile);

        // Execute
        final result = await AsyncUtils.retryWithBackoff(
          operation: () async {
            mockUserProfileService.removeProfile(testPubkey);
            final profile = await mockUserProfileService.fetchProfile(
              testPubkey,
              forceRefresh: true,
            );

            final eventIdMatches = profile?.eventId == testEventId;
            final timestampMatches =
                profile?.createdAt != null &&
                profile!.createdAt.millisecondsSinceEpoch >=
                    (testTimestamp * 1000 - 1000);

            if (eventIdMatches || timestampMatches) {
              return profile;
            }
            throw Exception('Profile not yet updated on relay - retrying...');
          },
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 100),
          debugName: 'test-profile-refresh',
        );

        // Verify
        expect(result, equals(updatedProfile));

        // Should only call once
        verify(mockUserProfileService.removeProfile(testPubkey)).called(1);
        verify(
          mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
        ).called(1);
      },
    );

    test('should fail after max retries if profile never updates', () async {
      // Setup: Always return stale profile
      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async => staleProfile);

      // Execute and expect failure
      expect(
        AsyncUtils.retryWithBackoff(
          operation: () async {
            mockUserProfileService.removeProfile(testPubkey);
            final profile = await mockUserProfileService.fetchProfile(
              testPubkey,
              forceRefresh: true,
            );

            final eventIdMatches = profile?.eventId == testEventId;
            final timestampMatches =
                profile?.createdAt != null &&
                profile!.createdAt.millisecondsSinceEpoch >=
                    (testTimestamp * 1000 - 1000);

            if (eventIdMatches || timestampMatches) {
              return profile;
            }
            throw Exception('Profile not yet updated on relay - retrying...');
          },
          maxRetries: 2, // Lower for faster test
          baseDelay: const Duration(milliseconds: 50),
          debugName: 'test-profile-refresh',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle null profile response', () async {
      // Setup: Return null profile
      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async => null);

      // Execute and expect failure
      expect(
        AsyncUtils.retryWithBackoff(
          operation: () async {
            mockUserProfileService.removeProfile(testPubkey);
            final profile = await mockUserProfileService.fetchProfile(
              testPubkey,
              forceRefresh: true,
            );

            final eventIdMatches = profile?.eventId == testEventId;
            final timestampMatches =
                profile?.createdAt != null &&
                profile!.createdAt.millisecondsSinceEpoch >=
                    (testTimestamp * 1000 - 1000);

            if (eventIdMatches || timestampMatches) {
              return profile;
            }
            throw Exception('Profile not yet updated on relay - retrying...');
          },
          maxRetries: 1,
          baseDelay: const Duration(milliseconds: 50),
          debugName: 'test-profile-refresh',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should validate event ID match correctly', () async {
      // Create profile with matching event ID but older timestamp
      final profileWithMatchingId = UserProfile.fromJson({
        'pubkey': testPubkey,
        'name': 'updated-name',
        'about': 'updated-bio',
        'event_id': testEventId, // Matching event ID
        'created_at': (testTimestamp - 30) * 1000, // Older timestamp
      });

      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async => profileWithMatchingId);

      final result = await AsyncUtils.retryWithBackoff(
        operation: () async {
          mockUserProfileService.removeProfile(testPubkey);
          final profile = await mockUserProfileService.fetchProfile(
            testPubkey,
            forceRefresh: true,
          );

          final eventIdMatches = profile?.eventId == testEventId;
          final timestampMatches =
              profile?.createdAt != null &&
              profile!.createdAt.millisecondsSinceEpoch >=
                  (testTimestamp * 1000 - 1000);

          if (eventIdMatches || timestampMatches) {
            return profile;
          }
          throw Exception('Profile not yet updated on relay - retrying...');
        },
        maxRetries: 1,
        baseDelay: const Duration(milliseconds: 50),
        debugName: 'test-profile-refresh',
      );

      // Should succeed due to matching event ID
      expect(result, equals(profileWithMatchingId));
      expect(result?.eventId, equals(testEventId));
    });

    test('should validate timestamp match correctly', () async {
      // Create profile with newer timestamp but different event ID
      final profileWithNewerTimestamp = UserProfile.fromJson({
        'pubkey': testPubkey,
        'name': 'updated-name',
        'about': 'updated-bio',
        'event_id': 'different-event-id',
        'created_at': (testTimestamp + 10) * 1000, // Newer timestamp
      });

      when(mockUserProfileService.removeProfile(testPubkey)).thenReturn(null);
      when(
        mockUserProfileService.fetchProfile(testPubkey, forceRefresh: true),
      ).thenAnswer((_) async => profileWithNewerTimestamp);

      final result = await AsyncUtils.retryWithBackoff(
        operation: () async {
          mockUserProfileService.removeProfile(testPubkey);
          final profile = await mockUserProfileService.fetchProfile(
            testPubkey,
            forceRefresh: true,
          );

          final eventIdMatches = profile?.eventId == testEventId;
          final timestampMatches =
              profile?.createdAt != null &&
              profile!.createdAt.millisecondsSinceEpoch >=
                  (testTimestamp * 1000 - 1000);

          if (eventIdMatches || timestampMatches) {
            return profile;
          }
          throw Exception('Profile not yet updated on relay - retrying...');
        },
        maxRetries: 1,
        baseDelay: const Duration(milliseconds: 50),
        debugName: 'test-profile-refresh',
      );

      // Should succeed due to valid timestamp
      expect(result, equals(profileWithNewerTimestamp));
      expect(
        result?.createdAt.millisecondsSinceEpoch,
        greaterThan(testTimestamp * 1000 - 1000),
      );
    });
  });
}
