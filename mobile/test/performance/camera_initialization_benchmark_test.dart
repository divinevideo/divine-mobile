// ABOUTME: Performance benchmarks for camera initialization across platforms
// ABOUTME: Measures initialization time, memory usage, and resource allocation

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('Camera Initialization Performance Benchmarks', () {
    test(
      'Camera initialization should complete within acceptable time limits',
      () async {
        final controller = VineRecordingController();
        final stopwatch = Stopwatch()..start();

        try {
          await controller.initialize();
          stopwatch.stop();

          // Platform-specific expectations
          final maxInitTime = _getMaxInitTime();

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(maxInitTime),
            reason:
                'Camera initialization took ${stopwatch.elapsedMilliseconds}ms, '
                'expected less than ${maxInitTime}ms',
          );

          // Log performance metrics
          print('📊 Camera initialization metrics:');
          print('   Platform: ${_getPlatformName()}');
          print('   Time: ${stopwatch.elapsedMilliseconds}ms');
          print('   Memory before: ${_getMemoryUsage()}MB');
        } finally {
          controller.dispose();
        }
      },
    );

    test('Rapid camera switching performance', () async {
      final controller = VineRecordingController();

      try {
        await controller.initialize();

        if (!controller.canSwitchCamera) {
          return; // Skip if only one camera
        }

        final switchTimes = <int>[];

        // Perform 10 rapid camera switches
        for (int i = 0; i < 10; i++) {
          final stopwatch = Stopwatch()..start();
          await controller.switchCamera();
          stopwatch.stop();
          switchTimes.add(stopwatch.elapsedMilliseconds);
        }

        // Calculate statistics
        final avgTime =
            switchTimes.reduce((a, b) => a + b) / switchTimes.length;
        final maxTime = switchTimes.reduce((a, b) => a > b ? a : b);

        print('📊 Camera switching performance:');
        print('   Average: ${avgTime.toStringAsFixed(2)}ms');
        print('   Maximum: ${maxTime}ms');
        print('   All times: $switchTimes');

        // Performance assertions
        expect(
          avgTime,
          lessThan(500),
          reason: 'Average camera switch time should be under 500ms',
        );
        expect(
          maxTime,
          lessThan(1000),
          reason: 'Maximum camera switch time should be under 1s',
        );
      } finally {
        controller.dispose();
      }
    });

    test('Memory leak detection during long recording session', () async {
      final controller = VineRecordingController();

      try {
        await controller.initialize();

        final initialMemory = _getMemoryUsage();

        // Simulate 50 recording segments
        for (int i = 0; i < 50; i++) {
          await controller.startRecording();
          await Future.delayed(Duration(milliseconds: 100));
          await controller.stopRecording();
        }

        final finalMemory = _getMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        print('📊 Memory usage after 50 segments:');
        print('   Initial: ${initialMemory}MB');
        print('   Final: ${finalMemory}MB');
        print('   Increase: ${memoryIncrease}MB');

        // Memory should not increase dramatically
        expect(
          memoryIncrease,
          lessThan(50),
          reason:
              'Memory usage increased by ${memoryIncrease}MB, '
              'possible memory leak detected',
        );
      } finally {
        controller.dispose();
      }
    });
  });
}

int _getMaxInitTime() {
  if (kIsWeb) return 3000;
  if (Platform.isMacOS) return 1000;
  if (Platform.isIOS || Platform.isAndroid) return 2000;
  return 5000;
}

String _getPlatformName() {
  if (kIsWeb) return 'Web';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  return 'Unknown';
}

double _getMemoryUsage() {
  // Simplified memory calculation - in real implementation,
  // use proper memory profiling tools
  return ProcessInfo.currentRss / 1024 / 1024; // Convert to MB
}
