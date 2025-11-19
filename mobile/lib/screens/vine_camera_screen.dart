// ABOUTME: Main camera screen with orientation fix and full recording features
// ABOUTME: Uses exact camera preview structure from experimental app to ensure proper orientation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:openvine/utils/unified_logger.dart';

class VineCameraScreen extends StatefulWidget {
  const VineCameraScreen({super.key});

  @override
  State<VineCameraScreen> createState() => _VineCameraScreenState();
}

class _VineCameraScreenState extends State<VineCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isSwitchingCamera = false;
  String? _errorMessage;
  FlashMode _flashMode = FlashMode.off;
  List<CameraDescription> _availableCameras = [];

  // Separate camera lists for front/back
  List<CameraDescription> _rearCameras = [];
  CameraDescription? _frontCamera;
  int _currentRearCameraIndex = 0;
  bool _isFrontCamera = false;

  // Focus indicator state
  Offset? _focusPoint;
  bool _showFocusIndicator = false;

  @override
  void initState() {
    super.initState();
    Log.info('📹 VineCameraScreen.initState() - Starting camera initialization',
        name: 'VineCameraScreen', category: LogCategory.system);
    _initializeCamera();
  }

  @override
  void dispose() {
    Log.info('📹 VineCameraScreen.dispose() - Cleaning up camera controller',
        name: 'VineCameraScreen', category: LogCategory.system);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      Log.info('📹 Getting available cameras...',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Get available cameras
      _availableCameras = await availableCameras();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during availableCameras(), aborting initialization',
            name: 'VineCameraScreen', category: LogCategory.system);
        return;
      }

      Log.info('📹 Found ${_availableCameras.length} cameras',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (_availableCameras.isEmpty) {
        Log.error('📹 No cameras available',
            name: 'VineCameraScreen', category: LogCategory.system);
        if (mounted) {
          setState(() {
            _errorMessage = 'No cameras found';
          });
        }
        return;
      }

      // Categorize cameras into rear and front
      _rearCameras = _availableCameras
          .where((cam) => cam.lensDirection == CameraLensDirection.back)
          .toList();
      _frontCamera = _availableCameras
          .firstWhere((cam) => cam.lensDirection == CameraLensDirection.front,
              orElse: () => _availableCameras.first);

      Log.info('📹 Categorized cameras: ${_rearCameras.length} rear, ${_frontCamera != null ? '1' : '0'} front',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Log rear camera details for debugging zoom labels
      for (var i = 0; i < _rearCameras.length; i++) {
        final cam = _rearCameras[i];
        Log.debug('📹 Rear camera $i: ${cam.name}, lensType: ${cam.lensType}',
            name: 'VineCameraScreen', category: LogCategory.system);
      }

      // Start with first rear camera (default is back camera)
      _currentRearCameraIndex = 0;
      _isFrontCamera = false;
      final camera = _rearCameras.isNotEmpty ? _rearCameras[0] : _availableCameras[0];

      Log.info('📹 Initializing camera: ${camera.name} (${camera.lensDirection})',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Initialize camera controller
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      Log.info('📹 Calling controller.initialize()...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.initialize();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during controller.initialize(), disposing controller',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Camera initialized, locking orientation to portraitUp',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Lock camera orientation to portrait
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        Log.warning('📹 Widget unmounted during lockCaptureOrientation(), disposing controller',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Setting flash mode to $_flashMode',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Set initial flash mode
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        Log.info('📹 ✅ Camera initialization complete!',
            name: 'VineCameraScreen', category: LogCategory.system);

        // Start warming up recording pipeline in background (don't await - fire and forget)
        // This runs asynchronously so it doesn't block the UI, but may help reduce first recording delay
        _controller!.prepareForVideoRecording().then((_) {
          Log.info('📹 Recording pipeline warm-up complete',
              name: 'VineCameraScreen', category: LogCategory.system);
        }).catchError((e) {
          Log.warning('📹 Recording pipeline warm-up failed (non-critical): $e',
              name: 'VineCameraScreen', category: LogCategory.system);
        });
      } else {
        Log.warning('📹 Widget unmounted after initialization, disposing controller',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
      }
    } catch (e, stackTrace) {
      Log.error('📹 ❌ Camera initialization failed: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
      Log.debug('Stack trace: $stackTrace',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  // Mobile recording: press-hold pattern
  Future<void> _startRecording() async {
    Log.info('📹 _startRecording() called',
        name: 'VineCameraScreen', category: LogCategory.system);

    if (!mounted) {
      Log.warning('📹 Cannot start recording - widget not mounted',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_controller == null) {
      Log.warning('📹 Cannot start recording - controller is null',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (!_controller!.value.isInitialized) {
      Log.warning('📹 Cannot start recording - controller not initialized',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_isRecording) {
      Log.debug('📹 Already recording, ignoring start request',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_isSwitchingCamera) {
      Log.warning('📹 Cannot start recording - camera switch in progress',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    try {
      Log.info('📹 Starting video recording...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.startVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
        Log.info('📹 ✅ Video recording started',
            name: 'VineCameraScreen', category: LogCategory.system);
      }
    } catch (e, stackTrace) {
      Log.error('📹 ❌ Failed to start recording: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
      Log.debug('Stack trace: $stackTrace',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _errorMessage = 'Recording error: $e';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    Log.info('📹 _stopRecording() called',
        name: 'VineCameraScreen', category: LogCategory.system);

    if (!mounted) {
      Log.warning('📹 Cannot stop recording - widget not mounted',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_controller == null) {
      Log.warning('📹 Cannot stop recording - controller is null',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (!_controller!.value.isInitialized) {
      Log.warning('📹 Cannot stop recording - controller not initialized',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (!_isRecording) {
      Log.debug('📹 Not recording, ignoring stop request',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    try {
      Log.info('📹 Stopping video recording...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.stopVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        Log.info('📹 ✅ Video recording stopped',
            name: 'VineCameraScreen', category: LogCategory.system);
      }
    } catch (e, stackTrace) {
      // Handle "No video is recording" gracefully - this can happen if camera was switched during recording
      if (e.toString().contains('No video is recording')) {
        Log.info('📹 Recording already stopped (likely due to camera switch)',
            name: 'VineCameraScreen', category: LogCategory.system);
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
        }
        return;
      }

      // Log other errors
      Log.error('📹 ❌ Failed to stop recording: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
      Log.debug('Stack trace: $stackTrace',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _errorMessage = 'Recording error: $e';
        });
      }
    }
  }

  // Toggle recording: tap once to start, tap again to stop
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // Handle tap-to-focus
  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Get the tap position relative to the screen
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final tapPosition = details.localPosition;

      // Convert to normalized coordinates (0.0 to 1.0)
      final double x = tapPosition.dx / renderBox.size.width;
      final double y = tapPosition.dy / renderBox.size.height;

      // Set focus and exposure point
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));

      // Show focus indicator
      setState(() {
        _focusPoint = tapPosition;
        _showFocusIndicator = true;
      });

      Log.debug('📹 Focus set to: ($x, $y)',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Hide focus indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showFocusIndicator = false;
          });
        }
      });
    } catch (e) {
      Log.error('📹 Failed to set focus: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
    }
  }

  // Toggle flash mode: off → torch → off
  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      await _controller!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      // Flash might not be available on this camera
    }
  }

  // Switch between front and back cameras (toggles between front and current rear camera)
  Future<void> _switchCamera() async {
    Log.info('📹 _switchCamera() called - toggling front/back',
        name: 'VineCameraScreen', category: LogCategory.system);

    // Need at least one rear camera and one front camera
    if (_rearCameras.isEmpty || _frontCamera == null) {
      Log.debug('📹 Missing front or rear camera, cannot switch',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning('📹 Cannot switch camera - controller not initialized',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_isSwitchingCamera) {
      Log.warning('📹 Camera switch already in progress',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (!mounted) {
      Log.warning('📹 Cannot switch camera - widget not mounted',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    try {
      // If recording, stop it first before switching cameras
      final wasRecording = _isRecording;

      if (wasRecording) {
        Log.info('📹 Stopping recording before camera switch...',
            name: 'VineCameraScreen', category: LogCategory.system);
        try {
          await _controller!.stopVideoRecording();
        } catch (e) {
          Log.warning('📹 Recording already stopped during camera switch: $e',
              name: 'VineCameraScreen', category: LogCategory.system);
        }
        _isRecording = false;
      }

      setState(() {
        _isSwitchingCamera = true;
      });

      Log.info('📹 Disposing old camera controller...',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Dispose old controller first
      await _controller!.dispose();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during camera switch',
            name: 'VineCameraScreen', category: LogCategory.system);
        return;
      }

      // Toggle between front and back
      _isFrontCamera = !_isFrontCamera;
      final camera = _isFrontCamera
          ? _frontCamera!
          : _rearCameras[_currentRearCameraIndex];

      Log.info('📹 Switching to camera: ${camera.name} (${camera.lensDirection})',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Initialize new camera
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      Log.info('📹 Initializing new camera controller...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.initialize();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during new camera init',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Locking new camera to portrait orientation...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        Log.warning('📹 Widget unmounted during orientation lock',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Setting flash mode on new camera...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
        Log.info('📹 ✅ Camera switch complete!',
            name: 'VineCameraScreen', category: LogCategory.system);

        // Warm up recording pipeline in background (non-blocking)
        _controller!.prepareForVideoRecording().then((_) {
          Log.info('📹 Recording pipeline warm-up complete after camera switch',
              name: 'VineCameraScreen', category: LogCategory.system);
        }).catchError((e) {
          Log.warning('📹 Recording pipeline warm-up failed (non-critical): $e',
              name: 'VineCameraScreen', category: LogCategory.system);
        });
      }
    } catch (e, stackTrace) {
      Log.error('📹 ❌ Failed to switch camera: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
      Log.debug('Stack trace: $stackTrace',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
          _errorMessage = 'Failed to switch camera: $e';
        });
      }
    }
  }

  // Switch zoom level (cycles through rear cameras only)
  Future<void> _switchZoom() async {
    Log.info('📹 _switchZoom() called',
        name: 'VineCameraScreen', category: LogCategory.system);

    // Only works on rear cameras
    if (_isFrontCamera) {
      Log.debug('📹 Front camera active, zoom switching disabled',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    // Need at least 2 rear cameras to switch zoom
    if (_rearCameras.length <= 1) {
      Log.debug('📹 Only ${_rearCameras.length} rear camera(s), cannot switch zoom',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning('📹 Cannot switch zoom - controller not initialized',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (_isSwitchingCamera) {
      Log.warning('📹 Camera switch already in progress',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    if (!mounted) {
      Log.warning('📹 Cannot switch zoom - widget not mounted',
          name: 'VineCameraScreen', category: LogCategory.system);
      return;
    }

    try {
      // If recording, stop it first before switching zoom
      final wasRecording = _isRecording;

      if (wasRecording) {
        Log.info('📹 Stopping recording before zoom switch...',
            name: 'VineCameraScreen', category: LogCategory.system);
        try {
          await _controller!.stopVideoRecording();
        } catch (e) {
          Log.warning('📹 Recording already stopped during zoom switch: $e',
              name: 'VineCameraScreen', category: LogCategory.system);
        }
        _isRecording = false;
      }

      setState(() {
        _isSwitchingCamera = true;
      });

      Log.info('📹 Disposing old camera controller...',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Dispose old controller first
      await _controller!.dispose();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during zoom switch',
            name: 'VineCameraScreen', category: LogCategory.system);
        return;
      }

      // Cycle to next rear camera
      _currentRearCameraIndex = (_currentRearCameraIndex + 1) % _rearCameras.length;
      final camera = _rearCameras[_currentRearCameraIndex];

      Log.info('📹 Switching to rear camera ${_currentRearCameraIndex + 1}/${_rearCameras.length}: ${camera.name}',
          name: 'VineCameraScreen', category: LogCategory.system);

      // Initialize new camera
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      Log.info('📹 Initializing new camera controller...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.initialize();

      if (!mounted) {
        Log.warning('📹 Widget unmounted during new camera init',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Locking new camera to portrait orientation...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        Log.warning('📹 Widget unmounted during orientation lock',
            name: 'VineCameraScreen', category: LogCategory.system);
        _controller?.dispose();
        return;
      }

      Log.info('📹 Setting flash mode on new camera...',
          name: 'VineCameraScreen', category: LogCategory.system);

      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
        Log.info('📹 ✅ Zoom switch complete!',
            name: 'VineCameraScreen', category: LogCategory.system);

        // Warm up recording pipeline in background (non-blocking)
        _controller!.prepareForVideoRecording().then((_) {
          Log.info('📹 Recording pipeline warm-up complete (after zoom switch)',
              name: 'VineCameraScreen', category: LogCategory.system);
        }).catchError((e) {
          Log.warning('📹 Recording pipeline warm-up failed (non-critical): $e',
              name: 'VineCameraScreen', category: LogCategory.system);
        });
      }
    } catch (e, stackTrace) {
      Log.error('📹 ❌ Failed to switch zoom: $e',
          name: 'VineCameraScreen', category: LogCategory.system);
      Log.debug('Stack trace: $stackTrace',
          name: 'VineCameraScreen', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
          _errorMessage = 'Failed to switch zoom: $e';
        });
      }
    }
  }

  // Get zoom level display text (e.g., "1x", "0.5x", "3x")
  String get _zoomLevelText {
    if (_isFrontCamera || _rearCameras.isEmpty) {
      return '1x';
    }

    // Use lensType property to determine zoom level
    final camera = _rearCameras[_currentRearCameraIndex];

    switch (camera.lensType) {
      case CameraLensType.ultraWide:
        return '0.5x';
      case CameraLensType.wide:
        return '1x';
      case CameraLensType.telephoto:
        // For telephoto, check camera name for 5x vs 3x
        final name = camera.name.toLowerCase();
        if (name.contains('5x') || name.contains('periscope')) {
          return '5x';
        }
        return '3x';
      case CameraLensType.unknown:
        // Fallback: try to parse from name
        final name = camera.name.toLowerCase();
        if (name.contains('ultra')) return '0.5x';
        if (name.contains('tele') || name.contains('telephoto')) return '3x';
        if (name.contains('5x')) return '5x';
        return '1x';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap anywhere to focus camera
        onTapDown: (details) => _handleTapToFocus(details),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Camera preview - full screen without black bars
          // EXACT structure from experimental app
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 60,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Camera controls (Flash, Switch Camera) at top-right
          Positioned(
            top: 60,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flash button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ),
                const SizedBox(height: 16),
                // Switch camera button
                if (_availableCameras.length > 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ),
              ],
            ),
          ),

          // Recording button at the bottom center
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : Colors.white,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: _isRecording
                      ? const Center(
                          child: Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 40,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Zoom button (above record button, only visible for rear camera with multiple lenses)
          if (!_isFrontCamera && _rearCameras.length > 1)
            Positioned(
              bottom: 140, // 100px above record button (40 + 80 + 20)
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _switchZoom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _zoomLevelText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Focus indicator
          if (_showFocusIndicator && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 40,
              top: _focusPoint!.dy - 40,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'RECORDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ],
        ), // End of Stack
      ), // End of GestureDetector
    );
  }
}
