// ABOUTME: Camera and video recording performance analytics
// ABOUTME: Tracks camera initialization, recording duration, upload performance, and success rates

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking camera and video recording performance
class CameraMetricsTracker {
  static final CameraMetricsTracker _instance =
      CameraMetricsTracker._internal();
  factory CameraMetricsTracker() => _instance;
  CameraMetricsTracker._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, _CameraSession> _cameraSessions = {};
  final Map<String, _RecordingSession> _recordingSessions = {};
  final Map<String, _UploadSession> _uploadSessions = {};

  /// Start tracking camera initialization
  void startCameraInit(String sessionId) {
    final session = _CameraSession(
      sessionId: sessionId,
      startTime: DateTime.now(),
    );

    _cameraSessions[sessionId] = session;

    UnifiedLogger.info(
      '📷 Camera initialization started',
      name: 'CameraMetrics',
    );
  }

  /// Mark camera initialized
  void markCameraReady(String sessionId) {
    final session = _cameraSessions[sessionId];
    if (session == null) return;

    session.readyTime = DateTime.now();
    final initTime = session.readyTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Camera ready in ${initTime}ms',
      name: 'CameraMetrics',
    );

    _analytics.logEvent(
      name: 'camera_init',
      parameters: {'init_time_ms': initTime, 'success': true},
    );

    _cameraSessions.remove(sessionId);
  }

  /// Mark camera initialization failure
  void markCameraInitFailed(String sessionId, String errorMessage) {
    final session = _cameraSessions[sessionId];
    if (session == null) return;

    final attemptTime = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.error(
      '❌ Camera init failed after ${attemptTime}ms: $errorMessage',
      name: 'CameraMetrics',
    );

    _analytics.logEvent(
      name: 'camera_init',
      parameters: {
        'init_time_ms': attemptTime,
        'success': false,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
      },
    );

    _cameraSessions.remove(sessionId);
  }

  /// Start tracking recording session
  void startRecording(String sessionId) {
    final session = _RecordingSession(
      sessionId: sessionId,
      startTime: DateTime.now(),
    );

    _recordingSessions[sessionId] = session;

    UnifiedLogger.info('🎥 Recording started', name: 'CameraMetrics');

    _analytics.logEvent(name: 'recording_started', parameters: {});
  }

  /// Stop recording and track metrics
  void stopRecording(
    String sessionId, {
    required int durationMs,
    required int fileSizeBytes,
    bool? success,
  }) {
    final session = _recordingSessions[sessionId];
    if (session == null) return;

    session.stopTime = DateTime.now();
    session.durationMs = durationMs;
    session.fileSizeBytes = fileSizeBytes;

    final recordingDuration = session.stopTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '⏹️  Recording stopped: ${durationMs}ms duration, ${fileSizeBytes} bytes, ${success ?? true ? "success" : "failed"}',
      name: 'CameraMetrics',
    );

    _analytics.logEvent(
      name: 'recording_stopped',
      parameters: {
        'recording_duration_ms': recordingDuration,
        'video_duration_ms': durationMs,
        'file_size_bytes': fileSizeBytes,
        'file_size_mb': (fileSizeBytes / 1024 / 1024).toStringAsFixed(2),
        'success': success ?? true,
      },
    );

    _recordingSessions.remove(sessionId);
  }

  /// Track recording cancellation
  void trackRecordingCancelled(String sessionId, String reason) {
    final session = _recordingSessions[sessionId];
    if (session == null) return;

    final duration = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    _analytics.logEvent(
      name: 'recording_cancelled',
      parameters: {'duration_before_cancel_ms': duration, 'reason': reason},
    );

    UnifiedLogger.info(
      '🚫 Recording cancelled after ${duration}ms: $reason',
      name: 'CameraMetrics',
    );

    _recordingSessions.remove(sessionId);
  }

  /// Start tracking upload
  void startUpload(
    String uploadId, {
    required int fileSizeBytes,
    required String uploadType, // 'video', 'thumbnail', etc.
  }) {
    final session = _UploadSession(
      uploadId: uploadId,
      uploadType: uploadType,
      fileSizeBytes: fileSizeBytes,
      startTime: DateTime.now(),
    );

    _uploadSessions[uploadId] = session;

    UnifiedLogger.info(
      '📤 Upload started: $uploadType (${fileSizeBytes} bytes)',
      name: 'CameraMetrics',
    );
  }

  /// Track upload progress
  void trackUploadProgress(
    String uploadId, {
    required int bytesUploaded,
    required double progressPercentage,
  }) {
    final session = _uploadSessions[uploadId];
    if (session == null) return;

    session.bytesUploaded = bytesUploaded;

    // Log significant progress milestones
    if (progressPercentage >= 25 && !session.milestone25) {
      session.milestone25 = true;
      UnifiedLogger.debug('📊 Upload 25% complete', name: 'CameraMetrics');
    } else if (progressPercentage >= 50 && !session.milestone50) {
      session.milestone50 = true;
      UnifiedLogger.debug('📊 Upload 50% complete', name: 'CameraMetrics');
    } else if (progressPercentage >= 75 && !session.milestone75) {
      session.milestone75 = true;
      UnifiedLogger.debug('📊 Upload 75% complete', name: 'CameraMetrics');
    }
  }

  /// Mark upload success
  void markUploadSuccess(String uploadId, {String? uploadUrl}) {
    final session = _uploadSessions[uploadId];
    if (session == null) return;

    session.completedTime = DateTime.now();
    final uploadTime = session.completedTime!
        .difference(session.startTime)
        .inMilliseconds;

    final uploadSpeedMbps =
        (session.fileSizeBytes * 8 / 1024 / 1024) / (uploadTime / 1000);

    UnifiedLogger.info(
      '✅ Upload complete: ${session.uploadType} in ${uploadTime}ms (${uploadSpeedMbps.toStringAsFixed(2)} Mbps)',
      name: 'CameraMetrics',
    );

    _analytics.logEvent(
      name: 'upload_complete',
      parameters: {
        'upload_type': session.uploadType,
        'file_size_bytes': session.fileSizeBytes,
        'file_size_mb': (session.fileSizeBytes / 1024 / 1024).toStringAsFixed(
          2,
        ),
        'upload_time_ms': uploadTime,
        'upload_speed_mbps': uploadSpeedMbps.toStringAsFixed(2),
        'success': true,
      },
    );

    _uploadSessions.remove(uploadId);
  }

  /// Mark upload failure
  void markUploadFailed(
    String uploadId,
    String errorMessage, {
    int? retryAttempt,
  }) {
    final session = _uploadSessions[uploadId];
    if (session == null) return;

    final attemptTime = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.error(
      '❌ Upload failed: ${session.uploadType} after ${attemptTime}ms - $errorMessage',
      name: 'CameraMetrics',
    );

    _analytics.logEvent(
      name: 'upload_complete',
      parameters: {
        'upload_type': session.uploadType,
        'file_size_bytes': session.fileSizeBytes,
        'upload_time_ms': attemptTime,
        'success': false,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
        if (retryAttempt != null) 'retry_attempt': retryAttempt,
      },
    );

    _uploadSessions.remove(uploadId);
  }

  /// Track camera permission request
  void trackCameraPermission({
    required bool granted,
    bool? permanentlyDenied,
    int? attemptNumber,
  }) {
    _analytics.logEvent(
      name: 'camera_permission',
      parameters: {
        'granted': granted,
        if (permanentlyDenied != null) 'permanently_denied': permanentlyDenied,
        if (attemptNumber != null) 'attempt_number': attemptNumber,
      },
    );

    UnifiedLogger.info(
      '🔐 Camera permission ${granted ? "granted" : "denied"}${permanentlyDenied == true ? " (permanently)" : ""}',
      name: 'CameraMetrics',
    );
  }

  /// Track camera-specific error types
  void trackCameraError({
    required String
    errorType, // 'device_busy', 'unsupported_format', 'hardware_failure', 'timeout'
    required String errorMessage,
    String? deviceModel,
    String? cameraType, // 'front', 'back', 'external'
    Map<String, dynamic>? additionalContext,
  }) {
    _analytics.logEvent(
      name: 'camera_error_detail',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (deviceModel != null) 'device_model': deviceModel,
        if (cameraType != null) 'camera_type': cameraType,
        if (additionalContext != null) ...additionalContext,
      },
    );

    UnifiedLogger.error(
      '📷 Camera error: $errorType - $errorMessage',
      name: 'CameraMetrics',
    );
  }

  /// Track camera resolution and quality settings
  void trackCameraSettings({
    required String resolution, // e.g., '1920x1080', '1280x720'
    required int fps,
    String? videoCodec,
    int? bitrate,
  }) {
    _analytics.logEvent(
      name: 'camera_settings',
      parameters: {
        'resolution': resolution,
        'fps': fps,
        if (videoCodec != null) 'video_codec': videoCodec,
        if (bitrate != null) 'bitrate': bitrate,
      },
    );

    UnifiedLogger.debug(
      '⚙️ Camera settings: $resolution @ ${fps}fps',
      name: 'CameraMetrics',
    );
  }

  /// Track frame drops during recording
  void trackFrameDrops({
    required String sessionId,
    required int droppedFrames,
    required int totalFrames,
    int? recordingDurationMs,
  }) {
    final dropRate = totalFrames > 0 ? (droppedFrames / totalFrames) : 0.0;

    _analytics.logEvent(
      name: 'camera_frame_drops',
      parameters: {
        'dropped_frames': droppedFrames,
        'total_frames': totalFrames,
        'drop_rate': dropRate.toStringAsFixed(4),
        if (recordingDurationMs != null)
          'recording_duration_ms': recordingDurationMs,
      },
    );

    if (droppedFrames > 0) {
      UnifiedLogger.warning(
        '⚠️ Frame drops: $droppedFrames/$totalFrames (${(dropRate * 100).toStringAsFixed(2)}%)',
        name: 'CameraMetrics',
      );
    }
  }

  /// Track camera device switch
  void trackCameraSwitch({
    required String fromCamera,
    required String toCamera,
    required int switchTimeMs,
  }) {
    _analytics.logEvent(
      name: 'camera_switch',
      parameters: {
        'from_camera': fromCamera,
        'to_camera': toCamera,
        'switch_time_ms': switchTimeMs,
        'success': true,
      },
    );

    UnifiedLogger.info(
      '🔄 Camera switched: $fromCamera → $toCamera in ${switchTimeMs}ms',
      name: 'CameraMetrics',
    );
  }

  /// Track camera switch failure
  void trackCameraSwitchFailed({
    required String fromCamera,
    required String toCamera,
    required String errorMessage,
    int? attemptTimeMs,
  }) {
    _analytics.logEvent(
      name: 'camera_switch',
      parameters: {
        'from_camera': fromCamera,
        'to_camera': toCamera,
        'success': false,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (attemptTimeMs != null) 'attempt_time_ms': attemptTimeMs,
      },
    );

    UnifiedLogger.error(
      '❌ Camera switch failed: $fromCamera → $toCamera - $errorMessage',
      name: 'CameraMetrics',
    );
  }

  /// Track camera mode change
  void trackCameraModeChange({
    required String fromMode,
    required String toMode,
  }) {
    _analytics.logEvent(
      name: 'camera_mode_change',
      parameters: {'from_mode': fromMode, 'to_mode': toMode},
    );
  }

  /// Track video preview action
  void trackVideoPreview({
    required String action, // 'play', 'pause', 'restart', 'trim'
    int? durationMs,
  }) {
    _analytics.logEvent(
      name: 'video_preview',
      parameters: {
        'action': action,
        if (durationMs != null) 'duration_ms': durationMs,
      },
    );
  }

  /// Track draft save/discard
  void trackDraft({
    required String action, // 'saved', 'discarded', 'resumed'
    int? fileSizeBytes,
    int? durationMs,
  }) {
    _analytics.logEvent(
      name: 'video_draft',
      parameters: {
        'action': action,
        if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
        if (durationMs != null) 'duration_ms': durationMs,
      },
    );

    UnifiedLogger.info('📝 Video draft $action', name: 'CameraMetrics');
  }
}

/// Internal session tracking for camera initialization
class _CameraSession {
  _CameraSession({required this.sessionId, required this.startTime});

  final String sessionId;
  final DateTime startTime;
  DateTime? readyTime;
}

/// Internal session tracking for recording
class _RecordingSession {
  _RecordingSession({required this.sessionId, required this.startTime});

  final String sessionId;
  final DateTime startTime;
  DateTime? stopTime;
  int? durationMs;
  int? fileSizeBytes;
}

/// Internal session tracking for upload
class _UploadSession {
  _UploadSession({
    required this.uploadId,
    required this.uploadType,
    required this.fileSizeBytes,
    required this.startTime,
  });

  final String uploadId;
  final String uploadType;
  final int fileSizeBytes;
  final DateTime startTime;
  DateTime? completedTime;
  int bytesUploaded = 0;

  bool milestone25 = false;
  bool milestone50 = false;
  bool milestone75 = false;
}
