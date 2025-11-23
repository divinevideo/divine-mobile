// ABOUTME: CamerAwesome-based mobile camera implementation with physical sensor switching
// ABOUTME: Replaces Flutter camera package with CamerAwesome for seamless multi-camera support

import 'dart:async';
import 'dart:io';

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
  String? _currentRecordingPath;

  // Physical camera sensors detected on device
  List<PhysicalCameraSensor> _availableSensors = [];
  int _currentSensorIndex = 0;

  // Stream controller for camera state updates
  final _stateController = StreamController<CameraState>.broadcast();

  @override
  Future<void> initialize() async {
    try {
      Log.info('Initializing CamerAwesome camera interface...',
          name: 'CamerAwesomeCamera', category: LogCategory.system);

      // Lock device orientation to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      Log.info('Device orientation locked to portrait up',
          name: 'CamerAwesomeCamera', category: LogCategory.system);

      // Detect available physical cameras and their zoom factors
      if (Platform.isIOS) {
        _availableSensors = await CameraZoomDetector.getSortedBackCameras();
        Log.info(
          'Detected ${_availableSensors.length} physical cameras: ${_availableSensors.map((s) => '${s.displayName} (${s.zoomFactor}x)').join(', ')}',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );

        // CamerAwesome defaults to wide-angle camera (1.0x), so set current index to match
        // Sorted list: [0.5x ultrawide, 1.0x wide, 3.0x telephoto]
        _currentSensorIndex = _availableSensors.indexWhere((s) => s.zoomFactor == 1.0);
        if (_currentSensorIndex == -1) {
          _currentSensorIndex = 0; // Fallback to first camera if 1.0x not found
        }
        Log.info(
          'Initial camera: ${_availableSensors[_currentSensorIndex].displayName} (${_availableSensors[_currentSensorIndex].zoomFactor}x)',
          name: 'CamerAwesomeCamera',
          category: LogCategory.system,
        );
      }

      // CamerAwesome will be initialized via the builder widget
      // We don't initialize it here - the widget handles that

      Log.info('CamerAwesome camera initialized successfully',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
    } catch (e) {
      Log.error('CamerAwesome camera initialization failed: $e',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      rethrow;
    }
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      Log.warning('Already recording, ignoring duplicate start request',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return;
    }

    try {
      Log.info('Starting video recording to: $filePath',
          name: 'CamerAwesomeCamera', category: LogCategory.system);

      _currentRecordingPath = filePath;
      _isRecording = true;

      // Start recording via CamerAwesome state
      await _cameraState!.when(
        onPhotoMode: (state) async {
          throw Exception('Camera in photo mode, cannot record video');
        },
        onVideoMode: (state) async {
          // startRecording returns Future<CaptureRequest>, uses pathBuilder from SaveConfig
          await state.startRecording();
        },
        onVideoRecordingMode: (state) async {
          Log.warning('Already in recording mode',
              name: 'CamerAwesomeCamera', category: LogCategory.system);
        },
        onPreparingCamera: (state) async {
          throw Exception('Camera still preparing');
        },
      );

      Log.info('Video recording started successfully',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
    } catch (e) {
      _isRecording = false;
      _currentRecordingPath = null;
      Log.error('Failed to start recording: $e',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      rethrow;
    }
  }

  @override
  Future<String?> stopRecordingSegment() async {
    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    if (!_isRecording) {
      Log.warning('Not currently recording, ignoring stop request',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return null;
    }

    try {
      Log.info('Stopping video recording...',
          name: 'CamerAwesomeCamera', category: LogCategory.system);

      final recordedPath = _currentRecordingPath;

      // Stop recording via CamerAwesome state
      await _cameraState!.when(
        onPhotoMode: (state) async {
          throw Exception('Not in video mode');
        },
        onVideoMode: (state) async {
          Log.warning('Not in recording mode',
              name: 'CamerAwesomeCamera', category: LogCategory.system);
        },
        onVideoRecordingMode: (state) async {
          await state.stopRecording();
        },
        onPreparingCamera: (state) async {
          throw Exception('Camera still preparing');
        },
      );

      _isRecording = false;
      _currentRecordingPath = null;

      Log.info('Video recording stopped: $recordedPath',
          name: 'CamerAwesomeCamera', category: LogCategory.system);

      return recordedPath;
    } catch (e) {
      Log.error('Failed to stop recording: $e',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_availableSensors.isEmpty) {
      Log.warning('No physical sensors available for switching',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return;
    }

    if (_cameraState == null) {
      throw Exception('Camera not initialized');
    }

    try {
      // Cycle to next sensor
      _currentSensorIndex = (_currentSensorIndex + 1) % _availableSensors.length;
      final nextSensor = _availableSensors[_currentSensorIndex];

      Log.info(
        'Switching to sensor: ${nextSensor.displayName} (${nextSensor.zoomFactor}x)',
        name: 'CamerAwesomeCamera',
        category: LogCategory.system,
      );

      // Map our sensor type to CamerAwesome SensorType
      final sensorType = _mapToSensorType(nextSensor.type);

      // Switch sensor via CamerAwesome (setSensorType returns void, not Future)
      _cameraState!.setSensorType(0, sensorType, nextSensor.deviceId);

      Log.info('Sensor switched successfully',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to switch camera: $e',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      rethrow;
    }
  }

  /// Switch to a specific sensor by zoom factor
  Future<void> switchToSensor(double zoomFactor) async {
    if (_availableSensors.isEmpty) {
      Log.warning('No physical sensors available',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return;
    }

    // Find sensor with matching zoom factor
    final sensorIndex = _availableSensors.indexWhere(
      (s) => (s.zoomFactor - zoomFactor).abs() < 0.1,
    );

    if (sensorIndex == -1) {
      Log.warning('No sensor found for zoom factor: $zoomFactor',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return;
    }

    if (sensorIndex == _currentSensorIndex) {
      Log.debug('Already on sensor: ${_availableSensors[sensorIndex].displayName}',
          name: 'CamerAwesomeCamera', category: LogCategory.system);
      return;
    }

    _currentSensorIndex = sensorIndex;
    final sensor = _availableSensors[_currentSensorIndex];

    Log.info(
      'Switching to sensor: ${sensor.displayName} (${sensor.zoomFactor}x)',
      name: 'CamerAwesomeCamera',
      category: LogCategory.system,
    );

    final sensorType = _mapToSensorType(sensor.type);
    // setSensorType returns void, not Future
    _cameraState!.setSensorType(0, sensorType, sensor.deviceId);
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
          // Path will be provided via startRecordingSegment
          return SingleCaptureRequest(
            _currentRecordingPath ?? '/tmp/temp.mp4',
            sensors.first,
          );
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
  bool get canSwitchCamera => _availableSensors.length > 1;

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

  @override
  void dispose() {
    _stateController.close();
    _cameraState = null;
    _isRecording = false;
    _currentRecordingPath = null;

    Log.info('CamerAwesome camera interface disposed',
        name: 'CamerAwesomeCamera', category: LogCategory.system);
  }
}
