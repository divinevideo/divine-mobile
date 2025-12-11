// ABOUTME: Model for tracking broadcast results across multiple relays
// ABOUTME: Provides per-relay success/failure status and convenience getters

import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template nostr_broadcast_result}
/// Result of broadcasting an event to multiple relays.
///
/// Tracks success/failure status for each relay and provides
/// convenience getters for analyzing broadcast outcomes.
/// {@endtemplate}
class NostrBroadcastResult {
  /// {@macro nostr_broadcast_result}
  const NostrBroadcastResult({
    required this.event,
    required this.successCount,
    required this.totalRelays,
    required this.results,
    required this.errors,
  });

  /// The event that was broadcast, or null if event creation failed
  final Event? event;

  /// Number of relays that successfully received the event
  final int successCount;

  /// Total number of relays the event was broadcast to
  final int totalRelays;

  /// Per-relay results: relay URL -> success status
  final Map<String, bool> results;

  /// Per-relay errors: relay URL -> error message (only for failed relays)
  final Map<String, String> errors;

  /// Whether the broadcast was successful (at least one relay accepted)
  bool get success => successCount > 0;

  /// Alias for [success] for API compatibility
  bool get isSuccessful => successCount > 0;

  /// Whether all relays successfully received the event
  bool get isCompleteSuccess => successCount == totalRelays;

  /// Success rate as a fraction (0.0 to 1.0)
  double get successRate => totalRelays > 0 ? successCount / totalRelays : 0.0;

  /// List of relay URLs that failed to receive the event
  List<String> get failedRelays =>
      results.entries.where((e) => !e.value).map((e) => e.key).toList();

  /// List of relay URLs that successfully received the event
  List<String> get successfulRelays =>
      results.entries.where((e) => e.value).map((e) => e.key).toList();
}
