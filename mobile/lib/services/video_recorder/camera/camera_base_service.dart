// ABOUTME: Base service for camera operations across different platforms
// ABOUTME: Provides unified API for camera control, recording, and preview

import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_linux_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Base service for camera operations across different platforms.
/// Provides a unified API for camera control, recording, and preview.
abstract class CameraService {
  /// Protected constructor for subclasses
  CameraService({required this.onUpdateState, required this.onAutoStopped});

  /// Factory constructor that returns the appropriate camera service
  /// implementation based on the current platform.
  factory CameraService.create({
    required void Function({bool? forceCameraRebuild}) onUpdateState,
    required void Function(EditorVideo? video) onAutoStopped,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return CameraLinuxService(
        onUpdateState: onUpdateState,
        onAutoStopped: onAutoStopped,
      );
    }
    return CameraMobileService(
      onUpdateState: onUpdateState,
      onAutoStopped: onAutoStopped,
    );
  }

  /// Callback to trigger UI updates when camera state changes.
  final void Function({bool? forceCameraRebuild}) onUpdateState;

  /// Called when the camera stops recording on its own — the max duration
  /// was reached, or (iOS only) the camera was interrupted. [video] is null
  /// when nothing was captured; the recording has ended either way.
  final void Function(EditorVideo? video) onAutoStopped;

  /// Initializes the camera and prepares it for use.
  ///
  /// [videoQuality] specifies the video recording quality (default: FHD/1080p).
  /// [initialLens] specifies which camera lens to initialize with
  /// (default: front).
  /// [enableAutoLensSwitch] enables automatic lens switching based on zoom
  /// level (default: true).
  /// [preferUnprocessedAudio] captures the microphone without the platform's
  /// speech-tuned noise suppression, so instruments survive at their real
  /// level (default: false). iOS and Android — see
  /// `MusicModePreferenceService`.
  ///
  /// Mobile implementations rethrow platform initialization failures after
  /// updating [initializationError]. Callers must handle those exceptions.
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  });

  /// Releases camera resources and cleans up.
  Future<void> dispose();

  /// Sets the flash mode. Returns true if successful.
  Future<bool> setFlashMode(DivineFlashMode mode);

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  Future<bool> setFocusPoint(Offset offset);

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  Future<bool> setExposurePoint(Offset offset);

  /// Sets the zoom level.
  ///
  /// Returns the zoom level the camera actually applied, or null on
  /// failure. The applied zoom can be lower than [value] when the OS
  /// restricts the available zoom range at runtime (iOS clamps such
  /// requests silently); [minZoomLevel] / [maxZoomLevel] reflect the
  /// refreshed range after the call.
  Future<double?> setZoomLevel(double value);

  /// Switches between front and back camera. Returns true if successful.
  Future<bool> switchCamera();

  /// Sets the video stabilization mode. Returns true if applied.
  Future<bool> setVideoStabilizationMode(DivineVideoStabilizationMode mode);

  /// Switches to a specific camera lens. Returns true if successful.
  Future<bool> setLens(DivineCameraLens lens);

  /// Starts video recording.
  /// [outputDirectory] specifies where to save the video.
  Future<bool> startRecording({Duration? maxDuration, String? outputDirectory});

  /// Stops video recording.
  Future<EditorVideo?> stopRecording();

  /// Captures a single still photo (e.g. for stop-motion).
  ///
  /// [outputDirectory] specifies where to save the photo. Returns the
  /// captured photo, or null if the camera is not ready or capture failed.
  Future<PhotoCaptureResult?> capturePhoto({String? outputDirectory});

  /// Handles app lifecycle changes (pause, resume, etc.).
  Future<void> handleAppLifecycleState(AppLifecycleState state);

  /// Releases the microphone until [resumeAudioCapture] or the next
  /// recording, leaving the preview running.
  ///
  /// Call it before the countdown beeps play out of the speaker: on iOS the
  /// mic is kept open between recordings, and the input level it settles on
  /// during the beeps takes seconds to recover, so a clip started right
  /// after them begins quiet and grows louder (#4539).
  Future<void> suspendAudioCapture();

  /// Reopens the microphone released by [suspendAudioCapture].
  ///
  /// Starting a recording reopens it as well, so a missed resume only moves
  /// the reopen onto the record tap.
  Future<void> resumeAudioCapture();

  /// The aspect ratio of the camera sensor.
  double get cameraAspectRatio;

  /// Minimum zoom level supported by the camera.
  double get minZoomLevel;

  /// Maximum zoom level supported by the camera.
  double get maxZoomLevel;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized;

  /// Whether the camera supports manual focus point selection.
  bool get isFocusPointSupported;

  /// Whether the camera is ready to record (initialized and not recording).
  bool get canRecord;

  /// Whether the device has multiple cameras to switch between.
  bool get canSwitchCamera;

  /// Whether a camera switch is currently in progress.
  /// Used to block recording triggers during the switch.
  bool get isSwitchingCamera;

  /// The Flutter texture id backing the live preview, or null when no camera
  /// is active. Changes when a lens switch rebinds the preview onto a fresh
  /// texture; the UI keys the preview on it so the new camera's frames are
  /// picked up.
  int? get textureId;

  /// Whether the device can active the camera-flash.
  bool get hasFlash;

  /// The current active camera lens.
  DivineCameraLens get currentLens;

  /// List of available camera lenses on this device.
  List<DivineCameraLens> get availableLenses;

  /// The currently requested video stabilization mode.
  DivineVideoStabilizationMode get videoStabilizationMode;

  /// The stabilization modes supported by the active camera/lens.
  List<DivineVideoStabilizationMode> get availableVideoStabilizationModes;

  /// Whether the active camera supports video stabilization beyond off.
  bool get isVideoStabilizationSupported;

  /// Metadata for the currently active camera lens.
  /// Returns null if metadata is not available.
  CameraLensMetadata? get currentLensMetadata;

  /// Why initialization failed, or null if it succeeded.
  ///
  /// A reason code rather than a message: `state_management.md` forbids error
  /// strings in state, and this value is carried into `VideoRecorderBlocState`
  /// and localized by the UI.
  CameraInitializationError? get initializationError;

  /// Enables or disables remote record control via volume buttons.
  ///
  /// When enabled, volume button presses will trigger the
  /// [setOnRemoteRecordTrigger] callback instead of changing the system volume.
  /// This allows users to start/stop recording using physical volume buttons
  /// or Bluetooth accessories like clickers or earbuds.
  ///
  /// Returns `true` if successfully enabled/disabled.
  Future<bool> setRemoteRecordControlEnabled({required bool enabled});

  /// Enables or disables volume key interception.
  ///
  /// When disabled, volume buttons will change system volume instead of
  /// triggering recording. Bluetooth media buttons are NOT affected.
  /// Use this when a sound is selected and the user needs to adjust volume.
  ///
  /// Returns `true` if successfully set.
  Future<bool> setVolumeKeysEnabled({required bool enabled});

  /// Callback for when a remote record trigger is detected.
  ///
  /// This is called when the user presses a volume button or Bluetooth
  /// remote while remote record control is enabled.
  void setOnRemoteRecordTrigger(void Function()? callback);
}
