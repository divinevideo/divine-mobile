// ABOUTME: Records one creation funnel from camera entry through publish.
// ABOUTME: Keeps mode and elapsed-time attribution consistent across routes.

import 'package:analytics/analytics.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:unified_logger/unified_logger.dart';

typedef CreationAnalyticsClock = DateTime Function();

/// Stages used by the creation funnel and its abandonment event.
enum CreationFunnelStage { camera, recording, editor, publishing }

/// App-scoped tracker for the active creation session.
///
/// The tracker is deliberately stateful so recorder, editor, metadata, and
/// publish routes all contribute to the same funnel without putting analytics
/// metadata on the Nostr event.
class CreationAnalyticsTracker {
  CreationAnalyticsTracker({
    required AnalyticsEventSink analytics,
    CreationAnalyticsClock? now,
  }) : _analytics = analytics,
       _now = now ?? DateTime.now;

  final AnalyticsEventSink _analytics;
  final CreationAnalyticsClock _now;

  VideoRecorderMode? _mode;
  DateTime? _cameraOpenedAt;
  CreationFunnelStage? _lastStage;
  bool _cameraOpenedLogged = false;
  bool _recordingStarted = false;
  bool _recordingCompleted = false;
  bool _editorOpened = false;
  bool _publishStarted = false;
  bool _terminal = false;

  VideoRecorderMode? get activeMode => _terminal ? null : _mode;
  DateTime? get cameraOpenedAt => _cameraOpenedAt;

  Future<void> cameraOpened({
    required VideoRecorderMode mode,
    required String entryPoint,
  }) async {
    if (_mode != null && !_terminal) {
      _mode = mode;
      if (_cameraOpenedLogged) return;
      _cameraOpenedAt = _now();
      _cameraOpenedLogged = true;
    } else {
      _reset(mode: mode, openedAt: _now(), cameraOpenedLogged: true);
    }

    await _logEvent(
      name: 'camera_opened',
      parameters: {'mode': mode.name, 'entry_point': entryPoint},
    );
  }

  void modeChanged(VideoRecorderMode mode) {
    if (!_terminal) _mode = mode;
  }

  Future<void> recordingStarted(VideoRecorderMode mode) async {
    _ensureSession(mode);
    if (_recordingStarted || _terminal) return;
    _recordingStarted = true;
    _lastStage = CreationFunnelStage.recording;
    await _logEvent(name: 'recording_started', parameters: {'mode': mode.name});
  }

  /// Logs that the creator continued from the recorder.
  ///
  /// [hasSound] says whether the takes were recorded against a sound, and
  /// [hasColorMask] whether any take carries a color mask. Both were modes of
  /// their own once, and are capture's sound chip and color mask now.
  Future<void> recordingCompleted({
    required VideoRecorderMode mode,
    required int clipCount,
    required Duration duration,
    bool hasSound = false,
    bool hasColorMask = false,
  }) async {
    _ensureSession(mode);
    if (_recordingCompleted || _terminal) return;
    _recordingCompleted = true;
    _lastStage = CreationFunnelStage.recording;
    await _logEvent(
      name: 'recording_completed',
      parameters: {
        'mode': mode.name,
        'clip_count': clipCount,
        'duration_ms': duration.inMilliseconds,
        // Firebase takes strings and numbers only, so the flags go as 1 or 0.
        'has_sound': hasSound ? 1 : 0,
        'has_color_mask': hasColorMask ? 1 : 0,
      },
    );
  }

  Future<void> editorOpened(VideoRecorderMode mode) async {
    _ensureSession(mode);
    if (_editorOpened || _terminal) return;
    _editorOpened = true;
    _lastStage = CreationFunnelStage.editor;
    await _logEvent(name: 'editor_opened', parameters: {'mode': mode.name});
  }

  Future<void> publishStarted(VideoRecorderMode mode) async {
    _ensureSession(mode);
    if (_terminal) return;
    _publishStarted = true;
    _lastStage = CreationFunnelStage.publishing;
    await _logEvent(
      name: 'publish_started',
      parameters: {
        'mode': mode.name,
        'time_since_camera_open_ms': ?_elapsedSinceCameraOpenMs,
      },
    );
  }

  Future<void> publishSucceeded(VideoRecorderMode mode) async {
    _ensureSession(mode);
    if (_terminal) return;
    await _logEvent(
      name: 'publish_succeeded',
      parameters: {
        'mode': mode.name,
        'time_since_camera_open_ms': ?_elapsedSinceCameraOpenMs,
      },
    );
    _terminal = true;
  }

  Future<void> publishFailed({
    required VideoRecorderMode mode,
    required String reason,
  }) async {
    _ensureSession(mode);
    if (_terminal) return;
    await _logEvent(
      name: 'publish_failed',
      parameters: {'mode': mode.name, 'reason': reason},
    );
  }

  Future<void> creationAbandoned() async {
    if (_mode == null || _lastStage == null || _terminal || _publishStarted) {
      return;
    }
    await _logEvent(
      name: 'creation_abandoned',
      parameters: {'mode': _mode!.name, 'last_stage': _lastStage!.name},
    );
    _terminal = true;
  }

  /// Null when the active session never opened the camera (an editor-only
  /// restored draft). Reporting `0` there would be indistinguishable from an
  /// instant publish and would drag the funnel's timing distribution down.
  int? get _elapsedSinceCameraOpenMs {
    final openedAt = _cameraOpenedAt;
    if (openedAt == null) return null;
    final elapsed = _now().difference(openedAt).inMilliseconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  void _ensureSession(VideoRecorderMode mode) {
    if (_mode == null || _terminal) {
      _reset(mode: mode, openedAt: null, cameraOpenedLogged: false);
    } else {
      _mode = mode;
    }
  }

  void _reset({
    required VideoRecorderMode mode,
    required DateTime? openedAt,
    required bool cameraOpenedLogged,
  }) {
    _mode = mode;
    _cameraOpenedAt = openedAt;
    _lastStage = CreationFunnelStage.camera;
    _cameraOpenedLogged = cameraOpenedLogged;
    _recordingStarted = false;
    _recordingCompleted = false;
    _editorOpened = false;
    _publishStarted = false;
    _terminal = false;
  }

  Future<void> _logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      Log.warning(
        'Creation analytics event $name failed: $error',
        name: 'CreationAnalyticsTracker',
        category: LogCategory.system,
      );
    }
  }
}
