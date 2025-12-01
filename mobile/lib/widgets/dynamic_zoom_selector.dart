// ABOUTME: Dynamic zoom selector that shows buttons for each physical camera
// ABOUTME: Detects actual zoom factors (0.5x, 1x, 3x, etc.) instead of hardcoded values

import 'package:flutter/material.dart';
import 'package:openvine/services/camera/camerawesome_mobile_camera_interface.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Dynamic zoom selector that builds UI based on detected physical cameras
class DynamicZoomSelector extends StatefulWidget {
  const DynamicZoomSelector({required this.cameraInterface, super.key});

  final CamerAwesomeMobileCameraInterface cameraInterface;

  @override
  State<DynamicZoomSelector> createState() => _DynamicZoomSelectorState();
}

class _DynamicZoomSelectorState extends State<DynamicZoomSelector> {
  double? _selectedZoom;

  @override
  void initState() {
    super.initState();
    _selectedZoom = widget.cameraInterface.currentZoomFactor;
  }

  @override
  Widget build(BuildContext context) {
    final sensors = widget.cameraInterface.availableSensors;

    if (sensors.isEmpty || sensors.length == 1) {
      // No zoom options available
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: sensors.map((sensor) {
          final isSelected =
              _selectedZoom != null &&
              (sensor.zoomFactor - _selectedZoom!).abs() < 0.1;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _ZoomButton(
              zoomFactor: sensor.zoomFactor,
              displayName: _formatZoomLabel(sensor.zoomFactor),
              isSelected: isSelected,
              onTap: () => _switchToZoom(sensor.zoomFactor),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatZoomLabel(double zoomFactor) {
    // Format zoom factor for display
    if (zoomFactor == zoomFactor.roundToDouble()) {
      // Whole number (1.0 → "1", 3.0 → "3")
      return '${zoomFactor.round()}';
    } else {
      // Decimal (0.5 → "0.5", 2.5 → "2.5")
      return zoomFactor.toStringAsFixed(1);
    }
  }

  Future<void> _switchToZoom(double zoomFactor) async {
    if (_selectedZoom == zoomFactor) {
      return; // Already on this zoom
    }

    setState(() {
      _selectedZoom = zoomFactor;
    });

    try {
      await widget.cameraInterface.switchToSensor(zoomFactor);
    } catch (e) {
      // Revert selection on error
      setState(() {
        _selectedZoom = widget.cameraInterface.currentZoomFactor;
      });
    }
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.zoomFactor,
    required this.displayName,
    required this.isSelected,
    required this.onTap,
  });

  final double zoomFactor;
  final String displayName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 50 : 42,
        height: isSelected ? 50 : 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? VineTheme.vineGreen.withOpacity(0.3)
              : Colors.black.withOpacity(0.4),
          border: Border.all(
            color: isSelected
                ? VineTheme.vineGreen
                : Colors.white.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '${displayName}x',
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: isSelected ? 15 : 13,
            ),
          ),
        ),
      ),
    );
  }
}
