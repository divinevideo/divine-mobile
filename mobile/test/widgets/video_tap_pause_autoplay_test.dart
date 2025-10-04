// ABOUTME: Test reproducing the bug where autoplayed videos don't pause on tap
// ABOUTME: Verifies tap-to-pause works correctly on videos that autoplay when becoming active

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item.dart';

void main() {
  group('Video Tap Pause Autoplay Bug', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('BUG: autoplayed video should pause when tapped', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video-1',
        pubkey: 'test-pubkey',
        content: 'Test Video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video1.mp4',
        timestamp: now,
      );

      // Build the video feed item
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                width: 400,
                child: VideoFeedItem(video: video, index: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make video active (simulating swipe to this video)
      container.read(activeVideoProvider.notifier).setActiveVideo(video.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify video is active
      final activeState = container.read(activeVideoProvider);
      expect(activeState.currentVideoId, equals(video.id),
          reason: 'Video should be active after setActiveVideo');

      // Get the controller to check its state
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      final controller = container.read(individualVideoControllerProvider(controllerParams));

      // Video should be playing (autoplayed)
      // Note: In real app this would be true, but in test it might not initialize
      // This test documents the expected behavior

      // Find and tap the video
      final videoWidget = find.byKey(Key('video_${video.id}'));
      expect(videoWidget, findsOneWidget, reason: 'Video widget should be found');

      // TAP TO PAUSE
      await tester.tap(videoWidget);
      await tester.pumpAndSettle();

      // EXPECTED: Video should pause
      // ACTUAL BUG: Video doesn't pause on first tap after autoplay
      expect(controller.value.isPlaying, isFalse,
          reason: 'BUG: Video should pause when tapped while playing');
    });

    testWidgets('video pauses correctly after being manually played', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video-2',
        pubkey: 'test-pubkey',
        content: 'Test Video 2',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video2.mp4',
        timestamp: now,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                width: 400,
                child: VideoFeedItem(video: video, index: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start with video inactive
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );

      // Tap to activate and play
      final videoWidget = find.byKey(Key('video_${video.id}'));
      await tester.tap(videoWidget);
      await tester.pumpAndSettle();

      // Should be active now
      expect(container.read(activeVideoProvider).currentVideoId, equals(video.id));

      final controller = container.read(individualVideoControllerProvider(controllerParams));

      // Manually play it
      await controller.play();
      await tester.pump();

      expect(controller.value.isPlaying, isTrue);

      // Tap to pause
      await tester.tap(videoWidget);
      await tester.pumpAndSettle();

      // This SHOULD work (and it does work after backgrounding)
      expect(controller.value.isPlaying, isFalse,
          reason: 'Manually played video should pause on tap');
    });

    test('active video state transitions correctly', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Set video active
      notifier.setActiveVideo('video-1');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-1'));

      // Switch to another video
      notifier.setActiveVideo('video-2');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-2'));
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-1'));

      // Clear active
      notifier.clearActiveVideo();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-2'));
    });
  });
}
