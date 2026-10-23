// ABOUTME: Measures notification opens through the existing consented event sink.
// ABOUTME: Deduplicates callbacks locally without exporting delivery identifiers.

import 'package:analytics/src/analytics_event_sink.dart';
import 'package:unified_logger/unified_logger.dart';

/// The callback that observed an actual tap, rather than message receipt.
enum NotificationOpenSource {
  osColdStart('os_cold_start'),
  localColdStart('local_cold_start'),
  osBackground('os_background'),
  localTap('local_tap');

  const NotificationOpenSource(this.wireValue);

  final String wireValue;
}

/// Best-effort measurement; callers must not await it before navigation.
class NotificationAnalyticsTracker {
  NotificationAnalyticsTracker({
    required AnalyticsEventSink sink,
    required Future<bool> Function() collectionAllowed,
    required Object Function() privacyBoundary,
  }) : _sink = sink,
       _collectionAllowed = collectionAllowed,
       _privacyBoundary = privacyBoundary;

  static const _types = {
    'like',
    'comment',
    'follow',
    'mention',
    'repost',
    'campaign',
    'direct_message',
    'new_post',
    'list_add',
  };
  static const _maxRememberedOpens = 256;

  final AnalyticsEventSink _sink;
  final Future<bool> Function() _collectionAllowed;
  final Object Function() _privacyBoundary;
  final _seen = <String, Object>{};
  Object? _boundary;

  /// [deduplicationKey] stays in memory, scoped to the current privacy/session
  /// boundary. Missing keys never collapse unrelated legacy notifications.
  Future<void> opened({
    required String? notificationType,
    required NotificationOpenSource source,
    String? deduplicationKey,
  }) async {
    final reservation = Object();
    final key = deduplicationKey?.isNotEmpty ?? false ? deduplicationKey : null;
    var recorded = false;
    try {
      final boundary = _privacyBoundary();
      if (_boundary != boundary) {
        _seen.clear();
        _boundary = boundary;
      }
      if (key != null) {
        if (_seen.containsKey(key)) return;
        if (_seen.length >= _maxRememberedOpens) {
          _seen.remove(_seen.keys.first);
        }
        // Reserve before awaiting consent so simultaneous callbacks coalesce.
        _seen[key] = reservation;
      }
      if (!await _collectionAllowed() || _privacyBoundary() != boundary) {
        return;
      }
      final normalizedType = switch (notificationType) {
        'directMessage' => 'direct_message',
        'newPost' => 'new_post',
        _ => notificationType,
      };
      await _sink.logEvent(
        name: 'push_notification_opened',
        parameters: {
          'notification_type': _types.contains(normalizedType)
              ? normalizedType!
              : 'unknown',
          'open_source': source.wireValue,
        },
      );
      recorded = true;
    } on Object catch (error) {
      // Analytics failure must never affect the notification's destination.
      Log.warning(
        'Notification open analytics failed: $error',
        name: 'NotificationAnalyticsTracker',
        category: LogCategory.system,
      );
    } finally {
      if (!recorded && key != null && identical(_seen[key], reservation)) {
        _seen.remove(key);
      }
    }
  }
}
