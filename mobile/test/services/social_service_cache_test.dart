import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks
@GenerateMocks([
  NostrClient,
  AuthService,
  SubscriptionManager,
  PersonalEventCacheService,
])
import 'social_service_cache_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocialService Cache Behavior', () {
    late SocialService socialService;
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;
    late MockPersonalEventCacheService mockPersonalEventCache;
    const testUserPubkey = 'test_user_pubkey_123';
    const testTargetPubkey = 'target_user_pubkey_456';

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();
      mockPersonalEventCache = MockPersonalEventCacheService();

      // Set up default stubs
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.fromIterable([]));
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          timeout: anyNamed('timeout'),
          priority: anyNamed('priority'),
        ),
      ).thenAnswer((_) async => 'test_subscription_id');

      // Set up PersonalEventCacheService mocks
      when(mockPersonalEventCache.isInitialized).thenReturn(true);
      when(mockPersonalEventCache.getEventsByKind(any)).thenReturn([]);
      when(mockPersonalEventCache.cacheUserEvent(any)).thenReturn(null);

      socialService = SocialService(
        mockNostrService,
        mockAuthService,
        subscriptionManager: mockSubscriptionManager,
        personalEventCache: mockPersonalEventCache,
      );
    });

    tearDown(() {
      socialService.dispose();
      resetMockitoState();
    });

    test(
      'FAILING TEST: should save follow list to SharedPreferences cache immediately after followUser',
      () async {
        // Mock successful Kind 3 event creation
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);
        final mockContactListEvent = Event(publicKey, 3, [
          ['p', testTargetPubkey],
        ], '');
        mockContactListEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 3,
            content: '',
            tags: [
              ['p', testTargetPubkey],
            ],
          ),
        ).thenAnswer((_) async => mockContactListEvent);

        when(mockNostrService.broadcast(mockContactListEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockContactListEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Follow a user
        await socialService.followUser(testTargetPubkey);

        // Verify the follow list is immediately cached in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final cachedFollowingKey = 'following_list_$testUserPubkey';
        final cachedFollowing = prefs.getString(cachedFollowingKey);

        // THIS TEST SHOULD PASS BUT CURRENTLY FAILS
        // because SocialService.followUser() does not call _saveFollowingListToCache()
        expect(
          cachedFollowing,
          isNotNull,
          reason:
              'Following list should be cached immediately after followUser()',
        );

        // Verify the cached data contains the followed user
        if (cachedFollowing != null) {
          final followingList = (jsonDecode(cachedFollowing) as List<dynamic>)
              .cast<String>();
          expect(
            followingList,
            contains(testTargetPubkey),
            reason:
                'Cached following list should contain the newly followed user',
          );
        }
      },
    );

    test(
      'FAILING TEST: should save follow list to SharedPreferences cache immediately after unfollowUser',
      () async {
        // First, follow a user
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);
        final followEvent = Event(publicKey, 3, [
          ['p', testTargetPubkey],
        ], '');
        followEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 3,
            content: '',
            tags: [
              ['p', testTargetPubkey],
            ],
          ),
        ).thenAnswer((_) async => followEvent);

        when(mockNostrService.broadcast(followEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: followEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        await socialService.followUser(testTargetPubkey);

        // Reset mocks for unfollow
        reset(mockAuthService);
        reset(mockNostrService);
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);

        // Now unfollow the user
        final unfollowEvent = Event(
          publicKey,
          3,
          [], // Empty tags list
          '',
        );
        unfollowEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(kind: 3, content: '', tags: []),
        ).thenAnswer((_) async => unfollowEvent);

        when(mockNostrService.broadcast(unfollowEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: unfollowEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        await socialService.unfollowUser(testTargetPubkey);

        // Verify the follow list is immediately cached in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final cachedFollowingKey = 'following_list_$testUserPubkey';
        final cachedFollowing = prefs.getString(cachedFollowingKey);

        // THIS TEST SHOULD PASS BUT CURRENTLY FAILS
        // because SocialService.unfollowUser() does not call _saveFollowingListToCache()
        expect(
          cachedFollowing,
          isNotNull,
          reason:
              'Following list should be cached immediately after unfollowUser()',
        );

        // Verify the cached data does NOT contain the unfollowed user
        if (cachedFollowing != null) {
          final followingList = (jsonDecode(cachedFollowing) as List<dynamic>)
              .cast<String>();
          expect(
            followingList,
            isNot(contains(testTargetPubkey)),
            reason:
                'Cached following list should NOT contain the unfollowed user',
          );
          expect(
            followingList,
            isEmpty,
            reason: 'Following list should be empty after unfollowing',
          );
        }
      },
    );

    test(
      'FAILING TEST: PersonalEventCacheService Kind 3 events should be used to populate cache on startup',
      () async {
        // Create a mock Kind 3 event that would be in PersonalEventCacheService
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);
        final cachedContactListEvent = Event(publicKey, 3, [
          ['p', 'user1'],
          ['p', 'user2'],
          ['p', 'user3'],
        ], '');
        cachedContactListEvent.sign(privateKey);

        // Mock PersonalEventCacheService to return the cached Kind 3 event
        when(
          mockPersonalEventCache.getEventsByKind(3),
        ).thenReturn([cachedContactListEvent]);

        // Create a new service instance (simulating app startup)
        final newService = SocialService(
          mockNostrService,
          mockAuthService,
          subscriptionManager: mockSubscriptionManager,
          personalEventCache: mockPersonalEventCache,
        );

        // Wait for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify SharedPreferences cache was updated during initialization
        final prefs = await SharedPreferences.getInstance();
        final cachedFollowingKey = 'following_list_$testUserPubkey';
        final cachedFollowing = prefs.getString(cachedFollowingKey);

        // THIS TEST SHOULD PASS BUT CURRENTLY FAILS
        // The PersonalEventCacheService load triggers cache save, but only if auth is ready
        expect(
          cachedFollowing,
          isNotNull,
          reason:
              'Following list should be cached during initialization from PersonalEventCacheService',
        );

        if (cachedFollowing != null) {
          final followingList = (jsonDecode(cachedFollowing) as List<dynamic>)
              .cast<String>();
          expect(followingList.length, 3);
          expect(followingList, containsAll(['user1', 'user2', 'user3']));
        }

        newService.dispose();
      },
    );
  });
}
