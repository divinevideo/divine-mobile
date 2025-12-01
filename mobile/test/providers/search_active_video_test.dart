// ABOUTME: Test for activeVideoIdProvider working correctly with search route
// ABOUTME: Verifies videos in search results become active when navigating to search/0, search/1, etc.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/router_location_provider.dart';

void main() {
  group('Search Active Video Provider', () {
    // Create mock video data
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockSearchResults = [
      VideoEvent(
        id: 'search-video-0',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Search Result 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/video0.mp4',
      ),
      VideoEvent(
        id: 'search-video-1',
        pubkey: 'pubkey-2',
        createdAt: nowUnix,
        content: 'Search Result 1',
        timestamp: now,
        title: 'Video 1',
        videoUrl: 'https://example.com/video1.mp4',
      ),
      VideoEvent(
        id: 'search-video-2',
        pubkey: 'pubkey-3',
        createdAt: nowUnix,
        content: 'Search Result 2',
        timestamp: now,
        title: 'Video 2',
        videoUrl: 'https://example.com/video2.mp4',
      ),
    ];

    test(
      'activeVideoIdProvider returns correct video at search index 0',
      () async {
        final container = ProviderContainer(
          overrides: [
            // Mock router location to /search/sexy/0
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/search/sexy/0'),
            ),
            // Mock search results
            searchScreenVideosProvider.overrideWith((ref) => mockSearchResults),
            // Mock app as foreground
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        // Listen for page context and app foreground to be emitted
        container.listen(
          pageContextProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        container.listen(
          appForegroundProvider,
          (previous, next) {},
          fireImmediately: true,
        );

        // Start providers by reading them
        container.read(pageContextProvider);
        container.read(appForegroundProvider);

        // Wait for streams to emit
        await pumpEventQueue();

        // Read active video ID
        final activeVideoId = container.read(activeVideoIdProvider);

        // Should be the first search result
        expect(activeVideoId, equals('search-video-0'));

        // Verify isVideoActiveProvider works correctly
        final isVideo0Active = container.read(
          isVideoActiveProvider('search-video-0'),
        );
        final isVideo1Active = container.read(
          isVideoActiveProvider('search-video-1'),
        );

        expect(isVideo0Active, isTrue);
        expect(isVideo1Active, isFalse);

        container.dispose();
      },
    );

    test(
      'activeVideoIdProvider returns correct video at search index 1',
      () async {
        final container = ProviderContainer(
          overrides: [
            // Mock router location to /search/test/1
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/search/test/1'),
            ),
            // Mock search results
            searchScreenVideosProvider.overrideWith((ref) => mockSearchResults),
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
          appForegroundProvider,
          (previous, next) {},
          fireImmediately: true,
        );

        // Start providers by reading them
        container.read(pageContextProvider);
        container.read(appForegroundProvider);

        // Wait for async operations to complete
        await pumpEventQueue();

        // Read active video ID
        final activeVideoId = container.read(activeVideoIdProvider);

        // Should be the SECOND video (index 1)
        expect(activeVideoId, equals('search-video-1'));

        // Verify isVideoActiveProvider works correctly
        final isVideo0Active = container.read(
          isVideoActiveProvider('search-video-0'),
        );
        final isVideo1Active = container.read(
          isVideoActiveProvider('search-video-1'),
        );
        final isVideo2Active = container.read(
          isVideoActiveProvider('search-video-2'),
        );

        expect(isVideo0Active, isFalse);
        expect(isVideo1Active, isTrue);
        expect(isVideo2Active, isFalse);

        container.dispose();
      },
    );

    test(
      'activeVideoIdProvider returns null in search grid mode (no videoIndex)',
      () async {
        // This test verifies that when URL is /search/query (no index), no video is active
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            searchScreenVideosProvider.overrideWith((ref) => mockSearchResults),
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

        // Start providers
        container.read(pageContextProvider);

        // Emit location: /search/test (no index - grid mode)
        locationController.add('/search/test');
        await pumpEventQueue();

        // Active video should be null (grid mode)
        print(
          'Active video ID in search grid mode: ${container.read(activeVideoIdProvider)}',
        );
        expect(container.read(activeVideoIdProvider), isNull);

        locationController.close();
        container.dispose();
      },
    );

    test(
      'activeVideoIdProvider returns null when search has no results',
      () async {
        final container = ProviderContainer(
          overrides: [
            // Mock router location to /search/empty/0
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/search/empty/0'),
            ),
            // Mock search with empty results
            searchScreenVideosProvider.overrideWith((ref) => const []),
            // Mock app as foreground
            appForegroundProvider.overrideWith((ref) => Stream.value(true)),
          ],
        );

        container.listen(
          pageContextProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        container.listen(
          appForegroundProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        container.read(pageContextProvider);
        container.read(appForegroundProvider);
        await pumpEventQueue();

        // Should be null when there are no search results
        final activeVideoId = container.read(activeVideoIdProvider);
        expect(activeVideoId, isNull);

        container.dispose();
      },
    );
  });
}
