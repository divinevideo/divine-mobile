// ABOUTME: Tests for router-driven HomeScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization using mock home feed data

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  group('HomeScreenRouter Router-Driven Tests', () {
    // Create mock video data for testing
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'home-video-1',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Test Home Video 1',
        timestamp: now,
        title: 'Home Video 1',
        videoUrl: 'https://example.com/home-video1.mp4',
      ),
      VideoEvent(
        id: 'home-video-2',
        pubkey: 'pubkey-2',
        createdAt: nowUnix,
        content: 'Test Home Video 2',
        timestamp: now,
        title: 'Home Video 2',
        videoUrl: 'https://example.com/home-video2.mp4',
      ),
      VideoEvent(
        id: 'home-video-3',
        pubkey: 'pubkey-3',
        createdAt: nowUnix,
        content: 'Test Home Video 3',
        timestamp: now,
        title: 'Home Video 3',
        videoUrl: 'https://example.com/home-video3.mp4',
      ),
    ];

    testWidgets('initial URL /home/0 renders first video', (tester) async {
      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home/0
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Verify HomeScreenRouter is rendered
      expect(find.byType(HomeScreenRouter), findsOneWidget);

      // Verify first video is shown
      expect(find.text('Home Video 1/3'), findsOneWidget);
      expect(find.text('ID: home-video-1'), findsOneWidget);

      // Flush any pending post-frame callbacks
      await tester.pump();
      await tester.pump();

      container.dispose();
    });

    testWidgets('URL /home/1 renders second video', (tester) async {
      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate directly to home/1
      container.read(goRouterProvider).go('/home/1');
      await tester.pumpAndSettle();

      // Verify HomeScreenRouter is rendered
      expect(find.byType(HomeScreenRouter), findsOneWidget);

      // Verify second video is shown
      expect(find.text('Home Video 2/3'), findsOneWidget);
      expect(find.text('ID: home-video-2'), findsOneWidget);

      // Flush any pending post-frame callbacks
      await tester.pump();
      await tester.pump();

      container.dispose();
    });

    testWidgets('changing URL updates PageView', (tester) async {
      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Start at home/0
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Change URL to home/2
      container.read(goRouterProvider).go('/home/2');
      await tester.pumpAndSettle();

      // Verify PageView shows video 3
      expect(find.text('Home Video 3/3'), findsOneWidget);
      expect(find.text('ID: home-video-3'), findsOneWidget);

      // Flush any pending post-frame callbacks
      await tester.pump();
      await tester.pump();

      container.dispose();
    });

    testWidgets('no provider mutations in widget lifecycle', (tester) async {
      // This test verifies the core router-driven principle:
      // Widgets should NEVER mutate providers during initState/dispose

      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Flush any pending post-frame callbacks before disposal
      await tester.pump();
      await tester.pump();

      // Dispose the widget tree (simulates navigation away)
      await tester.pumpWidget(const SizedBox());

      // If we get here without errors, lifecycle is clean
      expect(true, isTrue);

      container.dispose();
    });

    testWidgets('empty state shown when no videos', (tester) async {
      final container = ProviderContainer(
        overrides: [homeFeedProvider.overrideWith(() => HomeFeedMock([]))],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home/0
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Verify HomeScreenRouter is rendered
      expect(find.byType(HomeScreenRouter), findsOneWidget);

      // Verify empty state is shown (inline widget, no specific type)
      expect(find.text('No videos available'), findsOneWidget);
      expect(
        find.text('Follow some creators to see their videos here'),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('pull-to-refresh triggers refresh', (tester) async {
      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home/0
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Verify RefreshIndicator is present
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Trigger pull-to-refresh
      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // After refresh, videos should still be visible
      expect(find.text('Home Video 1/3'), findsOneWidget);

      // Flush any pending post-frame callbacks
      await tester.pump();
      await tester.pump();

      container.dispose();
    });

    testWidgets('RefreshIndicator has correct semantic label', (tester) async {
      final mockNotifier = FakeUserProfileNotifier(onPrefetch: (_) {});

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home/0
      container.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Find RefreshIndicator widget
      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );

      // Verify semantic label
      expect(refreshIndicator.semanticsLabel, 'searching for more videos');

      container.dispose();
    });

    testWidgets('prefetches profiles around current index', (tester) async {
      final prefetchedPubkeys = <String>[];

      // Create mock notifier that tracks prefetch calls
      final mockNotifier = FakeUserProfileNotifier(
        onPrefetch: (pubkeys) => prefetchedPubkeys.addAll(pubkeys),
      );

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          homeFeedProvider.overrideWith(() => HomeFeedMock(mockVideos)),
          userProfileProvider.overrideWith(() => mockNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to home/1 (middle video)
      container.read(goRouterProvider).go('/home/1');
      await tester.pumpAndSettle();

      // Should prefetch profiles for index 0 and 2 (±1 from current)
      expect(prefetchedPubkeys, containsAll(['pubkey-1', 'pubkey-3']));
      expect(
        prefetchedPubkeys,
        isNot(contains('pubkey-2')),
      ); // current, not prefetch

      container.dispose();
    });
  });
}

/// Mock HomeFeed provider for testing
class HomeFeedMock extends HomeFeed {
  HomeFeedMock(this.videos);

  final List<VideoEvent> videos;

  @override
  Future<VideoFeedState> build() async {
    return VideoFeedState(
      videos: videos,
      hasMoreContent: false,
      isLoadingMore: false,
    );
  }
}

/// Fake UserProfileNotifier for testing prefetch behavior
class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier({required this.onPrefetch});

  final void Function(List<String>) onPrefetch;

  @override
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    onPrefetch(pubkeys);
  }
}
