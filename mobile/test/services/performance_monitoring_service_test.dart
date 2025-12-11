// ABOUTME: Tests for Firebase Performance Monitoring service
// ABOUTME: Verifies trace creation, metrics, and attributes

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

void main() {
  group('PerformanceMonitoringService', () {
    late PerformanceMonitoringService service;

    setUp(() {
      service = PerformanceMonitoringService.instance;
    });

    test('should be a singleton', () {
      final instance1 = PerformanceMonitoringService.instance;
      final instance2 = PerformanceMonitoringService.instance;
      expect(instance1, same(instance2));
    });

    test('should initialize without error', () async {
      // Service initialization should not throw
      await service.initialize();
      // If we get here, initialization succeeded
      expect(true, true);
    });

    test('should handle trace start and stop without error', () async {
      await service.initialize();

      // These should not throw even if Firebase isn't configured
      await service.startTrace('test_trace');
      await service.stopTrace('test_trace');

      expect(true, true);
    });

    test('should handle metrics without error', () async {
      await service.initialize();
      await service.startTrace('test_trace');

      // These should not throw even if Firebase isn't configured
      service.setMetric('test_trace', 'test_metric', 100);
      service.incrementMetric('test_trace', 'counter', 1);

      await service.stopTrace('test_trace');
      expect(true, true);
    });

    test('should handle attributes without error', () async {
      await service.initialize();
      await service.startTrace('test_trace');

      // This should not throw even if Firebase isn't configured
      service.putAttribute('test_trace', 'test_attr', 'test_value');

      await service.stopTrace('test_trace');
      expect(true, true);
    });

    test('trace convenience method should work', () async {
      await service.initialize();

      // Test the trace wrapper
      final result = await service.trace('test_operation', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'success';
      });

      expect(result, 'success');
    });

    test('trace convenience method should handle errors', () async {
      await service.initialize();

      // Test that errors are propagated
      expect(
        () => service.trace('error_operation', () async {
          throw Exception('Test error');
        }),
        throwsException,
      );
    });
  });
}
