// ABOUTME: REST client for Divine Gateway API (gateway.divine.video)
// ABOUTME: Provides cached query, profile, and event fetching via HTTP

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/models/gateway_response.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown when gateway request fails
class GatewayException implements Exception {
  final String message;
  final int? statusCode;

  GatewayException(this.message, {this.statusCode});

  @override
  String toString() => 'GatewayException: $message (status: $statusCode)';
}

/// REST client for the Divine Gateway API
///
/// Provides cached access to Nostr events via HTTP REST endpoints.
/// Use for discovery feeds, hashtag feeds, profiles, and single event lookups.
/// Falls back to WebSocket (via NostrService) on failure.
class RelayGatewayService {
  /// Default gateway URL for Divine relay infrastructure
  static const String defaultGatewayUrl = 'https://gateway.divine.video';

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 10);

  final String gatewayUrl;
  final http.Client _client;

  RelayGatewayService({
    String? gatewayUrl,
    http.Client? client,
  })  : gatewayUrl = gatewayUrl ?? defaultGatewayUrl,
        _client = client ?? http.Client();

  /// Query events using NIP-01 filter via REST gateway
  ///
  /// Filter is base64url-encoded in the URL query parameter.
  /// Returns [GatewayResponse] with events and cache metadata.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<GatewayResponse> query(nostr.Filter filter) async {
    final filterJson = jsonEncode(_filterToJson(filter));
    final encoded = base64Url.encode(utf8.encode(filterJson));
    final url = '$gatewayUrl/query?filter=$encoded';

    Log.debug(
      'Gateway query: ${filter.kinds} limit=${filter.limit}',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      Log.info(
        'Gateway returned ${gatewayResponse.eventCount} events '
        '(cached: ${gatewayResponse.cached}, age: ${gatewayResponse.cacheAgeSeconds}s)',
        name: 'RelayGatewayService',
        category: LogCategory.relay,
      );

      return gatewayResponse;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Get profile (kind 0) by pubkey
  ///
  /// Returns raw event JSON or null if not found.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<Map<String, dynamic>?> getProfile(String pubkey) async {
    final url = '$gatewayUrl/profile/$pubkey';

    Log.debug(
      'Gateway profile fetch: $pubkey',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      if (gatewayResponse.events.isEmpty) {
        return null;
      }

      return gatewayResponse.events.first;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Get single event by ID
  ///
  /// Returns raw event JSON or null if not found.
  /// Throws [GatewayException] on HTTP or network errors.
  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    final url = '$gatewayUrl/event/$eventId';

    Log.debug(
      'Gateway event fetch: $eventId',
      name: 'RelayGatewayService',
      category: LogCategory.relay,
    );

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final gatewayResponse = GatewayResponse.fromJson(json);

      if (gatewayResponse.events.isEmpty) {
        return null;
      }

      return gatewayResponse.events.first;
    } on http.ClientException catch (e) {
      throw GatewayException('Network error: $e');
    } on FormatException catch (e) {
      throw GatewayException('Invalid response format: $e');
    }
  }

  /// Convert nostr_sdk Filter to JSON map for gateway
  Map<String, dynamic> _filterToJson(nostr.Filter filter) {
    final json = <String, dynamic>{};

    if (filter.ids != null && filter.ids!.isNotEmpty) {
      json['ids'] = filter.ids;
    }
    if (filter.authors != null && filter.authors!.isNotEmpty) {
      json['authors'] = filter.authors;
    }
    if (filter.kinds != null && filter.kinds!.isNotEmpty) {
      json['kinds'] = filter.kinds;
    }
    if (filter.since != null) {
      json['since'] = filter.since;
    }
    if (filter.until != null) {
      json['until'] = filter.until;
    }
    if (filter.limit != null) {
      json['limit'] = filter.limit;
    }
    // Handle tag filters (#e, #p, #t, etc.)
    if (filter.e != null && filter.e!.isNotEmpty) {
      json['#e'] = filter.e;
    }
    if (filter.p != null && filter.p!.isNotEmpty) {
      json['#p'] = filter.p;
    }
    if (filter.t != null && filter.t!.isNotEmpty) {
      json['#t'] = filter.t;
    }
    if (filter.h != null && filter.h!.isNotEmpty) {
      json['#h'] = filter.h;
    }
    if (filter.d != null && filter.d!.isNotEmpty) {
      json['#d'] = filter.d;
    }

    return json;
  }

  /// Dispose of HTTP client resources
  void dispose() {
    _client.close();
  }
}
