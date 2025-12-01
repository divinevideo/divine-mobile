// ABOUTME: Riverpod notifier for tracking seen videos with reactive state
// ABOUTME: Provides observable state that videoEventsProvider can watch for reordering

import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/state/seen_videos_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seen_videos_notifier.g.dart';

/// Notifier for managing seen videos state reactively
@Riverpod(keepAlive: true)
class SeenVideosNotifier extends _$SeenVideosNotifier {
  SeenVideosService? _service;

  @override
  SeenVideosState build() {
    _initializeService();
    return SeenVideosState.initial;
  }

  void _initializeService() {
    _service = SeenVideosService();
    _service!
        .initialize()
        .then((_) {
          // Load initial state from persistent storage
          if (!ref.mounted) return; // Provider was disposed

          final seenIds = _service!.getSeenVideoIds();
          state = state.copyWith(seenVideoIds: seenIds, isInitialized: true);
          Log.info(
            'SeenVideosNotifier initialized with ${seenIds.length} seen videos',
          );
        })
        .catchError((e) {
          if (!ref.mounted) return; // Provider was disposed
          Log.error('Failed to initialize SeenVideosNotifier: $e');
        });
  }

  /// Check if a video has been seen
  bool hasSeenVideo(String videoId) {
    return state.seenVideoIds.contains(videoId);
  }

  /// Mark a video as seen and persist to storage
  Future<void> markVideoAsSeen(String videoId) async {
    if (state.seenVideoIds.contains(videoId)) {
      return; // Already seen
    }

    // Update state immutably
    final newSeenIds = Set<String>.from(state.seenVideoIds)..add(videoId);
    state = state.copyWith(seenVideoIds: newSeenIds);

    // Persist to storage
    await _service?.markVideoAsSeen(videoId);

    Log.debug(
      'Marked video as seen: ${videoId.substring(0, videoId.length > 8 ? 8 : videoId.length)}... (total: ${newSeenIds.length})',
    );
  }

  /// Record video view with metrics
  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {
    // Mark as seen
    await markVideoAsSeen(videoId);

    // Record metrics in service
    await _service?.recordVideoView(
      videoId,
      loopCount: loopCount,
      watchDuration: watchDuration,
    );
  }
}
