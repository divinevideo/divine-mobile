// ABOUTME: RelayCapabilityService - fetches and caches NIP-11 relay information documents
// ABOUTME: Detects divine_extensions support for sorted queries and engagement metric filtering

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown when relay capability detection fails
class RelayCapabilityException implements Exception {
  final String message;
  final String relayUrl;
  final dynamic cause;

  RelayCapabilityException(this.message, this.relayUrl, [this.cause]);

  @override
  String toString() =>
      'RelayCapabilityException: $message for $relayUrl${cause != null ? ' (cause: $cause)' : ''}';
}

/// Represents capabilities of a Nostr relay based on NIP-11
class RelayCapabilities {
  final String relayUrl;
  final String? name;
  final String? description;
  final List<int> supportedNips;
  final Map<String, dynamic> rawData;

  // Divine extensions support
  final bool hasDivineExtensions;
  final List<String> sortFields;
  final List<String> intFilterFields;
  final String? cursorFormat;
  final int? videosKind;
  final int? metricsFreshnessSec;
  final int? maxLimit;

  RelayCapabilities({
    required this.relayUrl,
    this.name,
    this.description,
    this.supportedNips = const [],
    required this.rawData,
    this.hasDivineExtensions = false,
    this.sortFields = const [],
    this.intFilterFields = const [],
    this.cursorFormat,
    this.videosKind,
    this.metricsFreshnessSec,
    this.maxLimit,
  });

  /// Parse from NIP-11 JSON response
  factory RelayCapabilities.fromJson(
    String relayUrl,
    Map<String, dynamic> json,
  ) {
    final supportedNips =
        (json['supported_nips'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    // Check for divine_extensions
    final divineExtensions = json['divine_extensions'] as Map<String, dynamic>?;
    final hasDivineExtensions = divineExtensions != null;

    List<String> sortFields = [];
    List<String> intFilterFields = [];
    String? cursorFormat;
    int? videosKind;
    int? metricsFreshnessSec;
    int? maxLimit;

    if (hasDivineExtensions) {
      sortFields =
          (divineExtensions['sort_fields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      intFilterFields =
          (divineExtensions['int_filters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      cursorFormat = divineExtensions['cursor_format'] as String?;
      videosKind = divineExtensions['videos_kind'] as int?;
      metricsFreshnessSec = divineExtensions['metrics_freshness_sec'] as int?;
      maxLimit = divineExtensions['limit_max'] as int?;
    }

    return RelayCapabilities(
      relayUrl: relayUrl,
      name: json['name'] as String?,
      description: json['description'] as String?,
      supportedNips: supportedNips,
      rawData: json,
      hasDivineExtensions: hasDivineExtensions,
      sortFields: sortFields,
      intFilterFields: intFilterFields,
      cursorFormat: cursorFormat,
      videosKind: videosKind,
      metricsFreshnessSec: metricsFreshnessSec,
      maxLimit: maxLimit,
    );
  }

  /// Check if relay supports sorting queries
  bool get supportsSorting => sortFields.isNotEmpty;

  /// Check if relay supports int# filters
  bool get supportsIntFilters => intFilterFields.isNotEmpty;

  /// Check if relay supports cursor-based pagination
  bool get supportsCursor => cursorFormat != null;

  /// Check if relay supports a specific metric for filtering or sorting
  bool supportsMetric(String metric) {
    return intFilterFields.contains(metric) || sortFields.contains(metric);
  }

  /// Check if relay supports sorting by a specific field
  bool supportsSortBy(String field) {
    return sortFields.contains(field);
  }

  /// Check if relay supports filtering by a specific int metric
  bool supportsIntFilter(String field) {
    return intFilterFields.contains(field);
  }
}

/// Service for fetching and caching relay capabilities via NIP-11
class RelayCapabilityService {
  final http.Client _httpClient;
  final Duration _cacheTtl;
  final Map<String, _CachedCapability> _cache = {};

  RelayCapabilityService({http.Client? httpClient, Duration? cacheTtl})
    : _httpClient = httpClient ?? http.Client(),
      _cacheTtl = cacheTtl ?? Duration(hours: 24);

  /// Get capabilities for a relay (with caching)
  Future<RelayCapabilities> getRelayCapabilities(String relayWsUrl) async {
    // Check cache first
    final cached = _cache[relayWsUrl];
    if (cached != null && !cached.isExpired) {
      UnifiedLogger.debug(
        'Using cached capabilities for $relayWsUrl',
        name: 'RelayCapability',
      );
      return cached.capabilities;
    }

    // Convert wss:// to https:// for NIP-11 HTTP request
    final httpUrl = relayWsUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://');

    UnifiedLogger.info(
      'Fetching NIP-11 capabilities from $httpUrl',
      name: 'RelayCapability',
    );

    try {
      final response = await _httpClient
          .get(
            Uri.parse(httpUrl),
            headers: {'Accept': 'application/nostr+json'},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw RelayCapabilityException(
          'HTTP ${response.statusCode}',
          relayWsUrl,
          response.body,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final capabilities = RelayCapabilities.fromJson(relayWsUrl, json);

      // Cache the result
      _cache[relayWsUrl] = _CachedCapability(
        capabilities,
        DateTime.now().add(_cacheTtl),
      );

      if (capabilities.hasDivineExtensions) {
        UnifiedLogger.info(
          'Relay $relayWsUrl supports divine extensions:\n'
          '  - Sort fields: ${capabilities.sortFields}\n'
          '  - Int filters: ${capabilities.intFilterFields}\n'
          '  - Max limit: ${capabilities.maxLimit}',
          name: 'RelayCapability',
        );
      } else {
        UnifiedLogger.info(
          'Relay $relayWsUrl does not support divine extensions (will use local sorting)',
          name: 'RelayCapability',
        );
      }

      return capabilities;
    } on FormatException catch (e) {
      throw RelayCapabilityException('Invalid JSON response', relayWsUrl, e);
    } on TimeoutException catch (e) {
      throw RelayCapabilityException('Request timeout', relayWsUrl, e);
    } catch (e) {
      throw RelayCapabilityException(
        'Failed to fetch capabilities',
        relayWsUrl,
        e,
      );
    }
  }

  /// Clear all cached capabilities
  void clearCache() {
    _cache.clear();
    UnifiedLogger.debug(
      'Cleared relay capability cache',
      name: 'RelayCapability',
    );
  }

  /// Dispose of resources
  void dispose() {
    _cache.clear();
  }
}

/// Internal class for caching capabilities with expiration
class _CachedCapability {
  final RelayCapabilities capabilities;
  final DateTime expiresAt;

  _CachedCapability(this.capabilities, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
