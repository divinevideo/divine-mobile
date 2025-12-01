// ABOUTME: Test for activeVideoIdProvider working correctly with explore route
// ABOUTME: Verifies videos at different indices become active when URL changes

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/router/router_location_provider.dart';

void main() {
  group('Explore Active Video Provider', () {
    // Create mock video data
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'explore-video-0',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Explore Video 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/video0.mp4',
      ),
      VideoEvent(
        id: 'explore-video-1',
        pubkey: 'pubkey-2',
        createdAt: nowUnix,
        content: 'Explore Video 1',
        timestamp: now,
        title: 'Video 1',
        videoUrl: 'https://example.com/video1.mp4',
      ),
      VideoEvent(
        id: 'explore-video-2',
        pubkey: 'pubkey-3',
        createdAt: nowUnix,
        content: 'Explore Video 2',
        timestamp: now,
        title: 'Video 2',
        videoUrl: 'https://example.com/video2.mp4',
      ),
    ];

    test('activeVideoIdProvider returns correct video at index 0', () async {
      final container = ProviderContainer(
        overrides: [
          // Mock router location to /explore/0
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value('/explore/0'),
          ),
          // Mock video events with our test data
          videoEventsProvider.overrideWith(() => VideoEventsMock(mockVideos)),
          // Mock app as foreground
          appForegroundProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );

      // Listen for page context to be emitted
      final pageContextStates = <AsyncValue<RouteContext>>[];
      container.listen(
        pageContextProvider,
        (previous, next) => pageContextStates.add(next),
        fireImmediately: true,
      );

      // Listen for video events to be emitted
      final videoEventsStates = <AsyncValue<List<VideoEvent>>>[];
      container.listen(
        videoEventsProvider,
        (previous, next) => videoEventsStates.add(next),
        fireImmediately: true,
      );

      // Start providers by reading them
      container.read(pageContextProvider);
      container.read(videoEventsProvider);

      // Wait for streams to emit
      await pumpEventQueue();

      // Read active video ID
      final activeVideoId = container.read(activeVideoIdProvider);

      // Should be the first video
      expect(activeVideoId, equals('explore-video-0'));

      // Verify isVideoActiveProvider works correctly
      final isVideo0Active = container.read(
        isVideoActiveProvider('explore-video-0'),
      );
      final isVideo1Active = container.read(
        isVideoActiveProvider('explore-video-1'),
      );

      expect(isVideo0Active, isTrue);
      expect(isVideo1Active, isFalse);

      container.dispose();
    });

    test('activeVideoIdProvider returns correct video at index 1', () async {
      final container = ProviderContainer(
        overrides: [
          // Mock router location to /explore/1
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value('/explore/1'),
          ),
          // Mock video events with our test data
          videoEventsProvider.overrideWith(() => VideoEventsMock(mockVideos)),
          // Mock app as foreground
          appForegroundProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );

      // Listen for streams to emit
      container.listen(
        pageContextProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      container.listen(
        videoEventsProvider,
        (previous, next) {},
        fireImmediately: true,
      );

      // Start providers by reading them
      container.read(pageContextProvider);
      container.read(videoEventsProvider);

      // Wait for async operations to complete
      await pumpEventQueue();

      // Read active video ID
      final activeVideoId = container.read(activeVideoIdProvider);

      // Should be the SECOND video (index 1)
      expect(activeVideoId, equals('explore-video-1'));

      // Verify isVideoActiveProvider works correctly
      final isVideo0Active = container.read(
        isVideoActiveProvider('explore-video-0'),
      );
      final isVideo1Active = container.read(
        isVideoActiveProvider('explore-video-1'),
      );
      final isVideo2Active = container.read(
        isVideoActiveProvider('explore-video-2'),
      );

      expect(isVideo0Active, isFalse);
      expect(isVideo1Active, isTrue);
      expect(isVideo2Active, isFalse);

      container.dispose();
    });

    test(
      'activeVideoIdProvider changes when scrolling from index 0 to 1',
      () async {
        // This test reproduces the bug where scrolling doesn't update active video
        // Use StreamController from the start to simulate URL changes
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videoEventsProvider.overrideWith(() => VideoEventsMock(mockVideos)),
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        // Listen for active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO CHANGED: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        // Listen for streams to emit
        container.listen(
          pageContextProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        container.listen(
          videoEventsProvider,
          (previous, next) {},
          fireImmediately: true,
        );

        // Start providers
        container.read(pageContextProvider);
        container.read(videoEventsProvider);

        // Emit initial location: /explore/0
        locationController.add('/explore/0');
        await pumpEventQueue();

        // Verify we start at index 0
        expect(
          container.read(activeVideoIdProvider),
          equals('explore-video-0'),
        );
        expect(activeVideoIds.last, equals('explore-video-0'));

        // Now simulate scroll: change URL to /explore/1
        locationController.add('/explore/1');
        await pumpEventQueue();

        // Active video should change to index 1
        print('Active video IDs seen: $activeVideoIds');
        expect(
          container.read(activeVideoIdProvider),
          equals('explore-video-1'),
        );
        expect(activeVideoIds, contains('explore-video-1'));

        locationController.close();
        container.dispose();
      },
    );

    test(
      'activeVideoIdProvider returns null in grid mode (no videoIndex)',
      () async {
        // This test verifies that when URL is /explore (no index), no video is active
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videoEventsProvider.overrideWith(() => VideoEventsMock(mockVideos)),
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        // Listen for active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO CHANGED: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        // Listen for streams to emit
        container.listen(
          pageContextProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        container.listen(
          videoEventsProvider,
          (previous, next) {},
          fireImmediately: true,
        );

        // Start providers
        container.read(pageContextProvider);
        container.read(videoEventsProvider);

        // Emit location: /explore (no index - grid mode)
        locationController.add('/explore');
        await pumpEventQueue();

        // Active video should be null (grid mode)
        print(
          'Active video ID in grid mode: ${container.read(activeVideoIdProvider)}',
        );
        expect(container.read(activeVideoIdProvider), isNull);

        locationController.close();
        container.dispose();
      },
    );
  });
}

/// Mock VideoEvents provider for testing
class VideoEventsMock extends VideoEvents {
  VideoEventsMock(this.videos);

  final List<VideoEvent> videos;

  @override
  Stream<List<VideoEvent>> build() async* {
    yield videos;
  }
}
