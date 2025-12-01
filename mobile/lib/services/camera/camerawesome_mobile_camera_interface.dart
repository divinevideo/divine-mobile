// ABOUTME: CamerAwesome-based mobile camera implementation with physical sensor switching
// ABOUTME: Replaces Flutter camera package with CamerAwesome for seamless multi-camera support

import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/services/camera/camera_zoom_detector.dart';
import 'package:openvine/utils/unified_logger.dart';

/// CamerAwesome-based camera implementation with physical sensor switching
class CamerAwesomeMobileCameraInterface extends CameraPlatformInterface {
  CameraState? _cameraState;
  bool _isRecording = false;
  // Hold reference to CaptureRequest to prevent garbage collection
  CaptureRequest? _currentCaptureRequest;

  // Use a static to ensure the pathBuilder closure can access the current path
  // This is needed because CameraAwesomeBuilder captures the closure at build time
  static String? _pendingRecordingPath;
  String? _currentRecordingPath;

  // Physical camera sensors detected on device
  List<PhysicalCameraSensor> _availableSensors = []; // Rear cameras only
  int _currentSensorIndex = 0;

  // Front camera and flip state
  PhysicalCameraSensor? _frontCamera;
  bool _isFrontCamera = false;
  int _lastRearCameraIndex =
      0; // Remember which rear camera was active before flip

  // Stream controller for camera state updates
  final _stateController = StreamController<CameraState>.broadcast();

  @override
  Future<void> initialize() async {
    try {
      Log.info(
        'Initializing CamerAwesome camera interface...',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // Lock device orientation to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      Log.info(
        'Device orientation locked to portrait up',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // Detect available physical cameras and their zoom factors
      _availableSensors = await CameraZoomDetector.getSortedBackCameras();
      Log.info(
        'Detected ${_availableSensors.length} physical cameras: ${_availableSensors.map((s) => '${s.displayName} (${s.zoomFactor}x)').join(', ')}',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // If only 1 physical camera, add synthetic 2x digital zoom to simulate multi-camera behavior
      if (_availableSensors.length == 1) {
        final physicalCamera = _availableSensors[0];
        _availableSensors.add(
          PhysicalCameraSensor(
            type: 'digital',
            zoomFactor: 2.0,
            deviceId: physicalCamera.deviceId, // Same device, digital zoom
            displayName: '2x',
            isDigital: true,
          ),
        );
        Log.info(
          'Added digital 2x zoom for single-camera device',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }

      // CamerAwesome defaults to wide-angle camera (1.0x), so set current index to match
      // Sorted list: [0.5x ultrawide, 1.0x wide, 3.0x telephoto] or [1.0x wide, 2.0x digital]
      _currentSensorIndex = _availableSensors.indexWhere(
        (s) => s.zoomFactor == 1.0,
      );
      if (_currentSensorIndex == -1) {
        _currentSensorIndex = 0; // Fallback to first camera if 1.0x not found
      }

      if (_availableSensors.isNotEmpty) {
        Log.info(
          'Initial camera: ${_availableSensors[_currentSensorIndex].displayName} (${_availableSensors[_currentSensorIndex].zoomFactor}x)',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }

      // Detect front camera for flip functionality
      _frontCamera = await CameraZoomDetector.getFrontCamera();
      if (_frontCamera != null) {
        Log.info(
          'Front camera detected: ${_frontCamera!.displayName}',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }

      // CamerAwesome will be initialized via the builder widget
      // We don't initialize it here - the widget handles that

      Log.info(
        'CamerAwesome camera initialized successfully',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'CamerAwesome camera initialization failed: $e',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      Log.warning(
        'Already recording, ignoring duplicate start request',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    try {
      Log.info(
        'Starting video recording to: $filePath',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // IMPORTANT: Set BOTH static and instance path BEFORE calling startRecording
      // The static is used by pathBuilder (which may be in a different instance due to closure capture)
      CamerAwesomeMobileCameraInterface._pendingRecordingPath = filePath;
      _currentRecordingPath = filePath;
      _isRecording = true;

      Log.info(
        'Path set to $filePath (static: $_pendingRecordingPath) before starting recording',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // Start recording via CamerAwesome state
      await _cameraState!.when(
        onPhotoMode: (state) async {
          throw Exception('Camera in photo mode, cannot record video');
        },
        onVideoMode: (state) async {
          // startRecording returns CaptureRequest - hold reference to prevent GC
          _currentCaptureRequest = await state.startRecording();
          Log.info(
            'Recording started with capture request: ${_currentCaptureRequest?.path}',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
        },
        onVideoRecordingMode: (state) async {
          Log.warning(
            'Already in recording mode',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
        },
        onPreparingCamera: (state) async {
          throw Exception('Camera still preparing');
        },
      );

      // Verify the path was used correctly
      if (_currentCaptureRequest?.path != filePath) {
        Log.warning(
          'Recording path mismatch! Expected: $filePath, Got: ${_currentCaptureRequest?.path}',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }

      Log.info(
        'Video recording started successfully',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      _isRecording = false;
      _currentRecordingPath = null;
      Log.error(
        'Failed to start recording: $e',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<String?> stopRecordingSegment() async {
    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    if (!_isRecording) {
      Log.warning(
        'Not currently recording, ignoring stop request',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      Log.info(
        'Stopping video recording...',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      final recordedPath = _currentRecordingPath;
      bool didStop = false;

      // Stop recording via CamerAwesome state
      await _cameraState!.when(
        onPhotoMode: (state) async {
          Log.warning(
            'Camera in photo mode during stop - recording may have failed',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
        },
        onVideoMode: (state) async {
          Log.warning(
            'Camera in video mode (not recording mode) during stop - recording may have failed',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
        },
        onVideoRecordingMode: (state) async {
          await state.stopRecording();
          didStop = true;
        },
        onPreparingCamera: (state) async {
          Log.warning(
            'Camera still preparing during stop',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
        },
      );

      _isRecording = false;
      _currentRecordingPath = null;
      _currentCaptureRequest = null; // Clear reference

      if (didStop) {
        Log.info(
          'Video recording stopped: $recordedPath',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
        return recordedPath;
      } else {
        Log.warning(
          'Recording stop may not have completed properly',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
        // Still return the path - the file might exist from a successful recording
        return recordedPath;
      }
    } catch (e) {
      _isRecording = false;
      _currentRecordingPath = null;
      _currentCaptureRequest = null;
      Log.error(
        'Failed to stop recording: $e',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_frontCamera == null) {
      Log.warning(
        'No front camera available for flipping',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    try {
      Log.info(
        'Switching camera: currently ${_isFrontCamera ? "front" : "rear"}',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // Use CamerAwesome's built-in switchCameraSensor which properly handles
      // front/back camera switching with correct surface management
      await _cameraState!.switchCameraSensor(
        aspectRatio: CameraAspectRatios.ratio_16_9,
        zoom: 0.0,
        flash: FlashMode.none,
      );

      // Toggle our tracking state
      _isFrontCamera = !_isFrontCamera;

      if (!_isFrontCamera) {
        // Switched back to rear - restore the last rear camera index
        _currentSensorIndex = _lastRearCameraIndex;
      } else {
        // Switching to front - save current rear camera index
        _lastRearCameraIndex = _currentSensorIndex;
      }

      Log.info(
        'Camera flip completed: now ${_isFrontCamera ? "front" : "rear"}',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to flip camera: $e',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Switch to a specific sensor by zoom factor
  Future<void> switchToSensor(double zoomFactor) async {
    if (_availableSensors.isEmpty) {
      Log.warning(
        'No physical sensors available',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    // Find sensor with matching zoom factor
    final sensorIndex = _availableSensors.indexWhere(
      (s) => (s.zoomFactor - zoomFactor).abs() < 0.1,
    );

    if (sensorIndex == -1) {
      Log.warning(
        'No sensor found for zoom factor: $zoomFactor',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    // If on front camera, switch back to rear camera first
    if (_isFrontCamera) {
      Log.info(
        'Switching from front to rear camera due to zoom selection',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      _isFrontCamera = false;
    }

    if (sensorIndex == _currentSensorIndex && !_isFrontCamera) {
      Log.debug(
        'Already on sensor: ${_availableSensors[sensorIndex].displayName}',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    _currentSensorIndex = sensorIndex;
    _lastRearCameraIndex = sensorIndex; // Update last rear camera
    final sensor = _availableSensors[_currentSensorIndex];

    Log.info(
      'Switching to sensor: ${sensor.displayName} (${sensor.zoomFactor}x)${sensor.isDigital ? ' [digital zoom]' : ''}',
      name: 'CamerAwesomeCamera',
      category: LogCategory.system,
    );

    if (sensor.isDigital) {
      // Digital zoom - apply zoom to current physical sensor
      // CamerAwesome zoom is normalized 0.0-1.0, where:
      // 0.0 = 1x (no zoom), 1.0 = max zoom (typically 4x-10x)
      // For 2x digital zoom, use 0.33 (assumes ~6x max zoom)
      final normalizedZoom =
          (sensor.zoomFactor - 1.0) / 3.0; // Maps 2x to ~0.33

      try {
        await _cameraState!.sensorConfig.setZoom(
          normalizedZoom.clamp(0.0, 1.0),
        );
        Log.info(
          'Applied digital zoom: ${sensor.zoomFactor}x (normalized: ${normalizedZoom.toStringAsFixed(2)})',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to apply digital zoom: $e',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }
    } else {
      // Physical sensor switch
      final sensorType = _mapToSensorType(sensor.type);
      // setSensorType returns void, not Future
      _cameraState!.setSensorType(0, sensorType, sensor.deviceId);

      // Reset zoom to 1x when switching physical sensors
      try {
        await _cameraState!.sensorConfig.setZoom(0.0);
      } catch (e) {
        Log.error(
          'Failed to reset zoom: $e',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Map our sensor type string to CamerAwesome SensorType enum
  SensorType _mapToSensorType(String type) {
    switch (type.toLowerCase()) {
      case 'ultrawide':
        return SensorType.ultraWideAngle;
      case 'telephoto':
        return SensorType.telephoto;
      case 'wide':
      default:
        return SensorType.wideAngle;
    }
  }

  @override
  Widget get previewWidget {
    return CameraAwesomeBuilder.custom(
      saveConfig: SaveConfig.video(
        pathBuilder: (sensors) async {
          // Use static path to avoid closure capture issues
          // The static is set by startRecordingSegment before this is called
          final path = CamerAwesomeMobileCameraInterface._pendingRecordingPath;
          Log.info(
            'pathBuilder called, using path: $path',
            name: 'CamerAwesomeCamera',
            category: LogCategory.system,
          );
          if (path == null || path == '/tmp/temp.mp4') {
            Log.error(
              'pathBuilder called with invalid path! _pendingRecordingPath=$path',
              name: 'CamerAwesomeCamera',
              category: LogCategory.system,
            );
          }
          return SingleCaptureRequest(path ?? '/tmp/temp.mp4', sensors.first);
        },
      ),
      sensorConfig: SensorConfig.single(
        sensor: Sensor.position(SensorPosition.back),
        flashMode: FlashMode.none,
        aspectRatio: CameraAspectRatios.ratio_16_9,
      ),
      enablePhysicalButton: false,
      previewFit: CameraPreviewFit.contain,
      builder: (state, preview) {
        // CameraLayoutBuilder signature: (CameraState, AnalysisPreview)
        // Store camera state for use in other methods
        _cameraState = state;
        _stateController.add(state);

        // Return empty container - preview is shown automatically
        return const SizedBox.shrink();
      },
    );
  }

  @override
  bool get canSwitchCamera =>
      _availableSensors.length > 1 || _frontCamera != null;

  /// Get available physical sensors for zoom UI
  List<PhysicalCameraSensor> get availableSensors => _availableSensors;

  /// Get current sensor zoom factor
  double get currentZoomFactor {
    if (_currentSensorIndex < _availableSensors.length) {
      return _availableSensors[_currentSensorIndex].zoomFactor;
    }
    return 1.0;
  }

  /// Stream of camera state changes
  Stream<CameraState> get cameraStateStream => _stateController.stream;

  /// Check if currently using front camera
  bool get isFrontCamera => _isFrontCamera;

  /// Set flash mode (torch for video recording)
  Future<void> setFlashMode(dynamic mode) async {
    if (_cameraState == null) {
      Log.warning(
        'Cannot set flash mode - camera not initialized',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    // Don't enable flash for front camera
    if (_isFrontCamera) {
      Log.info(
        'Flash not available for front camera',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // CamerAwesome uses its own FlashMode enum
      FlashMode awesomeFlashMode;

      // Handle both camera package FlashMode and direct string/enum
      final modeStr = mode.toString().toLowerCase();
      if (modeStr.contains('torch')) {
        awesomeFlashMode =
            FlashMode.always; // CamerAwesome's equivalent for continuous light
      } else if (modeStr.contains('auto')) {
        awesomeFlashMode = FlashMode.auto;
      } else if (modeStr.contains('always') || modeStr.contains('on')) {
        awesomeFlashMode = FlashMode.always;
      } else {
        awesomeFlashMode = FlashMode.none;
      }

      await _cameraState!.sensorConfig.setFlashMode(awesomeFlashMode);
      Log.info(
        'Flash mode set to $awesomeFlashMode',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to set flash mode: $e',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );
    }
  }

  @override
  void dispose() {
    _stateController.close();
    _cameraState = null;
    _isRecording = false;
    _currentRecordingPath = null;

    Log.info(
      'CamerAwesome camera interface disposed',
      name: 'CamerAwesomeCamera',
      category: LogCategory.system,
    );
  }
}
