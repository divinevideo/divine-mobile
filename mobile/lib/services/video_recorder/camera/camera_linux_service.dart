// ABOUTME: Stub camera service for Linux where native camera is unavailable.
// ABOUTME: Returns no-op results so the app can run for browsing/watching.

import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult;
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Linux stub implementation of [CameraService].
///
/// Camera hardware access is not yet available on Linux. This service
/// always reports [isInitialized] as `false` and reports
/// [CameraInitializationError.unsupportedPlatform] via [initializationError]
/// so the placeholder UI renders localized copy.
/// All recording methods are safe no-ops.
class CameraLinuxService extends CameraService {
  /// Creates a Linux camera service stub.
  CameraLinuxService({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  @override
  CameraInitializationError? get initializationError =>
      CameraInitializationError.unsupportedPlatform;

  @override
  bool get isInitialized => false;

  @override
  bool get canRecord => false;

  @override
  bool get canSwitchCamera => false;

  @override
  bool get isSwitchingCamera => false;

  @override
  int? get textureId => null;

  @override
  bool get hasFlash => false;

  @override
  bool get isFocusPointSupported => false;

  @override
  double get cameraAspectRatio => 9 / 16;

  @override
  double get minZoomLevel => 1;

  @override
  double get maxZoomLevel => 1;

  @override
  DivineCameraLens get currentLens => DivineCameraLens.front;

  @override
  List<DivineCameraLens> get availableLenses => const [];

  @override
  DivineVideoStabilizationMode get videoStabilizationMode =>
      DivineVideoStabilizationMode.off;

  @override
  List<DivineVideoStabilizationMode> get availableVideoStabilizationModes =>
      const [DivineVideoStabilizationMode.off];

  @override
  bool get isVideoStabilizationSupported => false;

  @override
  CameraLensMetadata? get currentLensMetadata => null;

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    Log.info(
      'Camera is not available on Linux - showing placeholder',
      name: 'CameraLinuxService',
      category: LogCategory.video,
    );
    onUpdateState();
  }

  @override
  Future<void> dispose() async {
    // No resources to release.
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async => false;

  @override
  Future<bool> setFocusPoint(Offset offset) async => false;

  @override
  Future<bool> setExposurePoint(Offset offset) async => false;

  @override
  Future<double?> setZoomLevel(double value) async => null;

  @override
  Future<bool> switchCamera() async => false;

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async => false;

  @override
  Future<bool> setLens(DivineCameraLens lens) async => false;

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async => false;

  @override
  Future<EditorVideo?> stopRecording() async => null;

  @override
  Future<PhotoCaptureResult?> capturePhoto({String? outputDirectory}) async =>
      null;

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    // No lifecycle management needed.
  }

  @override
  Future<void> suspendAudioCapture() async {
    // The Linux camera has no microphone to release.
  }

  @override
  Future<void> resumeAudioCapture() async {
    // The Linux camera has no microphone to reopen.
  }

  @override
  void setOnRemoteRecordTrigger(void Function()? callback) {
    // Remote record control is not supported on Linux.
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async =>
      false;

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async => false;
}
