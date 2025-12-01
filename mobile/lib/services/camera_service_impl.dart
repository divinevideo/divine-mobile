// ABOUTME: Camera service implementation with macOS support via camera_macos package
// ABOUTME: Provides cross-platform camera functionality for iOS, Android, and macOS

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart'; // For Offset
import 'package:openvine/utils/unified_logger.dart';
import 'camera_service.dart';

/// Concrete implementation of CameraService with macOS support
class CameraServiceImpl extends CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraMacOSController? _macOSController;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  CameraDescription? _selectedCamera;
  FlashMode _currentFlashMode = FlashMode.off;

  /// Optional frame capture callback for ProofMode
  void Function(CameraImage)? _frameCallback;

  /// Check if the camera is initialized
  bool get isInitialized => Platform.isMacOS
      ? _macOSController != null
      : _controller?.value.isInitialized ?? false;

  /// Check if currently recording
  @override
  bool get isRecording => _isRecording;

  /// Get the current camera controller (for non-macOS platforms)
  CameraController? get controller => _controller;

  /// Get the macOS camera controller
  CameraMacOSController? get macOSController => _macOSController;

  /// Get the selected camera
  CameraDescription? get selectedCamera => _selectedCamera;

  /// Get current flash mode
  FlashMode get currentFlashMode => _currentFlashMode;

  /// Initialize the camera service
  Future<void> initialize({
    ResolutionPreset preferredResolution = ResolutionPreset.medium,
  }) async {
    try {
      if (Platform.isMacOS) {
        await _initializeMacOS();
      } else {
        await _initializeStandardCamera(preferredResolution);
      }
    } catch (e) {
      Log.error(
        'Failed to initialize camera: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
    }
  }

  /// Initialize camera for macOS
  Future<void> _initializeMacOS() async {
    try {
      // Get available macOS cameras
      final macOSCameras = await CameraMacOS.instance.listDevices();

      if (macOSCameras.isEmpty) {
        throw CameraException(
          'NoCameraAvailable',
          'No cameras found on macOS device',
        );
      }

      // Create controller with first available camera
      // CameraMacOSArguments requires a size parameter
      _macOSController = CameraMacOSController(
        CameraMacOSArguments(
          size: Size(1280, 720), // HD resolution
          devices: macOSCameras,
        ),
      );

      // The controller is ready after construction, no initialize method needed
      Log.info(
        'macOS camera initialized: ${macOSCameras.first.deviceId}',
        name: 'CameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'macOS camera initialization failed: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Initialize camera for iOS/Android
  Future<void> _initializeStandardCamera(ResolutionPreset resolution) async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw CameraException(
          'NoCameraAvailable',
          'No cameras found on device',
        );
      }

      // Prefer back camera if available
      _selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        _selectedCamera!,
        resolution,
        enableAudio: true,
      );

      await _controller!.initialize();

      Log.info(
        'Camera initialized: ${_selectedCamera!.name}',
        name: 'CameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Standard camera initialization failed: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Set frame capture callback for ProofMode frame hashing
  void setFrameCallback(void Function(CameraImage)? callback) {
    _frameCallback = callback;
  }

  /// Start recording video with optional frame streaming for ProofMode
  @override
  Future<void> startRecording() async {
    if (!isInitialized) {
      throw StateError('Camera not initialized');
    }

    if (_isRecording) {
      Log.warning(
        'Already recording',
        name: 'CameraService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      if (Platform.isMacOS) {
        // Use recordVideo method for macOS
        // NOTE: macOS camera_macos package doesn't support frame streaming during recording
        Log.warning(
          'Frame capture not available on macOS',
          name: 'CameraService',
          category: LogCategory.system,
        );
        await _macOSController!.recordVideo();
      } else {
        // Start video recording with optional frame streaming
        if (_frameCallback != null) {
          Log.info(
            'Starting recording with frame capture enabled',
            name: 'CameraService',
            category: LogCategory.system,
          );
          await _controller!.startVideoRecording(
            onAvailable: (CameraImage image) {
              // Call the frame callback asynchronously to avoid blocking recording
              _frameCallback?.call(image);
            },
          );
        } else {
          await _controller!.startVideoRecording();
        }
      }

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      Log.info(
        'Recording started',
        name: 'CameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to start recording: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Stop recording and return the result
  @override
  Future<VineRecordingResult> stopRecording() async {
    if (!_isRecording) {
      throw StateError('Not currently recording');
    }

    try {
      final duration = DateTime.now().difference(_recordingStartTime!);

      if (Platform.isMacOS) {
        final file = await _macOSController!.stopRecording();
        _isRecording = false;

        // CameraMacOSFile has url property, not path
        return VineRecordingResult(
          videoFile: File(file?.url ?? ''),
          duration: duration,
        );
      } else {
        final xFile = await _controller!.stopVideoRecording();
        _isRecording = false;

        return VineRecordingResult(
          videoFile: File(xFile.path),
          duration: duration,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to stop recording: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
      _isRecording = false;
      rethrow;
    }
  }

  /// Start video recording (alternative method name)
  Future<void> startVideoRecording() async => startRecording();

  /// Stop video recording (alternative method returning File)
  Future<File?> stopVideoRecording() async {
    final result = await stopRecording();
    return result.videoFile;
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (Platform.isMacOS) {
      // For macOS, get list of cameras and switch to next one
      final devices = await CameraMacOS.instance.listDevices();
      if (devices.length > 1) {
        // Camera switching on macOS requires recreating the controller
        // The current API doesn't expose device selection after construction
        await _macOSController?.destroy();

        // Create new controller (will use default camera)
        _macOSController = CameraMacOSController(
          CameraMacOSArguments(
            size: Size(1280, 720), // HD resolution
            devices: devices,
          ),
        );

        Log.info(
          'Switched macOS camera',
          name: 'CameraService',
          category: LogCategory.system,
        );
      }
    } else {
      if (_cameras == null || _cameras!.length < 2) {
        Log.warning(
          'Multiple cameras not available',
          name: 'CameraService',
          category: LogCategory.system,
        );
        return;
      }

      final lensDirection =
          _selectedCamera!.lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      _selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == lensDirection,
        orElse: () => _cameras!.first,
      );

      await _controller?.dispose();

      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
    }
  }

  /// Set flash mode
  Future<void> setFlashMode(FlashMode mode) async {
    if (Platform.isMacOS) {
      // Flash not typically available on macOS cameras
      Log.info(
        'Flash mode not supported on macOS',
        name: 'CameraService',
        category: LogCategory.system,
      );
      return;
    }

    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(mode);
      _currentFlashMode = mode;
    }
  }

  /// Set focus point (for supported platforms)
  Future<void> setFocusPoint(Offset point) async {
    if (Platform.isMacOS) {
      Log.info(
        'Focus point not supported on macOS',
        name: 'CameraService',
        category: LogCategory.system,
      );
      return;
    }

    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFocusPoint(point);
    }
  }

  /// Set exposure point (for supported platforms)
  Future<void> setExposurePoint(Offset point) async {
    if (Platform.isMacOS) {
      Log.info(
        'Exposure point not supported on macOS',
        name: 'CameraService',
        category: LogCategory.system,
      );
      return;
    }

    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setExposurePoint(point);
    }
  }

  /// Dispose of camera resources
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }

      if (Platform.isMacOS) {
        await _macOSController?.destroy();
        _macOSController = null;
      } else {
        await _controller?.dispose();
        _controller = null;
      }

      _selectedCamera = null;

      Log.info(
        'Camera resources disposed',
        name: 'CameraService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error disposing camera resources: $e',
        name: 'CameraService',
        category: LogCategory.system,
      );
    }
  }
}

// Export the concrete implementation as default
CameraService createCameraService() => CameraServiceImpl();
