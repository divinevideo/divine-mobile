import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/social_service.dart';

// Generate mocks
@GenerateMocks([SocialService])
import 'profile_stats_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // Create temporary directory for Hive testing
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      await tempDir.delete(recursive: true);
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('ProfileStatsProvider', () {
    late ProviderContainer container;
    late MockSocialService mockSocialService;

    setUp(() {
      mockSocialService = MockSocialService();
      container = ProviderContainer(
        overrides: [socialServiceProvider.overrideWithValue(mockSocialService)],
      );
    });

    tearDown(() async {
      container.dispose();
      // Clean up Hive between tests
      try {
        await clearAllProfileStatsCache();
        if (Hive.isBoxOpen('profile_stats_cache')) {
          await Hive.box('profile_stats_cache').close();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('FetchProfileStatsProvider (AsyncProvider)', () {
      const testPubkey = 'test_pubkey_async';

      test('should auto-fetch stats when watched', () async {
        // Mock social service responses
        when(
          mockSocialService.getFollowerStats(testPubkey),
        ).thenAnswer((_) async => {'followers': 100, 'following': 50});
        when(
          mockSocialService.getUserVideoCount(testPubkey),
        ).thenAnswer((_) async => 25);

        // Keep the provider alive by listening to it
        final sub = container.listen(
          fetchProfileStatsProvider(testPubkey),
          (previous, next) {},
        );

        // Wait for the future to complete
        final asyncValue = await container.read(
          fetchProfileStatsProvider(testPubkey).future,
        );

        // Verify stats were fetched automatically
        expect(asyncValue.videoCount, 25);
        expect(asyncValue.followers, 100);
        expect(asyncValue.following, 50);
        expect(asyncValue.totalLikes, 0);
        expect(asyncValue.totalViews, 0);

        // Verify service calls happened automatically
        verify(mockSocialService.getFollowerStats(testPubkey)).called(1);
        verify(mockSocialService.getUserVideoCount(testPubkey)).called(1);

        // Clean up
        sub.close();
      });

      test('should use cache on subsequent watches', () async {
        // First watch - should fetch
        when(
          mockSocialService.getFollowerStats(testPubkey),
        ).thenAnswer((_) async => {'followers': 100, 'following': 50});
        when(
          mockSocialService.getUserVideoCount(testPubkey),
        ).thenAnswer((_) async => 25);

        final stats1 = await container.read(
          fetchProfileStatsProvider(testPubkey).future,
        );
        expect(stats1.videoCount, 25);
        expect(stats1.followers, 100);

        // Clear interactions to verify no new calls
        clearInteractions(mockSocialService);

        // Second watch - should use cache
        final stats2 = await container.read(
          fetchProfileStatsProvider(testPubkey).future,
        );
        expect(stats2.videoCount, 25);
        expect(stats2.followers, 100);

        // Should NOT have called services again (cache hit)
        verifyNever(mockSocialService.getFollowerStats(any));
        verifyNever(mockSocialService.getUserVideoCount(any));
      });
    });

    group('Utility Methods', () {
      test('should format counts correctly', () {
        expect(formatProfileStatsCount(0), '0');
        expect(formatProfileStatsCount(999), '999');
        expect(formatProfileStatsCount(1000), '1k');
        expect(formatProfileStatsCount(1500), '1.5k');
        expect(formatProfileStatsCount(1000000), '1M');
        expect(formatProfileStatsCount(2500000), '2.5M');
        expect(formatProfileStatsCount(1000000000), '1B');
        expect(formatProfileStatsCount(3200000000), '3.2B');
      });
    });

    group('ProfileStats Model', () {
      test('should create ProfileStats correctly', () {
        final stats = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        expect(stats.videoCount, 25);
        expect(stats.totalLikes, 500);
        expect(stats.followers, 100);
        expect(stats.following, 50);
        expect(stats.totalViews, 1000);
      });

      test('should copy ProfileStats with changes', () {
        final original = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final updated = original.copyWith(videoCount: 30, totalLikes: 600);

        expect(updated.videoCount, 30);
        expect(updated.totalLikes, 600);
        expect(updated.followers, 100); // Unchanged
        expect(updated.following, 50); // Unchanged
        expect(updated.totalViews, 1000); // Unchanged
      });

      test('should have meaningful toString', () {
        final stats = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final string = stats.toString();
        expect(string, contains('25'));
        expect(string, contains('500'));
        expect(string, contains('100'));
        expect(string, contains('50'));
        expect(string, contains('1000'));
      });
    });
  });
}
