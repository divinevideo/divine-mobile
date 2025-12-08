import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template gateway_response}
/// Response from REST Gateway API
/// {@endtemplate}
class GatewayResponse {
  /// {@macro gateway_response}
  const GatewayResponse({
    required this.events,
    required this.eose,
    required this.complete,
    required this.cached,
    this.cacheAgeSeconds,
  });

  /// Create a GatewayResponse from a JSON object
  factory GatewayResponse.fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List<dynamic>? ?? [];
    final events = eventsList
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();

    return GatewayResponse(
      events: events,
      eose: json['eose'] as bool? ?? false,
      complete: json['complete'] as bool? ?? false,
      cached: json['cached'] as bool? ?? false,
      cacheAgeSeconds: json['cache_age_seconds'] as int?,
    );
  }

  /// List of events returned by the gateway
  final List<Event> events;
  /// Whether End of Stored Events was reached
  final bool eose;
  /// Whether the query is complete (all matching events returned)
  final bool complete;
  /// Whether the response came from cache
  final bool cached;
  /// Age of cached data in seconds (null if not cached)
  final int? cacheAgeSeconds;

  /// Whether the response contains any events
  bool get hasEvents => events.isNotEmpty;

  /// Number of events in the response
  int get eventCount => events.length;
}
