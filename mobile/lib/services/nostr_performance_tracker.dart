// ABOUTME: Nostr relay connection and event fetching performance analytics
// ABOUTME: Tracks relay connection times, event fetch latency, and subscription performance

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking Nostr relay and event performance
class NostrPerformanceTracker {
  static final NostrPerformanceTracker _instance =
      NostrPerformanceTracker._internal();
  factory NostrPerformanceTracker() => _instance;
  NostrPerformanceTracker._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, _RelayConnectionSession> _relayConnections = {};
  final Map<String, _EventFetchSession> _eventFetches = {};
  final Map<String, _SubscriptionSession> _subscriptions = {};

  /// Start tracking relay connection
  void startRelayConnection(String relayUrl) {
    final session = _RelayConnectionSession(
      relayUrl: relayUrl,
      startTime: DateTime.now(),
    );

    _relayConnections[relayUrl] = session;

    UnifiedLogger.info(
      '🔌 Relay connection started: $relayUrl',
      name: 'NostrPerformance',
    );
  }

  /// Mark relay connection success
  void markRelayConnected(String relayUrl) {
    final session = _relayConnections[relayUrl];
    if (session == null) return;

    session.connectedTime = DateTime.now();
    final connectionTime = session.connectedTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Relay connected: $relayUrl in ${connectionTime}ms',
      name: 'NostrPerformance',
    );

    _analytics.logEvent(
      name: 'relay_connection',
      parameters: {
        'relay_url': _sanitizeRelayUrl(relayUrl),
        'connection_time_ms': connectionTime,
        'success': true,
      },
    );

    _relayConnections.remove(relayUrl);
  }

  /// Mark relay connection failure
  void markRelayConnectionFailed(String relayUrl, String errorMessage) {
    final session = _relayConnections[relayUrl];
    if (session == null) return;

    final attemptTime = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.error(
      '❌ Relay connection failed: $relayUrl after ${attemptTime}ms - $errorMessage',
      name: 'NostrPerformance',
    );

    _analytics.logEvent(
      name: 'relay_connection',
      parameters: {
        'relay_url': _sanitizeRelayUrl(relayUrl),
        'connection_time_ms': attemptTime,
        'success': false,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
      },
    );

    _relayConnections.remove(relayUrl);
  }

  /// Start tracking subscription
  void startSubscription(
    String subscriptionId,
    String subscriptionType, {
    List<String>? relays,
    Map<String, dynamic>? filters,
  }) {
    final session = _SubscriptionSession(
      subscriptionId: subscriptionId,
      subscriptionType: subscriptionType,
      startTime: DateTime.now(),
      relays: relays ?? [],
      filters: filters ?? {},
    );

    _subscriptions[subscriptionId] = session;

    UnifiedLogger.info(
      '📡 Subscription started: $subscriptionType ($subscriptionId)',
      name: 'NostrPerformance',
    );
  }

  /// Mark first event received for subscription
  void markFirstEventReceived(String subscriptionId) {
    final session = _subscriptions[subscriptionId];
    if (session == null) return;

    session.firstEventTime = DateTime.now();
    final timeToFirstEvent = session.firstEventTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '📬 First event received for ${session.subscriptionType} in ${timeToFirstEvent}ms',
      name: 'NostrPerformance',
    );

    _analytics.logEvent(
      name: 'subscription_first_event',
      parameters: {
        'subscription_type': session.subscriptionType,
        'time_to_first_ms': timeToFirstEvent,
        'relay_count': session.relays.length,
      },
    );
  }

  /// Track subscription completion
  void trackSubscriptionComplete(
    String subscriptionId, {
    required int eventsReceived,
    int? relaysResponded,
  }) {
    final session = _subscriptions[subscriptionId];
    if (session == null) return;

    final totalTime = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Subscription complete: ${session.subscriptionType} received $eventsReceived events in ${totalTime}ms',
      name: 'NostrPerformance',
    );

    _analytics.logEvent(
      name: 'subscription_complete',
      parameters: {
        'subscription_type': session.subscriptionType,
        'total_time_ms': totalTime,
        'events_received': eventsReceived,
        'relays_responded': relaysResponded ?? 0,
        'relay_count': session.relays.length,
      },
    );

    _subscriptions.remove(subscriptionId);
  }

  /// Track individual event fetch
  void startEventFetch(String eventId, String eventKind) {
    final session = _EventFetchSession(
      eventId: eventId,
      eventKind: eventKind,
      startTime: DateTime.now(),
    );

    _eventFetches[eventId] = session;
  }

  /// Mark event fetch success
  void markEventFetched(String eventId, {String? relay}) {
    final session = _eventFetches[eventId];
    if (session == null) return;

    final fetchTime = DateTime.now()
        .difference(session.startTime)
        .inMilliseconds;

    _analytics.logEvent(
      name: 'event_fetch',
      parameters: {
        'event_kind': session.eventKind,
        'fetch_time_ms': fetchTime,
        'success': true,
        if (relay != null) 'relay': _sanitizeRelayUrl(relay),
      },
    );

    _eventFetches.remove(eventId);
  }

  /// Track relay reconnection
  void trackRelayReconnection(
    String relayUrl, {
    required int attemptNumber,
    required bool success,
  }) {
    _analytics.logEvent(
      name: 'relay_reconnection',
      parameters: {
        'relay_url': _sanitizeRelayUrl(relayUrl),
        'attempt_number': attemptNumber,
        'success': success,
      },
    );

    UnifiedLogger.info(
      '🔄 Relay reconnection ${success ? "succeeded" : "failed"}: $relayUrl (attempt $attemptNumber)',
      name: 'NostrPerformance',
    );
  }

  /// Track relay latency
  void trackRelayLatency(String relayUrl, int latencyMs) {
    _analytics.logEvent(
      name: 'relay_latency',
      parameters: {
        'relay_url': _sanitizeRelayUrl(relayUrl),
        'latency_ms': latencyMs,
      },
    );
  }

  /// Track event publish performance
  void trackEventPublish({
    required String eventKind,
    required int publishTimeMs,
    required bool success,
    int? relaysSucceeded,
    int? relaysFailed,
  }) {
    _analytics.logEvent(
      name: 'event_publish',
      parameters: {
        'event_kind': eventKind,
        'publish_time_ms': publishTimeMs,
        'success': success,
        if (relaysSucceeded != null) 'relays_succeeded': relaysSucceeded,
        if (relaysFailed != null) 'relays_failed': relaysFailed,
      },
    );

    UnifiedLogger.info(
      '📤 Event published: kind $eventKind in ${publishTimeMs}ms (${success ? "success" : "failed"})',
      name: 'NostrPerformance',
    );
  }

  /// Track subscription retry
  void trackSubscriptionRetry(
    String subscriptionType, {
    required int attemptNumber,
    required String reason,
  }) {
    _analytics.logEvent(
      name: 'subscription_retry',
      parameters: {
        'subscription_type': subscriptionType,
        'attempt_number': attemptNumber,
        'reason': reason,
      },
    );
  }

  /// Sanitize relay URL for analytics (remove sensitive info)
  String _sanitizeRelayUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'invalid_url';
    return uri.host;
  }
}

/// Internal session tracking for relay connection
class _RelayConnectionSession {
  _RelayConnectionSession({required this.relayUrl, required this.startTime});

  final String relayUrl;
  final DateTime startTime;
  DateTime? connectedTime;
}

/// Internal session tracking for event fetch
class _EventFetchSession {
  _EventFetchSession({
    required this.eventId,
    required this.eventKind,
    required this.startTime,
  });

  final String eventId;
  final String eventKind;
  final DateTime startTime;
}

/// Internal session tracking for subscription
class _SubscriptionSession {
  _SubscriptionSession({
    required this.subscriptionId,
    required this.subscriptionType,
    required this.startTime,
    required this.relays,
    required this.filters,
  });

  final String subscriptionId;
  final String subscriptionType;
  final DateTime startTime;
  final List<String> relays;
  final Map<String, dynamic> filters;
  DateTime? firstEventTime;
}
