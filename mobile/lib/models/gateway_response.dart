// ABOUTME: Response model for REST gateway API responses
// ABOUTME: Parses events and cache metadata from gateway.divine.video

/// Response from the Divine REST Gateway API
class GatewayResponse {
  /// List of raw event JSON objects from the gateway
  final List<Map<String, dynamic>> events;

  /// Whether End of Stored Events was reached
  final bool eose;

  /// Whether the query is complete (all matching events returned)
  final bool complete;

  /// Whether the response came from cache
  final bool cached;

  /// Age of cached data in seconds (null if not cached)
  final int? cacheAgeSeconds;

  GatewayResponse({
    required this.events,
    required this.eose,
    required this.complete,
    required this.cached,
    this.cacheAgeSeconds,
  });

  factory GatewayResponse.fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List<dynamic>? ?? [];

    return GatewayResponse(
      events: eventsList.cast<Map<String, dynamic>>(),
      eose: json['eose'] as bool? ?? false,
      complete: json['complete'] as bool? ?? false,
      cached: json['cached'] as bool? ?? false,
      cacheAgeSeconds: json['cache_age_seconds'] as int?,
    );
  }

  /// Whether the response contains any events
  bool get hasEvents => events.isNotEmpty;

  /// Number of events in the response
  int get eventCount => events.length;
}
