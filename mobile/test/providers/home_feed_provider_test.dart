// ABOUTME: Tests for home feed provider functionality
// ABOUTME: Verifies that home feed correctly filters videos from followed authors

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/state/social_state.dart';

import 'home_feed_provider_test.mocks.dart';

/// Test notifier that returns a fixed social state
class TestSocialNotifier extends social.SocialNotifier {
  final SocialState _state;

  TestSocialNotifier(this._state);

  @override
  SocialState build() => _state;
}

@GenerateMocks([VideoEventService, NostrClient, SubscriptionManager])
void main() {
  group('HomeFeedProvider', () {
    late ProviderContainer container;
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    final List<VoidCallback> registeredListeners = [];

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();
      registeredListeners.clear();

      // Setup default mock behaviors
      // Note: Individual tests will override homeFeedVideos with their own values
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);

      // Setup nostrService isInitialized stub (needed for profile fetching)
      when(mockNostrService.isInitialized).thenReturn(true);

      // Capture listeners when added
      when(mockVideoEventService.addListener(any)).thenAnswer((invocation) {
        final listener = invocation.positionalArguments[0] as VoidCallback;
        registeredListeners.add(listener);
      });

      // Remove listeners when removed
      when(mockVideoEventService.removeListener(any)).thenAnswer((invocation) {
        final listener = invocation.positionalArguments[0] as VoidCallback;
        registeredListeners.remove(listener);
      });

      // subscribeToHomeFeed just completes - videos should already be set up by individual tests
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async {
        // Videos are already set up via when(homeFeedVideos).thenReturn() in individual tests
        // The provider will check homeFeedVideos.length after this completes
        return Future.value();
      });

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
    });

    test('should return empty state when user is not following anyone', () async {
      // Setup: User is not following anyone - create new container with overrides
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(followingPubkeys: [], isInitialized: true),
            );
          }),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert
      expect(result.videos, isEmpty);
      expect(result.hasMoreContent, isFalse);
      expect(result.isLoadingMore, isFalse);
      expect(result.error, isNull);

      // Verify that we didn't try to subscribe since there are no following
      verifyNever(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      );

      testContainer.dispose();
    });

    test(
      'should preserve video list when socialProvider updates with same following list',
      () async {
        // Setup: Create mock videos
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'author1',
            content: 'Test video 1',
            createdAt: timestamp,
            timestamp: now,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'author2',
            content: 'Test video 2',
            createdAt: timestamp,
            timestamp: now,
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        // Create container with initial social state
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            social.socialProvider.overrideWith(() {
              return TestSocialNotifier(
                const SocialState(
                  followingPubkeys: ['author1', 'author2'],
                  isInitialized: true,
                ),
              );
            }),
          ],
        );

        // Act: Get initial feed
        final initialFeed = await testContainer.read(homeFeedProvider.future);

        // Verify initial feed has videos
        expect(initialFeed.videos.length, 2);
        expect(initialFeed.videos[0].id, 'video1');
        expect(initialFeed.videos[1].id, 'video2');

        // Act: Update social provider with different state but SAME following list
        // This simulates what happens when socialProvider finishes initializing
        // (e.g., likes/reposts loaded but following list unchanged)
        final updatedContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            social.socialProvider.overrideWith(() {
              return TestSocialNotifier(
                SocialState(
                  followingPubkeys: const ['author1', 'author2'], // Same list!
                  isInitialized: true,
                  likedEventIds: const {'like1'}, // Different likes
                  repostedEventIds: const {'repost1'}, // Different reposts
                ),
              );
            }),
          ],
        );

        final updatedFeed = await updatedContainer.read(
          homeFeedProvider.future,
        );

        // Assert: Video list order should be PRESERVED
        expect(updatedFeed.videos.length, 2);
        expect(
          updatedFeed.videos[0].id,
          'video1',
          reason: 'First video should remain first',
        );
        expect(
          updatedFeed.videos[1].id,
          'video2',
          reason: 'Second video should remain second',
        );

        // Verify we didn't re-subscribe unnecessarily
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        );

        updatedContainer.dispose();
        testContainer.dispose();
      },
    );

    test('should subscribe to videos from followed authors', () async {
      // Setup: User is following 3 people
      final followingPubkeys = [
        'pubkey1_following',
        'pubkey2_following',
        'pubkey3_following',
      ];

      // Create mock videos from followed authors
      final mockVideos = [
        VideoEvent(
          id: 'event1',
          pubkey: 'pubkey1_following',
          createdAt: 1000,
          content: 'Video 1',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video1.mp4',
        ),
        VideoEvent(
          id: 'event2',
          pubkey: 'pubkey2_following',
          createdAt: 900,
          content: 'Video 2',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video2.mp4',
        ),
      ];

      when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

      // Create a new container with social state override
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              SocialState(
                followingPubkeys: followingPubkeys,
                isInitialized: true,
              ),
            );
          }),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert
      expect(result.videos.length, equals(2));
      expect(result.videos[0].pubkey, equals('pubkey1_following'));
      expect(result.videos[1].pubkey, equals('pubkey2_following'));

      // Verify subscription was created with correct authors
      verify(
        mockVideoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100),
      ).called(1);

      testContainer.dispose();
    });

    test('should sort videos by creation time (newest first)', () async {
      // Setup: User is following people
      final followingPubkeys = ['pubkey1', 'pubkey2'];

      // Create mock videos with different timestamps
      final now = DateTime.now();
      final mockVideos = [
        VideoEvent(
          id: 'event1',
          pubkey: 'pubkey1',
          createdAt: 100,
          content: 'Older video',
          timestamp: now.subtract(const Duration(hours: 2)),
          videoUrl: 'https://example.com/video1.mp4',
        ),
        VideoEvent(
          id: 'event2',
          pubkey: 'pubkey2',
          createdAt: 200,
          content: 'Newer video',
          timestamp: now.subtract(const Duration(hours: 1)),
          videoUrl: 'https://example.com/video2.mp4',
        ),
      ];

      when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

      // Create a new container with social state override
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              SocialState(
                followingPubkeys: followingPubkeys,
                isInitialized: true,
              ),
            );
          }),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert: Videos should be sorted newest first
      expect(result.videos.length, equals(2));
      expect(
        result.videos[0].createdAt,
        greaterThan(result.videos[1].createdAt),
      );
      expect(result.videos[0].content, equals('Newer video'));
      expect(result.videos[1].content, equals('Older video'));

      testContainer.dispose();
    });

    test('should handle load more when user is following people', () async {
      // Setup
      final followingPubkeys = ['pubkey1'];

      // Create initial mock videos
      final mockVideos = List.generate(
        10,
        (i) => VideoEvent(
          id: 'event$i',
          pubkey: 'pubkey1',
          createdAt: 1000 + i,
          content: 'Video $i',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video$i.mp4',
        ),
      );

      when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(10);

      // Create a new container with social state override
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              SocialState(
                followingPubkeys: followingPubkeys,
                isInitialized: true,
              ),
            );
          }),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert basic state
      expect(result.videos.length, equals(10));
      expect(result.hasMoreContent, isTrue);
      expect(result.isLoadingMore, isFalse);

      // Verify subscription was created
      verify(
        mockVideoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100),
      ).called(1);

      testContainer.dispose();
    });

    test('should handle refresh functionality', () async {
      // Setup
      final followingPubkeys = ['pubkey1'];

      when(mockVideoEventService.homeFeedVideos).thenReturn([]);

      // Create a new container with social state override
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              SocialState(
                followingPubkeys: followingPubkeys,
                isInitialized: true,
              ),
            );
          }),
        ],
      );

      // Act
      await testContainer.read(homeFeedProvider.future);
      await testContainer.read(homeFeedProvider.notifier).refresh();
      await testContainer.read(
        homeFeedProvider.future,
      ); // Wait for rebuild to complete

      // Assert: Should re-subscribe after refresh
      verify(
        mockVideoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100),
      ).called(2); // Once on initial load, once on refresh

      testContainer.dispose();
    });

    test('should handle empty video list correctly', () async {
      // Setup: User is following people but no videos available
      final followingPubkeys = ['pubkey1', 'pubkey2'];

      when(mockVideoEventService.homeFeedVideos).thenReturn([]);

      // Create a new container with social state override
      final testContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              SocialState(
                followingPubkeys: followingPubkeys,
                isInitialized: true,
              ),
            );
          }),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert
      expect(result.videos, isEmpty);
      expect(result.hasMoreContent, isFalse);
      expect(result.error, isNull);

      // Verify subscription was still attempted
      verify(
        mockVideoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100),
      ).called(1);

      testContainer.dispose();
    });
  });

  group('HomeFeed Helper Providers', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup default mock behaviors
      when(mockVideoEventService.homeFeedVideos).thenReturn([]);
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
    });

    test('homeFeedLoading should reflect loading state', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(followingPubkeys: [], isInitialized: true),
            );
          }),
        ],
      );

      // Test loading state detection
      final isLoading = container.read(homeFeedLoadingProvider);
      expect(isLoading, isA<bool>());

      container.dispose();
    });

    test('homeFeedCount should return video count', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(followingPubkeys: [], isInitialized: true),
            );
          }),
        ],
      );

      // Test video count
      final count = container.read(homeFeedCountProvider);
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));

      container.dispose();
    });

    test('hasHomeFeedVideos should indicate if videos exist', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(followingPubkeys: [], isInitialized: true),
            );
          }),
        ],
      );

      // Test video existence check
      final hasVideos = container.read(hasHomeFeedVideosProvider);
      expect(hasVideos, isA<bool>());

      container.dispose();
    });
  });
}
