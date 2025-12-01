// ABOUTME: Comprehensive video loading performance metrics and analytics
// ABOUTME: Tracks video loading bottlenecks from initialization to first frame playback

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Tracks different stages of video loading for performance analysis
class VideoLoadingMetrics {
  static final VideoLoadingMetrics _instance = VideoLoadingMetrics._internal();
  factory VideoLoadingMetrics() => _instance;
  VideoLoadingMetrics._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, _VideoLoadingSession> _activeSessions = {};

  // Add a static variable to count metrics for visibility
  static int _metricsCount = 0;

  // Callback for visual overlay
  Function(String)? onMetricsEvent;

  // Public getters for debug info
  static VideoLoadingMetrics get instance => _instance;
  int get activeSessions => _activeSessions.length;
  static int get metricsCount => _metricsCount;

  void _notifyEvent(String event) {
    onMetricsEvent?.call(event);
  }

  /// Start tracking video loading performance
  void startVideoLoading(String videoId, String videoUrl) {
    _metricsCount++;
    final session = _VideoLoadingSession(
      videoId: videoId,
      videoUrl: videoUrl,
      startTime: DateTime.now(),
    );

    _activeSessions[videoId] = session;

    // Use both UnifiedLogger AND print to ensure visibility
    final message =
        '🎬 STARTED tracking video loading #$_metricsCount for ${videoId}... - $videoUrl';
    UnifiedLogger.info(message, name: 'VideoLoadingMetrics');
    // ignore: avoid_print
    print(message);

    // Also use Flutter's debugPrint which should definitely show up
    debugPrint('🎬🎬🎬 VIDEO METRICS #$_metricsCount: $message 🎬🎬🎬');

    // Force a visible print to stdout
    // ignore: avoid_print
    print('METRICS_TEST_OUTPUT: Video metrics started for ${videoId}');

    // Notify visual overlay
    _notifyEvent('🎬 STARTED #$_metricsCount: ${videoId}');
  }

  /// Mark when video controller creation begins
  void markControllerCreationStart(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.controllerCreationStart = DateTime.now();

    UnifiedLogger.debug(
      'Controller creation started for ${videoId}...',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when video controller creation completes
  void markControllerCreationEnd(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.controllerCreationEnd = DateTime.now();

    final duration = session.controllerCreationEnd!
        .difference(session.controllerCreationStart!)
        .inMilliseconds;

    UnifiedLogger.debug(
      'Controller creation completed for ${videoId}... in ${duration}ms',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when network initialization starts (first network request)
  void markNetworkInitStart(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.networkInitStart = DateTime.now();

    UnifiedLogger.debug(
      'Network initialization started for ${videoId}...',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when first network response is received
  void markFirstNetworkResponse(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.firstNetworkResponse = DateTime.now();

    final duration = session.firstNetworkResponse!
        .difference(session.networkInitStart!)
        .inMilliseconds;

    UnifiedLogger.info(
      'First network response for ${videoId}... in ${duration}ms',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when video initialization begins
  void markVideoInitStart(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.videoInitStart = DateTime.now();

    UnifiedLogger.debug(
      'Video initialization started for ${videoId}...',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when video initialization completes
  void markVideoInitComplete(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.videoInitComplete = DateTime.now();

    final duration = session.videoInitComplete!
        .difference(session.videoInitStart!)
        .inMilliseconds;

    UnifiedLogger.info(
      'Video initialization completed for ${videoId}... in ${duration}ms',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when first frame is ready for display
  void markFirstFrameReady(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.firstFrameReady = DateTime.now();

    final totalDuration = session.firstFrameReady!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      'First frame ready for ${videoId}... in ${totalDuration}ms total',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark when video starts playing
  void markPlaybackStart(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.playbackStart = DateTime.now();

    // Calculate total time to playback
    final totalDuration = session.playbackStart!
        .difference(session.startTime)
        .inMilliseconds;

    final message =
        '▶️ PLAYBACK STARTED for ${videoId}... in ${totalDuration}ms total';
    UnifiedLogger.info(message, name: 'VideoLoadingMetrics');
    // ignore: avoid_print
    print(message);

    // Send complete metrics to Firebase Analytics
    _recordCompleteMetrics(session);

    // Clean up session
    _activeSessions.remove(videoId);
  }

  /// Mark when video loading fails
  void markLoadingError(String videoId, String errorType, String errorMessage) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.errorTime = DateTime.now();
    session.errorType = errorType;
    session.errorMessage = errorMessage;

    final totalDuration = session.errorTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.error(
      'Video loading failed for ${videoId}... after ${totalDuration}ms: $errorType - $errorMessage',
      name: 'VideoLoadingMetrics',
    );

    // Send error metrics to Firebase Analytics
    _recordErrorMetrics(session);

    // Clean up session
    _activeSessions.remove(videoId);
  }

  /// Mark buffering events during playback
  void markBufferingStart(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.bufferingEvents.add(_BufferingEvent(startTime: DateTime.now()));

    UnifiedLogger.debug(
      'Buffering started for ${videoId}...',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Mark end of buffering event
  void markBufferingEnd(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    final bufferingEvents = session.bufferingEvents;
    if (bufferingEvents.isEmpty) return;

    final lastEvent = bufferingEvents.last;
    if (lastEvent.endTime != null) return; // Already ended

    lastEvent.endTime = DateTime.now();
    final duration = lastEvent.endTime!
        .difference(lastEvent.startTime)
        .inMilliseconds;

    UnifiedLogger.debug(
      'Buffering ended for ${videoId}... after ${duration}ms',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Record network performance metrics (bytes downloaded, bandwidth)
  void recordNetworkStats(
    String videoId, {
    int? bytesDownloaded,
    double? bandwidth,
    int? segmentCount,
  }) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    if (bytesDownloaded != null) session.bytesDownloaded = bytesDownloaded;
    if (bandwidth != null) session.estimatedBandwidth = bandwidth;
    if (segmentCount != null) session.segmentCount = segmentCount;

    UnifiedLogger.debug(
      'Network stats for ${videoId}... - '
      'Downloaded: ${bytesDownloaded ?? 'N/A'} bytes, '
      'Bandwidth: ${bandwidth?.toStringAsFixed(2) ?? 'N/A'} Mbps, '
      'Segments: ${segmentCount ?? 'N/A'}',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Track video segment loading
  void markSegmentLoaded(
    String videoId, {
    required int segmentIndex,
    required int segmentSizeBytes,
    required int loadTimeMs,
  }) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.segmentsLoaded.add(
      _SegmentLoadInfo(
        index: segmentIndex,
        sizeBytes: segmentSizeBytes,
        loadTimeMs: loadTimeMs,
      ),
    );

    UnifiedLogger.debug(
      'Segment $segmentIndex loaded for ${videoId}... (${segmentSizeBytes} bytes in ${loadTimeMs}ms)',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Track segment loading failure
  void markSegmentFailed(
    String videoId, {
    required int segmentIndex,
    required String errorMessage,
  }) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.failedSegments.add(segmentIndex);

    UnifiedLogger.warning(
      'Segment $segmentIndex failed for ${videoId}... - $errorMessage',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Track total segments for a video
  void setTotalSegments(String videoId, int totalSegments) {
    final session = _activeSessions[videoId];
    if (session == null) return;

    session.totalSegments = totalSegments;

    UnifiedLogger.debug(
      'Video ${videoId}... has $totalSegments segments',
      name: 'VideoLoadingMetrics',
    );
  }

  /// Get current loading status for a video
  VideoLoadingStatus? getLoadingStatus(String videoId) {
    final session = _activeSessions[videoId];
    if (session == null) return null;

    return VideoLoadingStatus(
      videoId: videoId,
      currentStage: session._getCurrentStage(),
      elapsedMs: DateTime.now().difference(session.startTime).inMilliseconds,
    );
  }

  /// Send complete metrics to Firebase Analytics
  void _recordCompleteMetrics(_VideoLoadingSession session) {
    final totalDuration = session.playbackStart!
        .difference(session.startTime)
        .inMilliseconds;

    // Calculate stage durations
    final controllerCreationMs =
        session.controllerCreationEnd != null &&
            session.controllerCreationStart != null
        ? session.controllerCreationEnd!
              .difference(session.controllerCreationStart!)
              .inMilliseconds
        : null;

    final networkInitMs =
        session.firstNetworkResponse != null && session.networkInitStart != null
        ? session.firstNetworkResponse!
              .difference(session.networkInitStart!)
              .inMilliseconds
        : null;

    final videoInitMs =
        session.videoInitComplete != null && session.videoInitStart != null
        ? session.videoInitComplete!
              .difference(session.videoInitStart!)
              .inMilliseconds
        : null;

    final firstFrameMs = session.firstFrameReady
        ?.difference(session.startTime)
        .inMilliseconds;

    // Calculate total buffering time
    final totalBufferingMs = session.bufferingEvents
        .where((event) => event.endTime != null)
        .map(
          (event) => event.endTime!.difference(event.startTime).inMilliseconds,
        )
        .fold<int>(0, (sum, duration) => sum + duration);

    // Calculate segment statistics
    final segmentsLoaded = session.segmentsLoaded.length;
    final segmentsFailed = session.failedSegments.length;
    final totalSegmentBytes = session.segmentsLoaded.fold<int>(
      0,
      (sum, seg) => sum + seg.sizeBytes,
    );
    final avgSegmentLoadTime = segmentsLoaded > 0
        ? session.segmentsLoaded.fold<int>(
                0,
                (sum, seg) => sum + seg.loadTimeMs,
              ) /
              segmentsLoaded
        : 0;

    // Send to Firebase Analytics
    _analytics.logEvent(
      name: 'video_loading_complete',
      parameters: {
        'video_id': session.videoId, // Truncate for privacy
        'total_duration_ms': totalDuration,
        'controller_creation_ms': controllerCreationMs ?? 0,
        'network_init_ms': networkInitMs ?? 0,
        'video_init_ms': videoInitMs ?? 0,
        'first_frame_ms': firstFrameMs ?? 0,
        'total_buffering_ms': totalBufferingMs,
        'buffering_events': session.bufferingEvents.length,
        'bytes_downloaded': session.bytesDownloaded ?? 0,
        'estimated_bandwidth_mbps': session.estimatedBandwidth ?? 0.0,
        'segment_count': session.segmentCount ?? 0,
        'total_segments': session.totalSegments ?? 0,
        'segments_loaded': segmentsLoaded,
        'segments_failed': segmentsFailed,
        'total_segment_bytes': totalSegmentBytes,
        'avg_segment_load_ms': avgSegmentLoadTime.toStringAsFixed(0),
        'video_url_domain': Uri.tryParse(session.videoUrl)?.host ?? 'unknown',
      },
    );

    // Create comprehensive performance summary
    final summary =
        '🚀 VIDEO PERFORMANCE COMPLETE: ${session.videoId}\n'
        '   ⏱️  TOTAL TIME: ${totalDuration}ms\n'
        '   🔧 Controller Creation: ${controllerCreationMs ?? 'N/A'}ms\n'
        '   🌐 Network Init: ${networkInitMs ?? 'N/A'}ms\n'
        '   📹 Video Init: ${videoInitMs ?? 'N/A'}ms\n'
        '   🎬 First Frame: ${firstFrameMs ?? 'N/A'}ms\n'
        '   ⏳ Total Buffering: ${totalBufferingMs}ms (${session.bufferingEvents.length} events)\n'
        '   📊 Downloaded: ${session.bytesDownloaded ?? 'N/A'} bytes\n'
        '   📡 Bandwidth: ${session.estimatedBandwidth?.toStringAsFixed(2) ?? 'N/A'} Mbps\n'
        '   🌍 Domain: ${Uri.tryParse(session.videoUrl)?.host ?? 'unknown'}';

    // Log to both systems for maximum visibility
    UnifiedLogger.info(summary, name: 'VideoLoadingMetrics');
    // ignore: avoid_print
    print(summary);

    // Also use debugPrint with extra visibility
    debugPrint('🚀🚀🚀 VIDEO PERFORMANCE SUMMARY 🚀🚀🚀');
    debugPrint(summary);
    debugPrint('🚀🚀🚀 END VIDEO PERFORMANCE 🚀🚀🚀');

    // Notify visual overlay with timing
    _notifyEvent('🚀 COMPLETE: ${session.videoId} in ${totalDuration}ms');
  }

  /// Send error metrics to Firebase Analytics
  void _recordErrorMetrics(_VideoLoadingSession session) {
    final totalDuration = session.errorTime!
        .difference(session.startTime)
        .inMilliseconds;

    _analytics.logEvent(
      name: 'video_loading_error',
      parameters: {
        'video_id': session.videoId, // Truncate for privacy
        'error_type': session.errorType!,
        'error_message': session.errorMessage!.substring(
          0,
          100,
        ), // Truncate long messages
        'time_to_error_ms': totalDuration,
        'stage_when_failed': session._getCurrentStage().name,
        'video_url_domain': Uri.tryParse(session.videoUrl)?.host ?? 'unknown',
      },
    );
  }

  /// Clear all active sessions (useful for testing/debugging)
  void clearAllSessions() {
    _activeSessions.clear();
    UnifiedLogger.debug(
      'Cleared all video loading sessions',
      name: 'VideoLoadingMetrics',
    );
  }
}

/// Represents the current loading status of a video
class VideoLoadingStatus {
  const VideoLoadingStatus({
    required this.videoId,
    required this.currentStage,
    required this.elapsedMs,
  });

  final String videoId;
  final VideoLoadingStage currentStage;
  final int elapsedMs;
}

/// Different stages of video loading
enum VideoLoadingStage {
  starting,
  creatingController,
  initializingNetwork,
  loadingVideo,
  preparingFirstFrame,
  playing,
  error,
}

/// Internal session tracking for a single video load
class _VideoLoadingSession {
  _VideoLoadingSession({
    required this.videoId,
    required this.videoUrl,
    required this.startTime,
  });

  final String videoId;
  final String videoUrl;
  final DateTime startTime;

  DateTime? controllerCreationStart;
  DateTime? controllerCreationEnd;
  DateTime? networkInitStart;
  DateTime? firstNetworkResponse;
  DateTime? videoInitStart;
  DateTime? videoInitComplete;
  DateTime? firstFrameReady;
  DateTime? playbackStart;
  DateTime? errorTime;
  String? errorType;
  String? errorMessage;

  int? bytesDownloaded;
  double? estimatedBandwidth;
  int? segmentCount;
  int? totalSegments;

  final List<_BufferingEvent> bufferingEvents = [];
  final List<_SegmentLoadInfo> segmentsLoaded = [];
  final List<int> failedSegments = [];

  VideoLoadingStage _getCurrentStage() {
    if (errorTime != null) return VideoLoadingStage.error;
    if (playbackStart != null) return VideoLoadingStage.playing;
    if (firstFrameReady != null) return VideoLoadingStage.preparingFirstFrame;
    if (videoInitStart != null) return VideoLoadingStage.loadingVideo;
    if (networkInitStart != null) return VideoLoadingStage.initializingNetwork;
    if (controllerCreationStart != null)
      return VideoLoadingStage.creatingController;
    return VideoLoadingStage.starting;
  }
}

/// Tracks individual buffering events
class _BufferingEvent {
  _BufferingEvent({required this.startTime});

  final DateTime startTime;
  DateTime? endTime;
}

/// Tracks individual segment loading
class _SegmentLoadInfo {
  _SegmentLoadInfo({
    required this.index,
    required this.sizeBytes,
    required this.loadTimeMs,
  });

  final int index;
  final int sizeBytes;
  final int loadTimeMs;
}

/// Extension to easily add metrics to VideoEvent
extension VideoEventMetrics on VideoEvent {
  /// Start tracking loading metrics for this video
  void startLoadingMetrics() {
    final url = videoUrl ?? thumbnailUrl;
    if (url != null) {
      VideoLoadingMetrics().startVideoLoading(id, url);
    }
  }

  /// Mark this video as successfully loaded
  void markLoadingComplete() {
    VideoLoadingMetrics().markPlaybackStart(id);
  }

  /// Mark this video as failed to load
  void markLoadingError(String errorType, String errorMessage) {
    VideoLoadingMetrics().markLoadingError(id, errorType, errorMessage);
  }
}
