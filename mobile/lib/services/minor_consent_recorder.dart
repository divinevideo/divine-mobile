// ABOUTME: Port over CameraService for the minor-consent recording flow so the
// ABOUTME: capture screen is testable without native camera hardware.

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:openvine/services/minor_consent_recorder_port.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

export 'minor_consent_recorder_port.dart';

/// Extracts the clip path from the camera's auto-stop payload.
///
/// The platform hands back an [EditorVideo] when the 60-second cap fires or an
/// interruption ends the recording; the path is what the capture flow needs.
String? minorConsentAutoStoppedPath(EditorVideo? video) => video?.file?.path;

/// [MinorConsentRecorder] backed by the app's platform [CameraService].
class CameraMinorConsentRecorder implements MinorConsentRecorder {
  CameraMinorConsentRecorder({required CameraService camera})
    : _camera = camera;

  final CameraService _camera;
  bool _disposed = false;
  Future<void>? _disposal;
  final _initializations = <Future<void>>{};
  final _lifecycleOperations = <Future<void>>{};

  @override
  void Function(String? path)? onAutoStopped;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    final operation = _camera.initialize();
    _initializations.add(operation);
    try {
      await operation;
    } finally {
      _initializations.remove(operation);
    }
  }

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async {
    if (_disposed) return false;
    return _camera.startRecording(
      maxDuration: maxDuration,
      outputDirectory: outputDirectory,
    );
  }

  @override
  Future<String?> stop() async {
    final EditorVideo? video = await _camera.stopRecording();
    return video?.file?.path;
  }

  @override
  Future<void> handleAppLifecycleState(ConsentCameraLifecycle state) async {
    if (_disposed) return;
    final operation = _camera.handleAppLifecycleState(
      AppLifecycleState.values.byName(state.name),
    );
    _lifecycleOperations.add(operation);
    try {
      await operation;
    } finally {
      _lifecycleOperations.remove(operation);
    }
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      // A late initialization can acquire the camera after an early release.
      await Future.wait([..._initializations, ..._lifecycleOperations]);
    } finally {
      await _camera.dispose();
    }
  }
}
