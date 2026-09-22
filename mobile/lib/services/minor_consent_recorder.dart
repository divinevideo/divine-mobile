// ABOUTME: Port over CameraService for the minor-consent recording flow so the
// ABOUTME: capture screen is testable without native camera hardware.

import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Narrow recording surface used by the in-app parent-consent capture flow.
abstract class MinorConsentRecorder {
  /// Prepares the camera so the live preview and recording are ready.
  ///
  /// Call before [start]; a capture screen needs an initialized camera for its
  /// preview to render. Throws when the platform camera cannot be initialized.
  Future<void> initialize();

  /// Starts recording, capping the clip at [maxDuration] and writing it under
  /// [outputDirectory]. Returns whether the camera actually started.
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  });

  /// Stops recording and returns the recorded clip's file path, or null when
  /// nothing was captured.
  Future<String?> stop();

  /// Releases the underlying camera resources.
  Future<void> dispose();
}

/// [MinorConsentRecorder] backed by the app's platform [CameraService].
class CameraMinorConsentRecorder implements MinorConsentRecorder {
  CameraMinorConsentRecorder({required CameraService camera})
    : _camera = camera;

  final CameraService _camera;

  @override
  Future<void> initialize() => _camera.initialize();

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) => _camera.startRecording(
    maxDuration: maxDuration,
    outputDirectory: outputDirectory,
  );

  @override
  Future<String?> stop() async {
    final EditorVideo? video = await _camera.stopRecording();
    return video?.file?.path;
  }

  @override
  Future<void> dispose() => _camera.dispose();
}
