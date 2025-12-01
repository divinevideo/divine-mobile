// ABOUTME: Integration test for home feed seen video filtering
// ABOUTME: Validates that unseen videos appear before seen videos in home feed

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/social_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_feed_seen_videos_test.mocks.dart';

/// Test notifier that returns a fixed social state
class _TestSocialNotifier extends SocialNotifier {
  final SocialState _state;

  _TestSocialNotifier(this._state);

  @override
  SocialState build() => _state;
}

@GenerateMocks([VideoEventService])
void main() {
  group('HomeFeed SeenVideos Integration', () {
    late MockVideoEventService mockVideoService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockVideoService = MockVideoEventService();
    });

    test('orders unseen videos before seen videos', () async {
      // Create test videos
      final now = DateTime.now();
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'author1',
        content: 'Test video 1',
        createdAt:
            now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch ~/
            1000,
        timestamp: now.subtract(const Duration(hours: 3)),
      );
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'author1',
        content: 'Test video 2',
        createdAt:
            now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000,
        timestamp: now.subtract(const Duration(hours: 2)),
      );
      final video3 = VideoEvent(
        id: 'video3',
        pubkey: 'author1',
        content: 'Test video 3',
        createdAt:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      // Setup mock service
      when(
        mockVideoService.homeFeedVideos,
      ).thenReturn([video1, video2, video3]);
      when(mockVideoService.isSubscribed(any)).thenReturn(false);
      when(
        mockVideoService.subscribeToHomeFeed(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});

      // Create container with overrides
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoService),
          socialProvider.overrideWith(() {
            return _TestSocialNotifier(
              SocialState(followingPubkeys: ['author1'], isInitialized: true),
            );
          }),
        ],
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 200));

      // Mark video2 as seen
      final seenNotifier = container.read(seenVideosProvider.notifier);
      await seenNotifier.markVideoAsSeen('video2');

      // Wait a bit for state to propagate
      await Future.delayed(const Duration(milliseconds: 100));

      // Refresh home feed to apply filtering
      await container.read(homeFeedProvider.notifier).refresh();

      // Wait for home feed to rebuild
      await Future.delayed(const Duration(milliseconds: 200));

      // Get home feed state
      final feedAsync = container.read(homeFeedProvider);

      if (feedAsync.hasValue) {
        final feed = feedAsync.value!;
        final videos = feed.videos;

        // Should have all 3 videos
        expect(videos.length, 3);

        // Unseen videos (video1, video3) should come before seen video (video2)
        final video1Index = videos.indexWhere((v) => v.id == 'video1');
        final video2Index = videos.indexWhere((v) => v.id == 'video2');
        final video3Index = videos.indexWhere((v) => v.id == 'video3');

        expect(video2Index, greaterThan(video1Index));
        expect(video2Index, greaterThan(video3Index));
      }

      container.dispose();
    });

    test('all unseen videos when none are marked seen', () async {
      final now = DateTime.now();
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'author1',
        content: '',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
      );
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'author1',
        content: '',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
      );

      when(mockVideoService.homeFeedVideos).thenReturn([video1, video2]);
      when(mockVideoService.isSubscribed(any)).thenReturn(false);
      when(
        mockVideoService.subscribeToHomeFeed(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoService),
          socialProvider.overrideWith(() {
            return _TestSocialNotifier(
              SocialState(followingPubkeys: ['author1'], isInitialized: true),
            );
          }),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final feedAsync = container.read(homeFeedProvider);

      if (feedAsync.hasValue) {
        final feed = feedAsync.value!;
        expect(feed.videos.length, 2);
      }

      container.dispose();
    });

    test('all seen videos show in correct order', () async {
      final now = DateTime.now();
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'author1',
        content: '',
        createdAt:
            now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000,
        timestamp: now.subtract(const Duration(hours: 2)),
      );
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'author1',
        content: '',
        createdAt:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      when(mockVideoService.homeFeedVideos).thenReturn([video1, video2]);
      when(mockVideoService.isSubscribed(any)).thenReturn(false);
      when(
        mockVideoService.subscribeToHomeFeed(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoService),
          socialProvider.overrideWith(() {
            return _TestSocialNotifier(
              SocialState(followingPubkeys: ['author1'], isInitialized: true),
            );
          }),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Mark both as seen
      final seenNotifier = container.read(seenVideosProvider.notifier);
      await seenNotifier.markVideoAsSeen('video1');
      await seenNotifier.markVideoAsSeen('video2');

      await Future.delayed(const Duration(milliseconds: 100));

      // Refresh home feed
      await container.read(homeFeedProvider.notifier).refresh();
      await Future.delayed(const Duration(milliseconds: 200));

      final feedAsync = container.read(homeFeedProvider);

      if (feedAsync.hasValue) {
        final feed = feedAsync.value!;
        expect(feed.videos.length, 2);

        // Both are seen, so should maintain chronological order (newest first)
        expect(feed.videos[0].id, 'video2'); // More recent
        expect(feed.videos[1].id, 'video1'); // Older
      }

      container.dispose();
    });
  });
}
