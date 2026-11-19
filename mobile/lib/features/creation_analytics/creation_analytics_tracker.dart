// ABOUTME: Records one creation funnel from camera entry through publish.
// ABOUTME: Keeps mode and elapsed-time attribution consistent across routes.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:unified_logger/unified_logger.dart';

typedef CreationAnalyticsClock = DateTime Function();

/// Stages used by the creation funnel and its abandonment event.
enum CreationFunnelStage { camera, recording, editor, publishing }

/// Owns the recorder events of a flow that can open the camera repeatedly.
class CreationAnalyticsSession {
  bool _closed = false;
}

/// The analytics context retained while a publish can finish in the background.
class CreationAnalyticsPublishAttempt {
  CreationAnalyticsPublishAttempt._(this._mode, this._cameraOpenedAt);

  final VideoRecorderMode _mode;
  final DateTime? _cameraOpenedAt;
  bool _completed = false;
}

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
  CreationAnalyticsSession? _cameraSession;
  CreationAnalyticsSession? _editorSession;
  bool _cameraOpenedLogged = false;
  bool _recordingStarted = false;
  bool _recordingCompleted = false;
  bool _editorOpened = false;
  CreationAnalyticsPublishAttempt? _publishAttempt;
  bool _terminal = false;

  VideoRecorderMode? get activeMode => _terminal ? null : _mode;
  DateTime? get cameraOpenedAt => _cameraOpenedAt;

  /// Mode of the camera flow this recorder is joining, if it is still active.
  VideoRecorderMode? activeRecorderMode(
    CreationAnalyticsSession? session, {
    bool continuesEditorSession = false,
  }) {
    if (!_accepts(session) ||
        _startsAfterEditorOrPublish(
          session,
          continuesEditorSession: continuesEditorSession,
        )) {
      return null;
    }
    return activeMode;
  }

  Future<void> cameraOpened({
    required VideoRecorderMode mode,
    required String entryPoint,
    CreationAnalyticsSession? session,
    bool continuesEditorSession = false,
  }) async {
    if (session?._closed ?? false) return;
    final startsNewFunnel = _startsAfterEditorOrPublish(
      session,
      continuesEditorSession: continuesEditorSession,
    );
    final previous = _cameraSession;
    if (startsNewFunnel || !identical(previous, session)) {
      // A publish attempt suppresses abandonment analytics. The replacement
      // still needs a fresh funnel even when there is no abandonment event.
      if (startsNewFunnel || previous != null) {
        unawaited(creationAbandoned(session: previous));
      }
      _cameraSession = session;
      _reset(mode: mode, openedAt: _now(), cameraOpenedLogged: true);
    } else if (_mode != null && !_terminal) {
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

  void modeChanged(
    VideoRecorderMode mode, {
    CreationAnalyticsSession? session,
  }) {
    if (_accepts(session) && !_terminal) _mode = mode;
  }

  Future<void> recordingStarted(
    VideoRecorderMode mode, {
    CreationAnalyticsSession? session,
  }) async {
    if (!_accepts(session)) return;
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
    CreationAnalyticsSession? session,
  }) async {
    if (!_accepts(session)) return;
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

  /// Claims a reaction at editor mount, before the editor can open a recorder.
  Future<void> claimEditorSession(CreationAnalyticsSession session) async {
    final mode = activeRecorderMode(session);
    if (mode == null) return;
    session._closed = true;
    _cameraSession = null;
    _editorSession = session;
    await editorOpened(mode);
  }

  /// Ends a mounted reaction editor without abandoning a newer session.
  Future<void> abandonEditorSession(CreationAnalyticsSession session) async {
    if (identical(_editorSession, session)) await creationAbandoned();
  }

  Future<void> editorOpened(VideoRecorderMode mode) async {
    if (_cameraSession case final session?) {
      unawaited(creationAbandoned(session: session));
      _cameraSession = null;
    }
    _ensureSession(mode);
    if (_editorOpened || _terminal) return;
    _editorOpened = true;
    _lastStage = CreationFunnelStage.editor;
    await _logEvent(name: 'editor_opened', parameters: {'mode': mode.name});
  }

  Future<CreationAnalyticsPublishAttempt> publishStarted(
    VideoRecorderMode mode,
  ) async {
    _ensureSession(mode);
    final attempt = CreationAnalyticsPublishAttempt._(mode, _cameraOpenedAt);
    _publishAttempt = attempt;
    _lastStage = CreationFunnelStage.publishing;
    await _logEvent(
      name: 'publish_started',
      parameters: {
        'mode': mode.name,
        'time_since_camera_open_ms': ?_elapsedSinceCameraOpenMs(
          attempt._cameraOpenedAt,
        ),
      },
    );
    return attempt;
  }

  Future<void> publishSucceeded(CreationAnalyticsPublishAttempt attempt) async {
    if (attempt._completed) return;
    attempt._completed = true;
    if (identical(_publishAttempt, attempt)) _terminal = true;
    await _logEvent(
      name: 'publish_succeeded',
      parameters: {
        'mode': attempt._mode.name,
        'time_since_camera_open_ms': ?_elapsedSinceCameraOpenMs(
          attempt._cameraOpenedAt,
        ),
      },
    );
  }

  Future<void> publishFailed(
    CreationAnalyticsPublishAttempt attempt, {
    required String reason,
  }) async {
    if (attempt._completed) return;
    attempt._completed = true;
    await _logEvent(
      name: 'publish_failed',
      parameters: {'mode': attempt._mode.name, 'reason': reason},
    );
  }

  Future<void> creationAbandoned({CreationAnalyticsSession? session}) async {
    if (session != null) session._closed = true;
    if (!identical(_cameraSession, session) ||
        _mode == null ||
        _lastStage == null ||
        _terminal ||
        _publishAttempt != null) {
      return;
    }
    // The next camera can open before the analytics transport finishes.
    _terminal = true;
    await _logEvent(
      name: 'creation_abandoned',
      parameters: {'mode': _mode!.name, 'last_stage': _lastStage!.name},
    );
  }

  // A standalone camera can open while the preceding editor is disposing or
  // its publish is still finishing in the background.
  bool _startsAfterEditorOrPublish(
    CreationAnalyticsSession? session, {
    required bool continuesEditorSession,
  }) =>
      (_editorSession != null || _publishAttempt != null) &&
      (session != null || !continuesEditorSession);

  bool _accepts(CreationAnalyticsSession? session) =>
      identical(_cameraSession, session) && !(session?._closed ?? false);

  /// Null when the active session never opened the camera (an editor-only
  /// restored draft). Reporting `0` there would be indistinguishable from an
  /// instant publish and would drag the funnel's timing distribution down.
  int? _elapsedSinceCameraOpenMs(DateTime? openedAt) {
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
    _editorSession = null;
    _cameraOpenedAt = openedAt;
    _lastStage = CreationFunnelStage.camera;
    _cameraOpenedLogged = cameraOpenedLogged;
    _recordingStarted = false;
    _recordingCompleted = false;
    _editorOpened = false;
    _publishAttempt = null;
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
