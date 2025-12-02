// ABOUTME: Test camera screen using exact code from experimental camera app
// ABOUTME: to verify camera orientation fix works

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

class TestCameraScreen extends StatefulWidget {
  const TestCameraScreen({super.key});

  @override
  State<TestCameraScreen> createState() => _TestCameraScreenState();
}

class _TestCameraScreenState extends State<TestCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found';
        });
        return;
      }

      // Use the first camera (usually back camera)
      final camera = cameras.first;

      // Initialize camera controller
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();

      // Lock camera orientation to portrait
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      if (_isRecording) {
        // Stop recording
        await _controller!.stopVideoRecording();
        setState(() {
          _isRecording = false;
        });
      } else {
        // Start recording
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording error: $e';
      });
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
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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

          // Recording button at the bottom
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
                    border: Border.all(color: Colors.white, width: 4),
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
      ),
    );
  }
}
