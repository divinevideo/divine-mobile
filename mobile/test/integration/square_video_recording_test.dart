// ABOUTME: Integration test for square (1:1 aspect ratio) video recording
// ABOUTME: Tests that videos are recorded in Vine-style square format, not vertical or horizontal

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Square Video Recording Tests', () {
    test('recorded video should have 1:1 (square) aspect ratio', () async {
      // Arrange
      final container = ProviderContainer();

      final controller = container.read(vineRecordingProvider.notifier);

      // Initialize camera
      await controller.initialize();

      // Act - Record a short video
      await controller.startRecording();
      await Future.delayed(const Duration(seconds: 2));
      await controller.stopRecording();

      final (videoFile, _) = await controller.finishRecording();

      // Assert - Video should exist and be square
      expect(
        videoFile,
        isNotNull,
        reason: 'Recording should produce a video file',
      );
      expect(
        videoFile!.existsSync(),
        isTrue,
        reason: 'Video file should exist',
      );

      // Check video dimensions using video_player
      final videoController = VideoPlayerController.file(videoFile);
      await videoController.initialize();

      final size = videoController.value.size;
      final aspectRatio = size.width / size.height;

      // Aspect ratio should be 1:1 (square), allowing small tolerance
      expect(
        aspectRatio,
        closeTo(1.0, 0.05),
        reason:
            'Video aspect ratio should be 1:1 (square), but got ${size.width}x${size.height} = $aspectRatio',
      );

      // Cleanup
      await videoController.dispose();
      await videoFile.delete();
      container.dispose();
    });

    test('recorded segments should maintain square aspect ratio', () async {
      // Arrange
      final container = ProviderContainer();

      final controller = container.read(vineRecordingProvider.notifier);
      await controller.initialize();

      // Act - Record multiple segments (Vine-style)
      await controller.startRecording();
      await Future.delayed(const Duration(milliseconds: 500));
      await controller.stopRecording();

      await controller.startRecording();
      await Future.delayed(const Duration(milliseconds: 500));
      await controller.stopRecording();

      final (videoFile, _) = await controller.finishRecording();

      // Assert
      expect(videoFile, isNotNull);
      expect(videoFile!.existsSync(), isTrue);

      final videoController = VideoPlayerController.file(videoFile);
      await videoController.initialize();

      final size = videoController.value.size;
      final aspectRatio = size.width / size.height;

      expect(
        aspectRatio,
        closeTo(1.0, 0.05),
        reason: 'Concatenated video should maintain square aspect ratio',
      );

      // Cleanup
      await videoController.dispose();
      await videoFile.delete();
      container.dispose();
    });

    test('video metadata should report square dimensions', () async {
      // Arrange
      final container = ProviderContainer();

      final controller = container.read(vineRecordingProvider.notifier);
      await controller.initialize();

      // Act
      await controller.startRecording();
      await Future.delayed(const Duration(seconds: 1));
      await controller.stopRecording();
      final (videoFile, _) = await controller.finishRecording();

      // Assert
      expect(videoFile, isNotNull);

      final videoController = VideoPlayerController.file(videoFile!);
      await videoController.initialize();

      final width = videoController.value.size.width;
      final height = videoController.value.size.height;

      expect(
        width,
        equals(height),
        reason:
            'Video width ($width) should equal height ($height) for square format',
      );

      // Cleanup
      await videoController.dispose();
      await videoFile.delete();
      container.dispose();
    });
  });
}
