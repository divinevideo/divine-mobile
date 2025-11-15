// ABOUTME: Universal Vine-style recording controller for all platforms
// ABOUTME: Handles press-to-record, release-to-pause segmented recording with cross-platform camera abstraction

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart' as macos;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:openvine/models/aspect_ratio.dart' as model;
import 'package:openvine/services/camera/native_macos_camera.dart';
import 'package:openvine/services/camera/enhanced_mobile_camera_interface.dart';
import 'package:openvine/services/web_camera_service_stub.dart'
    if (dart.library.html) 'web_camera_service.dart' as camera_service;
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/macos_camera_preview.dart';
import 'package:crypto/crypto.dart';

/// Represents a single recording segment in the Vine-style recording
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class RecordingSegment {
  RecordingSegment({
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.filePath,
  });
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String? filePath;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  @override
  String toString() => 'Segment(${duration.inMilliseconds}ms)';
}

/// Recording state for Vine-style segmented recording
enum VineRecordingState {
  idle, // Camera preview active, not recording
  recording, // Currently recording a segment
  paused, // Between segments, camera preview active
  processing, // Assembling final video
  completed, // Recording finished
  error, // Error state
}

/// Platform-agnostic interface for camera operations
abstract class CameraPlatformInterface {
  Future<void> initialize();
  Future<void> startRecordingSegment(String filePath);
  Future<String?> stopRecordingSegment();
  Future<void> switchCamera();
  Widget get previewWidget;
  bool get canSwitchCamera;
  void dispose();
}

/// Mobile camera implementation (iOS/Android)
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class MobileCameraInterface extends CameraPlatformInterface {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool isRecording = false;

  // Operation mutex to prevent concurrent start/stop race conditions
  bool _operationInProgress = false;

  // Zoom support
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  @override
  Future<void> initialize() async {
    _availableCameras = await availableCameras();
    if (_availableCameras.isEmpty) {
      throw Exception('No cameras available');
    }

    // Default to back camera if available
    _currentCameraIndex = _availableCameras.indexWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
    );
    if (_currentCameraIndex == -1) {
      _currentCameraIndex = 0;
    }

    await _initializeCurrentCamera();
  }

  Future<void> _initializeCurrentCamera() async {
    _controller?.dispose();

    final camera = _availableCameras[_currentCameraIndex];
    _controller =
        CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();

    // Prepare for video recording - critical for iOS
    try {
      await _controller!.prepareForVideoRecording();
      Log.info('Video recording preparation successful',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.warning('prepareForVideoRecording failed (may not be supported): $e',
          name: 'VineRecordingController', category: LogCategory.system);
      // Continue anyway - some platforms don't need this
    }

    // Initialize zoom levels
    try {
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      Log.info('Zoom range initialized: $_minZoomLevel - $_maxZoomLevel',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.warning('Failed to get zoom levels: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      _minZoomLevel = 1.0;
      _maxZoomLevel = 1.0;
      _currentZoomLevel = 1.0;
    }
  }

  Future<void> _initializeNewCamera() async {
    // Initialize new camera without disposing (disposal handled separately)
    final camera = _availableCameras[_currentCameraIndex];
    _controller =
        CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();

    // Prepare for video recording - critical for iOS
    try {
      await _controller!.prepareForVideoRecording();
      Log.info('Video recording preparation successful after camera switch',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.warning('prepareForVideoRecording failed during camera switch: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      // Continue anyway - some platforms don't need this
    }

    // Initialize zoom levels
    try {
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      Log.info('Zoom range initialized: $_minZoomLevel - $_maxZoomLevel',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.warning('Failed to get zoom levels: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      _minZoomLevel = 1.0;
      _maxZoomLevel = 1.0;
      _currentZoomLevel = 1.0;
    }
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }

    // Wait for any in-progress operation to complete with timeout protection
    // This prevents race conditions from rapid tap sequences
    int waitCount = 0;
    const maxWaitMs = 5000; // 5 second timeout
    while (_operationInProgress) {
      if (waitCount >= maxWaitMs / 10) {
        Log.error('Camera operation timeout after ${maxWaitMs}ms - forcing unlock',
            name: 'VineRecordingController', category: LogCategory.system);
        _operationInProgress = false;
        throw Exception('Camera operation timeout after ${maxWaitMs}ms');
      }
      Log.debug('Waiting for previous camera operation to complete',
          name: 'VineRecordingController', category: LogCategory.system);
      await Future.delayed(const Duration(milliseconds: 10));
      waitCount++;
    }

    if (waitCount > 0) {
      Log.info('Waited ${waitCount * 10}ms for camera operation to complete',
          name: 'VineRecordingController', category: LogCategory.system);
    }

    // Already recording - ignore duplicate start request
    if (isRecording) {
      Log.warning('Already recording, ignoring start request',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    _operationInProgress = true;
    try {
      await _controller!.startVideoRecording();
      isRecording = true;
      Log.info('Started mobile camera recording',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      isRecording = false;
      Log.error('Failed to start mobile camera recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    } finally {
      _operationInProgress = false;
    }
  }

  @override
  Future<String?> stopRecordingSegment() async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }

    // Wait for any in-progress operation to complete with timeout protection
    int waitCount = 0;
    const maxWaitMs = 5000; // 5 second timeout
    while (_operationInProgress) {
      if (waitCount >= maxWaitMs / 10) {
        Log.error('Camera operation timeout after ${maxWaitMs}ms - forcing unlock',
            name: 'VineRecordingController', category: LogCategory.system);
        _operationInProgress = false;
        throw Exception('Camera operation timeout after ${maxWaitMs}ms');
      }
      Log.debug('Waiting for previous camera operation to complete',
          name: 'VineRecordingController', category: LogCategory.system);
      await Future.delayed(const Duration(milliseconds: 10));
      waitCount++;
    }

    if (waitCount > 0) {
      Log.info('Waited ${waitCount * 10}ms for camera operation to complete',
          name: 'VineRecordingController', category: LogCategory.system);
    }

    // Not recording - nothing to stop
    if (!isRecording) {
      Log.warning('Not currently recording, skipping stopVideoRecording',
          name: 'VineRecordingController', category: LogCategory.system);
      return null;
    }

    _operationInProgress = true;
    try {
      final xFile = await _controller!.stopVideoRecording();
      isRecording = false;
      Log.info('Stopped mobile camera recording: ${xFile.path}',
          name: 'VineRecordingController', category: LogCategory.system);
      return xFile.path;
    } catch (e) {
      isRecording = false; // Reset state even on error
      Log.error('Failed to stop mobile camera recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - return null to indicate no file was saved
      return null;
    } finally {
      _operationInProgress = false;
    }
  }

  @override
  Future<void> switchCamera() async {
    Log.info('🔄 switchCamera called, current cameras: ${_availableCameras.length}',
        name: 'VineRecordingController', category: LogCategory.system);

    if (_availableCameras.length <= 1) {
      Log.warning('Cannot switch camera - only ${_availableCameras.length} camera(s) available',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    // Wait for any in-progress operation to complete before switching (with timeout)
    int waitCount = 0;
    const maxWaitMs = 5000; // 5 second timeout
    while (_operationInProgress) {
      if (waitCount >= maxWaitMs / 10) {
        Log.error('Camera operation timeout after ${maxWaitMs}ms - forcing unlock',
            name: 'VineRecordingController', category: LogCategory.system);
        _operationInProgress = false;
        throw Exception('Camera operation timeout after ${maxWaitMs}ms');
      }
      Log.debug('Waiting for camera operation to complete before switch',
          name: 'VineRecordingController', category: LogCategory.system);
      await Future.delayed(const Duration(milliseconds: 10));
      waitCount++;
    }

    if (waitCount > 0) {
      Log.info('Waited ${waitCount * 10}ms for camera operation before switch',
          name: 'VineRecordingController', category: LogCategory.system);
    }

    // Don't switch if controller is not properly initialized
    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning('Cannot switch camera - controller not initialized',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    Log.info('🔄 Current camera index: $_currentCameraIndex, direction: ${_availableCameras[_currentCameraIndex].lensDirection}',
        name: 'VineRecordingController', category: LogCategory.system);
    Log.info('🔄 OLD controller state: isInitialized=${_controller!.value.isInitialized}, isRecording=${_controller!.value.isRecordingVideo}, isStreaming=${_controller!.value.isStreamingImages}',
        name: 'VineRecordingController', category: LogCategory.system);

    // Stop any active recording before switching
    if (isRecording) {
      Log.info('🔄 Stopping active recording before camera switch',
          name: 'VineRecordingController', category: LogCategory.system);
      try {
        await _controller?.stopVideoRecording();
      } catch (e) {
        Log.error('Error stopping recording during camera switch: $e',
            name: 'VineRecordingController', category: LogCategory.system);
      }
      isRecording = false;
    }

    // Store old controller reference for safe disposal
    final oldController = _controller;
    _controller = null; // Clear reference to prevent access during switch
    Log.info('🔄 OLD controller cleared from _controller reference',
        name: 'VineRecordingController', category: LogCategory.system);

    try {
      // CRITICAL FIX: Dispose old controller BEFORE initializing new one
      // AVFoundation requires the capture session to be fully stopped before switching
      // See: https://stackoverflow.com/questions/5704464/video-freezes-on-camera-switch-with-avfoundation
      Log.info('🔄 Disposing OLD controller to stop AVFoundation session...',
          name: 'VineRecordingController', category: LogCategory.system);
      await oldController?.dispose();
      Log.info('🔄 OLD controller disposed, AVFoundation session stopped',
          name: 'VineRecordingController', category: LogCategory.system);

      // Switch to the next camera
      final oldIndex = _currentCameraIndex;
      _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;

      Log.info('🔄 Switching from camera $oldIndex to $_currentCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);

      Log.info('🔄 About to call _initializeNewCamera() for camera $_currentCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
      await _initializeNewCamera();
      Log.info('🔄 _initializeNewCamera() completed',
          name: 'VineRecordingController', category: LogCategory.system);

      if (_controller != null && _controller!.value.isInitialized) {
        Log.info('🔄 NEW camera initialized: ${_availableCameras[_currentCameraIndex].lensDirection}',
            name: 'VineRecordingController', category: LogCategory.system);
        Log.info('🔄 NEW controller state: isInitialized=${_controller!.value.isInitialized}, isRecording=${_controller!.value.isRecordingVideo}, isStreaming=${_controller!.value.isStreamingImages}',
            name: 'VineRecordingController', category: LogCategory.system);
      } else {
        Log.error('🔄 NEW controller is NULL or not initialized!',
            name: 'VineRecordingController', category: LogCategory.system);
      }

      Log.info('✅ Successfully switched to camera $_currentCameraIndex (${_availableCameras[_currentCameraIndex].lensDirection})',
          name: 'VineRecordingController', category: LogCategory.system);

      // CRITICAL: Notify listeners that camera changed to force UI rebuild
      // The preview widget needs to be re-rendered with new controller

    } catch (e) {
      // If switching fails, restore old controller
      Log.error('❌ Camera switch failed, restoring previous camera: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      _controller = oldController;
      rethrow;
    }
  }

  @override
  Widget get previewWidget {
    final controller = _controller;
    Log.info('📸 previewWidget getter called: controller=${controller != null ? "exists" : "null"}, isInitialized=${controller?.value.isInitialized ?? false}, cameraIndex=$_currentCameraIndex',
        name: 'VineRecordingController', category: LogCategory.system);

    if (controller != null && controller.value.isInitialized) {
      Log.info('📸 Returning CameraPreview widget with initialized controller for camera $_currentCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
      // CRITICAL: Use RepaintBoundary to force complete repaint when key changes
      // This helps ensure the platform view texture updates properly on iOS
      return RepaintBoundary(
        key: ValueKey('camera_boundary_$_currentCameraIndex'),
        child: CameraPreview(
          controller,
          key: ValueKey('camera_preview_$_currentCameraIndex'),
        ),
      );
    }

    Log.info('📸 Returning loading placeholder (controller not ready)',
        name: 'VineRecordingController', category: LogCategory.system);
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B488)), // Vine green
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

  /// Set zoom level (clamped to camera's supported range)
  Future<void> setZoom(double zoomLevel) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning('Cannot set zoom - controller not initialized',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    try {
      final clampedZoom = zoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
      await _controller!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;

      Log.debug('Set zoom level to ${clampedZoom.toStringAsFixed(1)}x',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to set zoom: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  }

  /// Get current zoom level
  double get currentZoom => _currentZoomLevel;

  /// Get minimum zoom level
  double get minZoom => _minZoomLevel;

  /// Get maximum zoom level
  double get maxZoom => _maxZoomLevel;

  @override
  bool get canSwitchCamera => _availableCameras.length > 1;

  /// Public getter for camera controller to access aspect ratio
  CameraController? get controller => _controller;

  @override
  void dispose() {
    // Stop any active recording before disposal
    if (isRecording) {
      try {
        _controller?.stopVideoRecording();
      } catch (e) {
        Log.error('Error stopping recording during disposal: $e',
            name: 'VineRecordingController', category: LogCategory.system);
      }
      isRecording = false;
    }
    _controller?.dispose();
  }
}

/// macOS camera implementation using hybrid approach:
/// - camera_macos for visual preview
/// - native platform channels for recording (more reliable)
class MacOSCameraInterface extends CameraPlatformInterface
    with AsyncInitialization {
  final GlobalKey _cameraKey = GlobalKey(debugLabel: 'vineCamera');
  Widget? _previewWidget;
  String? currentRecordingPath;
  bool isRecording = false;
  int _currentCameraIndex = 0;
  int _availableCameraCount = 1;

  // For macOS single recording mode
  bool isSingleRecordingMode = false;
  final List<RecordingSegment> _virtualSegments = [];

  // Recording completion tracking
  DateTime? _recordingStartTime;
  Timer? _maxDurationTimer;

  @override
  Future<void> initialize() async {
    startInitialization();

    // Get available cameras
    final cameras = await NativeMacOSCamera.getAvailableCameras();
    _availableCameraCount = cameras.length;
    Log.info('Found $_availableCameraCount cameras on macOS',
        name: 'VineRecordingController', category: LogCategory.system);

    // Initialize the native macOS camera for recording
    final nativeResult = await NativeMacOSCamera.initialize();
    if (!nativeResult) {
      throw Exception('Failed to initialize native macOS camera');
    }

    // Start native preview
    await NativeMacOSCamera.startPreview();

    // Complete initialization now that native camera is ready for recording
    completeInitialization();

    // Create the camera widget for visual preview (asynchronous, doesn't block recording)
    _previewWidget = SizedBox.expand(
      child: macos.CameraMacOSView(
        key: _cameraKey,
        fit: BoxFit.cover,
        cameraMode: macos.CameraMacOSMode.video,
        onCameraInizialized: (controller) {
          Log.info('📱 macOS camera visual preview initialized',
              name: 'VineRecordingController', category: LogCategory.system);
        },
      ),
    );

    Log.info('📱 Native macOS camera initialized successfully',
        name: 'VineRecordingController', category: LogCategory.system);
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    Log.info(
        '📱 Starting recording segment, initialized: $isInitialized, recording: $isRecording, singleMode: $isSingleRecordingMode',
        name: 'VineRecordingController',
        category: LogCategory.system);

    // Wait for visual preview to be initialized
    try {
      await waitForInitialization(timeout: const Duration(seconds: 5));
    } catch (e) {
      Log.error('macOS camera failed to initialize: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      throw Exception(
          'macOS camera not initialized after waiting 5 seconds: $e');
    }

    // For macOS, use single recording mode
    if (!isSingleRecordingMode && !isRecording) {
      // First time - start the single recording
      // Don't set currentRecordingPath yet - native will provide the actual path
      isRecording = true;
      isSingleRecordingMode = true;
      _recordingStartTime = DateTime.now();

      // Start native recording
      final started = await NativeMacOSCamera.startRecording();
      if (!started) {
        isRecording = false;
        isSingleRecordingMode = false;
        _recordingStartTime = null;
        throw Exception('Failed to start native macOS recording');
      }

      // Note: Auto-stop timer is handled by VineRecordingController._startMaxDurationTimer()
      // No need for a separate timer here to avoid race conditions

      Log.info('Started native macOS single recording mode',
          name: 'VineRecordingController', category: LogCategory.system);
    } else if (isSingleRecordingMode && isRecording) {
      // Already recording in single mode - just track the virtual segment start
      Log.verbose(
          'Native macOS single recording mode - tracking new virtual segment',
          name: 'VineRecordingController',
          category: LogCategory.system);
    }
  }

  @override
  Future<String?> stopRecordingSegment() async {
    Log.debug(
        '📱 Stopping recording segment, recording: $isRecording, singleMode: $isSingleRecordingMode',
        name: 'VineRecordingController',
        category: LogCategory.system);

    if (!isSingleRecordingMode) {
      return null;
    }

    // In single recording mode, complete the recording and get the actual file
    if (isSingleRecordingMode && isRecording) {
      Log.verbose('Native macOS single recording mode - completing recording',
          name: 'VineRecordingController', category: LogCategory.system);
      // Complete the recording and get the actual file path
      final completedPath = await completeRecording();
      return completedPath;
    }

    return null;
  }

  /// Complete the recording and get the final file
  Future<String?> completeRecording() async {
    if (!isRecording) {
      return null;
    }

    _maxDurationTimer?.cancel();
    isRecording = false;

    // Stop native recording and get the file path
    final recordedPath = await NativeMacOSCamera.stopRecording();

    if (recordedPath != null && recordedPath.isNotEmpty) {
      // The native implementation returns the actual file path
      currentRecordingPath = recordedPath;

      // Create a virtual segment for the entire recording
      if (_recordingStartTime != null) {
        final endTime = DateTime.now();
        final duration = endTime.difference(_recordingStartTime!);

        final segment = RecordingSegment(
          startTime: _recordingStartTime!,
          endTime: endTime,
          duration: duration,
          filePath: recordedPath,
        );

        _virtualSegments.add(segment);
        Log.info('Added virtual segment: ${duration.inMilliseconds}ms',
            name: 'VineRecordingController', category: LogCategory.system);
      }

      Log.info('Native macOS recording completed: $recordedPath',
          name: 'VineRecordingController', category: LogCategory.system);

      // Don't clear isSingleRecordingMode here - it's needed by finishRecording()
      // It will be cleared in dispose() or when starting a new recording
      _recordingStartTime = null;

      return recordedPath;
    } else {
      Log.error('Native macOS recording failed - no file path returned',
          name: 'VineRecordingController', category: LogCategory.system);
      // Clear flags on error
      isSingleRecordingMode = false;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Stop the single recording mode and return the final file
  Future<String?> stopSingleRecording() async {
    Log.debug('📱 Stopping native macOS single recording mode',
        name: 'VineRecordingController', category: LogCategory.system);

    if (!isSingleRecordingMode || !isRecording) {
      return null;
    }

    return await completeRecording();
  }

  /// Wait for recording completion using proper async pattern
  Future<String> waitForRecordingCompletion({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // For native implementation, we complete the recording directly
    final path = await completeRecording();
    if (path != null) {
      return path;
    }
    throw TimeoutException('Recording completion failed');
  }

  /// Get virtual segments for macOS single recording mode
  List<RecordingSegment> getVirtualSegments() => _virtualSegments;

  @override
  Widget get previewWidget {
    // Return the visual preview from camera_macos, or placeholder if not ready
    if (_previewWidget == null) {
      if (isInitialized) {
        Log.info('📱 macOS camera initialized but preview widget not created yet',
            name: 'VineRecordingController', category: LogCategory.system);
      }
      // Return placeholder until preview widget is ready
      return const CameraPreviewPlaceholder();
    }
    return _previewWidget!;
  }

  @override
  bool get canSwitchCamera => _availableCameraCount > 1;

  @override
  Future<void> switchCamera() async {
    try {
      if (_availableCameraCount <= 1) {
        Log.info('Only one camera available on macOS, cannot switch',
            name: 'VineRecordingController', category: LogCategory.system);
        return;
      }

      // Cycle to next camera
      final nextCameraIndex = (_currentCameraIndex + 1) % _availableCameraCount;

      Log.info('Switching macOS camera from $_currentCameraIndex to $nextCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);

      final success = await NativeMacOSCamera.switchCamera(nextCameraIndex);

      if (success) {
        _currentCameraIndex = nextCameraIndex;
        Log.info('📱 macOS camera switched successfully to camera $_currentCameraIndex',
            name: 'VineRecordingController', category: LogCategory.system);
      } else {
        Log.error('Failed to switch macOS camera to index $nextCameraIndex',
            name: 'VineRecordingController', category: LogCategory.system);
      }
    } catch (e) {
      Log.error('macOS camera switching failed: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    // Stop any active recording
    if (isRecording) {
      NativeMacOSCamera.stopRecording();
      isRecording = false;
    }
    // Stop preview
    NativeMacOSCamera.stopPreview();
  }

  /// Reset the interface state (for reuse)
  void reset() {
    _maxDurationTimer?.cancel();
    isRecording = false;
    isSingleRecordingMode = false;
    currentRecordingPath = null;
    _virtualSegments.clear();
    _recordingStartTime = null;
    Log.debug('📱 Native macOS camera interface reset',
        name: 'VineRecordingController', category: LogCategory.system);
  }
}

/// Web camera implementation (using getUserMedia)
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class WebCameraInterface extends CameraPlatformInterface {
  camera_service.WebCameraService? _webCameraService;
  Widget? _previewWidget;

  @override
  Future<void> initialize() async {
    if (!kIsWeb) throw Exception('WebCameraInterface only works on web');

    try {
      _webCameraService = camera_service.WebCameraService();
      await _webCameraService!.initialize();

      // Create preview widget with the initialized camera service
      _previewWidget =
          camera_service.WebCameraPreview(cameraService: _webCameraService!);

      Log.info('📱 Web camera interface initialized successfully',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Web camera interface initialization failed: $e',
          name: 'VineRecordingController', category: LogCategory.system);

      // Provide more specific error messages
      if (e.toString().contains('NotFoundError')) {
        throw Exception(
            'No camera found. Please ensure a camera is connected and accessible.');
      } else if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('PermissionDeniedError')) {
        throw Exception(
            'Camera access denied. Please allow camera permissions and try again.');
      } else if (e.toString().contains('NotReadableError')) {
        throw Exception('Camera is already in use by another application.');
      } else if (e.toString().contains('MediaDevices API not available')) {
        throw Exception(
            'Camera API not available. Please ensure you are using HTTPS.');
      }

      rethrow;
    }
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_webCameraService == null) {
      throw Exception('Web camera service not initialized');
    }

    await _webCameraService!.startRecording();
  }

  @override
  Future<String?> stopRecordingSegment() async {
    if (_webCameraService == null) {
      throw Exception('Web camera service not initialized');
    }

    try {
      final blobUrl = await _webCameraService!.stopRecording();
      Log.info('📱 Web recording completed: $blobUrl',
          name: 'VineRecordingController', category: LogCategory.system);
      return blobUrl;
    } catch (e) {
      Log.error('Failed to stop web recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_webCameraService == null) {
      Log.warning('Web camera service not initialized',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    try {
      await _webCameraService!.switchCamera();
      Log.info('📱 Web camera switched successfully',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Camera switching failed on web: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  }

  @override
  Widget get previewWidget =>
      _previewWidget ??
      const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );

  @override
  bool get canSwitchCamera {
    // For web, hide camera switch button as it's less common and
    // can cause confusion. Most users have only one camera.
    return false;
  }

  /// Clean up a blob URL (internal method for cleanup)
  void _cleanupBlobUrl(String blobUrl) {
    if (kIsWeb && _webCameraService != null) {
      try {
        // Call the static method through the service
        camera_service.WebCameraService.revokeBlobUrl(blobUrl);
      } catch (e) {
        Log.error('Error revoking blob URL: $e',
            name: 'VineRecordingController', category: LogCategory.system);
      }
    }
  }

  @override
  void dispose() {
    _webCameraService?.dispose();
    _webCameraService = null;
    _previewWidget = null;
  }
}

/// Universal Vine recording controller that works across all platforms
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VineRecordingController {
  static const Duration maxRecordingDuration =
      Duration(milliseconds: 6300); // 6.3 seconds like original Vine
  static const Duration minSegmentDuration = Duration(milliseconds: 33); // 1 frame at 30fps for stop-motion

  CameraPlatformInterface? _cameraInterface;
  VineRecordingState _state = VineRecordingState.idle;
  bool _cameraInitialized = false;

  /// Constructor
  VineRecordingController();

  // Getter for camera interface (needed for enhanced controls)
  CameraPlatformInterface? get cameraInterface => _cameraInterface;

  // Getter for camera preview widget
  Widget get previewWidget =>
      _cameraInterface?.previewWidget ??
      const SizedBox(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );

  // Callback for notifying UI of state changes during recording
  VoidCallback? _onStateChanged;

  // Recording session data
  final List<RecordingSegment> _segments = [];
  model.AspectRatio _aspectRatio = model.AspectRatio.vertical; // Default to 9:16 vertical
  DateTime? _currentSegmentStartTime;
  Timer? _progressTimer;
  Timer? _maxDurationTimer;
  String? _tempDirectory;

  // Progress tracking
  Duration _totalRecordedDuration = Duration.zero;
  bool _disposed = false;

  // Getters
  VineRecordingState get state => _state;
  bool get isCameraInitialized => _cameraInitialized;
  List<RecordingSegment> get segments => List.unmodifiable(_segments);

  /// Get current aspect ratio
  model.AspectRatio get aspectRatio => _aspectRatio;
  Duration get totalRecordedDuration => _totalRecordedDuration;
  Duration get remainingDuration =>
      maxRecordingDuration - _totalRecordedDuration;
  double get progress =>
      _totalRecordedDuration.inMilliseconds /
      maxRecordingDuration.inMilliseconds;
  bool get canRecord =>
      remainingDuration > minSegmentDuration &&
      _state != VineRecordingState.processing;
  bool get hasSegments => _segments.isNotEmpty;
  Widget get cameraPreview =>
      _cameraInterface?.previewWidget ??
      const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B488)), // Vine green
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
                'Starting camera...',
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

  /// Check if camera switching is available on current platform
  bool get canSwitchCamera {
    if (_state == VineRecordingState.recording) return false;
    return _cameraInterface?.canSwitchCamera ?? false;
  }

  /// Set callback for state change notifications during recording
  void setStateChangeCallback(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// Set aspect ratio (only allowed when not recording)
  void setAspectRatio(model.AspectRatio ratio) {
    if (state == VineRecordingState.recording) {
      Log.warning('Cannot change aspect ratio while recording',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    _aspectRatio = ratio;
    Log.info('Aspect ratio changed to: $ratio',
        name: 'VineRecordingController', category: LogCategory.system);
    _onStateChanged?.call();
  }

  /// Switch between front and rear cameras
  Future<void> switchCamera() async {
    Log.info('🔄 VineRecordingController.switchCamera() called, current state: $_state',
        name: 'VineRecordingController', category: LogCategory.system);

    if (_state == VineRecordingState.recording) {
      Log.warning('Cannot switch camera while recording',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    // If we're in paused state with a segment in progress, ensure it's properly stopped
    if (_currentSegmentStartTime != null) {
      Log.warning('Cleaning up incomplete segment before camera switch',
          name: 'VineRecordingController', category: LogCategory.system);
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
    }

    try {
      Log.info('🔄 Calling _cameraInterface?.switchCamera()...',
          name: 'VineRecordingController', category: LogCategory.system);
      await _cameraInterface?.switchCamera();
      Log.info('📱 Camera switched successfully at interface level',
          name: 'VineRecordingController', category: LogCategory.system);

      // CRITICAL: Force state notification to trigger UI rebuild
      Log.info('🔄 Calling _onStateChanged callback to trigger UI rebuild, callback=${_onStateChanged != null ? "exists" : "null"}',
          name: 'VineRecordingController', category: LogCategory.system);
      _onStateChanged?.call();
      Log.info('🔄 _onStateChanged callback completed',
          name: 'VineRecordingController', category: LogCategory.system);

    } catch (e) {
      Log.error('Failed to switch camera: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  }

  /// Initialize the recording controller for the current platform
  Future<void> initialize() async {
    try {
      _setState(VineRecordingState.idle);

      // Clean up any old recordings from previous sessions
      _cleanupRecordings();

      // Create platform-specific camera interface
      if (kIsWeb) {
        _cameraInterface = WebCameraInterface();
      } else if (Platform.isMacOS) {
        _cameraInterface = MacOSCameraInterface();
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Use basic camera for iOS due to performance issues with enhanced camera
        // Enhanced camera causes dark/slow preview on iOS devices
        if (Platform.isIOS) {
          _cameraInterface = MobileCameraInterface();
          await _cameraInterface!.initialize();
          Log.info('Using basic mobile camera for iOS (performance optimization)',
              name: 'VineRecordingController', category: LogCategory.system);
        } else {
          // Try enhanced mobile camera interface first for Android, fallback to basic if it fails
          try {
            _cameraInterface = EnhancedMobileCameraInterface();
            await _cameraInterface!.initialize();
            Log.info('Using enhanced mobile camera with zoom and focus features',
                name: 'VineRecordingController', category: LogCategory.system);
          } catch (enhancedError) {
            Log.warning('Enhanced camera failed, falling back to basic camera: $enhancedError',
                name: 'VineRecordingController', category: LogCategory.system);
            _cameraInterface?.dispose();
            _cameraInterface = MobileCameraInterface();
            await _cameraInterface!.initialize();
            Log.info('Using basic mobile camera interface as fallback',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        }
      } else {
        throw Exception('Platform not supported: ${Platform.operatingSystem}');
      }

      // For non-mobile platforms, initialize here (mobile initialization handled above)
      if (!Platform.isIOS && !Platform.isAndroid) {
        await _cameraInterface!.initialize();
      }

      // Set up temp directory for segments
      if (!kIsWeb) {
        final tempDir = await _getTempDirectory();
        _tempDirectory = tempDir.path;
      }

      // Mark camera as initialized - UI can now show preview
      _cameraInitialized = true;

      Log.info('VineRecordingController initialized for ${_getPlatformName()}',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      _setState(VineRecordingState.error);
      _cameraInitialized = false;
      Log.error('VineRecordingController initialization failed: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }

  /// Start recording a new segment (press down)
  Future<void> startRecording() async {
    if (!canRecord) return;

    // Prevent starting if already recording
    if (_state == VineRecordingState.recording) {
      Log.warning('Already recording, ignoring start request',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    // On web, prevent multiple segments - MediaRecorder doesn't support pause/resume like mobile
    // Web needs continuous recording or a different concatenation approach
    if (kIsWeb && _segments.isNotEmpty) {
      Log.warning('Multiple segments not supported on web - use single continuous recording',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    try {
      _setState(VineRecordingState.recording);
      _currentSegmentStartTime = DateTime.now();

      // ProofMode proof will be generated after recording using Guardian Project native library

      // Normal segmented recording for all platforms
      final segmentPath = _generateSegmentPath();
      await _cameraInterface!.startRecordingSegment(segmentPath);

      // Start progress timer
      _startProgressTimer();

      // Set max duration timer if this is the first segment or we're close to limit
      _startMaxDurationTimer();

      Log.info('Started recording segment ${_segments.length + 1}',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      // Reset state and clean up on error
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error('Failed to start recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - handle gracefully in UI
    }
  }

  /// Stop recording current segment (release)
  Future<void> stopRecording() async {
    if (_state != VineRecordingState.recording ||
        _currentSegmentStartTime == null) {
      Log.warning('Not recording or no start time, ignoring stop request',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    try {
      var segmentEndTime = DateTime.now();
      var segmentDuration =
          segmentEndTime.difference(_currentSegmentStartTime!);

      // For stop-motion: if user taps very quickly, wait for minimum duration
      // to ensure at least one frame is captured
      if (segmentDuration < minSegmentDuration) {
        final waitTime = minSegmentDuration - segmentDuration;
        Log.info(
            '🎬 Stop-motion mode: waiting ${waitTime.inMilliseconds}ms to capture frame',
            name: 'VineRecordingController',
            category: LogCategory.system);
        await Future.delayed(waitTime);

        // Recalculate after waiting
        segmentEndTime = DateTime.now();
        segmentDuration = segmentEndTime.difference(_currentSegmentStartTime!);
      }

      // Now we're guaranteed to have at least minSegmentDuration
      if (segmentDuration >= minSegmentDuration) {
        // For macOS in single recording mode, stop the native recording to get the actual path
        if (!kIsWeb &&
            Platform.isMacOS &&
            _cameraInterface is MacOSCameraInterface) {
          final macOSInterface = _cameraInterface as MacOSCameraInterface;

          // Cancel auto-stop timer since user is manually stopping
          macOSInterface._maxDurationTimer?.cancel();

          // Stop the native recording and get the actual file path
          final recordedPath = await macOSInterface.completeRecording();

          if (recordedPath != null) {
            Log.info('📱 Native recording stopped, path: $recordedPath',
                name: 'VineRecordingController', category: LogCategory.system);

            final segment = RecordingSegment(
              startTime: _currentSegmentStartTime!,
              endTime: segmentEndTime,
              duration: segmentDuration,
              filePath: recordedPath,
            );

            _segments.add(segment);
            _totalRecordedDuration += segmentDuration;

            Log.info('📱 Segment added - segments count now: ${_segments.length}',
                name: 'VineRecordingController', category: LogCategory.system);

            Log.info(
                'Completed segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms',
                name: 'VineRecordingController',
                category: LogCategory.system);
          } else {
            Log.warning('Failed to stop native recording - no path returned',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        } else {
          // Normal segment recording for other platforms
          final filePath = await _cameraInterface!.stopRecordingSegment();

          if (filePath != null) {
            final segment = RecordingSegment(
              startTime: _currentSegmentStartTime!,
              endTime: segmentEndTime,
              duration: segmentDuration,
              filePath: filePath,
            );

            _segments.add(segment);
            _totalRecordedDuration += segmentDuration;

            Log.info(
                'Completed segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms',
                name: 'VineRecordingController',
                category: LogCategory.system);
          } else {
            Log.warning('No file path returned from camera interface',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        }
      }

      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();

      // Reset total duration to actual segments total (removing any in-progress time)
      _totalRecordedDuration = _segments.fold<Duration>(
        Duration.zero,
        (total, segment) => total + segment.duration,
      );

      // Check if we've reached the maximum duration or if on web (single segment only)
      if (_totalRecordedDuration >= maxRecordingDuration || kIsWeb) {
        _setState(VineRecordingState.completed);
        Log.info(
            '📱 Recording completed - ${kIsWeb ? "web single segment" : "reached maximum duration"}',
            name: 'VineRecordingController',
            category: LogCategory.system);
      } else {
        _setState(VineRecordingState.paused);
      }
    } catch (e) {
      // Reset state and clean up on error
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error('Failed to stop recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - handle gracefully in UI
    }
  }

  /// Build FFmpeg crop filter for the specified aspect ratio
  ///
  /// Square: Center crop to 1:1 (minimum dimension)
  /// Vertical: Center crop to 9:16 (portrait)
  String _buildCropFilter(model.AspectRatio aspectRatio) {
    switch (aspectRatio) {
      case model.AspectRatio.square:
        // Center crop to 1:1 (existing production logic)
        return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";

      case model.AspectRatio.vertical:
        // Center crop to 9:16 vertical
        // Tested and validated with FFmpeg integration tests
        return "crop='if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw)':'if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9)':'(iw-if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw))/2':'(ih-if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9))/2'";
    }
  }

  /// Concatenate multiple video segments using FFmpeg (mobile/desktop only)
  /// NOTE: Android currently uses continuous recording (no segmentation) due to FFmpeg build issues
  Future<File?> _concatenateSegments(List<RecordingSegment> segments) async {
    if (kIsWeb) {
      throw Exception('FFmpeg concatenation not supported on web platform');
    }

    if (segments.isEmpty) {
      throw Exception('No segments to concatenate');
    }

    // Single segment - apply aspect ratio cropping via FFmpeg
    if (segments.length == 1 && segments.first.filePath != null) {
      Log.info('📹 Applying square cropping to single segment',
          name: 'VineRecordingController', category: LogCategory.system);

      final inputPath = segments.first.filePath!;
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final cropFilter = _buildCropFilter(_aspectRatio);
      final command = '-i "$inputPath" -vf "$cropFilter" -c:a copy "$outputPath"';

      Log.info('📹 Executing FFmpeg square crop command: $command',
          name: 'VineRecordingController', category: LogCategory.system);

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info('📹 FFmpeg square cropping successful: $outputPath',
            name: 'VineRecordingController', category: LogCategory.system);

        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          return outputFile;
        } else {
          throw Exception('Output file does not exist after cropping');
        }
      } else {
        final output = await session.getOutput();
        Log.error('📹 FFmpeg square cropping failed with code $returnCode',
            name: 'VineRecordingController', category: LogCategory.system);
        Log.error('📹 FFmpeg output: $output',
            name: 'VineRecordingController', category: LogCategory.system);
        throw Exception('FFmpeg square cropping failed with code $returnCode');
      }
    }

    try {
      Log.info('📹 Concatenating ${segments.length} video segments with FFmpeg',
          name: 'VineRecordingController', category: LogCategory.system);

      // Create output file path
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Create concat file list
      final concatFilePath = '${tempDir.path}/concat_list.txt';
      final concatFile = File(concatFilePath);

      // Write file paths to concat list
      final buffer = StringBuffer();
      for (final segment in segments) {
        if (segment.filePath != null) {
          // FFmpeg concat requires the 'file' prefix and proper escaping
          buffer.writeln("file '${segment.filePath}'");
        }
      }

      await concatFile.writeAsString(buffer.toString());

      Log.info('📹 FFmpeg concat list:\n${buffer.toString()}',
          name: 'VineRecordingController', category: LogCategory.system);

      // Execute FFmpeg concatenation with square (1:1) aspect ratio CENTER cropping
      // Vine-style videos must be square format, centered crop for best framing
      final cropFilter = _buildCropFilter(_aspectRatio);
      final command = '-f concat -safe 0 -i "$concatFilePath" -vf "$cropFilter" -c:a copy "$outputPath"';

      Log.info('📹 Executing FFmpeg command: $command',
          name: 'VineRecordingController', category: LogCategory.system);

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info('📹 FFmpeg concatenation successful: $outputPath',
            name: 'VineRecordingController', category: LogCategory.system);

        // Clean up concat list file
        try {
          await concatFile.delete();
        } catch (e) {
          Log.warning('Failed to delete concat list file: $e',
              name: 'VineRecordingController', category: LogCategory.system);
        }

        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          return outputFile;
        } else {
          throw Exception('Output file does not exist after concatenation');
        }
      } else {
        final output = await session.getOutput();
        Log.error('📹 FFmpeg concatenation failed with code $returnCode',
            name: 'VineRecordingController', category: LogCategory.system);
        Log.error('📹 FFmpeg output: $output',
            name: 'VineRecordingController', category: LogCategory.system);
        throw Exception('FFmpeg concatenation failed with code $returnCode');
      }
    } catch (e) {
      Log.error('📹 Video concatenation error: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }

  /// Calculate SHA256 hash of a video file
  Future<String> _calculateSHA256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get the recorded video path from macOS single recording mode.
  ///
  /// Refactored helper method that consolidates path discovery logic.
  /// Tries multiple sources in priority order:
  /// 1. Active recording completion (if still recording)
  /// 2. Current recording path (if already completed)
  /// 3. Virtual segments fallback (legacy path)
  ///
  /// Returns null if no valid recording is found.
  /// Throws exception if path discovery fails unexpectedly.
  Future<String?> _getMacOSRecordingPath(MacOSCameraInterface macOSInterface) async {
    // Try 1: If recording is still active, complete it first
    if (macOSInterface.isRecording) {
      try {
        final completedPath = await macOSInterface.completeRecording();
        if (completedPath != null && await File(completedPath).exists()) {
          Log.info('📱 Got recording from active recording completion',
              name: 'VineRecordingController', category: LogCategory.system);
          return completedPath;
        }
      } catch (e) {
        Log.error('Failed to complete macOS recording: $e',
            name: 'VineRecordingController', category: LogCategory.system);
      }
    }

    // Try 2: Check if we already have a recorded file
    if (macOSInterface.currentRecordingPath != null) {
      if (await File(macOSInterface.currentRecordingPath!).exists()) {
        Log.info('📱 Got recording from currentRecordingPath',
            name: 'VineRecordingController', category: LogCategory.system);
        return macOSInterface.currentRecordingPath;
      }
    }

    // Try 3: Check virtual segments as fallback
    final virtualSegments = macOSInterface.getVirtualSegments();
    if (virtualSegments.isNotEmpty && virtualSegments.first.filePath != null) {
      if (await File(virtualSegments.first.filePath!).exists()) {
        Log.info('📱 Got recording from virtual segments',
            name: 'VineRecordingController', category: LogCategory.system);
        return virtualSegments.first.filePath;
      }
    }

    return null;
  }

  /// Apply aspect ratio crop filter to a video file using FFmpeg.
  ///
  /// Refactored helper method that consolidates FFmpeg cropping logic.
  /// Uses the current aspect ratio setting (_aspectRatio) to:
  /// - Square (1:1): Crop to minimum dimension, centered
  /// - Vertical (9:16): Crop to 9:16 ratio, centered
  ///
  /// Returns a new cropped File in the temporary directory.
  /// Throws Exception if FFmpeg processing fails or output file doesn't exist.
  Future<File> _applyAspectRatioCrop(String inputPath) async {
    Log.info('📹 Applying aspect ratio crop to video',
        name: 'VineRecordingController', category: LogCategory.system);

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final cropFilter = _buildCropFilter(_aspectRatio);
    final command = '-i "$inputPath" -vf "$cropFilter" -c:a copy "$outputPath"';

    Log.info('📹 Executing FFmpeg crop command: $command',
        name: 'VineRecordingController', category: LogCategory.system);

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      Log.error('📹 FFmpeg crop failed with code $returnCode',
          name: 'VineRecordingController', category: LogCategory.system);
      Log.error('📹 FFmpeg output: $output',
          name: 'VineRecordingController', category: LogCategory.system);
      throw Exception('FFmpeg crop failed with code $returnCode');
    }

    final croppedFile = File(outputPath);
    if (!await croppedFile.exists()) {
      throw Exception('Cropped file does not exist after FFmpeg processing');
    }

    Log.info('📹 FFmpeg crop successful: $outputPath',
        name: 'VineRecordingController', category: LogCategory.system);

    return croppedFile;
  }

  /// Generate native ProofMode proof for a video file
  Future<NativeProofData?> _generateNativeProof(File videoFile) async {
    try {
      // Check if native ProofMode is available on this platform
      final isAvailable = await NativeProofModeService.isAvailable();
      if (!isAvailable) {
        Log.info('🔐 Native ProofMode not available on this platform',
            name: 'VineRecordingController', category: LogCategory.system);
        return null;
      }

      Log.info('🔐 Generating native ProofMode proof for: ${videoFile.path}',
          name: 'VineRecordingController', category: LogCategory.system);

      // Generate proof using native library
      final proofHash = await NativeProofModeService.generateProof(videoFile.path);
      if (proofHash == null) {
        Log.warning('🔐 Native proof generation returned null',
            name: 'VineRecordingController', category: LogCategory.system);
        return null;
      }

      Log.info('🔐 Native proof hash: $proofHash',
          name: 'VineRecordingController', category: LogCategory.system);

      // Read proof metadata from native library
      final metadata = await NativeProofModeService.readProofMetadata(proofHash);
      if (metadata == null) {
        Log.warning('🔐 Could not read native proof metadata',
            name: 'VineRecordingController', category: LogCategory.system);
        return null;
      }

      Log.info('🔐 Native proof metadata fields: ${metadata.keys.join(", ")}',
          name: 'VineRecordingController', category: LogCategory.system);

      // Create NativeProofData from metadata
      final proofData = NativeProofData.fromMetadata(metadata);
      Log.info('🔐 Native proof data created: ${proofData.verificationLevel}',
          name: 'VineRecordingController', category: LogCategory.system);

      return proofData;
    } catch (e) {
      Log.error('🔐 Native proof generation failed: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      return null;
    }
  }

  /// Finish recording and return the final compiled video with optional native ProofMode data
  Future<(File?, NativeProofData?)> finishRecording() async {
    try {
      _setState(VineRecordingState.processing);

      // For macOS single recording mode, handle specially
      if (!kIsWeb &&
          Platform.isMacOS &&
          _cameraInterface is MacOSCameraInterface) {
        final macOSInterface = _cameraInterface as MacOSCameraInterface;

        // For single recording mode, get the recorded file directly
        if (macOSInterface.isSingleRecordingMode) {
          Log.info(
              '📱 finishRecording: macOS single mode, isRecording=${macOSInterface.isRecording}',
              name: 'VineRecordingController',
              category: LogCategory.system);

          // Get the recording path from any available source
          final recordingPath = await _getMacOSRecordingPath(macOSInterface);
          if (recordingPath == null) {
            throw Exception('No valid recording found for macOS single recording mode');
          }

          // Apply aspect ratio crop to the video
          final croppedFile = await _applyAspectRatioCrop(recordingPath);

          _setState(VineRecordingState.completed);
          macOSInterface.isSingleRecordingMode = false; // Clear flag after successful completion

          // Generate native ProofMode proof
          final nativeProof = await _generateNativeProof(croppedFile);

          return (croppedFile, nativeProof);
        }
      }

      // For non-single recording mode, stop any active recording
      if (_state == VineRecordingState.recording) {
        await stopRecording();
      }

      // For multi-segment recording, check virtual segments first
      if (!kIsWeb &&
          Platform.isMacOS &&
          _cameraInterface is MacOSCameraInterface) {
        final macOSInterface = _cameraInterface as MacOSCameraInterface;
        final virtualSegments = macOSInterface.getVirtualSegments();

        // If we have virtual segments but no main segments, use the virtual ones
        if (_segments.isEmpty && virtualSegments.isNotEmpty) {
          _segments.addAll(virtualSegments);
          Log.info(
              'Using ${virtualSegments.length} virtual segments from macOS recording',
              name: 'VineRecordingController',
              category: LogCategory.system);
        }
      }

      Log.info('📱 finishRecording: hasSegments=$hasSegments, segments count=${_segments.length}',
          name: 'VineRecordingController', category: LogCategory.system);

      // Debug: Log all segment details
      for (int i = 0; i < _segments.length; i++) {
        final segment = _segments[i];
        Log.info('📱 Segment $i: duration=${segment.duration.inMilliseconds}ms, filePath=${segment.filePath}',
            name: 'VineRecordingController', category: LogCategory.system);
      }

      if (!hasSegments) {
        throw Exception('No valid video segments found for compilation');
      }

      // For web platform, handle blob URLs
      if (kIsWeb && _segments.length == 1 && _segments.first.filePath != null) {
        final filePath = _segments.first.filePath!;
        if (filePath.startsWith('blob:')) {
          // For web, we can't return a File object from blob URL
          // Instead, we'll create a temporary file representation
          try {
            // Use the standalone blobUrlToBytes function
            final bytes = await camera_service.blobUrlToBytes(filePath);
            if (bytes.isNotEmpty) {
              // Create a temporary file with the blob data
              final tempDir = await getTemporaryDirectory();
              final tempFile = File(
                  '${tempDir.path}/web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4');
              await tempFile.writeAsBytes(bytes);

              _setState(VineRecordingState.completed);

              // Generate native ProofMode proof
              final nativeProof = await _generateNativeProof(tempFile);

              return (tempFile, nativeProof);
            }
          } catch (e) {
            Log.error('Failed to convert blob to file: $e',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        }
      }

      // For other platforms (iOS, Android), handle single segment with aspect ratio crop
      if (!kIsWeb &&
          _segments.length == 1 &&
          _segments.first.filePath != null) {
        final file = File(_segments.first.filePath!);
        if (await file.exists()) {
          // Apply aspect ratio crop to the video
          final croppedFile = await _applyAspectRatioCrop(file.path);

          _setState(VineRecordingState.completed);

          // Generate native ProofMode proof
          final nativeProof = await _generateNativeProof(croppedFile);

          return (croppedFile, nativeProof);
        }
      }

      // Concatenate multiple segments using FFmpeg
      if (_segments.isNotEmpty) {
        Log.info('📹 Concatenating ${_segments.length} segments using FFmpeg',
            name: 'VineRecordingController', category: LogCategory.system);

        final concatenatedFile = await _concatenateSegments(_segments);
        if (concatenatedFile != null) {
          _setState(VineRecordingState.completed);

          // Generate native ProofMode proof
          final nativeProof = await _generateNativeProof(concatenatedFile);

          return (concatenatedFile, nativeProof);
        }
      }

      throw Exception('No valid video segments found for compilation');
    } catch (e) {
      _setState(VineRecordingState.error);
      Log.error('Failed to finish recording: $e',
          name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }

  /// Clean up recording files and prepare for new recording
  void cleanupFiles() {
    _cleanupRecordings();
  }

  /// Reset the recording session (but keep files for upload)
  void reset() {
    _stopProgressTimer();
    _stopMaxDurationTimer();

    // Don't clean up recording files here - they're needed for upload
    // Files will be cleaned up when starting a new recording session

    _segments.clear();
    _totalRecordedDuration = Duration.zero;
    _currentSegmentStartTime = null;

    // Check if we need to reinitialize before resetting state
    final wasInError = _state == VineRecordingState.error;

    // Reset camera initialization flag if we're in error state
    if (wasInError) {
      _cameraInitialized = false;
    }

    // Reset state
    _setState(VineRecordingState.idle);

    // If was in error state and on web, reinitialize the camera
    if (wasInError && kIsWeb) {
      Log.error('Reinitializing web camera after error...',
          name: 'VineRecordingController', category: LogCategory.system);
      if (_cameraInterface is WebCameraInterface) {
        final webInterface = _cameraInterface as WebCameraInterface;
        webInterface.dispose();
      }
      // Create new camera interface and initialize
      _cameraInterface = WebCameraInterface();
      initialize().then((_) {
        Log.info('Web camera reinitialized successfully',
            name: 'VineRecordingController', category: LogCategory.system);
        _setState(VineRecordingState.idle);
      }).catchError((e) {
        Log.error('Failed to reinitialize web camera: $e',
            name: 'VineRecordingController', category: LogCategory.system);
        _setState(VineRecordingState.error);
      });
    }

    Log.debug('Recording session reset',
        name: 'VineRecordingController', category: LogCategory.system);
  }

  /// Clean up recording files and resources
  void _cleanupRecordings() {
    try {
      // Clean up platform-specific resources
      if (kIsWeb && _cameraInterface is WebCameraInterface) {
        _cleanupWebRecordings();
      } else if (!kIsWeb &&
          Platform.isMacOS &&
          _cameraInterface is MacOSCameraInterface) {
        _cleanupMacOSRecording();
      } else {
        _cleanupMobileRecordings();
      }

      Log.debug('🧹 Cleaned up recording resources',
          name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Error cleaning up recordings: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  }

  /// Clean up web recordings (blob URLs)
  void _cleanupWebRecordings() {
    // Clean up through the web camera interface
    if (_cameraInterface is WebCameraInterface) {
      final webInterface = _cameraInterface as WebCameraInterface;

      // Clean up blob URLs through the service
      for (final segment in _segments) {
        if (segment.filePath != null && segment.filePath!.startsWith('blob:')) {
          try {
            webInterface._cleanupBlobUrl(segment.filePath!);
          } catch (e) {
            Log.error('Error cleaning up blob URL: $e',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        }
      }

      // Dispose the service
      webInterface._webCameraService?.dispose();
    }
  }

  /// Clean up macOS recording
  void _cleanupMacOSRecording() {
    final macOSInterface = _cameraInterface as MacOSCameraInterface;

    // Stop any active recording and clean up files
    if (macOSInterface.currentRecordingPath != null) {
      try {
        // Clean up the recording file if it exists
        final file = File(macOSInterface.currentRecordingPath!);
        if (file.existsSync()) {
          file.deleteSync();
          Log.debug(
              '🧹 Deleted macOS recording file: ${macOSInterface.currentRecordingPath}',
              name: 'VineRecordingController',
              category: LogCategory.system);
        }
      } catch (e) {
        Log.error('Error deleting macOS recording file: $e',
            name: 'VineRecordingController', category: LogCategory.system);
      }
    }

    // Reset the interface completely
    macOSInterface.reset();
  }

  /// Clean up mobile recordings
  void _cleanupMobileRecordings() {
    for (final segment in _segments) {
      if (segment.filePath != null) {
        try {
          final file = File(segment.filePath!);
          if (file.existsSync()) {
            file.deleteSync();
            Log.debug('🧹 Deleted mobile recording file: ${segment.filePath}',
                name: 'VineRecordingController', category: LogCategory.system);
          }
        } catch (e) {
          Log.error('Error deleting mobile recording file: $e',
              name: 'VineRecordingController', category: LogCategory.system);
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _stopProgressTimer();
    _stopMaxDurationTimer();

    // Clean up all recordings
    _cleanupRecordings();

    _cameraInterface?.dispose();
  }

  // Private methods

  void _setState(VineRecordingState newState) {
    if (_disposed) return;
    _state = newState;
    // Notify UI of state change
    _onStateChanged?.call();
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_disposed && _state == VineRecordingState.recording) {
        // For macOS, update the total duration based on current segment time
        if (_currentSegmentStartTime != null) {
          final currentSegmentDuration =
              DateTime.now().difference(_currentSegmentStartTime!);
          final previousDuration = _segments.fold<Duration>(
            Duration.zero,
            (total, segment) => total + segment.duration,
          );
          _totalRecordedDuration = previousDuration + currentSegmentDuration;
        }

        // Notify UI of progress update
        _onStateChanged?.call();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _startMaxDurationTimer() {
    _stopMaxDurationTimer();
    final remainingTime = remainingDuration;
    if (remainingTime > Duration.zero) {
      _maxDurationTimer = Timer(remainingTime, () {
        if (_state == VineRecordingState.recording) {
          Log.info('📱 Recording completed - reached maximum duration',
              name: 'VineRecordingController', category: LogCategory.system);

          // For macOS, handle auto-completion differently
          if (!kIsWeb &&
              Platform.isMacOS &&
              _cameraInterface is MacOSCameraInterface) {
            _handleMacOSAutoCompletion();
          } else {
            stopRecording();
          }
        }
      });
    }
  }

  /// Handle macOS recording auto-completion after max duration
  void _handleMacOSAutoCompletion() async {
    final macOSInterface = _cameraInterface as MacOSCameraInterface;

    // Stop the native recording first to get the file path
    final recordedPath = await macOSInterface.completeRecording();

    // Create a segment with the actual file path
    if (_currentSegmentStartTime != null && recordedPath != null) {
      final segmentEndTime = DateTime.now();
      final segmentDuration =
          segmentEndTime.difference(_currentSegmentStartTime!);

      final segment = RecordingSegment(
        startTime: _currentSegmentStartTime!,
        endTime: segmentEndTime,
        duration: segmentDuration,
        filePath: recordedPath,
      );

      _segments.add(segment);
      _totalRecordedDuration += segmentDuration;

      Log.info(
          'Completed segment ${_segments.length} after auto-stop: ${segmentDuration.inMilliseconds}ms, path: $recordedPath',
          name: 'VineRecordingController',
          category: LogCategory.system);
    } else if (_currentSegmentStartTime == null) {
      Log.warning('Cannot create segment - no start time recorded',
          name: 'VineRecordingController', category: LogCategory.system);
    } else if (recordedPath == null) {
      Log.error('Cannot create segment - completeRecording returned null path',
          name: 'VineRecordingController', category: LogCategory.system);
    }

    _currentSegmentStartTime = null;
    _stopProgressTimer();
    _stopMaxDurationTimer();

    // Set state to completed since we reached max duration
    _setState(VineRecordingState.completed);
  }

  void _stopMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }

  String _generateSegmentPath() {
    if (kIsWeb) {
      return 'segment_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$_tempDirectory/vine_segment_${_segments.length + 1}_${DateTime.now().millisecondsSinceEpoch}.mov';
  }

  Future<Directory> _getTempDirectory() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final directory = await getTemporaryDirectory();
      return directory;
    } else {
      // macOS/Windows temp directory
      return Directory.systemTemp;
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
