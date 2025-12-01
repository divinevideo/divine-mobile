// ABOUTME: Native platform channel to detect physical camera zoom factors dynamically
// ABOUTME: iOS: Queries AVCaptureDevice for exact zoom values. Android: Uses CamerAwesome API

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:openvine/utils/unified_logger.dart';

/// Information about a physical camera sensor
class PhysicalCameraSensor {
  const PhysicalCameraSensor({
    required this.type,
    required this.zoomFactor,
    required this.deviceId,
    required this.displayName,
    this.isDigital = false,
  });

  final String type; // 'wide', 'ultrawide', 'telephoto', 'front', 'digital'
  final double zoomFactor; // Actual zoom factor (e.g., 0.5, 1.0, 2.0, 3.0)
  final String deviceId; // Native device identifier
  final String displayName; // Human-readable name
  final bool
  isDigital; // True if this is a digital zoom, false for physical sensor

  @override
  String toString() =>
      'PhysicalCameraSensor($displayName, ${zoomFactor}x, $type${isDigital ? ' [digital]' : ''})';
}

/// Detects available physical cameras and their actual zoom factors
class CameraZoomDetector {
  static const MethodChannel _channel = MethodChannel(
    'com.openvine/camera_zoom_detector',
  );

  /// Get all available physical cameras with their actual zoom factors
  /// iOS: Uses AVCaptureDevice to get exact zoom factors from device
  /// Android: Uses CamerAwesome API with calculated standard zoom factors
  static Future<List<PhysicalCameraSensor>> getPhysicalCameras() async {
    try {
      Log.info(
        'Detecting physical cameras and zoom factors...',
        name: 'CameraZoomDetector',
        category: LogCategory.system,
      );

      if (Platform.isIOS) {
        // iOS: Use custom method channel for exact zoom factors
        final List<dynamic>? result = await _channel.invokeListMethod(
          'getPhysicalCameras',
        );

        if (result == null || result.isEmpty) {
          Log.warning(
            'No physical cameras detected from iOS native side',
            name: 'CameraZoomDetector',
            category: LogCategory.system,
          );
          return [];
        }

        final cameras = result.map((dynamic item) {
          final map = Map<String, dynamic>.from(item as Map);
          return PhysicalCameraSensor(
            type: map['type'] as String,
            zoomFactor: (map['zoomFactor'] as num).toDouble(),
            deviceId: map['deviceId'] as String,
            displayName: map['displayName'] as String,
          );
        }).toList();

        Log.info(
          'Detected ${cameras.length} physical cameras: ${cameras.map((c) => '${c.displayName} (${c.zoomFactor}x)').join(', ')}',
          name: 'CameraZoomDetector',
          category: LogCategory.system,
        );

        return cameras;
      } else if (Platform.isAndroid) {
        // Android: Use CamerAwesome getSensors API
        final sensorData = await CamerawesomePlugin.getSensors();
        final cameras = <PhysicalCameraSensor>[];

        // Add ultrawide if available
        if (sensorData.ultraWideAngle != null) {
          cameras.add(
            PhysicalCameraSensor(
              type: 'ultrawide',
              zoomFactor: 0.5,
              deviceId: sensorData.ultraWideAngle!.uid,
              displayName: sensorData.ultraWideAngle!.name,
            ),
          );
        }

        // Add wide angle if available
        if (sensorData.wideAngle != null) {
          cameras.add(
            PhysicalCameraSensor(
              type: 'wide',
              zoomFactor: 1.0,
              deviceId: sensorData.wideAngle!.uid,
              displayName: sensorData.wideAngle!.name,
            ),
          );
        }

        // Add telephoto if available (use 3.0x as standard zoom for Android telephoto)
        if (sensorData.telephoto != null) {
          cameras.add(
            PhysicalCameraSensor(
              type: 'telephoto',
              zoomFactor: 3.0,
              deviceId: sensorData.telephoto!.uid,
              displayName: sensorData.telephoto!.name,
            ),
          );
        }

        // Detect front camera using Flutter camera package
        try {
          final availableCameras = await camera_pkg.availableCameras();
          final frontCamera = availableCameras
              .where(
                (cam) =>
                    cam.lensDirection == camera_pkg.CameraLensDirection.front,
              )
              .firstOrNull;

          if (frontCamera != null) {
            cameras.add(
              PhysicalCameraSensor(
                type: 'front',
                zoomFactor: 1.0,
                deviceId: frontCamera.name,
                displayName: 'Front Camera',
              ),
            );
            Log.info(
              'Front camera detected: ${frontCamera.name}',
              name: 'CameraZoomDetector',
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to detect front camera: $e',
            name: 'CameraZoomDetector',
            category: LogCategory.system,
          );
        }

        Log.info(
          'Detected ${cameras.length} physical cameras: ${cameras.map((c) => '${c.displayName} (${c.zoomFactor}x)').join(', ')}',
          name: 'CameraZoomDetector',
          category: LogCategory.system,
        );

        return cameras;
      }

      return [];
    } catch (e) {
      Log.error(
        'Failed to detect physical cameras: $e',
        name: 'CameraZoomDetector',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Get back-facing cameras only (for zoom UI)
  static Future<List<PhysicalCameraSensor>> getBackCameras() async {
    final allCameras = await getPhysicalCameras();
    return allCameras.where((c) => c.type != 'front').toList();
  }

  /// Get sorted back cameras by zoom factor (ascending order)
  static Future<List<PhysicalCameraSensor>> getSortedBackCameras() async {
    final backCameras = await getBackCameras();
    backCameras.sort((a, b) => a.zoomFactor.compareTo(b.zoomFactor));
    return backCameras;
  }

  /// Get front-facing camera
  static Future<PhysicalCameraSensor?> getFrontCamera() async {
    final allCameras = await getPhysicalCameras();
    try {
      return allCameras.firstWhere((c) => c.type == 'front');
    } catch (e) {
      Log.warning(
        'No front camera found',
        name: 'CameraZoomDetector',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
