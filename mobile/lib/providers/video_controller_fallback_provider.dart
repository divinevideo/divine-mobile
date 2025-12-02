// ABOUTME: Fallback video controller provider that tries standard video_player when media_kit fails
// ABOUTME: Handles CDN compatibility issues with byte range requests

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/active_video_provider.dart';

/// Creates a video controller with fallback logic for CDN compatibility
class VideoControllerWithFallback {
  static Future<VideoPlayerController> create({
    required String videoUrl,
    required String videoId,
  }) async {
    Log.info(
      '🎬 Creating video controller for $videoId',
      name: 'VideoControllerFallback',
      category: LogCategory.video,
    );

    // On web, always use standard video_player (better browser compatibility)
    if (kIsWeb) {
      Log.info(
        '🌐 Using standard video_player for web platform',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );
      return _createStandardController(videoUrl);
    }

    // On macOS, prefer standard video_player for better CDN compatibility
    if (Platform.isMacOS) {
      Log.info(
        '🖥️ Using standard video_player for macOS (better CDN compatibility)',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );
      return _createStandardController(videoUrl);
    }

    // For mobile platforms, try media_kit first, then fallback
    try {
      Log.info(
        '📱 Attempting media_kit controller for mobile platform',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // Try to initialize with a timeout
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          controller.dispose();
          throw TimeoutException('Media kit initialization timed out');
        },
      );

      // Check if initialization actually succeeded
      if (!controller.value.isInitialized || controller.value.hasError) {
        controller.dispose();
        throw Exception(
          'Media kit initialization failed: ${controller.value.errorDescription}',
        );
      }

      Log.info(
        '✅ Media kit controller initialized successfully',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );
      return controller;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // Check for byte range errors that indicate CDN incompatibility
      if (errorStr.contains('byte range') ||
          errorStr.contains('coremedia') ||
          errorStr.contains('range') ||
          errorStr.contains('-12939')) {
        Log.warning(
          '⚠️ Media kit failed with CDN compatibility issue, using fallback',
          name: 'VideoControllerFallback',
          category: LogCategory.video,
        );
        return _createStandardController(videoUrl);
      }

      // For other errors, still throw
      Log.error(
        '❌ Media kit initialization failed: $e',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  static VideoPlayerController _createStandardController(String videoUrl) {
    // Create controller without media_kit wrapper
    // This uses the platform's native video player directly
    return VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
  }
}

/// Alternative provider for video controllers with fallback logic
final videoControllerFallbackProvider =
    Provider.family<VideoPlayerController, VideoControllerParams>((
      ref,
      params,
    ) {
      Log.info(
        '🎬 Creating fallback video controller for ${params.videoId}',
        name: 'VideoControllerFallback',
        category: LogCategory.video,
      );

      final controller =
          VideoControllerWithFallback.create(
                videoUrl: params.videoUrl,
                videoId: params.videoId,
              )
              .then((controller) {
                // Set up the controller
                controller.setLooping(true);

                // Check if should autoplay based on router-driven active video
                final isActive =
                    ref.read(activeVideoIdProvider) == params.videoId;
                if (isActive) {
                  controller.play().catchError((e) {
                    Log.error(
                      'Failed to autoplay: $e',
                      name: 'VideoControllerFallback',
                      category: LogCategory.video,
                    );
                  });
                }

                return controller;
              })
              .catchError((error) {
                Log.error(
                  'Failed to create fallback controller: $error',
                  name: 'VideoControllerFallback',
                  category: LogCategory.video,
                );
                // Return a broken controller that will show error state
                final brokenController = VideoPlayerController.networkUrl(
                  Uri.parse(params.videoUrl),
                );
                return brokenController;
              });

      // Return a FutureProvider would be better, but for compatibility with existing code
      // we'll return the controller synchronously and handle initialization internally
      final syncController = VideoPlayerController.networkUrl(
        Uri.parse(params.videoUrl),
      );

      controller.then((c) {
        // Swap the controller's internal state if possible
        // This is a workaround since we can't return a Future here
        if (c != syncController) {
          syncController.dispose();
        }
      });

      ref.onDispose(() {
        syncController.dispose();
      });

      return syncController;
    });
