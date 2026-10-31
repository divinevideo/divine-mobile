import 'dart:convert';

/// Visibility reported by an authenticated app session.
enum NotificationActivityState {
  /// Visible to the account holder; refreshes the presence lease.
  foreground,

  /// No longer visible; releases this session's presence lease.
  background,
}

/// An ordered lifecycle update, retried unchanged after transport uncertainty.
class NotificationActivityUpdate {
  /// Creates an update scoped to one account and app process.
  const NotificationActivityUpdate({
    required this.sessionId,
    required this.sequence,
    required this.visit,
    required this.state,
  });

  /// Random UUID retained across visits during the account session.
  final String sessionId;

  /// Monotonically increasing sequence within [sessionId].
  final int sequence;

  /// Foreground visit epoch; heartbeats retain the same value.
  final int visit;

  /// Current app visibility.
  final NotificationActivityState state;

  /// Exact JSON bytes to sign and send with NIP-98.
  String get body => jsonEncode({
    'sessionId': sessionId,
    'sequence': sequence,
    'visit': visit,
    'state': state.name,
  });
}
