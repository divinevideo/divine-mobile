// ABOUTME: Base service for camera operations across different platforms
// ABOUTME: Provides unified API for camera control, recording, and preview

import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/models/audio_device.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/photo_capture_result.dart';
import 'package:divine_camera/src/models/remote_record_trigger.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:divine_camera/src/models/video_stabilization_mode.dart';
import 'package:flutter/widgets.dart';

// Export models for external use
export 'src/models/audio_device.dart';
export 'src/models/camera_lens.dart';
export 'src/models/camera_lens_metadata.dart';
export 'src/models/camera_state.dart';
export 'src/models/camera_zoom_state.dart';
export 'src/models/flash_mode.dart';
export 'src/models/photo_capture_result.dart';
export 'src/models/remote_record_trigger.dart';
export 'src/models/video_quality.dart';
export 'src/models/video_recording_result.dart';
export 'src/models/video_stabilization_mode.dart';
// Export widgets
export 'src/widgets/camera_preview_widget.dart';

/// Base service for camera operations across different platforms.
/// Provides a unified API for camera control, recording, and preview.
///
/// Use [DivineCamera.instance] to access the singleton instance:
/// ```dart
/// await DivineCamera.instance.initialize();
/// ```
class DivineCamera {
  DivineCamera._internal();

  /// The singleton instance of [DivineCamera].
  static final DivineCamera instance = DivineCamera._internal();

  /// Callback invoked when camera state changes.
  void Function(CameraState state)? onStateChanged;

  /// Callback invoked when the native layer stops a recording on its own —
  /// the max duration was reached, or the camera was interrupted. The result
  /// is null when nothing was captured; recording has ended either way.
  void Function(VideoRecordingResult? result)? onRecordingAutoStopped;

  /// Callback invoked when a remote record trigger is detected.
  ///
  /// This includes volume button presses or Bluetooth remote triggers
  /// when remote record control is enabled.
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  /// Whether remote record control is currently enabled.
  bool _remoteRecordControlEnabled = false;

  /// Whether remote record control is currently enabled.
  bool get remoteRecordControlEnabled => _remoteRecordControlEnabled;

  /// The current camera state.
  CameraState _state = const CameraState();

  /// Gets the current camera state.
  CameraState get state => _state;

  /// Whether the front camera video output should be mirrored.
  /// When `true`, recorded video appears as mirror image (like preview).
  /// When `false`, recorded video shows real-world orientation.
  bool _mirrorFrontCameraOutput = false;

  /// Gets whether the front camera video output is mirrored.
  bool get mirrorFrontCameraOutput => _mirrorFrontCameraOutput;

  /// The platform interface instance.
  DivineCameraPlatform get _platform => DivineCameraPlatform.instance;

  /// Handles auto-stop event from platform.
  void _handleAutoStop(VideoRecordingResult? result) {
    _state = _state.copyWith(isRecording: false);
    _notifyStateChanged();
    onRecordingAutoStopped?.call(result);
  }

  /// Handles remote record trigger event from platform.
  void _handleRemoteRecordTrigger(RemoteRecordTrigger trigger) {
    onRemoteRecordTrigger?.call(trigger);
  }

  /// Returns the platform version.
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Initializes the camera and prepares it for use.
  ///
  /// [lens] specifies which camera to use (front or back).
  /// [videoQuality] specifies the video recording quality (default: FHD/1080p).
  /// [enableScreenFlash] enables using screen brightness as flash for
  /// front camera (default: true).
  /// [mirrorFrontCameraOutput] controls whether the front camera video output
  /// is horizontally mirrored.
  /// When `true`, the recorded video appears
  /// as a mirror image (like the preview).
  /// When `false`, the video shows the real-world orientation (non-mirrored).
  /// The preview is always mirrored.
  /// [preferUnprocessedAudio] captures the microphone without the
  /// speech-tuned noise suppression the platform applies by default, so
  /// instruments and music survive at their real level. iOS and Android
  /// act on it; every other platform ignores it.
  ///
  /// Returns the initialized camera state.
  Future<CameraState> initialize({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = true,
    bool preferUnprocessedAudio = false,
  }) async {
    // Register auto-stop callback with platform
    _platform.onRecordingAutoStopped = _handleAutoStop;

    // Register remote record trigger callback with platform
    _platform.onRemoteRecordTrigger = _handleRemoteRecordTrigger;

    // Store the mirror setting for preview widget
    _mirrorFrontCameraOutput = mirrorFrontCameraOutput;

    _state = await _platform.initializeCamera(
      lens: lens,
      videoQuality: videoQuality,
      enableScreenFlash: enableScreenFlash,
      mirrorFrontCameraOutput: mirrorFrontCameraOutput,
      enableAutoLensSwitch: enableAutoLensSwitch,
      preferUnprocessedAudio: preferUnprocessedAudio,
    );
    _notifyStateChanged();
    return _state;
  }

  /// Releases camera resources and cleans up.
  ///
  /// This also clears any registered listeners.
  Future<void> dispose() async {
    await _platform.disposeCamera();
    _state = const CameraState();
    _notifyStateChanged();

    // Clear listeners to prevent memory leaks
    onStateChanged = null;
    onRecordingAutoStopped = null;
    onRemoteRecordTrigger = null;
    _platform.onRecordingAutoStopped = null;
    _platform.onRemoteRecordTrigger = null;
    _remoteRecordControlEnabled = false;
  }

  /// Sets the flash mode.
  ///
  /// [mode] the flash mode to set.
  /// Returns true if successful.
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    final success = await _platform.setFlashMode(mode);
    if (success) {
      _state = _state.copyWith(flashMode: mode);
      _notifyStateChanged();
    }
    return success;
  }

  /// Sets the focus point.
  ///
  /// [offset] is a point in the displayed (upright) preview's normalized
  /// coordinates (0.0-1.0), i.e. where the user tapped. It is mapped onto the
  /// raw sensor axes here so a rotated preview focuses the right spot; see
  /// [_sensorOrientedPoint].
  /// Returns true if successful.
  Future<bool> setFocusPoint(Offset offset) async {
    if (!_state.isFocusPointSupported) return false;
    return _platform.setFocusPoint(_sensorOrientedPoint(offset));
  }

  /// Sets the exposure point.
  ///
  /// [offset] is a point in the displayed (upright) preview's normalized
  /// coordinates (0.0-1.0); it is mapped onto the raw sensor axes here the same
  /// way as [setFocusPoint].
  /// Returns true if successful.
  Future<bool> setExposurePoint(Offset offset) async {
    if (!_state.isExposurePointSupported) return false;
    return _platform.setExposurePoint(_sensorOrientedPoint(offset));
  }

  /// Maps a point normalized against the displayed (upright) preview back into
  /// the raw sensor texture's coordinate space by undoing the clockwise
  /// [CameraState.previewRotationDegrees] the UI applies to render the preview
  /// upright (the Android ImageReader path). Native metering maps normalized
  /// coords onto the un-rotated sensor, so without this a non-center tap on a
  /// 90/270 preview would meter the wrong point. Returns the point unchanged
  /// when no rotation applies (the common 0° / SurfaceTexture cases).
  Offset _sensorOrientedPoint(Offset point) {
    final quarterTurns = (_state.previewRotationDegrees ~/ 90) % 4;
    return switch (quarterTurns) {
      1 => Offset(point.dy, 1.0 - point.dx),
      2 => Offset(1.0 - point.dx, 1.0 - point.dy),
      3 => Offset(1.0 - point.dy, point.dx),
      _ => point,
    };
  }

  /// Cancels any active focus/metering lock and returns to continuous
  /// auto-focus mode.
  ///
  /// Call this to reset focus behavior after a tap-to-focus.
  /// For example, when recording ends or camera switches.
  /// Returns true if successful.
  Future<bool> cancelFocusAndMetering() async {
    return _platform.cancelFocusAndMetering();
  }

  /// Sets the zoom level.
  ///
  /// [level] the zoom level to set.
  ///
  /// Returns the zoom level the camera actually applied, or `null` when
  /// the platform failed to apply it. The applied zoom can be lower than
  /// [level]: on iOS virtual multi-camera devices the system restricts
  /// the available zoom range at runtime and silently clamps out-of-range
  /// assignments, so the platform reads the factor back after setting it.
  /// The live range reported alongside it replaces [minZoomLevel] /
  /// [maxZoomLevel], keeping [state] honest in both directions (it heals
  /// once a runtime restriction lifts).
  Future<double?> setZoomLevel(double level) async {
    final clampedLevel = level.clamp(_state.minZoomLevel, _state.maxZoomLevel);
    final zoom = await _platform.setZoomLevel(clampedLevel);
    if (zoom == null) return null;
    _state = _state.copyWith(
      zoomLevel: zoom.zoomLevel,
      minZoomLevel: zoom.minZoomLevel,
      maxZoomLevel: zoom.maxZoomLevel,
    );
    _notifyStateChanged();
    return zoom.zoomLevel;
  }

  /// Switches between front and back camera.
  ///
  /// Returns true if successful. Returns false while a switch is already in
  /// flight: the native side now completes a switch on the incoming camera's
  /// first frame, so a re-entrant call would clobber that pending completion
  /// and target the wrong lens.
  Future<bool> switchCamera() async {
    if (!_state.canSwitchCamera || _state.isSwitchingCamera) return false;
    final newLens = _state.lens.opposite;

    // Set switching state to keep last frame visible
    _state = _state.copyWith(isSwitchingCamera: true);
    _notifyStateChanged();

    // Reset the flag in `finally` so a thrown platform switch (e.g. a CameraX
    // bind failure) doesn't leave `isSwitchingCamera` stuck true — which would
    // both freeze the preview and, via the re-entrancy guard above, block every
    // later switch for the session.
    try {
      _state = await _platform.switchCamera(newLens);
      return true;
    } finally {
      _state = _state.copyWith(isSwitchingCamera: false);
      _notifyStateChanged();
    }
  }

  /// Sets the video stabilization mode.
  ///
  /// The selected mode stabilizes the recorded file. On iOS 17+ the live
  /// preview is stabilized independently through a preview-optimized output so
  /// it stays smooth at record start, so the preview and the recording may use
  /// different stabilization internally. On platforms without stabilization
  /// support (macOS, Linux) this is a no-op that returns false.
  ///
  /// [mode] the stabilization mode to apply.
  /// Returns true if the requested mode was applied. Returns false while a
  /// lens switch is in flight: on Android the mode change rebinds through the
  /// same native switch path, so it would clobber the switch's pending
  /// first-frame completion and hold the frozen preview until its timeout.
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async {
    if (_state.isSwitchingCamera) return false;
    final success = await _platform.setVideoStabilizationMode(mode);
    if (success) {
      _state = _state.copyWith(videoStabilizationMode: mode);
      _notifyStateChanged();
    }
    return success;
  }

  /// Switches to a specific camera lens.
  ///
  /// [lens] the lens to switch to.
  /// Returns true if successful. Returns false while a switch is already in
  /// flight, for the same reason as [switchCamera].
  Future<bool> setLens(DivineCameraLens lens) async {
    if (lens == _state.lens) return true;
    if (!_state.availableLenses.contains(lens) || _state.isSwitchingCamera) {
      return false;
    }

    // Set switching state to keep last frame visible
    _state = _state.copyWith(isSwitchingCamera: true);
    _notifyStateChanged();

    // Reset the flag in `finally` for the same reason as [switchCamera]: a
    // thrown switch must not strand `isSwitchingCamera` true.
    try {
      _state = await _platform.switchCamera(lens);
      return true;
    } finally {
      _state = _state.copyWith(isSwitchingCamera: false);
      _notifyStateChanged();
    }
  }

  /// Starts video recording.
  ///
  /// [maxDuration] optionally limits the recording duration.
  /// When the duration is reached, recording stops automatically.
  /// [useCache] if true, saves video to cache directory (temporary),
  /// otherwise saves to documents directory (permanent). Defaults to true.
  /// [outputDirectory] specifies where to save the video.
  ///
  /// Returns true if recording successfully started (first keyframe recorded),
  /// false if recording failed to start or was stopped before first keyframe.
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    if (!_state.canRecord) return false;
    final result = await _platform.startRecording(
      maxDuration: maxDuration,
      useCache: useCache,
      outputDirectory: outputDirectory,
    );
    if (result) {
      _state = _state.copyWith(isRecording: true);
      _notifyStateChanged();
    }
    return result;
  }

  /// Stops video recording.
  ///
  /// Returns the recorded video result, or null if recording failed.
  Future<VideoRecordingResult?> stopRecording() async {
    if (!_state.isRecording) return null;
    try {
      return await _platform.stopRecording();
    } finally {
      _state = _state.copyWith(isRecording: false);
      _notifyStateChanged();
    }
  }

  /// Captures a single still photo from the live camera feed.
  ///
  /// Intended for stop-motion capture: each call writes one JPEG frame to
  /// disk and returns its location. Audio is never involved.
  ///
  /// [useCache] if true, saves the photo to the cache directory (temporary),
  /// otherwise to the documents directory (permanent). Defaults to true.
  /// [outputDirectory] specifies where to save the photo.
  ///
  /// Returns the captured photo result, or null if the camera is not ready
  /// or capture failed. Capture is rejected while a video recording is in
  /// progress.
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) async {
    if (!_state.isInitialized || _state.isRecording) return null;
    return _platform.capturePhoto(
      outputDirectory: outputDirectory,
      useCache: useCache,
    );
  }

  /// Handles app lifecycle changes (pause, resume, etc.).
  Future<void> handleAppLifecycleState(AppLifecycleState appState) async {
    if (!_state.isInitialized) return;

    switch (appState) {
      case AppLifecycleState.inactive:
        // `.inactive` fires on transient foreground interruptions (Control
        // Center / notification shade / app-switcher pulls) with no real
        // background transition. Stop the preview but keep the audio session
        // so we don't churn other apps' playback on every such pull; genuine
        // background always follows with `.paused`/`.hidden`.
        await _platform.pausePreview(releaseAudio: false);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await _platform.pausePreview();
      case AppLifecycleState.resumed:
        await _platform.resumePreview();
        _state = await _platform.getCameraState();
        _notifyStateChanged();
    }
  }

  /// Releases the microphone until [resumeAudioCapture] or the next
  /// recording, leaving the preview running.
  ///
  /// Call it before playing sound out of the speaker ahead of a recording
  /// (the countdown beeps). iOS keeps the mic open between recordings so
  /// the record tap is instant, and the input level it settles on while
  /// the speaker plays into the mic takes seconds to recover — a clip
  /// started right after the beeps begins quiet and grows louder. Closing
  /// the mic for the beeps and reopening it afterwards starts the recording
  /// on a fresh input path. No-op while recording or before [initialize].
  Future<void> suspendAudioCapture() async {
    if (!_state.isInitialized || _state.isRecording) return;
    await _platform.suspendAudioCapture();
  }

  /// Reopens the microphone released by [suspendAudioCapture].
  ///
  /// [startRecording] reopens it as well, so skipping this only moves the
  /// reopen onto the record tap, where it delays the whole recording.
  /// No-op before [initialize].
  Future<void> resumeAudioCapture() async {
    if (!_state.isInitialized) return;
    await _platform.resumeAudioCapture();
  }

  /// Enables or disables remote record control via volume buttons.
  ///
  /// When enabled, volume button presses will trigger the
  /// [onRemoteRecordTrigger] callback instead of changing the system volume.
  /// This allows users to start/stop recording using physical volume buttons
  /// or Bluetooth accessories like clickers or earbuds.
  ///
  /// Returns `true` if successfully enabled/disabled.
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    final success = await _platform.setRemoteRecordControlEnabled(
      enabled: enabled,
    );
    if (success) {
      _remoteRecordControlEnabled = enabled;
    }
    return success;
  }

  /// Enables or disables volume key interception.
  ///
  /// When disabled, volume buttons will change system volume instead of
  /// triggering recording. Bluetooth media buttons are NOT affected and will
  /// continue to trigger recording.
  ///
  /// Use this when a sound is selected and the user needs to adjust volume
  /// for the sound preview.
  ///
  /// Returns `true` if successfully set.
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    return _platform.setVolumeKeysEnabled(enabled: enabled);
  }

  /// The aspect ratio of the camera sensor.
  double get cameraAspectRatio => _state.aspectRatio;

  /// Minimum zoom level supported by the camera.
  double get minZoomLevel => _state.minZoomLevel;

  /// Maximum zoom level supported by the camera.
  double get maxZoomLevel => _state.maxZoomLevel;

  /// The current zoom level.
  double get zoomLevel => _state.zoomLevel;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized => _state.isInitialized;

  /// Whether the camera supports manual focus point selection.
  bool get isFocusPointSupported => _state.isFocusPointSupported;

  /// Whether the camera supports manual exposure point selection.
  bool get isExposurePointSupported => _state.isExposurePointSupported;

  /// Whether the camera is ready to record (initialized and not recording).
  bool get canRecord => _state.canRecord;

  /// Whether the device has multiple cameras to switch between.
  bool get canSwitchCamera => _state.canSwitchCamera;

  /// Whether the device can activate the camera-flash.
  bool get hasFlash => _state.hasFlash;

  /// Whether the camera is currently recording.
  bool get isRecording => _state.isRecording;

  /// Whether the device has a front-facing camera.
  bool get hasFrontCamera => _state.hasFrontCamera;

  /// Whether the device has a back-facing camera.
  bool get hasBackCamera => _state.hasBackCamera;

  /// Whether the camera is currently switching between lenses.
  bool get isSwitchingCamera => _state.isSwitchingCamera;

  /// The texture ID for the camera preview.
  int? get textureId => _state.textureId;

  /// The currently active camera lens (front or back).
  DivineCameraLens get lens => _state.lens;

  /// The currently requested video stabilization mode.
  DivineVideoStabilizationMode get videoStabilizationMode =>
      _state.videoStabilizationMode;

  /// The stabilization modes supported by the active camera/lens.
  List<DivineVideoStabilizationMode> get availableVideoStabilizationModes =>
      _state.availableVideoStabilizationModes;

  /// Whether the active camera supports video stabilization beyond off.
  bool get isVideoStabilizationSupported =>
      _state.isVideoStabilizationSupported;

  /// Lists available audio input devices (microphones).
  ///
  /// Returns an empty list on platforms that do not support device
  /// enumeration.
  Future<List<AudioDevice>> listAudioDevices() {
    return _platform.listAudioDevices();
  }

  /// Notifies listeners of state changes.
  void _notifyStateChanged() {
    onStateChanged?.call(_state);
  }
}
