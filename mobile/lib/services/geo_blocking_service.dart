// ABOUTME: Service for checking if user's location is in a geo-blocked region
// ABOUTME: Uses Cloudflare Worker to check IP-based geolocation for compliance with state laws

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Response from geo-blocking API
class GeoBlockResponse {
  final bool blocked;
  final String country;
  final String region;
  final String city;
  final String? reason;

  GeoBlockResponse({
    required this.blocked,
    required this.country,
    required this.region,
    required this.city,
    this.reason,
  });

  factory GeoBlockResponse.fromJson(Map<String, dynamic> json) {
    return GeoBlockResponse(
      blocked: json['blocked'] as bool? ?? false,
      country: json['country'] as String? ?? 'UNKNOWN',
      region: json['region'] as String? ?? 'UNKNOWN',
      city: json['city'] as String? ?? 'UNKNOWN',
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'blocked': blocked,
    'country': country,
    'region': region,
    'city': city,
    'reason': reason,
  };
}

class GeoBlockingService {
  static const String _geoBlockApiUrl =
      'https://openvine-geo-blocker.protestnet.workers.dev';
  static const String _cacheKey = 'geo_block_status';
  static const String _cacheTimestampKey = 'geo_block_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  GeoBlockResponse? _cachedResponse;
  DateTime? _cacheTimestamp;

  /// Check if user is in a geo-blocked region
  /// Returns cached result if available and not expired
  Future<GeoBlockResponse> checkGeoBlock() async {
    // Check memory cache first
    if (_cachedResponse != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      Log.debug(
        'Using cached geo-block status: ${_cachedResponse!.blocked}',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
      return _cachedResponse!;
    }

    // Check persistent cache
    final cachedResult = await _loadFromCache();
    if (cachedResult != null) {
      _cachedResponse = cachedResult;
      return cachedResult;
    }

    // Make API call
    try {
      Log.debug(
        'Checking geo-block status via API',
        name: 'GeoBlockingService',
        category: LogCategory.api,
      );

      final response = await http
          .get(Uri.parse(_geoBlockApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 451) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = GeoBlockResponse.fromJson(json);

        // Cache the result
        await _saveToCache(result);
        _cachedResponse = result;
        _cacheTimestamp = DateTime.now();

        Log.info(
          'Geo-block check complete: blocked=${result.blocked}, region=${result.region}',
          name: 'GeoBlockingService',
          category: LogCategory.system,
        );

        return result;
      } else {
        Log.error(
          'Geo-block API returned status ${response.statusCode}',
          name: 'GeoBlockingService',
          category: LogCategory.api,
        );
        return _failOpen();
      }
    } catch (e) {
      Log.error(
        'Error checking geo-block status: $e',
        name: 'GeoBlockingService',
        category: LogCategory.api,
      );
      return _failOpen();
    }
  }

  /// Check if user is blocked (convenience method)
  Future<bool> isBlocked() async {
    final response = await checkGeoBlock();
    return response.blocked;
  }

  /// Get detailed geo information
  Future<GeoBlockResponse> getGeoInfo() async {
    return checkGeoBlock();
  }

  /// Fail-open: if API fails, allow access
  GeoBlockResponse _failOpen() {
    Log.warning(
      'Geo-block check failed, allowing access (fail-open)',
      name: 'GeoBlockingService',
      category: LogCategory.system,
    );
    return GeoBlockResponse(
      blocked: false,
      country: 'UNKNOWN',
      region: 'UNKNOWN',
      city: 'UNKNOWN',
      reason: null,
    );
  }

  /// Load cached geo-block result from persistent storage
  Future<GeoBlockResponse?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final timestampMillis = prefs.getInt(_cacheTimestampKey);

      if (cachedJson == null || timestampMillis == null) {
        return null;
      }

      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      if (DateTime.now().difference(timestamp) >= _cacheDuration) {
        Log.debug(
          'Cached geo-block status expired',
          name: 'GeoBlockingService',
          category: LogCategory.system,
        );
        return null;
      }

      final json = jsonDecode(cachedJson) as Map<String, dynamic>;
      _cacheTimestamp = timestamp;
      return GeoBlockResponse.fromJson(json);
    } catch (e) {
      Log.error(
        'Error loading cached geo-block status: $e',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Save geo-block result to persistent storage
  Future<void> _saveToCache(GeoBlockResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(response.toJson());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      Log.debug(
        'Cached geo-block status saved',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving geo-block cache: $e',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear cached geo-block status (for testing or manual refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      _cachedResponse = null;
      _cacheTimestamp = null;

      Log.debug(
        'Geo-block cache cleared',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing geo-block cache: $e',
        name: 'GeoBlockingService',
        category: LogCategory.system,
      );
    }
  }
}
