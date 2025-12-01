// ABOUTME: API rate limiter to prevent excessive requests and protect against DoS
// ABOUTME: Implements configurable per-endpoint rate limits with time windows

import 'dart:async';

import 'package:openvine/services/api_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Configuration for rate limiting
class RateLimitConfig {
  const RateLimitConfig(this.maxRequests, this.window);
  final int maxRequests;
  final Duration window;

  /// Calculate requests per second for monitoring
  double get requestsPerSecond => maxRequests / window.inSeconds;
}

/// Status of rate limit for an endpoint
class RateLimitStatus {
  RateLimitStatus({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetTime,
  });
  final int limit;
  final int used;
  final int remaining;
  final DateTime resetTime;
}

/// Rate limit violation event
class RateLimitViolation {
  RateLimitViolation({
    required this.endpoint,
    required this.timestamp,
    this.clientId,
  });
  final String endpoint;
  final DateTime timestamp;
  final String? clientId;
}

/// Clock abstraction for testability
abstract class Clock {
  DateTime now();
}

/// Default clock implementation
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Rate limiter for API endpoints
class RateLimiter {
  RateLimiter({Clock? clock}) : _clock = clock ?? const SystemClock();
  final Map<String, List<DateTime>> _requests = {};
  final Map<String, RateLimitConfig> _configs = {
    '/v1/media/ready-events': const RateLimitConfig(100, Duration(minutes: 1)),
    '/v1/media/request-upload': const RateLimitConfig(10, Duration(minutes: 1)),
    '/v1/media/cleanup': const RateLimitConfig(50, Duration(minutes: 1)),
  };

  final Clock _clock;
  final _violationsController =
      StreamController<RateLimitViolation>.broadcast();
  bool _disposed = false;

  /// Stream of rate limit violations for monitoring
  Stream<RateLimitViolation> get violations => _violationsController.stream;

  /// Check if request is allowed under rate limit
  Future<void> checkLimit(String endpoint) async {
    if (_disposed) {
      throw StateError('RateLimiter has been disposed');
    }

    final config =
        _configs[endpoint] ??
        const RateLimitConfig(200, Duration(minutes: 1)); // Default

    final now = _clock.now();
    _requests[endpoint] ??= [];

    // Remove old requests outside window
    _requests[endpoint]!.removeWhere(
      (time) => now.difference(time) >= config.window,
    );

    if (_requests[endpoint]!.length >= config.maxRequests) {
      // Rate limit exceeded
      final violation = RateLimitViolation(endpoint: endpoint, timestamp: now);
      _violationsController.add(violation);

      Log.warning(
        'Rate limit exceeded for $endpoint: ${_requests[endpoint]!.length}/${config.maxRequests} in ${config.window.inMinutes} minutes',
        name: 'RateLimiter',
        category: LogCategory.api,
      );

      throw ApiException(
        'Rate limit exceeded. Try again in ${config.window.inMinutes} minutes',
        statusCode: 429,
      );
    }

    _requests[endpoint]!.add(now);

    // Log when approaching limit
    final used = _requests[endpoint]!.length;
    final remaining = config.maxRequests - used;
    if (remaining <= config.maxRequests * 0.1) {
      Log.debug(
        'Approaching rate limit for $endpoint: $remaining requests remaining',
        name: 'RateLimiter',
        category: LogCategory.api,
      );
    }
  }

  /// Get current rate limit status for an endpoint
  RateLimitStatus getStatus(String endpoint) {
    final config =
        _configs[endpoint] ?? const RateLimitConfig(200, Duration(minutes: 1));

    final now = _clock.now();
    _requests[endpoint] ??= [];

    // Clean old requests
    _requests[endpoint]!.removeWhere(
      (time) => now.difference(time) > config.window,
    );

    final used = _requests[endpoint]!.length;

    // Calculate reset time based on oldest request
    DateTime resetTime;
    if (_requests[endpoint]!.isEmpty) {
      resetTime = now.add(config.window);
    } else {
      final oldestRequest = _requests[endpoint]!.first;
      resetTime = oldestRequest.add(config.window);
    }

    return RateLimitStatus(
      limit: config.maxRequests,
      used: used,
      remaining: config.maxRequests - used,
      resetTime: resetTime,
    );
  }

  /// Configure rate limit for an endpoint
  void configureEndpoint(String endpoint, RateLimitConfig config) {
    _configs[endpoint] = config;
    Log.info(
      'Configured rate limit for $endpoint: ${config.maxRequests} per ${config.window.inMinutes} minutes',
      name: 'RateLimiter',
      category: LogCategory.api,
    );
  }

  /// Clear rate limit history for an endpoint
  void clearEndpoint(String endpoint) {
    _requests[endpoint]?.clear();
  }

  /// Clear all rate limit history
  void clearAll() {
    _requests.clear();
  }

  /// Get endpoints that are currently rate limited
  List<String> getRateLimitedEndpoints() {
    final limited = <String>[];
    final now = _clock.now();

    for (final entry in _requests.entries) {
      final endpoint = entry.key;
      final requests = entry.value;
      final config =
          _configs[endpoint] ??
          const RateLimitConfig(200, Duration(minutes: 1));

      // Clean old requests
      requests.removeWhere((time) => now.difference(time) > config.window);

      if (requests.length >= config.maxRequests) {
        limited.add(endpoint);
      }
    }

    return limited;
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _violationsController.close();
    _requests.clear();
  }

  /// Get monitoring metrics
  Map<String, dynamic> getMetrics() {
    final metrics = <String, dynamic>{};
    final now = _clock.now();

    for (final entry in _configs.entries) {
      final endpoint = entry.key;
      final config = entry.value;
      final requests = _requests[endpoint] ?? [];

      // Clean old requests
      requests.removeWhere((time) => now.difference(time) > config.window);

      metrics[endpoint] = {
        'limit': config.maxRequests,
        'window': config.window.inSeconds,
        'used': requests.length,
        'remaining': config.maxRequests - requests.length,
        'utilization': requests.length / config.maxRequests,
      };
    }

    return metrics;
  }
}

/// Extension to add rate limiting to HTTP clients
extension RateLimitedClient on ApiService {
  /// Wrap API calls with rate limiting
  Future<T> withRateLimit<T>(
    String endpoint,
    Future<T> Function() operation,
    RateLimiter rateLimiter,
  ) async {
    await rateLimiter.checkLimit(endpoint);
    return operation();
  }
}
