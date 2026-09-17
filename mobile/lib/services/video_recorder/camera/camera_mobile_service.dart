// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Mobile implementation of [CameraService] using the camera package.
///
/// Manages camera initialization, recording, and switching between front/back cameras.
class CameraMobileService extends CameraService {
  /// Creates a mobile camera service instance.
  CameraMobileService({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  bool _isInitialized = false;
  CameraInitializationError? _initializationError;
  final DivineCamera _camera = DivineCamera.instance;

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    _isInitialized = false;
    _initializationError = null;

    Log.info(
      '📷 Initializing mobile camera with quality: ${videoQuality.value}, '
      'lens: ${initialLens.displayName}',
      name: 'CameraMobileService',
      category: .video,
    );
    try {
      await _camera.initialize(
        lens: initialLens,
        videoQuality: videoQuality,
        enableAutoLensSwitch: enableAutoLensSwitch,
        preferUnprocessedAudio: preferUnprocessedAudio,
      );
      _camera.onRecordingAutoStopped = (result) {
        onAutoStopped(
          result == null ? null : EditorVideo.file(result.filePath),
        );
      };
      // Re-apply remote record trigger callback (gets cleared on dispose)
      if (_remoteRecordTriggerCallback != null) {
        final callback = _remoteRecordTriggerCallback!;
        _camera.onRemoteRecordTrigger = (trigger) {
          Log.info(
            '🎮 Native remote trigger received: $trigger',
            name: 'CameraMobileService',
            category: .video,
          );
          callback();
        };
        Log.debug(
          '🎮 Remote record trigger callback re-applied after initialize',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      _isInitialized = true;
    } catch (e, stackTrace) {
      _initializationError = CameraInitializationError.failed;
      Log.error(
        '📷 Failed to initialize camera: $e',
        name: 'CameraMobileService',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(e, stackTrace);
    } finally {
      onUpdateState(forceCameraRebuild: true);
    }
  }

  @override
  Future<void> dispose() async {
    Log.info(
      '📷 Disposing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );

    _isInitialized = false;
    onUpdateState();
    await _camera.dispose();
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting flash mode to ${mode.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      await _camera.setFlashMode(_getFlashMode(mode));
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set flash mode (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting focus point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.setFocusPoint(offset);

      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set focus point (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting exposure point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.setExposurePoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set exposure point (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<double?> setZoomLevel(double value) async {
    if (!_isInitialized) return null;
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMobileService',
        category: .video,
      );

      // DivineCamera clamps the request and returns what the camera
      // actually applied (which iOS can silently cap below the request).
      final applied = await _camera.setZoomLevel(value);
      if (applied != null && (applied - value).abs() > 0.01) {
        Log.info(
          '📷 Zoom clamped by platform: requested $value, applied $applied '
          '(available ${_camera.minZoomLevel}-${_camera.maxZoomLevel})',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return applied;
    } catch (e) {
      Log.error(
        '📷 Failed to set zoom level (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (!_isInitialized) return false;
    _isSwitchingCamera = true;
    try {
      Log.info(
        '📷 Switching camera',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.switchCamera();
      onUpdateState(forceCameraRebuild: true);

      Log.info(
        '📷 Camera switched',
        name: 'CameraMobileService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to switch camera (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    } finally {
      _isSwitchingCamera = false;
    }
  }

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting video stabilization mode to ${mode.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      final success = await _camera.setVideoStabilizationMode(mode);
      if (success) onUpdateState();
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set video stabilization mode (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setLens(DivineCameraLens lens) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Switching to lens: ${lens.displayName}',
        name: 'CameraMobileService',
        category: .video,
      );

      final success = await _camera.setLens(lens);
      if (success) {
        onUpdateState(forceCameraRebuild: true);
        Log.info(
          '📷 Switched to lens: ${lens.displayName}',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set lens: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    if (!_isInitialized) return false;
    try {
      final docsDir = await getDocumentsPath();
      final outputPath = outputDirectory ?? docsDir;

      Log.info(
        '📷 Starting video recording to: $outputPath',
        name: 'CameraMobileService',
        category: .video,
      );
      final success = await _camera.startRecording(
        maxDuration: maxDuration,
        useCache: false,
        outputDirectory: outputPath,
      );
      if (success) {
        Log.info(
          '📷 Video recording truly started',
          name: 'CameraMobileService',
          category: .video,
        );
      } else {
        Log.warning(
          '📷 Recording failed to start or was stopped before first keyframe',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to start recording (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    if (!_isInitialized) return null;
    try {
      Log.info(
        '📷 Stopping video recording',
        name: 'CameraMobileService',
        category: .video,
      );

      final result = await _camera.stopRecording();

      Log.info(
        '📷 Video recording stopped',
        name: 'CameraMobileService',
        category: .video,
      );
      if (result?.filePath == null) return null;

      return EditorVideo.autoSource(file: result!.filePath);
    } catch (e) {
      Log.error(
        '📷 Failed to stop recording (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }
  }

  @override
  Future<PhotoCaptureResult?> capturePhoto({String? outputDirectory}) async {
    if (!_isInitialized) return null;
    try {
      final docsDir = await getDocumentsPath();
      final outputPath = outputDirectory ?? docsDir;

      Log.info(
        '📷 Capturing photo to: $outputPath',
        name: 'CameraMobileService',
        category: .video,
      );

      final result = await _camera.capturePhoto(
        outputDirectory: outputPath,
        useCache: false,
      );

      if (result == null) {
        Log.warning(
          '📷 Photo capture returned no result',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return result;
    } catch (e) {
      Log.error(
        '📷 Failed to capture photo (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    return _camera.handleAppLifecycleState(state);
  }

  @override
  Future<void> suspendAudioCapture() async {
    if (!_isInitialized) return;
    try {
      await _camera.suspendAudioCapture();
    } catch (e) {
      // The countdown still runs; the clip just keeps today's audio path.
      Log.warning(
        '📷 Failed to suspend audio capture: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
    }
  }

  @override
  Future<void> resumeAudioCapture() async {
    if (!_isInitialized) return;
    try {
      await _camera.resumeAudioCapture();
    } catch (e) {
      // startRecording reopens the mic itself, so the recording still gets
      // audio; only the reopen moves onto the record tap.
      Log.warning(
        '📷 Failed to resume audio capture: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
    }
  }

  /// Converts [DivineFlashMode] to [DivineCameraFlashMode] mode.
  DivineCameraFlashMode _getFlashMode(DivineFlashMode mode) {
    return switch (mode) {
      .torch => .torch,
      .auto => .auto,
      .off => .off,
    };
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get canRecord => isInitialized;

  @override
  double get cameraAspectRatio => _camera.cameraAspectRatio;

  @override
  double get minZoomLevel => _camera.minZoomLevel;

  @override
  double get maxZoomLevel => _camera.maxZoomLevel;

  @override
  bool get isFocusPointSupported => _camera.isFocusPointSupported;

  @override
  bool get hasFlash => _camera.hasFlash;

  @override
  bool get canSwitchCamera => _camera.canSwitchCamera;

  bool _isSwitchingCamera = false;

  @override
  bool get isSwitchingCamera => _isSwitchingCamera;

  @override
  int? get textureId => _camera.textureId;

  @override
  DivineCameraLens get currentLens => _camera.state.lens;

  @override
  List<DivineCameraLens> get availableLenses => _camera.state.availableLenses;

  @override
  DivineVideoStabilizationMode get videoStabilizationMode =>
      _camera.state.videoStabilizationMode;

  @override
  List<DivineVideoStabilizationMode> get availableVideoStabilizationModes =>
      _camera.state.availableVideoStabilizationModes;

  @override
  bool get isVideoStabilizationSupported =>
      _camera.state.isVideoStabilizationSupported;

  @override
  CameraLensMetadata? get currentLensMetadata =>
      _camera.state.currentLensMetadata;

  @override
  CameraInitializationError? get initializationError => _initializationError;

  void Function()? _remoteRecordTriggerCallback;

  @override
  void setOnRemoteRecordTrigger(void Function()? callback) {
    _remoteRecordTriggerCallback = callback;
    // Connect to native callback with logging
    _camera.onRemoteRecordTrigger = callback != null
        ? (trigger) {
            Log.info(
              '🎮 Native remote trigger received: $trigger',
              name: 'CameraMobileService',
              category: .video,
            );
            callback();
          }
        : null;
    Log.debug(
      '🎮 Remote record trigger callback ${callback != null ? 'set' : 'cleared'}',
      name: 'CameraMobileService',
      category: .video,
    );
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting remote record control: ${enabled ? 'enabled' : 'disabled'}',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      final success = await _camera.setRemoteRecordControlEnabled(
        enabled: enabled,
      );
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set remote record control: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      return false;
    }
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    if (!_isInitialized) return false;
    try {
      Log.debug(
        '📷 Setting volume keys: ${enabled ? 'enabled' : 'disabled'}',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      final success = await _camera.setVolumeKeysEnabled(enabled: enabled);
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set volume keys enabled: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
