// ABOUTME: Widget that tracks video playback metrics like watch duration and loop count
// ABOUTME: Sends detailed analytics when video ends or user navigates away

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Tracks video playback metrics and sends analytics
class VideoMetricsTracker extends ConsumerStatefulWidget {
  const VideoMetricsTracker({
    required this.video,
    required this.controller,
    required this.child,
    super.key,
  });

  final VideoEvent video;
  final VideoPlayerController? controller;
  final Widget child;

  @override
  ConsumerState<VideoMetricsTracker> createState() =>
      _VideoMetricsTrackerState();
}

class _VideoMetricsTrackerState extends ConsumerState<VideoMetricsTracker> {
  // Tracking state
  DateTime? _viewStartTime;
  Duration _totalWatchDuration = Duration.zero;
  Duration? _lastPosition;
  int _loopCount = 0;
  bool _hasTrackedView = false;
  Timer? _positionTimer;

  // Track if we've sent end event to avoid duplicates
  bool _hasSentEndEvent = false;

  // Track if we've started playback performance trace
  bool _hasStartedPlaybackTrace = false;
  bool _hasCompletedPlaybackTrace = false;

  // Save provider references for safe access during dispose
  dynamic _analyticsService;
  dynamic _authService;
  dynamic _seenVideosService;

  @override
  void initState() {
    super.initState();
    // CRITICAL: Save provider references BEFORE any async work
    _analyticsService = ref.read(analyticsServiceProvider);
    _authService = ref.read(authServiceProvider);
    _seenVideosService = ref.read(seenVideosServiceProvider);
    _initializeTracking();
  }

  @override
  void didUpdateWidget(VideoMetricsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If video changed, send end event for previous video and start tracking new one
    if (oldWidget.video.id != widget.video.id) {
      _sendVideoEndEvent();
      _resetTracking();
      _initializeTracking();
    }

    // If controller changed, update listeners
    if (oldWidget.controller != widget.controller) {
      _removeControllerListeners(oldWidget.controller);
      _addControllerListeners();
    }
  }

  void _initializeTracking() {
    if (widget.controller == null) return;

    // Start performance trace for video playback
    if (!_hasStartedPlaybackTrace) {
      _hasStartedPlaybackTrace = true;
      final traceName = 'video_playback_${widget.video.id}';
      PerformanceMonitoringService.instance.startTrace(traceName);
    }

    _addControllerListeners();
    _startPositionTracking();

    // Track view start
    if (!_hasTrackedView) {
      _trackViewStart();
    }
  }

  void _addControllerListeners() {
    final controller = widget.controller;
    if (controller == null) return;
    // Controller.value access can still succeed after dispose; guard addListener
    if (!controller.value.isInitialized) return;
    try {
      // Listen for video completion (loops)
      controller.addListener(_onControllerUpdate);
    } catch (e) {
      // If controller was disposed between checks, skip attaching listeners
      Log.warning(
        'VideoMetricsTracker: controller not usable (disposed?) - $e',
        name: 'VideoMetricsTracker',
        category: LogCategory.video,
      );
    }
  }

  void _removeControllerListeners(VideoPlayerController? controller) {
    if (controller == null) return;
    try {
      controller.removeListener(_onControllerUpdate);
    } catch (_) {
      // Ignore if already disposed
    }
  }

  void _onControllerUpdate() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Stop performance trace when video starts playing for the first time
    if (!_hasCompletedPlaybackTrace && controller.value.isPlaying) {
      _hasCompletedPlaybackTrace = true;
      final traceName = 'video_playback_${widget.video.id}';
      PerformanceMonitoringService.instance.stopTrace(traceName);
      Log.debug(
        '⏱️ Video playback started for ${widget.video.id}',
        name: 'VideoMetricsTracker',
        category: LogCategory.video,
      );
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Detect loop: position jumps back to start
    if (_lastPosition != null &&
        position < _lastPosition! &&
        position < const Duration(seconds: 1) &&
        _lastPosition!.inMilliseconds > duration.inMilliseconds - 1000) {
      _loopCount++;
      Log.debug(
        '🔄 Video looped (count: $_loopCount) for ${widget.video.id}',
        name: 'VideoMetricsTracker',
        category: LogCategory.video,
      );
    }

    _lastPosition = position;
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateWatchDuration();
    });
  }

  void _updateWatchDuration() {
    if (_viewStartTime == null) return;

    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Only count time when video is actually playing
    if (controller.value.isPlaying) {
      final now = DateTime.now();
      final sessionDuration = now.difference(_viewStartTime!);

      // Update total watch duration (capped by actual video length to handle pauses)
      final videoDuration = controller.value.duration;
      if (videoDuration > Duration.zero) {
        final effectiveDuration = sessionDuration > videoDuration
            ? videoDuration
            : sessionDuration;
        _totalWatchDuration = effectiveDuration;
      }
    }
  }

  void _trackViewStart() {
    _viewStartTime = DateTime.now();
    _hasTrackedView = true;
    _hasSentEndEvent = false;

    // Use saved provider references
    _analyticsService.trackDetailedVideoViewWithUser(
      widget.video,
      userId: _authService.currentPublicKeyHex,
      source: 'mobile',
      eventType: 'view_start',
    );

    Log.debug(
      '▶️ Started tracking video ${widget.video.id}',
      name: 'VideoMetricsTracker',
      category: LogCategory.video,
    );
  }

  void _sendVideoEndEvent() {
    if (!_hasTrackedView || _hasSentEndEvent) return;
    if (_viewStartTime == null) return;

    _updateWatchDuration(); // Final update

    final controller = widget.controller;
    final totalDuration = controller?.value.duration;

    // Only send if we have meaningful data
    if (_totalWatchDuration.inSeconds > 0) {
      try {
        // Use saved provider references instead of ref.read()
        // CRITICAL: Never use ref.read() in dispose-related methods
        _analyticsService.trackDetailedVideoViewWithUser(
          widget.video,
          userId: _authService.currentPublicKeyHex,
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: _totalWatchDuration,
          totalDuration: totalDuration,
          loopCount: _loopCount,
          completedVideo:
              _loopCount > 0 ||
              (_totalWatchDuration.inMilliseconds >=
                  (totalDuration?.inMilliseconds ?? 0) * 0.9),
        );

        // Persist to local storage for "show fresh content" feature
        _seenVideosService.recordVideoView(
          widget.video.id,
          loopCount: _loopCount,
          watchDuration: _totalWatchDuration,
        );

        Log.debug(
          '⏹️ Video end: duration=${_totalWatchDuration.inSeconds}s, loops=$_loopCount',
          name: 'VideoMetricsTracker',
          category: LogCategory.video,
        );

        _hasSentEndEvent = true;
      } catch (e) {
        // Widget may be disposed, ignore ref access errors
        Log.warning(
          'Failed to send video end event (widget disposed): $e',
          name: 'VideoMetricsTracker',
          category: LogCategory.video,
        );
      }
    }
  }

  void _resetTracking() {
    _viewStartTime = null;
    _totalWatchDuration = Duration.zero;
    _lastPosition = null;
    _loopCount = 0;
    _hasTrackedView = false;
    _hasSentEndEvent = false;
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _sendVideoEndEvent(); // Send final metrics when widget is disposed
    _removeControllerListeners(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This is a transparent wrapper - just return the child
    return widget.child;
  }
}
