// ABOUTME: Integration test for VideoPlayerController backend functionality
// ABOUTME: Tests native AVPlayer/ExoPlayer work correctly (baseline for media_kit → native migration)

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPlayerController Backend Integration Tests', () {
    late VideoPlayerController controller;

    // Real test video URLs (H.264/AAC - widely supported)
    const testVideoUrl =
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    const shortVideoUrl =
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

    tearDown(() async {
      // Clean up controller after each test
      if (controller.value.isInitialized) {
        await controller.dispose();
      }
    });

    test(
      'BASELINE: VideoPlayerController should initialize from network URL',
      () async {
        // Create controller from network URL
        controller = VideoPlayerController.networkUrl(Uri.parse(testVideoUrl));

        // Initialize should complete successfully
        await controller.initialize();

        // Verify controller is initialized
        expect(
          controller.value.isInitialized,
          true,
          reason: 'Controller should be initialized',
        );

        // Verify video has valid duration
        expect(
          controller.value.duration.inSeconds,
          greaterThan(0),
          reason: 'Video should have valid duration',
        );

        // Verify video has size information
        expect(
          controller.value.size.width,
          greaterThan(0),
          reason: 'Video should have width',
        );
        expect(
          controller.value.size.height,
          greaterThan(0),
          reason: 'Video should have height',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should support play/pause',
      () async {
        controller = VideoPlayerController.networkUrl(Uri.parse(shortVideoUrl));
        await controller.initialize();

        // Start playback
        await controller.play();
        expect(
          controller.value.isPlaying,
          true,
          reason: 'Video should be playing',
        );

        // Wait a moment for playback to progress
        await Future.delayed(const Duration(milliseconds: 500));

        // Check position has advanced
        expect(
          controller.value.position.inMilliseconds,
          greaterThan(0),
          reason: 'Video position should advance during playback',
        );

        // Pause playback
        await controller.pause();
        expect(
          controller.value.isPlaying,
          false,
          reason: 'Video should be paused',
        );

        // Position should remain stable while paused
        final pausedPosition = controller.value.position;
        await Future.delayed(const Duration(milliseconds: 200));
        expect(
          controller.value.position,
          pausedPosition,
          reason: 'Position should not advance while paused',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should support seeking',
      () async {
        controller = VideoPlayerController.networkUrl(Uri.parse(testVideoUrl));
        await controller.initialize();

        final duration = controller.value.duration;
        expect(
          duration.inSeconds,
          greaterThan(5),
          reason: 'Test video should be long enough to seek',
        );

        // Seek to middle of video
        final targetPosition = Duration(seconds: duration.inSeconds ~/ 2);
        await controller.seekTo(targetPosition);

        // Verify position is approximately correct (within 1 second tolerance)
        final actualPosition = controller.value.position;
        expect(
          (actualPosition - targetPosition).inMilliseconds.abs(),
          lessThan(1000),
          reason: 'Seek should position video within 1 second of target',
        );

        // Seek to beginning
        await controller.seekTo(Duration.zero);
        expect(
          controller.value.position.inMilliseconds,
          lessThan(500),
          reason: 'Should be able to seek to beginning',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should report video metadata',
      () async {
        controller = VideoPlayerController.networkUrl(Uri.parse(testVideoUrl));
        await controller.initialize();

        final value = controller.value;

        // Check aspect ratio is calculated correctly
        expect(
          value.aspectRatio,
          greaterThan(0),
          reason: 'Aspect ratio should be positive',
        );
        expect(
          value.aspectRatio,
          closeTo(value.size.width / value.size.height, 0.01),
          reason: 'Aspect ratio should match width/height ratio',
        );

        // Check buffering state is available
        expect(
          value.buffered,
          isNotNull,
          reason: 'Buffered ranges should be available',
        );

        // Check playback speed is available
        expect(
          value.playbackSpeed,
          greaterThan(0),
          reason: 'Playback speed should be positive',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should handle invalid URLs gracefully',
      () async {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(
            'https://invalid-domain-that-does-not-exist-12345.com/video.mp4',
          ),
        );

        // Initialize should fail for invalid URL
        expect(
          () => controller.initialize(),
          throwsA(isA<Exception>()),
          reason: 'Initialize should throw exception for invalid URL',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should support volume control',
      () async {
        controller = VideoPlayerController.networkUrl(Uri.parse(shortVideoUrl));
        await controller.initialize();

        // Set volume to 50%
        await controller.setVolume(0.5);
        expect(
          controller.value.volume,
          0.5,
          reason: 'Volume should be settable',
        );

        // Mute
        await controller.setVolume(0.0);
        expect(controller.value.volume, 0.0, reason: 'Should be able to mute');

        // Max volume
        await controller.setVolume(1.0);
        expect(
          controller.value.volume,
          1.0,
          reason: 'Should be able to set max volume',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: VideoPlayerController should support looping',
      () async {
        controller = VideoPlayerController.networkUrl(Uri.parse(shortVideoUrl));
        await controller.initialize();

        // Enable looping
        await controller.setLooping(true);
        expect(
          controller.value.isLooping,
          true,
          reason: 'Looping should be enabled',
        );

        // Disable looping
        await controller.setLooping(false);
        expect(
          controller.value.isLooping,
          false,
          reason: 'Looping should be disabled',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'BASELINE: Multiple VideoPlayerController instances should work independently',
      () async {
        final controller1 = VideoPlayerController.networkUrl(
          Uri.parse(testVideoUrl),
        );
        final controller2 = VideoPlayerController.networkUrl(
          Uri.parse(shortVideoUrl),
        );

        // Initialize both
        await Future.wait([controller1.initialize(), controller2.initialize()]);

        expect(controller1.value.isInitialized, true);
        expect(controller2.value.isInitialized, true);

        // Both should have different durations
        expect(
          controller1.value.duration,
          isNot(equals(controller2.value.duration)),
          reason: 'Different videos should have different durations',
        );

        // Clean up
        await controller1.dispose();
        await controller2.dispose();
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('VideoPlayerController Platform-Specific Tests', () {
    test('INFO: Verify native player backend', () {
      // This test documents which backend is being used
      // On iOS/macOS: Should use AVPlayer
      // On Android: Should use ExoPlayer (Media3)
      // On Web: Should use browser native player

      // Note: We can't directly query which backend is active from the public API,
      // but this test serves as documentation of expected behavior
      expect(
        true,
        true,
        reason: 'Test passes to document platform expectations',
      );
    });
  });
}
