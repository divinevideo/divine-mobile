// ABOUTME: Camera controls overlay for advanced features like zoom and flash
// ABOUTME: Works with CameraAwesome on mobile platforms to provide enhanced controls

import 'package:flutter/material.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Overlay widget that provides camera controls for zoom, flash, etc.
class CameraControlsOverlay extends StatefulWidget {
  const CameraControlsOverlay({
    required this.cameraInterface,
    required this.recordingState,
    super.key,
  });

  final CameraPlatformInterface cameraInterface;
  final VineRecordingState recordingState;

  @override
  State<CameraControlsOverlay> createState() => _CameraControlsOverlayState();
}

class _CameraControlsOverlayState extends State<CameraControlsOverlay> {
  @override
  Widget build(BuildContext context) {
    // CameraControlsOverlay now only handles gesture-based controls (zoom, focus)
    // Flash, timer, and aspect ratio buttons are in UniversalCameraScreenPure._buildCameraControls
    return const SizedBox.shrink();
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Enhanced camera features info widget
class CameraFeaturesInfo extends StatelessWidget {
  const CameraFeaturesInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Camera Controls',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: VineTheme.vineGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.touch_app, 'Tap to focus'),
          _buildFeatureRow(Icons.zoom_in, 'Pinch to zoom'),
          _buildFeatureRow(Icons.flash_on, 'Toggle flash'),
          _buildFeatureRow(Icons.cameraswitch, 'Switch camera'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
