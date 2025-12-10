// ABOUTME: Tracks per-relay statistics like subscriptions, events, and connection health
// ABOUTME: Provides data for enhanced relay status display in settings

import 'package:flutter/foundation.dart';

/// Statistics for a single relay
class RelayStatistics {
  RelayStatistics({required this.relayUrl});

  final String relayUrl;

  // Connection state
  bool isConnected = false;
  DateTime? lastConnected;
  DateTime? lastDisconnected;
  String? lastDisconnectReason;
  int connectionCount = 0;

  // Subscription tracking
  int activeSubscriptions = 0;
  int totalSubscriptions = 0;
  final Set<String> _activeSubscriptionIds = {};

  // Event tracking
  int eventsReceived = 0;
  int eventsSent = 0;

  // Request tracking
  int requestsThisSession = 0;
  int failedRequests = 0;
  String? lastError;
  DateTime? lastErrorTime;

  /// Duration of current session (if connected)
  Duration? get sessionDuration {
    if (!isConnected || lastConnected == null) return null;
    return DateTime.now().difference(lastConnected!);
  }

  /// Add an active subscription
  void addSubscription(String subscriptionId) {
    if (_activeSubscriptionIds.add(subscriptionId)) {
      activeSubscriptions = _activeSubscriptionIds.length;
      totalSubscriptions++;
    }
  }

  /// Remove an active subscription
  void removeSubscription(String subscriptionId) {
    if (_activeSubscriptionIds.remove(subscriptionId)) {
      activeSubscriptions = _activeSubscriptionIds.length;
    }
  }

  /// Get a summary string for display in the list
  String get statusSummary {
    if (!isConnected) {
      if (lastDisconnected != null) {
        final ago = DateTime.now().difference(lastDisconnected!);
        return 'Disconnected ${_formatDuration(ago)} ago';
      }
      return 'Not connected';
    }

    final parts = <String>[];
    if (activeSubscriptions > 0) {
      parts.add('$activeSubscriptions subs');
    }
    if (eventsReceived > 0) {
      parts.add('${_formatCount(eventsReceived)} events');
    }
    if (parts.isEmpty) {
      return 'Connected';
    }
    return parts.join(' | ');
  }

  /// Format a count for compact display
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// Format a duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  String toString() {
    return 'RelayStatistics(url: $relayUrl, connected: $isConnected, '
        'subs: $activeSubscriptions, events: $eventsReceived, '
        'requests: $requestsThisSession, failures: $failedRequests)';
  }
}

/// Service for tracking statistics for all relays
class RelayStatisticsService extends ChangeNotifier {
  final Map<String, RelayStatistics> _statistics = {};

  /// Get statistics for a specific relay
  RelayStatistics? getStatistics(String relayUrl) => _statistics[relayUrl];

  /// Get statistics for all relays
  Map<String, RelayStatistics> getAllStatistics() =>
      Map.unmodifiable(_statistics);

  /// Get or create statistics for a relay
  RelayStatistics _getOrCreate(String relayUrl) {
    return _statistics.putIfAbsent(
      relayUrl,
      () => RelayStatistics(relayUrl: relayUrl),
    );
  }

  /// Record that a relay connected
  void recordConnection(String relayUrl) {
    final stats = _getOrCreate(relayUrl);
    stats.isConnected = true;
    stats.lastConnected = DateTime.now();
    stats.connectionCount++;
    notifyListeners();
  }

  /// Record that a relay disconnected
  void recordDisconnection(String relayUrl, {String? reason}) {
    final stats = _getOrCreate(relayUrl);
    stats.isConnected = false;
    stats.lastDisconnected = DateTime.now();
    stats.lastDisconnectReason = reason;
    notifyListeners();
  }

  /// Record that a subscription was started
  void recordSubscriptionStarted(String relayUrl, String subscriptionId) {
    final stats = _getOrCreate(relayUrl);
    stats.addSubscription(subscriptionId);
    notifyListeners();
  }

  /// Record that a subscription was closed
  void recordSubscriptionClosed(String relayUrl, String subscriptionId) {
    final stats = _getOrCreate(relayUrl);
    stats.removeSubscription(subscriptionId);
    notifyListeners();
  }

  /// Record that an event was received from a relay
  void recordEventReceived(String relayUrl) {
    final stats = _getOrCreate(relayUrl);
    stats.eventsReceived++;
    notifyListeners();
  }

  /// Record that an event was sent to a relay
  void recordEventSent(String relayUrl) {
    final stats = _getOrCreate(relayUrl);
    stats.eventsSent++;
    notifyListeners();
  }

  /// Record that a request was made to a relay
  void recordRequest(String relayUrl) {
    final stats = _getOrCreate(relayUrl);
    stats.requestsThisSession++;
    notifyListeners();
  }

  /// Record that a request failed
  void recordRequestFailure(String relayUrl, String error) {
    final stats = _getOrCreate(relayUrl);
    stats.failedRequests++;
    stats.lastError = error;
    stats.lastErrorTime = DateTime.now();
    notifyListeners();
  }

  /// Reset statistics for a specific relay
  void resetStatistics(String relayUrl) {
    _statistics.remove(relayUrl);
    notifyListeners();
  }

  /// Reset all statistics
  void resetAllStatistics() {
    _statistics.clear();
    notifyListeners();
  }
}
