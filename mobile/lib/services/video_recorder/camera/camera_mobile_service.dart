// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Mobile implementation of [CameraService] using the `divine_camera` package.
///
/// Manages camera initialization, recording, and switching between front/back cameras.
class CameraMobileService extends CameraService implements DualCameraCapture {
  /// Creates a mobile camera service instance.
  CameraMobileService({
    required super.onUpdateState,
    required super.onAutoStopped,
    super.onScreenFlashChanged,
  });

  // The platform has a single controller shared by all recorder routes.
  static CameraMobileService? _cameraOwner;
  static Future<void> _cameraTransition = Future<void>.value();
  static Completer<void>? _captureTeardown;

  Completer<void>? _retainedCapture;
  int _initializationRequest = 0;
  bool _isInitialized = false;
  CameraInitializationError? _initializationError;
  final DivineCamera _camera = DivineCamera.instance;

  /// The second camera's file of the last stopped take, until
  /// [takeSecondaryRecording] hands it over.
  VideoRecordingResult? _secondaryRecording;

  static Future<T> _transition<T>(Future<T> Function() change) {
    final operation = _cameraTransition.then((_) => change());
    _cameraTransition = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        // The caller receives the error. Later transitions can still run.
      },
    );
    return operation;
  }

  /// Protects a take before it starts on the shared native camera. A new
  /// recorder can mount before Flutter disposes the outgoing recorder route.
  void holdCaptureForRetention() {
    if (!identical(_cameraOwner, this)) return;
    _retainedCapture ??= Completer<void>();
  }

  /// Allows another recorder to open once the take has been retained.
  void releaseRetainedCapture() {
    final capture = _retainedCapture;
    _retainedCapture = null;
    capture?.complete();
  }

  /// Gives an outgoing recorder time to finish its take and release the
  /// controller before a replacement route opens the same native camera.
  Future<void> finishCaptureTeardown(Future<void> Function() teardown) async {
    if (!identical(_cameraOwner, this) || _captureTeardown != null) {
      await teardown();
      return;
    }
    final completed = _captureTeardown = Completer<void>();
    try {
      await teardown();
    } finally {
      _captureTeardown = null;
      completed.complete();
    }
  }

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
    bool mirrorFrontCameraOutput = false,
  }) async {
    final request = ++_initializationRequest;
    while (request == _initializationRequest) {
      final outgoing = await _transition(() async {
        if (request != _initializationRequest) return null;
        if (_captureTeardown case final teardown?) return teardown;
        if (_cameraOwner?._retainedCapture case final capture?) {
          return identical(_cameraOwner, this) ? null : capture;
        }
        // The recorder that held the camera — say the Together tab under a
        // part's recorder — has to hear that it lost it, or it shows a dead
        // preview when it comes back instead of opening the camera again.
        final displaced = _cameraOwner;
        if (displaced != null && !identical(displaced, this)) {
          displaced._isInitialized = false;
          displaced.onUpdateState();
        }
        _cameraOwner = this;
        await _initializeCamera(
          videoQuality: videoQuality,
          initialLens: initialLens,
          enableAutoLensSwitch: enableAutoLensSwitch,
          preferUnprocessedAudio: preferUnprocessedAudio,
          videoStabilizationMode: videoStabilizationMode,
          mirrorFrontCameraOutput: mirrorFrontCameraOutput,
        );
        return null;
      });
      if (outgoing == null) return;
      await outgoing.future;
    }
  }

  Future<void> _initializeCamera({
    required DivineVideoQuality videoQuality,
    required DivineCameraLens initialLens,
    required bool enableAutoLensSwitch,
    required bool preferUnprocessedAudio,
    required DivineVideoStabilizationMode videoStabilizationMode,
    required bool mirrorFrontCameraOutput,
  }) async {
    _isInitialized = false;
    _initializationError = null;

    Log.info(
      '📷 Initializing mobile camera with quality: ${videoQuality.value}, '
      'lens: ${initialLens.displayName}, '
      'mirrorFrontCameraOutput: $mirrorFrontCameraOutput',
      name: 'CameraMobileService',
      category: .video,
    );
    try {
      await _camera.initialize(
        lens: initialLens,
        videoQuality: videoQuality,
        enableAutoLensSwitch: enableAutoLensSwitch,
        preferUnprocessedAudio: preferUnprocessedAudio,
        videoStabilizationMode: videoStabilizationMode,
        mirrorFrontCameraOutput: mirrorFrontCameraOutput,
      );
      _camera.onRecordingAutoStopped = (result) {
        _holdSecondaryRecording(result?.secondary);
        onAutoStopped(
          result == null ? null : EditorVideo.file(result.filePath),
        );
      };
      _camera.onScreenFlashChanged = onScreenFlashChanged;
      // Replace the previous recorder’s trigger as part of the handoff.
      _camera.onRemoteRecordTrigger = null;
      if (_remoteRecordTriggerCallback != null) {
        final callback = _remoteRecordTriggerCallback!;
        _camera.onRemoteRecordTrigger = (trigger) {
          Log.info(
            '🎮 Native remote trigger received: $trigger',
            name: 'CameraMobileService',
            category: .video,
          );
          callback(trigger);
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

    _initializationRequest++;
    releaseRetainedCapture();
    _isInitialized = false;
    onUpdateState();
    await _transition(() async {
      if (!identical(_cameraOwner, this)) return;
      _cameraOwner = null;
      _isInitialized = false;
      await _camera.dispose();
    });
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
    // No per-call log: a pinch sends one request per pointer update.
    try {
      // DivineCamera clamps the request and returns what the camera
      // actually applied (which iOS can silently cap below the request).
      final applied = await _camera.setZoomLevel(value);
      if (applied != null && (applied - value).abs() > 0.01) {
        Log.debug(
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

      // False when only one camera is usable or a switch is already in
      // flight; nothing changed, so there is nothing to rebuild.
      final success = await _camera.switchCamera();
      if (success) {
        onUpdateState(forceCameraRebuild: true);
        Log.info(
          '📷 Camera switched',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return success;
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
      _holdSecondaryRecording(result!.secondary);

      return EditorVideo.autoSource(file: result.filePath);
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
  bool get isDualCameraSupported => _camera.isDualCameraSupported;

  @override
  bool get isDualCameraEnabled => _camera.isDualCameraEnabled;

  @override
  SecondaryCameraState? get secondaryCamera => _camera.secondaryCamera;

  @override
  Future<bool> setDualCameraEnabled({required bool enabled}) async {
    if (!_isInitialized) return false;
    try {
      final applied = await _camera.setDualCameraEnabled(enabled: enabled);
      Log.info(
        '📷 Dual camera ${enabled ? 'on' : 'off'}: applied=$applied',
        name: 'CameraMobileService',
        category: .video,
      );
      onUpdateState(forceCameraRebuild: true);
      return applied;
    } catch (e) {
      Log.error(
        '📷 Failed to change dual camera: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      onUpdateState(forceCameraRebuild: true);
      return false;
    }
  }

  @override
  VideoRecordingResult? takeSecondaryRecording() {
    final secondary = _secondaryRecording;
    _secondaryRecording = null;
    return secondary;
  }

  /// Keeps the second camera's file of a stopped take for the recorder. A
  /// file the recorder never took is deleted: nothing else references it.
  void _holdSecondaryRecording(VideoRecordingResult? secondary) {
    final stale = _secondaryRecording;
    if (stale != null && stale.filePath != secondary?.filePath) {
      _deleteQuietly(stale.filePath);
    }
    _secondaryRecording = secondary;
  }

  static void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e) {
      Log.warning(
        '📷 Could not delete an unused second camera file: $e',
        name: 'CameraMobileService',
        category: .video,
      );
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
    if (!identical(_cameraOwner, this)) return;
    await _camera.handleAppLifecycleState(state);
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

  void Function(RemoteRecordTrigger)? _remoteRecordTriggerCallback;

  @override
  void setOnRemoteRecordTrigger(void Function(RemoteRecordTrigger)? callback) {
    _remoteRecordTriggerCallback = callback;
    if (!identical(_cameraOwner, this)) return;
    // Connect to native callback with logging
    _camera.onRemoteRecordTrigger = callback != null
        ? (trigger) {
            Log.info(
              '🎮 Native remote trigger received: $trigger',
              name: 'CameraMobileService',
              category: .video,
            );
            callback(trigger);
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
