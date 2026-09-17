// ABOUTME: Platform interface for divine_camera plugin
// ABOUTME: Defines abstract methods for camera operations across platforms

import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:divine_camera/src/models/audio_device.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/camera_zoom_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/photo_capture_result.dart';
import 'package:divine_camera/src/models/remote_record_trigger.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:divine_camera/src/models/video_stabilization_mode.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of divine_camera must implement.
abstract class DivineCameraPlatform extends PlatformInterface {
  /// Constructs a DivineCameraPlatform.
  DivineCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static DivineCameraPlatform _instance = MethodChannelDivineCamera();

  /// The default instance of [DivineCameraPlatform] to use.
  static DivineCameraPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DivineCameraPlatform].
  static set instance(DivineCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Initializes the camera with the specified lens.
  ///
  /// [preferUnprocessedAudio] asks the platform to capture the microphone
  /// without the speech-tuned processing it applies by default. iOS and
  /// Android act on it; other platforms ignore it.
  ///
  /// Returns the initial camera state.
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = true,
    bool preferUnprocessedAudio = false,
  }) {
    throw UnimplementedError('initializeCamera() has not been implemented.');
  }

  /// Disposes of camera resources.
  Future<void> disposeCamera() {
    throw UnimplementedError('disposeCamera() has not been implemented.');
  }

  /// Sets the flash mode.
  /// Returns true if successful.
  Future<bool> setFlashMode(DivineCameraFlashMode mode) {
    throw UnimplementedError('setFlashMode() has not been implemented.');
  }

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  /// Returns true if successful.
  Future<bool> setFocusPoint(Offset offset) {
    throw UnimplementedError('setFocusPoint() has not been implemented.');
  }

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  /// Returns true if successful.
  Future<bool> setExposurePoint(Offset offset) {
    throw UnimplementedError('setExposurePoint() has not been implemented.');
  }

  /// Cancels any active focus/metering lock and returns to continuous
  /// auto-focus mode.
  /// Call this to reset focus behavior after a tap-to-focus.
  Future<bool> cancelFocusAndMetering() {
    throw UnimplementedError(
      'cancelFocusAndMetering() has not been implemented.',
    );
  }

  /// Sets the zoom level.
  ///
  /// Returns the zoom state the camera actually applied (read back from
  /// the device, together with the live available zoom range), or `null`
  /// when the platform failed to apply the zoom. The applied zoom can be
  /// lower than [level] when the OS restricts the available range at
  /// runtime — see [CameraZoomState].
  Future<CameraZoomState?> setZoomLevel(double level) {
    throw UnimplementedError('setZoomLevel() has not been implemented.');
  }

  /// Switches to the specified camera lens.
  /// Returns the new camera state.
  Future<CameraState> switchCamera(DivineCameraLens lens) {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  /// Sets the video stabilization mode.
  /// Returns true if the requested mode was applied.
  Future<bool> setVideoStabilizationMode(DivineVideoStabilizationMode mode) {
    throw UnimplementedError(
      'setVideoStabilizationMode() has not been implemented.',
    );
  }

  /// Starts video recording.
  ///
  /// [maxDuration] optionally limits the recording duration.
  /// [useCache] if true, saves video to cache directory (temporary), otherwise
  /// saves to documents directory (permanent). Defaults to true.
  /// [outputDirectory] specifies where to save the video.
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) {
    throw UnimplementedError('startRecording() has not been implemented.');
  }

  /// Stops video recording and returns the result.
  Future<VideoRecordingResult?> stopRecording() {
    throw UnimplementedError('stopRecording() has not been implemented.');
  }

  /// Captures a single still photo from the live camera feed.
  ///
  /// [useCache] if true, saves the photo to the cache directory (temporary),
  /// otherwise to the documents directory (permanent). Defaults to true.
  /// [outputDirectory] specifies where to save the photo.
  ///
  /// Returns the captured photo result, or null if capture failed.
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) {
    throw UnimplementedError('capturePhoto() has not been implemented.');
  }

  /// Pauses the camera preview.
  ///
  /// When [releaseAudio] is `true` (genuine background), the platform also
  /// releases the microphone and deactivates the shared audio session so the
  /// OS stops attributing an active recording to the app. Pass `false` for
  /// transient foreground interruptions (e.g. iOS `.inactive` from a Control
  /// Center / app-switcher pull), which stop only the video preview and leave
  /// the audio session untouched to avoid churning other apps' playback.
  Future<void> pausePreview({bool releaseAudio = true}) {
    throw UnimplementedError('pausePreview() has not been implemented.');
  }

  /// Resumes the camera preview.
  Future<void> resumePreview() {
    throw UnimplementedError('resumePreview() has not been implemented.');
  }

  /// Releases the microphone until [resumeAudioCapture] or the next
  /// recording.
  ///
  /// Platforms that keep the mic open between recordings so the record tap
  /// is instant (iOS) close it here; platforms that open the mic per
  /// recording anyway treat this as a no-op. The preview keeps running.
  Future<void> suspendAudioCapture() {
    throw UnimplementedError('suspendAudioCapture() has not been implemented.');
  }

  /// Reopens the microphone released by [suspendAudioCapture].
  ///
  /// Starting a recording reopens it as well, so a resume that never comes
  /// is harmless; calling this ahead of the recording keeps the reopen off
  /// the record tap.
  Future<void> resumeAudioCapture() {
    throw UnimplementedError('resumeAudioCapture() has not been implemented.');
  }

  /// Gets the current camera state.
  Future<CameraState> getCameraState() {
    throw UnimplementedError('getCameraState() has not been implemented.');
  }

  /// Builds the platform-specific camera preview widget.
  Widget buildPreview(int textureId) {
    throw UnimplementedError('buildPreview() has not been implemented.');
  }

  /// Callback for when the native layer stops a recording on its own — the
  /// max duration was reached, or (iOS only) the camera was interrupted. The
  /// result is null when nothing was captured.
  void Function(VideoRecordingResult? result)? get onRecordingAutoStopped {
    throw UnimplementedError(
      'onRecordingAutoStopped has not been implemented.',
    );
  }

  /// Sets the callback for when the native layer stops a recording on its
  /// own. See [onRecordingAutoStopped].
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult? result)? callback,
  ) {
    throw UnimplementedError(
      'onRecordingAutoStopped has not been implemented.',
    );
  }

  /// Callback for when a remote record trigger is detected (volume button
  /// or Bluetooth remote).
  void Function(RemoteRecordTrigger trigger)? get onRemoteRecordTrigger {
    throw UnimplementedError('onRemoteRecordTrigger has not been implemented.');
  }

  /// Sets the callback for when a remote record trigger is detected.
  set onRemoteRecordTrigger(
    void Function(RemoteRecordTrigger trigger)? callback,
  ) {
    throw UnimplementedError('onRemoteRecordTrigger has not been implemented.');
  }

  /// Enables or disables remote record control via volume buttons.
  ///
  /// When enabled, volume button presses will trigger the
  /// [onRemoteRecordTrigger] callback instead of changing the system volume.
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) {
    throw UnimplementedError(
      'setRemoteRecordControlEnabled() has not been implemented.',
    );
  }

  /// Enables or disables volume key interception.
  ///
  /// When disabled, volume buttons will change system volume instead of
  /// triggering recording. Bluetooth media buttons are NOT affected.
  /// Use this when a sound is selected and the user needs to adjust volume.
  Future<bool> setVolumeKeysEnabled({required bool enabled}) {
    throw UnimplementedError(
      'setVolumeKeysEnabled() has not been implemented.',
    );
  }

  /// Lists available audio input devices (microphones).
  ///
  /// Returns an empty list on platforms that do not support device
  /// enumeration.
  Future<List<AudioDevice>> listAudioDevices() {
    throw UnimplementedError('listAudioDevices() has not been implemented.');
  }
}
