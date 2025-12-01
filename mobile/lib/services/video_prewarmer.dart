// ABOUTME: VideoPrewarmer abstraction for lifecycle-safe video controller prewarming
// ABOUTME: Manages timer cancellation and prevents leaks during widget disposal

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Abstract interface for video prewarming
abstract class VideoPrewarmer {
  void prewarmVideos(List<VideoControllerParams> params);
  void cancelAll();
}

/// Production implementation that manages video controller lifecycle
class DefaultVideoPrewarmer implements VideoPrewarmer {
  DefaultVideoPrewarmer(this._ref);

  final Ref _ref;
  final Set<VideoControllerParams> _prewarmedParams = {};

  @override
  void prewarmVideos(List<VideoControllerParams> params) {
    Log.debug(
      '🔥 Prewarming ${params.length} videos',
      name: 'VideoPrewarmer',
      category: LogCategory.video,
    );

    for (final param in params) {
      _prewarmedParams.add(param);
      // ref.read() creates the provider if it doesn't exist
      // but doesn't establish a listener, so the controller can autodispose
      _ref.read(individualVideoControllerProvider(param));
    }
  }

  @override
  void cancelAll() {
    if (_prewarmedParams.isEmpty) return;

    Log.debug(
      '🧊 Cancelling ${_prewarmedParams.length} prewarmed videos',
      name: 'VideoPrewarmer',
      category: LogCategory.video,
    );

    // Invalidate all prewarmed providers to cancel their timers
    for (final param in _prewarmedParams) {
      try {
        _ref.invalidate(individualVideoControllerProvider(param));
      } catch (e) {
        // Suppress errors - provider may already be disposed
        Log.debug(
          '⚠️ Failed to invalidate prewarmed video ${param.videoId}: $e',
          name: 'VideoPrewarmer',
          category: LogCategory.video,
        );
      }
    }
    _prewarmedParams.clear();
  }
}

/// No-op implementation for testing
class NoopPrewarmer implements VideoPrewarmer {
  @override
  void prewarmVideos(List<VideoControllerParams> params) {
    // No-op for tests
  }

  @override
  void cancelAll() {
    // No-op for tests
  }
}

/// Riverpod provider for video prewarmer
/// Widget-scoped so lifecycle binds to the widget tree
final videoPrewarmerProvider = Provider<VideoPrewarmer>((ref) {
  final prewarmer = DefaultVideoPrewarmer(ref);
  ref.onDispose(
    prewarmer.cancelAll,
  ); // Hard bind cancellation to provider lifecycle
  return prewarmer;
});
