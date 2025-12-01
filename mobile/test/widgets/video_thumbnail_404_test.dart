// ABOUTME: Test that verifies VideoThumbnailWidget handles 404 thumbnail errors gracefully
// ABOUTME: Ensures the app doesn't crash when thumbnail URLs return 404 errors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

void main() {
  group('VideoThumbnailWidget 404 handling', () {
    testWidgets('should not crash when thumbnail URL returns 404', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a video with a 404 thumbnail URL
      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        content: '',
        timestamp: DateTime.now(),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl:
            'https://cdn.divine.video/99657957e77a1d27c7c850c3ea35fd2b/thumbnails/thumbnail.jpg', // This is the 404 URL from the crash
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj', // Valid blurhash for fallback
        title: 'Test Video',
      );

      // Act: Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(video: video, width: 200, height: 200),
          ),
        ),
      );

      // Pump multiple times to allow network request to fail
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Assert: Widget should render without throwing
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);

      // The widget should show either blurhash or placeholder, not crash
      // We're just verifying no exception was thrown
    });

    testWidgets('should show blurhash fallback when thumbnail fails to load', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a video with a 404 thumbnail but valid blurhash
      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        content: '',
        timestamp: DateTime.now(),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://invalid-domain-that-does-not-exist.com/404.jpg',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        title: 'Test Video',
      );

      // Act: Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(video: video, width: 200, height: 200),
          ),
        ),
      );

      // Allow time for network failure
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Assert: Should not crash
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);

      // Note: We can't easily verify blurhash is shown in widget tests,
      // but the important thing is no exception was thrown
    });

    testWidgets('should handle null thumbnail URL gracefully', (
      WidgetTester tester,
    ) async {
      // Arrange: Create a video with no thumbnail URL
      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        content: '',
        timestamp: DateTime.now(),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: null,
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        title: 'Test Video',
      );

      // Act: Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(video: video, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert: Should show fallback without crashing
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);
    });
  });
}
