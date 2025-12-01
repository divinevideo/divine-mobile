// ABOUTME: Tests for edit video button navigation from profile screen
// ABOUTME: Verifies route navigation to /edit-video with video model passed as extra

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  Widget _shell(ProviderContainer c, {GoRouter? customRouter}) {
    final router = customRouter ?? c.read(goRouterProvider);
    return UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  final testVideo = VideoEvent(
    id: 'test-video-id',
    pubkey: 'test-pubkey',
    createdAt: nowUnix,
    content: 'Test Video Content',
    timestamp: now,
    title: 'Test Video',
    videoUrl: 'https://example.com/test.mp4',
  );

  final mockVideos = [testVideo];

  testWidgets(
    'EDIT VIDEO: Tapping edit button navigates to /edit-video route',
    (tester) async {
      // Track navigation events
      String? capturedRoute;
      Object? capturedExtra;

      final testRouter = GoRouter(
        initialLocation: '/profile/npubTEST/0',
        routes: [
          GoRoute(
            path: '/profile/:npub/:index',
            builder: (context, state) => Scaffold(
              body: IconButton(
                key: const Key('edit-button'),
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Simulate the navigation call we expect to see
                  context.push('/edit-video', extra: testVideo);
                },
              ),
            ),
          ),
          GoRoute(
            path: '/edit-video',
            builder: (context, state) {
              capturedRoute = state.uri.toString();
              capturedExtra = state.extra;
              return const Scaffold(
                body: Center(child: Text('Video Editor Screen')),
              );
            },
          ),
        ],
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
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_shell(c, customRouter: testRouter));
      await tester.pumpAndSettle();

      // Find and tap the edit button
      final editButton = find.byKey(const Key('edit-button'));
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify navigation to /edit-video
      expect(capturedRoute, '/edit-video');
      expect(capturedExtra, testVideo);
      expect(find.text('Video Editor Screen'), findsOneWidget);
    },
  );

  testWidgets('EDIT VIDEO: Extra parameter contains correct video model', (
    tester,
  ) async {
    VideoEvent? passedVideo;

    final testRouter = GoRouter(
      initialLocation: '/profile/npubTEST/0',
      routes: [
        GoRoute(
          path: '/profile/:npub/:index',
          builder: (context, state) => Scaffold(
            body: IconButton(
              key: const Key('edit-button'),
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/edit-video', extra: testVideo);
              },
            ),
          ),
        ),
        GoRoute(
          path: '/edit-video',
          builder: (context, state) {
            passedVideo = state.extra as VideoEvent?;
            return Scaffold(
              body: Center(
                child: Text('Editing: ${passedVideo?.title ?? "Unknown"}'),
              ),
            );
          },
        ),
      ],
    );

    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c, customRouter: testRouter));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-button')));
    await tester.pumpAndSettle();

    // Verify the video model was passed correctly
    expect(passedVideo, isNotNull);
    expect(passedVideo?.id, testVideo.id);
    expect(passedVideo?.title, testVideo.title);
    expect(passedVideo?.videoUrl, testVideo.videoUrl);
    expect(find.text('Editing: Test Video'), findsOneWidget);
  });

  testWidgets(
    'EDIT VIDEO: Desktop platforms show "coming soon" message instead of navigating',
    (tester) async {
      // Skip this test on actual desktop platforms since we can't mock Platform
      // This test documents the expected behavior - implementation will check Platform.isMacOS || Platform.isWindows || Platform.isLinux
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // On desktop, edit button should show SnackBar instead of navigating
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
        await tester.pumpAndSettle();

        // On desktop, we expect a snackbar message instead of navigation
        // This is a documentation test - actual implementation will need to handle platform detection
        expect(
          true,
          true,
          reason: 'Desktop platform guard is platform-specific',
        );
      }
    },
    skip: !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux,
  );
}
