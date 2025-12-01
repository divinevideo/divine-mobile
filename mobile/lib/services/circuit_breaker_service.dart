// ABOUTME: Enhanced circuit breaker service for video loading failure management
// ABOUTME: Implements sophisticated patterns to prevent repeated failures and improve UX

import 'dart:async';
import 'dart:collection';
import 'package:openvine/utils/unified_logger.dart';

/// Circuit breaker states
enum CircuitBreakerState {
  /// Normal operation - allowing requests
  closed,

  /// Failure threshold reached - blocking requests
  open,

  /// Testing if service has recovered - limited requests
  halfOpen,
}

/// Failure tracking entry
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class FailureEntry {
  const FailureEntry({
    required this.url,
    required this.timestamp,
    required this.errorMessage,
  });
  final String url;
  final DateTime timestamp;
  final String errorMessage;
}

/// Enhanced circuit breaker for video loading failures
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoCircuitBreaker {
  VideoCircuitBreaker({
    int failureThreshold = 5,
    Duration openTimeout = const Duration(minutes: 2),
    Duration halfOpenTimeout = const Duration(seconds: 30),
    int maxFailureHistory = 100,
  }) : _failureThreshold = failureThreshold,
       _openTimeout = openTimeout,
       _halfOpenTimeout = halfOpenTimeout,
       _maxFailureHistory = maxFailureHistory;
  final int _failureThreshold;
  final Duration _openTimeout;
  final Duration _halfOpenTimeout;
  final int _maxFailureHistory;

  // State tracking
  CircuitBreakerState _state = CircuitBreakerState.closed;
  final Queue<FailureEntry> _failureHistory = Queue();
  final Map<String, int> _urlFailureCounts = {};
  final Map<String, DateTime> _urlLastFailure = {};
  final Set<String> _permanentlyFailedUrls = {};
  Timer? _recoveryTimer;
  int _halfOpenSuccessCount = 0;
  final int _halfOpenRequiredSuccesses = 3;

  /// Current circuit breaker state
  CircuitBreakerState get state => _state;

  /// Whether requests should be allowed through
  bool get allowRequests => _state != CircuitBreakerState.open;

  /// Get current failure rate (percentage of recent failures)
  double get failureRate {
    final recentFailures = _getRecentFailures(const Duration(minutes: 5));
    if (recentFailures.isEmpty) return 0;

    // Calculate failure rate based on recent activity
    const maxRecentFailuresForRate =
        20; // Consider last 20 requests for rate calculation
    final failureCount = recentFailures.length;
    final rate = (failureCount / maxRecentFailuresForRate * 100).clamp(
      0.0,
      100.0,
    );

    return rate;
  }

  /// Check if a specific URL should be blocked
  bool shouldAllowUrl(String url) {
    // Permanently failed URLs are always blocked
    if (_permanentlyFailedUrls.contains(url)) {
      return false;
    }

    // Circuit breaker is open - block all except in half-open state
    if (_state == CircuitBreakerState.open) {
      return false;
    }

    // Check URL-specific failure patterns
    final urlFailures = _urlFailureCounts[url] ?? 0;
    if (urlFailures >= _failureThreshold) {
      final lastFailure = _urlLastFailure[url];
      if (lastFailure != null) {
        final timeSinceFailure = DateTime.now().difference(lastFailure);
        // Allow retry after exponential backoff
        final backoffTime = Duration(minutes: urlFailures * 2);
        if (timeSinceFailure < backoffTime) {
          return false;
        }
      }
    }

    return true;
  }

  /// Record a successful request
  void recordSuccess(String url) {
    // Reset URL-specific counters
    _urlFailureCounts.remove(url);
    _urlLastFailure.remove(url);

    if (_state == CircuitBreakerState.halfOpen) {
      _halfOpenSuccessCount++;

      if (_halfOpenSuccessCount >= _halfOpenRequiredSuccesses) {
        _transitionToClosed();
      }
    }

    Log.info(
      'CircuitBreaker: Success recorded for $url',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  /// Record a failed request
  void recordFailure(String url, String errorMessage) {
    final now = DateTime.now();

    // Add to failure history
    _failureHistory.add(
      FailureEntry(url: url, timestamp: now, errorMessage: errorMessage),
    );

    // Maintain history size
    while (_failureHistory.length > _maxFailureHistory) {
      _failureHistory.removeFirst();
    }

    // Update URL-specific counters
    _urlFailureCounts[url] = (_urlFailureCounts[url] ?? 0) + 1;
    _urlLastFailure[url] = now;

    // Check if URL should be permanently failed
    if (_urlFailureCounts[url]! >= _failureThreshold * 2) {
      _permanentlyFailedUrls.add(url);
      Log.error(
        'CircuitBreaker: URL permanently failed: $url',
        name: 'CircuitBreakerService',
        category: LogCategory.system,
      );
    }

    // Check overall failure rate
    _checkFailureThreshold();

    Log.debug(
      'CircuitBreaker: Failure recorded for $url (count: ${_urlFailureCounts[url]})',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  /// Get failure statistics
  Map<String, dynamic> getStats() {
    final recentFailures = _getRecentFailures(const Duration(minutes: 10));

    return {
      'state': _state.name,
      'totalFailures': _failureHistory.length,
      'recentFailures': recentFailures.length,
      'failedUrls': _urlFailureCounts.length,
      'permanentlyFailedUrls': _permanentlyFailedUrls.length,
      'allowRequests': allowRequests,
      'halfOpenSuccessCount': _halfOpenSuccessCount,
      'failureThreshold': _failureThreshold,
    };
  }

  /// Get detailed failure information for debugging
  Map<String, dynamic> getDetailedStats() {
    final stats = getStats();
    final recentFailures = _getRecentFailures(const Duration(hours: 1));

    return {
      ...stats,
      'urlFailureCounts': Map.from(_urlFailureCounts),
      'permanentlyFailedUrls': List.from(_permanentlyFailedUrls),
      'recentFailureUrls': recentFailures.map((f) => f.url).toSet().toList(),
      'mostFailedUrls': _getMostFailedUrls(5),
    };
  }

  /// Reset circuit breaker state (for testing or manual recovery)
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureHistory.clear();
    _urlFailureCounts.clear();
    _urlLastFailure.clear();
    _halfOpenSuccessCount = 0;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    Log.debug(
      'CircuitBreaker: Reset to closed state',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  /// Clear permanently failed URLs (allow retry)
  void clearPermanentFailures() {
    final count = _permanentlyFailedUrls.length;
    _permanentlyFailedUrls.clear();
    Log.error(
      'CircuitBreaker: Cleared $count permanently failed URLs',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  void dispose() {
    _recoveryTimer?.cancel();
  }

  // Private methods

  void _checkFailureThreshold() {
    if (_state == CircuitBreakerState.open) return;

    final recentFailures = _getRecentFailures(const Duration(minutes: 5));

    if (recentFailures.length >= _failureThreshold) {
      _transitionToOpen();
    }
  }

  void _transitionToOpen() {
    _state = CircuitBreakerState.open;
    _halfOpenSuccessCount = 0;

    // Set recovery timer
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(_openTimeout, _transitionToHalfOpen);

    Log.debug(
      'CircuitBreaker: Transitioned to OPEN state',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  void _transitionToHalfOpen() {
    _state = CircuitBreakerState.halfOpen;
    _halfOpenSuccessCount = 0;

    // Set timeout for half-open state
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(_halfOpenTimeout, () {
      if (_state == CircuitBreakerState.halfOpen) {
        // No successful requests - go back to open
        _transitionToOpen();
      }
    });

    Log.debug(
      'CircuitBreaker: Transitioned to HALF-OPEN state',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  void _transitionToClosed() {
    _state = CircuitBreakerState.closed;
    _halfOpenSuccessCount = 0;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    Log.debug(
      'CircuitBreaker: Transitioned to CLOSED state',
      name: 'CircuitBreakerService',
      category: LogCategory.system,
    );
  }

  List<FailureEntry> _getRecentFailures(Duration timeWindow) {
    final cutoff = DateTime.now().subtract(timeWindow);
    return _failureHistory.where((f) => f.timestamp.isAfter(cutoff)).toList();
  }

  List<MapEntry<String, int>> _getMostFailedUrls(int limit) {
    final entries = _urlFailureCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
}

/// Mixin for integrating circuit breaker into video services
mixin CircuitBreakerMixin {
  VideoCircuitBreaker? _circuitBreaker;

  /// Initialize circuit breaker
  void initializeCircuitBreaker({
    int failureThreshold = 5,
    Duration openTimeout = const Duration(minutes: 2),
    Duration halfOpenTimeout = const Duration(seconds: 30),
  }) {
    _circuitBreaker = VideoCircuitBreaker(
      failureThreshold: failureThreshold,
      openTimeout: openTimeout,
      halfOpenTimeout: halfOpenTimeout,
    );
  }

  /// Check if URL should be allowed
  bool shouldAllowVideoUrl(String url) =>
      _circuitBreaker?.shouldAllowUrl(url) ?? true;

  /// Record successful video load
  void recordVideoSuccess(String url) {
    _circuitBreaker?.recordSuccess(url);
  }

  /// Record failed video load
  void recordVideoFailure(String url, String error) {
    _circuitBreaker?.recordFailure(url, error);
  }

  /// Get circuit breaker statistics
  Map<String, dynamic>? getCircuitBreakerStats() => _circuitBreaker?.getStats();

  /// Dispose circuit breaker
  void disposeCircuitBreaker() {
    _circuitBreaker?.dispose();
    _circuitBreaker = null;
  }
}
