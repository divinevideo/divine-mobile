// ABOUTME: Unit tests for profile stats calculation logic
// ABOUTME: Tests summing loops and likes from videos using VideoEventService

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import '../builders/video_event_builder.dart';

@GenerateMocks([SocialService, VideoEventService])
import 'profile_stats_calculation_test.mocks.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for tests
    Hive.init('./test_hive');
  });

  tearDownAll(() async {
    // Clean up Hive
    await Hive.close();
  });

  group('ProfileStats Calculation', () {
    const testPubkey = 'test_pubkey_123';

    tearDown(() async {
      // Clean up Hive boxes between tests
      try {
        await Hive.deleteBoxFromDisk('profile_stats_cache');
      } catch (e) {
        // Ignore if box doesn't exist
      }
    });

    test('calculates total loops and likes from videos', () async {
      // Create test videos with known loop/like counts
      final videos = [
        VideoEventBuilder(
          originalLoops: 100,
          originalLikes: 50,
        ).fromUser(testPubkey).build(),
        VideoEventBuilder(
          originalLoops: 200,
          originalLikes: 75,
        ).fromUser(testPubkey).build(),
        VideoEventBuilder(
          originalLoops: 150,
          originalLikes: 25,
        ).fromUser(testPubkey).build(),
      ];

      // Create mocks
      final mockSocialService = MockSocialService();
      final mockVideoEventService = MockVideoEventService();

      // Stub social service
      when(
        mockSocialService.getCachedFollowerStats(testPubkey),
      ).thenReturn({'followers': 10, 'following': 20});
      when(
        mockSocialService.getFollowerStats(testPubkey),
      ).thenAnswer((_) async => {'followers': 10, 'following': 20});

      // Stub video event service
      when(
        mockVideoEventService.subscribeToUserVideos(testPubkey, limit: 100),
      ).thenAnswer((_) async => {});
      when(mockVideoEventService.authorVideos(testPubkey)).thenReturn(videos);

      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
      addTearDown(container.dispose);

      // Wait for stats to load
      final stats = await container.read(
        fetchProfileStatsProvider(testPubkey).future,
      );

      // Verify totals: 100 + 200 + 150 = 450 loops, 50 + 75 + 25 = 150 likes
      expect(
        stats.totalViews,
        equals(450),
        reason: 'Should sum all loops from videos',
      );
      expect(
        stats.totalLikes,
        equals(150),
        reason: 'Should sum all likes from videos',
      );
      expect(
        stats.videoCount,
        equals(3),
        reason: 'Should report correct video count',
      );
      expect(stats.followers, equals(10));
      expect(stats.following, equals(20));
    });

    test('handles videos with null loop/like counts', () async {
      final videos = [
        VideoEventBuilder(
          originalLoops: 100,
          originalLikes: null, // null likes
        ).fromUser(testPubkey).build(),
        VideoEventBuilder(
          originalLoops: null, // null loops
          originalLikes: 50,
        ).fromUser(testPubkey).build(),
        VideoEventBuilder(
          originalLoops: null,
          originalLikes: null, // both null
        ).fromUser(testPubkey).build(),
      ];

      final mockSocialService = MockSocialService();
      final mockVideoEventService = MockVideoEventService();

      when(
        mockSocialService.getCachedFollowerStats(testPubkey),
      ).thenReturn({'followers': 0, 'following': 0});
      when(
        mockSocialService.getFollowerStats(testPubkey),
      ).thenAnswer((_) async => {'followers': 0, 'following': 0});

      when(
        mockVideoEventService.subscribeToUserVideos(testPubkey, limit: 100),
      ).thenAnswer((_) async => {});
      when(mockVideoEventService.authorVideos(testPubkey)).thenReturn(videos);

      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        fetchProfileStatsProvider(testPubkey).future,
      );

      // Should treat null as 0
      expect(
        stats.totalViews,
        equals(100),
        reason: 'Should treat null loops as 0',
      );
      expect(
        stats.totalLikes,
        equals(50),
        reason: 'Should treat null likes as 0',
      );
    });

    test('handles empty video list', () async {
      final mockSocialService = MockSocialService();
      final mockVideoEventService = MockVideoEventService();

      when(
        mockSocialService.getCachedFollowerStats(testPubkey),
      ).thenReturn({'followers': 5, 'following': 10});
      when(
        mockSocialService.getFollowerStats(testPubkey),
      ).thenAnswer((_) async => {'followers': 5, 'following': 10});

      when(
        mockVideoEventService.subscribeToUserVideos(testPubkey, limit: 100),
      ).thenAnswer((_) async => {});
      when(mockVideoEventService.authorVideos(testPubkey)).thenReturn([]);

      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        fetchProfileStatsProvider(testPubkey).future,
      );

      expect(
        stats.totalViews,
        equals(0),
        reason: 'Empty list should have 0 views',
      );
      expect(
        stats.totalLikes,
        equals(0),
        reason: 'Empty list should have 0 likes',
      );
      expect(stats.videoCount, equals(0));
    });

    test('calculates stats for videos with only loops (no likes)', () async {
      final videos = [
        VideoEventBuilder(
          originalLoops: 1000,
          originalLikes: 0, // has loops but no likes
        ).fromUser(testPubkey).build(),
        VideoEventBuilder(
          originalLoops: 2000,
          originalLikes: 0,
        ).fromUser(testPubkey).build(),
      ];

      final mockSocialService = MockSocialService();
      final mockVideoEventService = MockVideoEventService();

      when(
        mockSocialService.getCachedFollowerStats(testPubkey),
      ).thenReturn({'followers': 0, 'following': 0});
      when(
        mockSocialService.getFollowerStats(testPubkey),
      ).thenAnswer((_) async => {'followers': 0, 'following': 0});

      when(
        mockVideoEventService.subscribeToUserVideos(testPubkey, limit: 100),
      ).thenAnswer((_) async => {});
      when(mockVideoEventService.authorVideos(testPubkey)).thenReturn(videos);

      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        fetchProfileStatsProvider(testPubkey).future,
      );

      expect(
        stats.totalViews,
        equals(3000),
        reason: 'Should sum loops even with 0 likes',
      );
      expect(
        stats.totalLikes,
        equals(0),
        reason: 'Should correctly report 0 likes',
      );
    });

    test('uses cached follower stats to avoid network delay', () async {
      final videos = [
        VideoEventBuilder(
          originalLoops: 50,
          originalLikes: 25,
        ).fromUser(testPubkey).build(),
      ];

      final mockSocialService = MockSocialService();
      final mockVideoEventService = MockVideoEventService();

      // Mock cached stats
      when(
        mockSocialService.getCachedFollowerStats(testPubkey),
      ).thenReturn({'followers': 100, 'following': 200});

      // Network call should complete later (simulating 8s delay)
      when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer((
        _,
      ) async {
        await Future.delayed(const Duration(seconds: 8));
        return {'followers': 100, 'following': 200};
      });

      when(
        mockVideoEventService.subscribeToUserVideos(testPubkey, limit: 100),
      ).thenAnswer((_) async => {});
      when(mockVideoEventService.authorVideos(testPubkey)).thenReturn(videos);

      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
      addTearDown(container.dispose);

      // Stats should load immediately using cached values
      final stats = await container.read(
        fetchProfileStatsProvider(testPubkey).future,
      );

      // Verify it used cached stats (not waiting for network)
      expect(
        stats.followers,
        equals(100),
        reason: 'Should use cached follower count',
      );
      expect(
        stats.following,
        equals(200),
        reason: 'Should use cached following count',
      );
      expect(stats.totalViews, equals(50));
      expect(stats.totalLikes, equals(25));
    });
  });
}
