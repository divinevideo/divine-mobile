// ABOUTME: Enhanced mobile camera implementation using standard camera package
// ABOUTME: Adds zoom, focus, and improved camera controls for iOS/Android

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Enhanced mobile camera implementation with zoom and focus features
class EnhancedMobileCameraInterface extends CameraPlatformInterface {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _isRecording = false;

  // Zoom and focus tracking
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Flash mode tracking
  FlashMode _currentFlashMode = FlashMode.auto;

  @override
  Future<void> initialize() async {
    try {
      Log.info(
        'Initializing enhanced mobile camera interface...',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      _availableCameras = await availableCameras();
      Log.info(
        'Found ${_availableCameras.length} available cameras',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      if (_availableCameras.isEmpty) {
        throw Exception('No cameras available - check camera permissions');
      }

      // Default to back camera if available
      _currentCameraIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      Log.info(
        'Selected camera $_currentCameraIndex: ${_availableCameras[_currentCameraIndex].name}',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      await _initializeCurrentCamera();

      Log.info(
        'Enhanced mobile camera initialized successfully',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Enhanced mobile camera initialization failed: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  Future<void> _initializeCurrentCamera() async {
    _controller?.dispose();

    try {
      final camera = _availableCameras[_currentCameraIndex];
      Log.info(
        'Initializing camera controller for: ${camera.name}',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        // Remove imageFormatGroup - let iOS use default format for better performance
      );

      await _controller!.initialize();
      Log.info(
        'Camera controller initialized successfully',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      // Lock camera orientation to portrait up to prevent preview rotation
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      Log.info(
        'Camera orientation locked to portrait up',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      await _controller!.prepareForVideoRecording();
      Log.info(
        'Video recording preparation complete',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      // Initialize zoom levels
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      // Set initial flash mode
      await _controller!.setFlashMode(_currentFlashMode);

      Log.info(
        'Enhanced camera initialized - Zoom range: $_minZoomLevel to $_maxZoomLevel',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Camera controller initialization failed: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );

      // Provide more specific error messages
      if (e.toString().contains('CameraAccessDenied') ||
          e.toString().contains('permission')) {
        throw Exception(
          'Camera permission denied. Please enable camera access in iOS Settings > Privacy & Security > Camera.',
        );
      } else if (e.toString().contains('CameraInUse')) {
        throw Exception(
          'Camera is currently in use by another app. Please close other camera apps and try again.',
        );
      } else if (e.toString().contains('CameraNotFound')) {
        throw Exception(
          'Camera not found. This may happen on iOS Simulator - please test on a real device.',
        );
      }

      rethrow;
    }
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }

    // Check actual camera recording status to avoid state desync
    final isActuallyRecording = _controller!.value.isRecordingVideo;

    if (_isRecording && isActuallyRecording) {
      Log.warning(
        'Already recording, skipping startVideoRecording',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      return;
    }

    // State recovery: if we think we're recording but camera says no, reset our state
    if (_isRecording && !isActuallyRecording) {
      Log.warning(
        'State desync detected - resetting recording state',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      _isRecording = false;
    }

    // State recovery: if camera is recording but we think it's not, align our state
    if (!_isRecording && isActuallyRecording) {
      Log.warning(
        'Camera already recording - aligning state',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      _isRecording = true;
      return;
    }

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      Log.info(
        'Started enhanced camera recording',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      // Handle "Video is already recording" exception by aligning our state
      if (e.toString().contains('Video is already recording')) {
        Log.info(
          'Camera is already recording - aligning our state to continue with existing recording',
          name: 'EnhancedMobileCamera',
          category: LogCategory.system,
        );

        // Align our internal state with the camera's actual state
        _isRecording = true;

        // This is actually a success - we're now aligned with an ongoing recording
        return;
      }

      _isRecording = false;
      Log.error(
        'Failed to start enhanced camera recording: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<String?> stopRecordingSegment() async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }

    // Check actual camera recording status to avoid state desync
    final isActuallyRecording = _controller!.value.isRecordingVideo;

    if (!_isRecording && !isActuallyRecording) {
      Log.warning(
        'Not currently recording, skipping stopVideoRecording',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      return null;
    }

    // State recovery: if we think we're not recording but camera says yes, align our state
    if (!_isRecording && isActuallyRecording) {
      Log.warning(
        'Camera is recording but state says no - aligning state',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      _isRecording = true;
    }

    // State recovery: if camera is not recording but we think it is, reset our state
    if (_isRecording && !isActuallyRecording) {
      Log.warning(
        'State desync detected - camera not recording, resetting state',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      _isRecording = false;
      return null;
    }

    try {
      final xFile = await _controller!.stopVideoRecording();
      _isRecording = false;
      Log.info(
        'Stopped enhanced camera recording: ${xFile.path}',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      return xFile.path;
    } catch (e) {
      _isRecording = false;

      // Handle common camera exceptions gracefully
      if (e.toString().contains('not recording') ||
          e.toString().contains('VideoRecordingNotStarted')) {
        Log.warning(
          'Camera was not recording when stop requested - state aligned',
          name: 'EnhancedMobileCamera',
          category: LogCategory.system,
        );
        return null;
      }

      Log.error(
        'Failed to stop enhanced camera recording: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      return null;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_availableCameras.length <= 1) return;

    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning(
        'Cannot switch camera - controller not initialized',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      return;
    }

    if (_isRecording) {
      try {
        await _controller?.stopVideoRecording();
      } catch (e) {
        Log.error(
          'Error stopping recording during camera switch: $e',
          name: 'EnhancedMobileCamera',
          category: LogCategory.system,
        );
      }
      _isRecording = false;
    }

    final oldController = _controller;
    _controller = null;

    try {
      _currentCameraIndex =
          (_currentCameraIndex + 1) % _availableCameras.length;

      // CRITICAL: Dispose old controller FIRST before initializing new one
      // Android only allows one camera open at a time
      await oldController?.dispose();

      // Now initialize the new camera
      await _initializeCurrentCamera();

      Log.info(
        '✅ Successfully switched to camera $_currentCameraIndex',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      _controller = oldController;
      Log.error(
        'Camera switch failed, restored previous camera: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Widget get previewWidget {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return EnhancedCameraPreview(
        controller: controller,
        onZoomChanged: setZoom,
        onFocusPoint: setFocusPoint,
        currentZoom: _currentZoomLevel,
        minZoom: _minZoomLevel,
        maxZoom: _maxZoomLevel,
      );
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF00B488),
              ), // Vine green
              strokeWidth: 3.0,
            ),
            SizedBox(height: 16),
            Text(
              'Divine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: Color(0xFFBBBBBB),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get canSwitchCamera => _availableCameras.length > 1;

  /// Check if currently using front camera
  bool get isFrontCamera {
    if (_availableCameras.isEmpty ||
        _currentCameraIndex >= _availableCameras.length) {
      return false;
    }
    return _availableCameras[_currentCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  /// Set flash mode directly
  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _currentFlashMode = mode;
      await _controller!.setFlashMode(mode);

      Log.info(
        'Flash mode set to $mode',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to set flash mode: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    }
  }

  @override
  void dispose() {
    if (_isRecording) {
      try {
        _controller?.stopVideoRecording();
      } catch (e) {
        Log.error(
          'Error stopping recording during disposal: $e',
          name: 'EnhancedMobileCamera',
          category: LogCategory.system,
        );
      }
      _isRecording = false;
    }
    _controller?.dispose();
  }

  /// Set zoom level
  Future<void> setZoom(double zoomLevel) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final clampedZoom = zoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
      await _controller!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;

      Log.debug(
        'Set zoom level to ${clampedZoom.toStringAsFixed(1)}x',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to set zoom: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    }
  }

  /// Set focus point
  Future<void> setFocusPoint(Offset point) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);

      Log.debug(
        'Set focus/exposure point to: (${point.dx.toStringAsFixed(2)}, ${point.dy.toStringAsFixed(2)})',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to set focus point: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    }
  }

  /// Toggle flash mode
  Future<void> toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _currentFlashMode = _currentFlashMode == FlashMode.off
          ? FlashMode.auto
          : (_currentFlashMode == FlashMode.auto
                ? FlashMode.torch
                : FlashMode.off);

      await _controller!.setFlashMode(_currentFlashMode);

      Log.info(
        'Flash mode changed to $_currentFlashMode',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to toggle flash: $e',
        name: 'EnhancedMobileCamera',
        category: LogCategory.system,
      );
    }
  }
}

/// Enhanced camera preview widget with zoom and focus controls
class EnhancedCameraPreview extends StatefulWidget {
  const EnhancedCameraPreview({
    required this.controller,
    required this.onZoomChanged,
    required this.onFocusPoint,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    super.key,
  });

  final CameraController controller;
  final Function(double) onZoomChanged;
  final Function(Offset) onFocusPoint;
  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  @override
  State<EnhancedCameraPreview> createState() => _EnhancedCameraPreviewState();
}

class _EnhancedCameraPreviewState extends State<EnhancedCameraPreview> {
  double _baseZoom = 1.0;
  Offset? _focusPoint;
  Timer? _focusTimer;

  @override
  Widget build(BuildContext context) {
    // Debug: Log camera preview rebuild and orientation
    final mediaQueryOrientation = MediaQuery.of(context).orientation;
    final cameraValue = widget.controller.value;
    Log.warning(
      '📹 [CAMERA PREVIEW] Building camera preview - MediaQuery: $mediaQueryOrientation, '
      'Camera initialized: ${cameraValue.isInitialized}, '
      'Preview size: ${cameraValue.previewSize}, '
      'Device orientation: ${cameraValue.deviceOrientation}, '
      'Locked capture orientation: ${cameraValue.lockedCaptureOrientation}',
      name: 'EnhancedCameraPreview',
      category: LogCategory.system,
    );

    // Camera preview with proper sizing for portrait orientation
    // CRITICAL: Swap width/height to display camera sensor correctly in portrait
    // This structure MUST match experimental app EXACTLY!
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: widget.controller.value.previewSize!.height,
          height: widget.controller.value.previewSize!.width,
          child: CameraPreview(widget.controller),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }
}
