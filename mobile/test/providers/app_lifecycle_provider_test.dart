// ABOUTME: Tests for app lifecycle provider (foreground/background state)
// ABOUTME: Verifies reactive lifecycle tracking and activeVideoIdProvider integration

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  test('activeVideoIdProvider returns video ID when in foreground', () {
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'v0',
        pubkey: 'pubkey-0',
        createdAt: nowUnix,
        content: 'Video 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/v0.mp4',
      ),
      VideoEvent(
        id: 'v1',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Video 1',
        timestamp: now,
        title: 'Video 1',
        videoUrl: 'https://example.com/v1.mp4',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        // Foreground true
        appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),

        // URL context: home index 1
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.home, videoIndex: 1),
          ),
        ),

        // Feed (two items)
        videosForHomeRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );

    // Should return video at index 1
    expect(container.read(activeVideoIdProvider), 'v1');

    container.dispose();
  });

  test('activeVideoIdProvider returns null when backgrounded', () {
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'v0',
        pubkey: 'pubkey-0',
        createdAt: nowUnix,
        content: 'Video 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/v0.mp4',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        // Foreground FALSE - backgrounded
        appForegroundProvider.overrideWithValue(const AsyncValue.data(false)),

        // URL context: home index 0
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.home, videoIndex: 0),
          ),
        ),

        // Feed (one item)
        videosForHomeRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );

    // Should return null when backgrounded
    expect(container.read(activeVideoIdProvider), isNull);

    container.dispose();
  });
}
