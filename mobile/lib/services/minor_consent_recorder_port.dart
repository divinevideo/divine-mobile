// ABOUTME: Platform-independent recording boundary for parent consent.

import 'package:openvine/models/consent_camera_lifecycle.dart';

export 'package:openvine/models/consent_camera_lifecycle.dart';

/// Narrow recording surface used by the in-app parent-consent capture flow.
abstract class MinorConsentRecorder {
  /// Invoked when the camera stops recording on its own — the max duration was
  /// reached, or (iOS only) the camera was interrupted. Receives the recorded
  /// clip's path, or null when nothing was captured.
  ///
  /// The capture cubit subscribes here so an auto-stop reaches the UI instead
  /// of leaving it stuck on the recording pane.
  void Function(String? path)? onAutoStopped;

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

  /// Forwards app visibility changes to the camera preview and audio session.
  Future<void> handleAppLifecycleState(ConsentCameraLifecycle state);

  /// Releases the underlying camera resources.
  Future<void> dispose();
}
