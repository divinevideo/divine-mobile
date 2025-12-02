// ABOUTME: Tests for ComposableVideoGrid widget
// ABOUTME: Verifies grid rendering, broken video filtering, and user interactions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/broken_video_tracker.dart' as broken_tracker;
import 'package:openvine/widgets/composable_video_grid.dart';

void main() {
  group('ComposableVideoGrid', () {
    late List<VideoEvent> testVideos;
    late broken_tracker.BrokenVideoTracker mockTracker;

    setUp(() {
      final now = DateTime.now();
      final nowTimestamp = now.millisecondsSinceEpoch ~/ 1000;
      testVideos = [
        VideoEvent(
          id: 'video1',
          pubkey:
              'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2', // 64-char hex pubkey
          content: 'Test video 1',
          title: 'Video 1',
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
          duration: 5,
          originalLikes: 10,
          originalLoops: 100,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'video2',
          pubkey:
              'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3', // 64-char hex pubkey
          content: 'Test video 2',
          title: 'Video 2',
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
          duration: 3,
          originalLikes: 5,
          originalLoops: 50,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'broken_video',
          pubkey:
              'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4', // 64-char hex pubkey
          content: 'Broken video',
          title: 'Broken Video',
          videoUrl: 'https://example.com/broken.mp4',
          duration: 4,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
      ];

      // Create mock tracker with no broken videos
      mockTracker = broken_tracker.BrokenVideoTracker();
    });

    testWidgets('renders grid with provided videos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(), // Only non-broken videos
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      // Wait for widget to build
      await tester.pump();

      // Should render 2 video tiles
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('filters out broken videos using BrokenVideoTracker', (
      tester,
    ) async {
      // Mark video as broken
      mockTracker.markVideoBroken('broken_video', 'Test broken');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos, // All 3 videos including broken one
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should only render 2 tiles (broken_video filtered out)
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('shows empty state when no videos after filtering', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No videos available'), findsOneWidget);
    });

    testWidgets('calls onVideoTap with correct params when tile tapped', (
      tester,
    ) async {
      List<VideoEvent>? tappedVideos;
      int? tappedIndex;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {
                  tappedVideos = videos;
                  tappedIndex = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the second video
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      expect(tappedIndex, equals(1));
      expect(tappedVideos, isNotNull);
      expect(tappedVideos!.length, equals(2));
    });

    testWidgets('uses correct grid parameters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {},
                crossAxisCount: 3,
                childAspectRatio: 1.0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find GridView and verify delegate
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.childAspectRatio, equals(1.0));
    });

    testWidgets('displays video metadata correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWith((ref) async => mockTracker),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: [testVideos.first],
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check for video metadata display
      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // likes count
      expect(find.text('5s'), findsOneWidget); // duration badge
    });
  });
}
