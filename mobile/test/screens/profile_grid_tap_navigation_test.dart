// ABOUTME: Tests for profile grid → fullscreen video navigation
// ABOUTME: Verifies tapping grid item navigates to correct video index and autoplays

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

// Mock auth service for testing
class MockAuthService extends AuthService {
  @override
  String? currentPublicKeyHex;

  @override
  bool get isAuthenticated => currentPublicKeyHex != null;
}

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  const testUserHex =
      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
  const testUserNpub =
      'npub10zjuyx63vmwpga9kfh0hg49l08ntt4455ac5skfm785xddeuyuuqt7gxpj';

  final mockVideos = [
    VideoEvent(
      id: 'video0',
      pubkey: testUserHex,
      createdAt: nowUnix,
      content: 'Video 0',
      timestamp: now,
      title: 'Test Video 0',
      videoUrl: 'https://example.com/v0.mp4',
    ),
    VideoEvent(
      id: 'video1',
      pubkey: testUserHex,
      createdAt: nowUnix - 1,
      content: 'Video 1',
      timestamp: now.subtract(const Duration(seconds: 1)),
      title: 'Test Video 1',
      videoUrl: 'https://example.com/v1.mp4',
    ),
    VideoEvent(
      id: 'video2',
      pubkey: testUserHex,
      createdAt: nowUnix - 2,
      content: 'Video 2',
      timestamp: now.subtract(const Duration(seconds: 2)),
      title: 'Test Video 2',
      videoUrl: 'https://example.com/v2.mp4',
    ),
    VideoEvent(
      id: 'video3',
      pubkey: testUserHex,
      createdAt: nowUnix - 3,
      content: 'Video 3',
      timestamp: now.subtract(const Duration(seconds: 3)),
      title: 'Test Video 3',
      videoUrl: 'https://example.com/v3.mp4',
    ),
  ];

  final mockProfile = UserProfile(
    pubkey: testUserHex,
    displayName: 'Test User',
    name: 'testuser',
    about: 'Test profile',
    picture: 'https://example.com/avatar.jpg',
    banner: null,
    website: null,
    nip05: null,
    lud16: null,
    lud06: null,
    createdAt: now,
    eventId: 'profile_event_id',
    rawData: {
      'name': 'testuser',
      'display_name': 'Test User',
      'about': 'Test profile',
      'picture': 'https://example.com/avatar.jpg',
    },
  );

  group('Profile Grid Navigation', () {
    testWidgets('Tapping grid item at index 2 navigates to video at index 2', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(
                videos: mockVideos,
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWith((ref) {
            final mockAuth = MockAuthService();
            mockAuth.currentPublicKeyHex = testUserHex;
            return mockAuth;
          }),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Start at profile grid view (videoIndex=0)
      c.read(goRouterProvider).go('/profile/$testUserNpub/0');
      await tester.pumpAndSettle();

      // Verify we're on the grid view
      expect(find.byType(ProfileScreenRouter), findsOneWidget);

      // Debug: check what's visible
      expect(find.byIcon(Icons.grid_on), findsOneWidget); // Grid tab icon

      // Ensure the first tab (grid) is selected - it should be by default but let's be explicit
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // Now find grid items - they use GestureDetector wrapping DecoratedBox with play icon
      final gridItems = find.ancestor(
        of: find.byIcon(Icons.play_circle_filled),
        matching: find.byType(GestureDetector),
      );

      // If no items found, dump the widget tree for debugging
      if (gridItems.evaluate().isEmpty) {
        debugDumpApp();
        fail('No grid items found with play icons');
      }

      // Tap the third grid item (index 2)
      await tester.tap(gridItems.at(2));
      await tester.pumpAndSettle();

      // Verify route changed to /profile/:npub/3 (URL is 1-based: gridIndex 2 → urlIndex 3)
      final router = c.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile/$testUserNpub/3',
      );

      // Verify active video is now video at list index 2 (urlIndex 3 - 1 = 2)
      expect(c.read(activeVideoIdProvider), 'video2');

      // Verify VideoFeedItem for video2 is now rendered
      final videoItem = tester.widget<VideoFeedItem>(
        find.byType(VideoFeedItem).first,
      );
      expect(videoItem.video.id, 'video2');
      expect(videoItem.index, 2); // List index should be 2
    });

    testWidgets('Own profile video shows author name (not "Loading...")', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(
                videos: mockVideos,
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWith((ref) {
            final mockAuth = MockAuthService();
            mockAuth.currentPublicKeyHex = testUserHex;
            return mockAuth;
          }), // Own profile
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to video at index 1
      c.read(goRouterProvider).go('/profile/$testUserNpub/1');
      await tester.pumpAndSettle();

      // Verify profile name is shown (not "Loading...")
      expect(find.text('Loading...'), findsNothing);
      expect(find.textContaining('Test User'), findsOneWidget);
    });

    testWidgets(
      'Own profile video shows edit/delete buttons when forceShowOverlay=true',
      (tester) async {
        final c = ProviderContainer(
          overrides: [
            appForegroundProvider.overrideWithValue(
              const AsyncValue.data(true),
            ),
            videosForProfileRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(
                  videos: mockVideos,
                  hasMoreContent: false,
                  isLoadingMore: false,
                ),
              );
            }),
            fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
              return mockProfile;
            }),
            authServiceProvider.overrideWith((ref) {
              final mockAuth = MockAuthService();
              mockAuth.currentPublicKeyHex = testUserHex;
              return mockAuth;
            }), // Own profile
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        // Navigate to own video
        c.read(goRouterProvider).go('/profile/$testUserNpub/1');
        await tester.pumpAndSettle();

        // Verify VideoFeedItem has forceShowOverlay=true for own profile
        final videoItem = tester.widget<VideoFeedItem>(
          find.byType(VideoFeedItem).first,
        );
        expect(videoItem.forceShowOverlay, isTrue);

        // Verify share menu button is visible (overlay is shown)
        // Note: The actual edit/delete functionality is in ShareVideoMenu widget
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    testWidgets('Video autoplays when navigating from grid to fullscreen', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(
                videos: mockVideos,
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWith((ref) {
            final mockAuth = MockAuthService();
            mockAuth.currentPublicKeyHex = testUserHex;
            return mockAuth;
          }),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Start at grid
      c.read(goRouterProvider).go('/profile/$testUserNpub/0');
      await tester.pumpAndSettle();

      // Tap grid item - find gesture detectors with play icons (grid items)
      final gridGestureDetectors = find.ancestor(
        of: find.byIcon(Icons.play_circle_filled),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gridGestureDetectors.at(1)); // Tap second video
      await tester.pumpAndSettle();

      // Verify active video is set (which triggers autoplay)
      expect(c.read(activeVideoIdProvider), 'video1');

      // Verify isVideoActiveProvider returns true for the active video
      expect(c.read(isVideoActiveProvider('video1')), isTrue);
      expect(c.read(isVideoActiveProvider('video0')), isFalse);
    });
  });
}
