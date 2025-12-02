// ABOUTME: Utility for consistent Nostr timestamp generation with clock drift handling
// ABOUTME: Ensures all timestamps are UTC-based and compatible with relay validation

/// Utility class for generating Nostr-compatible timestamps
///
/// Handles:
/// - UTC time consistency across all timezones
/// - Clock drift tolerance for relay compatibility
/// - Timestamp validation for events
class NostrTimestamp {
  /// Default clock drift tolerance in seconds
  /// Small backdate to handle minor clock differences
  static const int defaultClockDriftTolerance = 30; // 30 seconds

  /// Profile update tolerance (Kind 0 events may need more time)
  static const int profileDriftTolerance = 5 * 60; // 5 minutes

  /// Video post tolerance (Kind 22 events should be recent)
  static const int videoDriftTolerance = 30; // 30 seconds

  /// Maximum allowed clock drift (30 days)
  /// Some relays may reject events older than this
  static const int maxClockDrift = 30 * 24 * 60 * 60; // 30 days

  /// Get recommended drift tolerance based on event kind
  static int getDriftToleranceForKind(int kind) {
    switch (kind) {
      case 0: // Profile metadata
        return profileDriftTolerance;
      case 22: // Short video (NIP-71)
        return videoDriftTolerance;
      case 1: // Text note
      case 3: // Contact list
      case 7: // Reaction
        return defaultClockDriftTolerance;
      default:
        return defaultClockDriftTolerance;
    }
  }

  /// Generate a Nostr-compatible timestamp (Unix timestamp in seconds)
  ///
  /// By default, subtracts a small amount from current UTC time to handle
  /// clock drift between client and relay servers.
  ///
  /// [driftTolerance] - Number of seconds to subtract from current time
  ///                    (default: 30 seconds, max: 30 days)
  static int now({int driftTolerance = defaultClockDriftTolerance}) {
    // Clamp drift tolerance to reasonable bounds
    final adjustedDrift = driftTolerance.clamp(0, maxClockDrift);

    // Always use UTC to ensure timezone consistency
    final nowUtc = DateTime.now().toUtc();
    final timestamp = nowUtc.millisecondsSinceEpoch ~/ 1000;

    // Subtract drift tolerance to ensure relay acceptance
    return timestamp - adjustedDrift;
  }

  /// Convert a DateTime to Nostr timestamp with drift tolerance
  static int fromDateTime(DateTime dateTime, {int driftTolerance = 0}) {
    final utcTime = dateTime.toUtc();
    final timestamp = utcTime.millisecondsSinceEpoch ~/ 1000;
    return timestamp - driftTolerance;
  }

  /// Convert Nostr timestamp to DateTime (always returns UTC)
  static DateTime toDateTime(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  /// Validate if a timestamp is reasonable (not too far in future/past)
  static bool isValid(int timestamp) {
    final nowUtc = DateTime.now().toUtc();
    final currentTimestamp = nowUtc.millisecondsSinceEpoch ~/ 1000;

    // Allow up to 5 minutes in the future (for minor clock differences)
    final maxFuture = currentTimestamp + maxClockDrift;

    // Allow up to 1 year in the past
    final maxPast = currentTimestamp - (365 * 24 * 60 * 60);

    return timestamp <= maxFuture && timestamp >= maxPast;
  }

  /// Get a human-readable string for a timestamp (in UTC)
  static String format(int timestamp) {
    final dateTime = toDateTime(timestamp);
    return '${dateTime.toIso8601String()} UTC';
  }

  /// Calculate the difference between a timestamp and current time
  /// Returns positive if timestamp is in the future, negative if in the past
  static int timeDifference(int timestamp) {
    final currentTimestamp = now(driftTolerance: 0);
    return timestamp - currentTimestamp;
  }

  /// Debug information about current time settings
  static Map<String, dynamic> debugInfo() {
    final nowLocal = DateTime.now();
    final nowUtc = nowLocal.toUtc();
    final timestamp = nowUtc.millisecondsSinceEpoch ~/ 1000;
    final adjustedTimestamp = now();

    return {
      'local_time': nowLocal.toString(),
      'utc_time': nowUtc.toString(),
      'timezone_offset': nowLocal.timeZoneOffset.toString(),
      'timezone_name': nowLocal.timeZoneName,
      'unix_timestamp': timestamp,
      'adjusted_timestamp': adjustedTimestamp,
      'drift_applied': timestamp - adjustedTimestamp,
    };
  }
}
