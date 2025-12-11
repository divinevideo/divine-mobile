// ABOUTME: Test for verifying profile fetching when videos are displayed
// ABOUTME: Ensures Kind 0 events are fetched and cached when viewing videos

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'dart:convert';

@GenerateMocks([NostrClient, SubscriptionManager, ProfileCacheService])
import 'profile_fetching_test.mocks.dart';

void main() {
  late UserProfileService profileService;
  late MockNostrClient mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockProfileCacheService mockCacheService;

  setUp(() {
    mockNostrService = MockNostrClient();
    mockSubscriptionManager = MockSubscriptionManager();
    mockCacheService = MockProfileCacheService();

    // Set up default mock behaviors
    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockCacheService.isInitialized).thenReturn(true);
    when(mockCacheService.getCachedProfile(any)).thenReturn(null);
    when(mockCacheService.shouldRefreshProfile(any)).thenReturn(false);

    profileService = UserProfileService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
    );
    profileService.setPersistentCache(mockCacheService);
  });

  group('Profile Fetching on Video Display', () {
    test(
      'should fetch profile when video is displayed without cached profile',
      () async {
        // Arrange
        const testPubkey = 'test_pubkey_123456789';
        const testSubscriptionId = 'sub_123';

        // Note: VideoEvent creation removed - not used in this test

        // Mock subscription creation
        when(
          mockSubscriptionManager.createSubscription(
            name: anyNamed('name'),
            filters: anyNamed('filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            priority: anyNamed('priority'),
          ),
        ).thenAnswer((_) async => testSubscriptionId);

        // Act - Simulate video display triggering profile fetch
        await profileService.initialize();
        final profileFuture = profileService.fetchProfile(testPubkey);

        // Assert - Verify subscription was created for Kind 0 event
        verify(
          mockSubscriptionManager.createSubscription(
            name: argThat(contains('profile'), named: 'name'),
            filters: argThat(
              predicate<List<Filter>>((filters) {
                if (filters.isEmpty) return false;
                final filter = filters.first;
                return filter.kinds!.contains(0) &&
                    filter.authors!.contains(testPubkey) &&
                    filter.limit == 1;
              }),
              named: 'filters',
            ),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            priority: anyNamed('priority'),
          ),
        ).called(1);

        // Verify profile is not yet available (async fetch)
        final profile = await profileFuture;
        expect(profile, isNull);

        // Verify profile is marked as pending
        expect(profileService.hasProfile(testPubkey), isFalse);
      },
    );

    test(
      'should handle and cache profile when Kind 0 event is received',
      () async {
        // Arrange
        const testPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // Valid 64-char hex pubkey
        const testName = 'Test User';
        const testDisplayName = 'TestUser123';
        const testAbout = 'This is a test user profile';
        const testPicture = 'https://example.com/avatar.jpg';

        // Create Kind 0 profile event
        final profileContent = jsonEncode({
          'name': testName,
          'display_name': testDisplayName,
          'about': testAbout,
          'picture': testPicture,
        });

        final profileEvent = Event(
          testPubkey,
          0, // kind
          [], // tags
          profileContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        // Set the id and sig manually since they're calculated fields
        profileEvent.id = 'profile_event_id';
        profileEvent.sig = 'profile_sig';

        // Act - Process the profile event
        await profileService.initialize();
        profileService.handleProfileEventForTesting(profileEvent);

        // Assert - Verify profile was cached
        final cachedProfile = profileService.getCachedProfile(testPubkey);
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals(testName));
        expect(cachedProfile.displayName, equals(testDisplayName));
        expect(cachedProfile.about, equals(testAbout));
        expect(cachedProfile.picture, equals(testPicture));
        expect(cachedProfile.bestDisplayName, equals(testDisplayName));

        // Verify persistent cache was updated
        verify(
          mockCacheService.cacheProfile(
            argThat(
              predicate<UserProfile>(
                (profile) =>
                    profile.pubkey == testPubkey &&
                    profile.name == testName &&
                    profile.displayName == testDisplayName,
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('should fetch multiple profiles in batch for video feed', () async {
      // Arrange
      final testPubkeys = [
        'pubkey_1',
        'pubkey_2',
        'pubkey_3',
        'pubkey_4',
        'pubkey_5',
      ];
      const testSubscriptionId = 'batch_sub_123';

      // Mock subscription creation for batch
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      ).thenAnswer((_) async => testSubscriptionId);

      // Act - Simulate batch profile fetch for video feed
      await profileService.initialize();
      await profileService.fetchMultipleProfiles(testPubkeys);

      // Small delay to allow debouncing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - Verify batch subscription was created
      verify(
        mockSubscriptionManager.createSubscription(
          name: argThat(contains('profile_batch'), named: 'name'),
          filters: argThat(
            predicate<List<Filter>>((filters) {
              if (filters.isEmpty) return false;
              final filter = filters.first;
              return filter.kinds!.contains(0) &&
                  filter.authors!.length == testPubkeys.length &&
                  testPubkeys.every((pk) => filter.authors!.contains(pk));
            }),
            named: 'filters',
          ),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      ).called(1);
    });

    test('should not fetch profile if already cached', () async {
      // Arrange
      const testPubkey = 'cached_pubkey_123';
      final cachedProfile = UserProfile(
        pubkey: testPubkey,
        name: 'Cached User',
        displayName: 'CachedUser',
        about: 'Already cached',
        picture: null,
        banner: null,
        website: null,
        lud06: null,
        lud16: null,
        nip05: null,
        createdAt: DateTime.now(),
        eventId: 'cached_event_id',
        rawData: {
          'name': 'Cached User',
          'display_name': 'CachedUser',
          'about': 'Already cached',
        },
      );

      // Mock cached profile
      when(
        mockCacheService.getCachedProfile(testPubkey),
      ).thenReturn(cachedProfile);

      // Act
      await profileService.initialize();
      final profile = await profileService.fetchProfile(testPubkey);

      // Assert - Verify no subscription was created
      verifyNever(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      );

      // Verify cached profile was returned
      expect(profile, equals(cachedProfile));
      expect(profileService.hasProfile(testPubkey), isTrue);
    });

    test('should handle profile fetch failure gracefully', () async {
      // Arrange
      const testPubkey = 'fail_pubkey_123';

      // Mock subscription creation that will fail
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          priority: anyNamed('priority'),
        ),
      ).thenThrow(Exception('Network error'));

      // Act
      await profileService.initialize();
      final profile = await profileService.fetchProfile(testPubkey);

      // Assert - Verify profile fetch returned null on error
      expect(profile, isNull);
      expect(profileService.hasProfile(testPubkey), isFalse);
    });

    test(
      'should provide fallback display name when profile not available',
      () async {
        // Arrange
        const testPubkey = 'no_profile_pubkey_123456789';

        // Act
        await profileService.initialize();
        final displayName = profileService.getDisplayName(testPubkey);

        // Assert - Verify fallback display name format
        expect(displayName, equals('User no_pro...'));
        expect(profileService.hasProfile(testPubkey), isFalse);
      },
    );
  });
}
