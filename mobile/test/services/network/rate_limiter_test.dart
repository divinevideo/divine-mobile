// ABOUTME: Tests for API rate limiting functionality
// ABOUTME: Ensures protection against excessive API requests

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/network/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
    });

    tearDown(() {
      rateLimiter.dispose();
    });

    test('should allow requests within rate limit', () async {
      // Arrange
      const endpoint = '/v1/media/ready-events';

      // Act & Assert - Should allow up to 100 requests per minute
      for (var i = 0; i < 100; i++) {
        await expectLater(rateLimiter.checkLimit(endpoint), completes);
      }
    });

    test('should block requests exceeding rate limit', () async {
      // Arrange
      const endpoint = '/v1/media/ready-events';

      // Fill up the rate limit
      for (var i = 0; i < 100; i++) {
        await rateLimiter.checkLimit(endpoint);
      }

      // Act & Assert - 101st request should be blocked
      expect(
        () => rateLimiter.checkLimit(endpoint),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.message,
                'message',
                contains('Rate limit exceeded'),
              ),
        ),
      );
    });

    test('should have different limits for different endpoints', () async {
      // Arrange
      const uploadEndpoint = '/v1/media/request-upload';

      // Act - Upload endpoint has lower limit (10 per minute)
      for (var i = 0; i < 10; i++) {
        await rateLimiter.checkLimit(uploadEndpoint);
      }

      // Assert - 11th request should be blocked
      expect(
        () => rateLimiter.checkLimit(uploadEndpoint),
        throwsA(isA<ApiException>()),
      );
    });

    test('should reset rate limit after time window', () async {
      // Arrange
      const endpoint = '/v1/media/cleanup';
      final testClock = FakeClock();
      rateLimiter = RateLimiter(clock: testClock);

      // Fill up the rate limit (50 per minute for cleanup)
      for (var i = 0; i < 50; i++) {
        await rateLimiter.checkLimit(endpoint);
      }

      // Should be blocked
      expect(
        () => rateLimiter.checkLimit(endpoint),
        throwsA(isA<ApiException>()),
      );

      // Act - Advance time by 1 minute
      testClock.advance(const Duration(minutes: 1, seconds: 1));

      // Assert - Should allow requests again
      await expectLater(rateLimiter.checkLimit(endpoint), completes);
    });

    test('should track requests per endpoint independently', () async {
      // Arrange
      const endpoint1 = '/v1/media/ready-events';
      const endpoint2 = '/v1/media/cleanup';

      // Act - Fill up rate limit for endpoint1
      for (var i = 0; i < 100; i++) {
        await rateLimiter.checkLimit(endpoint1);
      }

      // Assert - endpoint2 should still allow requests
      await expectLater(rateLimiter.checkLimit(endpoint2), completes);
    });

    test('should use default rate limit for unknown endpoints', () async {
      // Arrange
      const unknownEndpoint = '/v1/unknown/endpoint';

      // Act - Default is 200 per minute
      for (var i = 0; i < 200; i++) {
        await rateLimiter.checkLimit(unknownEndpoint);
      }

      // Assert - 201st request should be blocked
      expect(
        () => rateLimiter.checkLimit(unknownEndpoint),
        throwsA(isA<ApiException>()),
      );
    });

    test('should remove old requests from tracking', () async {
      // Arrange
      const endpoint = '/v1/media/ready-events';
      final testClock = FakeClock();
      rateLimiter = RateLimiter(clock: testClock);

      // Add 50 requests
      for (var i = 0; i < 50; i++) {
        await rateLimiter.checkLimit(endpoint);
      }

      // Advance time by 30 seconds
      testClock.advance(const Duration(seconds: 30));

      // Add 50 more requests
      for (var i = 0; i < 50; i++) {
        await rateLimiter.checkLimit(endpoint);
      }

      // Should be blocked (100 total within the minute window)
      expect(
        () => rateLimiter.checkLimit(endpoint),
        throwsA(isA<ApiException>()),
      );

      // Advance time by another 31 seconds (total 61 seconds)
      testClock.advance(const Duration(seconds: 31));

      // First 50 requests are now older than 60 seconds and should be removed
      // Second 50 requests are 31 seconds old and still count
      // So we can add 50 more requests (to reach 100 total)
      for (var i = 0; i < 50; i++) {
        await expectLater(rateLimiter.checkLimit(endpoint), completes);
      }

      // 51st request should be blocked
      expect(
        () => rateLimiter.checkLimit(endpoint),
        throwsA(isA<ApiException>()),
      );
    });

    test('should provide rate limit status', () {
      // Arrange
      const endpoint = '/v1/media/ready-events';

      // Act & Assert - Check initial status
      var status = rateLimiter.getStatus(endpoint);
      expect(status.remaining, 100);
      expect(status.limit, 100);
      expect(status.resetTime, isNotNull);

      // Make some requests
      for (var i = 0; i < 30; i++) {
        rateLimiter.checkLimit(endpoint);
      }

      // Check updated status
      status = rateLimiter.getStatus(endpoint);
      expect(status.remaining, 70);
      expect(status.used, 30);
    });

    test('should emit events for rate limit violations', () async {
      // Arrange
      const endpoint = '/v1/media/request-upload';
      final violations = <RateLimitViolation>[];
      rateLimiter.violations.listen(violations.add);

      // Fill up the rate limit
      for (var i = 0; i < 10; i++) {
        await rateLimiter.checkLimit(endpoint);
      }

      // Act - Trigger violation
      try {
        await rateLimiter.checkLimit(endpoint);
      } catch (_) {
        // Expected
      }

      // Assert
      expect(violations.length, 1);
      expect(violations.first.endpoint, endpoint);
      expect(violations.first.timestamp, isNotNull);
    });

    test('should clean up resources on dispose', () {
      // Arrange
      final rateLimiter = RateLimiter();

      // Act
      rateLimiter.dispose();

      // Assert - Should not throw when checking after dispose
      expect(() => rateLimiter.checkLimit('/test'), throwsA(isA<StateError>()));
    });
  });

  group('RateLimitConfig', () {
    test('should create config with required parameters', () {
      // Arrange & Act
      const config = RateLimitConfig(100, Duration(minutes: 1));

      // Assert
      expect(config.maxRequests, 100);
      expect(config.window, const Duration(minutes: 1));
    });

    test('should calculate requests per second', () {
      // Arrange
      const config = RateLimitConfig(120, Duration(minutes: 2));

      // Act & Assert
      expect(config.requestsPerSecond, 1.0);
    });
  });
}

/// Fake clock for testing time-based functionality
class FakeClock implements Clock {
  DateTime _currentTime = DateTime.now();

  @override
  DateTime now() => _currentTime;

  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }
}
