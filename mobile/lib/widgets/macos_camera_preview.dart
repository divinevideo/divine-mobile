// ABOUTME: macOS camera preview widget using platform view for native camera display
// ABOUTME: Renders the actual camera feed from AVFoundation through a platform view

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Widget that displays the native macOS camera preview
class MacOSCameraPreview extends StatefulWidget {
  const MacOSCameraPreview({super.key});

  @override
  State<MacOSCameraPreview> createState() => _MacOSCameraPreviewState();
}

class _MacOSCameraPreviewState extends State<MacOSCameraPreview> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return const Center(
        child: Text('macOS camera preview only available on macOS'),
      );
    }

    // Use AppKitView for macOS platform view
    return const AppKitView(
      viewType: 'openvine/camera_preview',
      creationParams: <String, dynamic>{'preview': true},
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}

/// Fallback preview widget for when camera is not available
class CameraPreviewPlaceholder extends StatelessWidget {
  final bool isRecording;

  const CameraPreviewPlaceholder({super.key, this.isRecording = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording ? Icons.fiber_manual_record : Icons.videocam,
              size: 64,
              color: isRecording ? Colors.red : Colors.white54,
            ),
            const SizedBox(height: 8),
            Text(
              isRecording ? 'Recording...' : 'Camera Preview',
              style: TextStyle(
                color: isRecording ? Colors.red : Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
