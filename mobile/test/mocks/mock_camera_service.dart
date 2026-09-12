// ABOUTME: Mock implementation of CameraService for testing
// ABOUTME: Provides a fake camera service that doesn't require actual hardware

import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mock camera service for testing without requiring actual camera hardware
class MockCameraService extends CameraService {
  bool _isInitialized = false;
  bool _isRecording = false;
  double zoomLevel = 1.0;
  DivineFlashMode flashMode = DivineFlashMode.auto;
  Offset focusPoint = Offset.zero;
  DivineCameraLens _currentLens = DivineCameraLens.back;
  DivineVideoStabilizationMode stabilizationMode =
      DivineVideoStabilizationMode.off;

  MockCameraService.create({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    _currentLens = initialLens;
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    flashMode = mode;
    return true;
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    focusPoint = offset;
    return true;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    return true;
  }

  @override
  Future<double?> setZoomLevel(double value) async {
    return zoomLevel = value.clamp(minZoomLevel, maxZoomLevel);
  }

  @override
  Future<bool> switchCamera() async {
    _currentLens = _currentLens.opposite;
    return true;
  }

  @override
  Future<bool> setLens(DivineCameraLens lens) async {
    _currentLens = lens;
    return true;
  }

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async {
    stabilizationMode = mode;
    return true;
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    _isRecording = true;
    return true;
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    _isRecording = false;
    return null; // Return null in mock
  }

  @override
  Future<PhotoCaptureResult?> capturePhoto({String? outputDirectory}) async {
    if (!_isInitialized) return null;
    return const PhotoCaptureResult(
      filePath: '/mock/photo.jpg',
      width: 1080,
      height: 1920,
    );
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    // Mock implementation - do nothing, just return successfully
    return;
  }

  @override
  double get cameraAspectRatio => 16 / 9;

  @override
  double get minZoomLevel => 1.0;

  @override
  double get maxZoomLevel => 8.0;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported => true;

  @override
  bool get canRecord => _isInitialized && !_isRecording;

  @override
  bool get canSwitchCamera => true;

  @override
  bool get isSwitchingCamera => false;

  @override
  int? get textureId => null;

  @override
  bool get hasFlash => true;

  @override
  DivineCameraLens get currentLens => _currentLens;

  @override
  List<DivineCameraLens> get availableLenses => [
    DivineCameraLens.front,
    DivineCameraLens.back,
    DivineCameraLens.ultraWide,
  ];

  @override
  DivineVideoStabilizationMode get videoStabilizationMode => stabilizationMode;

  @override
  List<DivineVideoStabilizationMode> get availableVideoStabilizationModes =>
      const [
        DivineVideoStabilizationMode.off,
        DivineVideoStabilizationMode.standard,
        DivineVideoStabilizationMode.cinematic,
        DivineVideoStabilizationMode.auto,
      ];

  @override
  bool get isVideoStabilizationSupported => true;

  @override
  CameraLensMetadata? get currentLensMetadata => null;

  @override
  CameraInitializationError? get initializationError => null;

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    return true;
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    return true;
  }

  @override
  void setOnRemoteRecordTrigger(void Function()? callback) {
    // Mock implementation - do nothing
  }
}
