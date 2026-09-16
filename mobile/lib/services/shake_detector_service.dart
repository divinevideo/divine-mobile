// ABOUTME: Detects phone shaking to enable hidden features
// ABOUTME: Uses accelerometer to detect shake gestures on mobile platforms

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service that detects shake gestures on mobile devices
class ShakeDetectorService {
  ShakeDetectorService({
    this.shakeThreshold = 15.0,
    this.shakeDuration = const Duration(milliseconds: 500),
    this.shakeCount = 3,
  });

  /// Minimum acceleration to count as a shake (m/s²)
  final double shakeThreshold;

  /// Time window to count shakes
  final Duration shakeDuration;

  /// Number of shakes required to trigger
  final int shakeCount;

  StreamSubscription<AccelerometerEvent>? _subscription;
  final _shakeController = StreamController<void>.broadcast();
  final List<DateTime> _shakeTimestamps = [];

  /// Stream that emits when a shake is detected
  Stream<void> get onShake => _shakeController.stream;

  /// Start listening for shake events
  void start() {
    // Only works on mobile platforms
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }

    if (_subscription != null) {
      runDetached(
        _subscription!.cancel(),
        'cancel the previous accelerometer subscription',
        logName: 'ShakeDetectorService',
        category: LogCategory.system,
      );
    }
    _subscription = accelerometerEventStream().listen(_onAccelerometerEvent);
  }

  /// Stop listening for shake events
  void stop() {
    if (_subscription != null) {
      runDetached(
        _subscription!.cancel(),
        'cancel the accelerometer subscription',
        logName: 'ShakeDetectorService',
        category: LogCategory.system,
      );
    }
    _subscription = null;
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate total acceleration magnitude (excluding gravity ~9.8)
    final acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Subtract approximate gravity to get movement acceleration
    final movementAcceleration = (acceleration - 9.8).abs();

    if (movementAcceleration > shakeThreshold) {
      final now = DateTime.now();

      // Remove old timestamps outside the window
      _shakeTimestamps.removeWhere((t) => now.difference(t) > shakeDuration);

      // Add new timestamp
      _shakeTimestamps.add(now);

      // Check if we have enough shakes
      if (_shakeTimestamps.length >= shakeCount) {
        _shakeTimestamps.clear();
        _shakeController.add(null);
      }
    }
  }

  /// Dispose the service
  void dispose() {
    stop();
    runDetached(
      _shakeController.close(),
      'close the shake event stream',
      logName: 'ShakeDetectorService',
      category: LogCategory.system,
    );
  }
}
