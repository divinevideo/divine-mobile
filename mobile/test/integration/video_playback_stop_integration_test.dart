// ABOUTME: Integration test for video playback stopping behavior
// ABOUTME: Verifies videos stop on route changes and background

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('Video Playback Stop Integration Tests', () {
    // Create mock video data
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockHomeVideos = [
      VideoEvent(
        id: 'home-video-0',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Home Video 0',
        timestamp: now,
        title: 'Home Video 0',
        videoUrl: 'https://example.com/home0.mp4',
      ),
      VideoEvent(
        id: 'home-video-1',
        pubkey: 'pubkey-2',
        createdAt: nowUnix,
        content: 'Home Video 1',
        timestamp: now,
        title: 'Home Video 1',
        videoUrl: 'https://example.com/home1.mp4',
      ),
    ];

    final mockExploreVideos = [
      VideoEvent(
        id: 'explore-video-0',
        pubkey: 'pubkey-3',
        createdAt: nowUnix,
        content: 'Explore Video 0',
        timestamp: now,
        title: 'Explore Video 0',
        videoUrl: 'https://example.com/explore0.mp4',
      ),
      VideoEvent(
        id: 'explore-video-1',
        pubkey: 'pubkey-4',
        createdAt: nowUnix,
        content: 'Explore Video 1',
        timestamp: now,
        title: 'Explore Video 1',
        videoUrl: 'https://example.com/explore1.mp4',
      ),
    ];

    test(
      'activeVideoId changes to null when navigating to grid mode',
      () async {
        // Verify that navigating from video view to grid stops video playback
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Start at home video 0
        locationController.add('/home/0');
        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), equals('home-video-0'));
        expect(activeVideoIds.last, equals('home-video-0'));

        // Navigate to explore grid (no index)
        locationController.add('/explore');
        await pumpEventQueue();

        // Active video should be null (grid mode)
        expect(container.read(activeVideoIdProvider), isNull);
        expect(activeVideoIds.last, isNull);

        locationController.close();
        container.dispose();
      },
    );

    test(
      'activeVideoId changes when navigating between different feeds',
      () async {
        // Verify that navigating from home to explore changes active video
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            videosForExploreRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(
                  videos: mockExploreVideos,
                  hasMoreContent: false,
                ),
              );
            }),
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Start at home video 0
        locationController.add('/home/0');
        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), equals('home-video-0'));

        // Navigate to explore video 0
        locationController.add('/explore/0');
        await pumpEventQueue();

        // Active video should change to explore-video-0
        expect(
          container.read(activeVideoIdProvider),
          equals('explore-video-0'),
        );
        expect(activeVideoIds, contains('explore-video-0'));

        // Verify home video is no longer active
        final isHomeVideoActive = container.read(
          isVideoActiveProvider('home-video-0'),
        );
        final isExploreVideoActive = container.read(
          isVideoActiveProvider('explore-video-0'),
        );

        expect(isHomeVideoActive, isFalse);
        expect(isExploreVideoActive, isTrue);

        locationController.close();
        container.dispose();
      },
    );

    test('activeVideoId becomes null when app backgrounds', () async {
      // Verify that backgrounding the app stops video playback
      final locationController = StreamController<String>();
      final lifecycleController = StreamController<bool>();

      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => locationController.stream,
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
            );
          }),
          appForegroundProvider.overrideWith(
            (ref) => lifecycleController.stream,
          ),
        ],
      );

      // Track active video changes
      final activeVideoIds = <String?>[];
      container.listen(activeVideoIdProvider, (previous, next) {
        print('ACTIVE VIDEO: $previous → $next');
        activeVideoIds.add(next);
      }, fireImmediately: true);

      container.listen(pageContextProvider, (_, __) {}, fireImmediately: true);

      // Start with app in foreground and video playing
      lifecycleController.add(true);
      locationController.add('/home/0');
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(activeVideoIds.last, equals('home-video-0'));

      // Background the app
      lifecycleController.add(false);
      await pumpEventQueue();

      // Active video should become null
      expect(container.read(activeVideoIdProvider), isNull);
      expect(activeVideoIds.last, isNull);

      // Foreground the app again
      lifecycleController.add(true);
      await pumpEventQueue();

      // Video should become active again
      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(activeVideoIds.last, equals('home-video-0'));

      lifecycleController.close();
      locationController.close();
      container.dispose();
    });

    test('swiping between videos in same feed changes active video', () async {
      // Verify that swiping within home feed changes which video is active
      final locationController = StreamController<String>();

      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => locationController.stream,
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
            );
          }),
          appForegroundProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );

      // Track active video changes
      final activeVideoIds = <String?>[];
      container.listen(activeVideoIdProvider, (previous, next) {
        print('ACTIVE VIDEO: $previous → $next');
        activeVideoIds.add(next);
      }, fireImmediately: true);

      container.listen(pageContextProvider, (_, __) {}, fireImmediately: true);

      // Start at home video 0
      locationController.add('/home/0');
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(container.read(isVideoActiveProvider('home-video-0')), isTrue);
      expect(container.read(isVideoActiveProvider('home-video-1')), isFalse);

      // Swipe to home video 1
      locationController.add('/home/1');
      await pumpEventQueue();

      // Active video should change
      expect(container.read(activeVideoIdProvider), equals('home-video-1'));
      expect(container.read(isVideoActiveProvider('home-video-0')), isFalse);
      expect(container.read(isVideoActiveProvider('home-video-1')), isTrue);

      // Verify we saw both videos in the active video stream
      expect(
        activeVideoIds,
        containsAllInOrder(['home-video-0', 'home-video-1']),
      );

      locationController.close();
      container.dispose();
    });

    test(
      'defensive behavior: defaults to background if lifecycle provider not ready',
      () async {
        // Verify that if lifecycle provider hasn't emitted yet, we assume background
        final locationController = StreamController<String>();
        final lifecycleController = StreamController<bool>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            // Lifecycle provider stream but don't emit value yet
            appForegroundProvider.overrideWith(
              (ref) => lifecycleController.stream,
            ),
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Navigate to video without lifecycle being ready
        locationController.add('/home/0');
        await pumpEventQueue();

        // Should be null because lifecycle provider hasn't emitted (defensive default)
        expect(container.read(activeVideoIdProvider), isNull);

        // Now emit foreground state
        lifecycleController.add(true);
        await pumpEventQueue();

        // Now video should be active
        expect(container.read(activeVideoIdProvider), equals('home-video-0'));

        lifecycleController.close();
        locationController.close();
        container.dispose();
      },
    );
  });
}
