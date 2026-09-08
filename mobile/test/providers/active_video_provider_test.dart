// ABOUTME: Tests for the router-driven active video provider
// ABOUTME: Pins which route types hand playback off to a self-managing screen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group(activeVideoIdProvider, () {
    final video = VideoEvent(
      id: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      pubkey:
          '9f2c1d8a4b6e0f37c5d2a8b1e4f7092c3a6d5b8e1f0c4a7d2b9e6f3c0a5d8b1e',
      createdAt: 1755300000,
      content: 'video',
      timestamp: DateTime.utc(2026, 8, 16),
      videoUrl: 'https://example.com/video.mp4',
    );

    ProviderContainer containerFor(RouteContext context) {
      final container = ProviderContainer(
        overrides: [
          hasVisibleOverlayProvider.overrideWithValue(false),
          pageContextProvider.overrideWithValue(AsyncValue.data(context)),
          videosForExploreRouteProvider.overrideWithValue(
            AsyncValue.data(
              VideoFeedState(videos: [video], hasMoreContent: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // Positive control: proves the overridden route context really reaches
    // the provider, so the null expectations below cannot pass vacuously
    // through the "no page context" early return.
    test('resolves the video at the index for a feed-backed route', () {
      final container = containerFor(
        const RouteContext(type: RouteType.explore, videoIndex: 0),
      );

      expect(container.read(activeVideoIdProvider), video.stableId);
    });

    test('returns null for a feed-backed route when backgrounded', () {
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(
            () => _TestAppForegroundNotifier(false),
          ),
          hasVisibleOverlayProvider.overrideWithValue(false),
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.explore, videoIndex: 0),
            ),
          ),
          videosForExploreRouteProvider.overrideWithValue(
            AsyncValue.data(
              VideoFeedState(videos: [video], hasMoreContent: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(activeVideoIdProvider), isNull);
    });

    // Every fullscreen video route hands playback to a screen that owns its
    // own player. Profile joined them in #7680: resolving an active video
    // here needed a second video list, and the only one a Riverpod provider
    // could reach was a raw relay subscription that could disagree with the
    // REST-backed ProfileFeedCubit the screen actually renders.
    for (final type in const [
      RouteType.profile,
      RouteType.hashtag,
      RouteType.likedVideos,
      RouteType.pooledVideoFeed,
      RouteType.videoDetail,
      RouteType.videoFeed,
      RouteType.home,
    ]) {
      test('returns null for $type even at a video index', () {
        final container = containerFor(
          RouteContext(type: type, videoIndex: 0),
        );

        expect(container.read(activeVideoIdProvider), isNull);
      });
    }
  });
}

class _TestAppForegroundNotifier extends AppForeground {
  _TestAppForegroundNotifier(this._initialValue);

  final bool _initialValue;

  @override
  bool build() => _initialValue;
}
