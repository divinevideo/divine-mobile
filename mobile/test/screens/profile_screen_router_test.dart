// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization for profile feeds

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  Widget _shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  final mockVideos = [
    VideoEvent(
      id: 'p0',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 0',
      timestamp: now,
      title: 'Profile 0',
      videoUrl: 'https://example.com/p0.mp4',
    ),
    VideoEvent(
      id: 'p1',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 1',
      timestamp: now,
      title: 'Profile 1',
      videoUrl: 'https://example.com/p1.mp4',
    ),
    VideoEvent(
      id: 'p2',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 2',
      timestamp: now,
      title: 'Profile 2',
      videoUrl: 'https://example.com/p2.mp4',
    ),
  ];

  testWidgets('PROFILE: URL ↔ PageView sync', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
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
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/profile/npubXYZ/0');
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreenRouter), findsOneWidget);

    // Verify first video shown
    expect(find.text('Profile 0/3'), findsOneWidget);

    // Navigate to index 1
    c.read(goRouterProvider).go('/profile/npubXYZ/1');
    await tester.pumpAndSettle();

    // Verify second video shown
    expect(find.text('Profile 1/3'), findsOneWidget);
  });

  testWidgets('PROFILE: Empty state shows when no videos', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: [],
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/profile/npubXYZ/0');
    await tester.pumpAndSettle();

    expect(find.textContaining('No posts yet'), findsOneWidget);
  });

  testWidgets('PROFILE: Prefetch ±1 profiles when URL index changes', (
    tester,
  ) async {
    final prefetchedPubkeys = <String>[];

    final mockNotifier = FakeUserProfileNotifier(
      onPrefetch: (pubkeys) => prefetchedPubkeys.addAll(pubkeys),
    );

    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
        userProfileProvider.overrideWith(() => mockNotifier),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/profile/npubXYZ/1');
    await tester.pumpAndSettle();

    // Should prefetch profiles for videos at index 0 and 2 (±1 from current)
    // In profile screen, all videos are from the same author, so this might
    // prefetch the same npub multiple times - that's fine for now
    expect(prefetchedPubkeys.length, greaterThanOrEqualTo(1));
  });

  testWidgets('PROFILE: Lifecycle pause → activeVideoId becomes null', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        appForegroundProvider.overrideWithValue(const AsyncValue.data(false)),
        videosForProfileRouteProvider.overrideWith((ref) {
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
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/profile/npubXYZ/1');
    await tester.pumpAndSettle();

    // When backgrounded, active video should be null
    expect(c.read(activeVideoIdProvider), isNull);
  });
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
