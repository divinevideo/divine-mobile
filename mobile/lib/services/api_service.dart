// ABOUTME: HTTP API service for communicating with the divine backend
import 'package:flutter/foundation.dart'; // ABOUTME: Handles ready events polling, authentication, and error handling

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/services/network/rate_limiter.dart'
    show RateLimiter, RateLimitStatus;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown by API service
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.responseBody});
  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => 'ApiException: $message (${statusCode ?? 'no status'})';
}

/// Service for backend API communication
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ApiService {
  ApiService({
    http.Client? client,
    Nip98AuthService? authService,
    RateLimiter? rateLimiter,
  }) : _client = client ?? http.Client(),
       _authService = authService,
       _rateLimiter = rateLimiter;
  static String get _baseUrl => AppConfig.backendBaseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Nip98AuthService? _authService;
  final RateLimiter? _rateLimiter;

  /// Request signed upload parameters (from previous implementation)
  Future<Map<String, dynamic>> requestSignedUpload({
    required String nostrPubkey,
    required int fileSize,
    required String mimeType,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    Log.debug(
      '📱 Requesting signed upload parameters',
      name: 'ApiService',
      category: LogCategory.api,
    );

    try {
      // Check rate limit if configured
      if (_rateLimiter != null) {
        await _rateLimiter.checkLimit('/v1/media/request-upload');
      }

      final uri = Uri.parse('$_baseUrl/v1/media/request-upload');

      final requestBody = {
        'nostr_pubkey': nostrPubkey,
        'file_size': fileSize,
        'mime_type': mimeType,
        'title': title,
        'description': description,
        'hashtags': hashtags,
      };

      final response = await _client
          .post(
            uri,
            headers: await _getHeaders(
              url: uri.toString(),
              method: HttpMethod.post,
            ),
            body: jsonEncode(requestBody),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        Log.info(
          'Received signed upload parameters',
          name: 'ApiService',
          category: LogCategory.api,
        );
        return data;
      } else {
        throw ApiException(
          'Failed to get signed upload parameters',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on TimeoutException {
      throw const ApiException('Request timeout for signed upload');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during signed upload request: $e');
    }
  }

  /// Get user's upload status
  Future<Map<String, dynamic>> getUserUploadStatus() async {
    Log.debug(
      'Fetching user upload status',
      name: 'ApiService',
      category: LogCategory.api,
    );

    try {
      final uri = Uri.parse('$_baseUrl/v1/media/status');

      final response = await _client
          .get(
            uri,
            headers: await _getHeaders(
              url: uri.toString(),
              method: HttpMethod.get,
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        Log.info(
          'Retrieved upload status',
          name: 'ApiService',
          category: LogCategory.api,
        );
        return data;
      } else {
        throw ApiException(
          'Failed to get upload status',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on TimeoutException {
      throw const ApiException('Request timeout for upload status');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during status request: $e');
    }
  }

  /// Get standard headers for API requests
  Future<Map<String, String>> _getHeaders({
    String? url,
    HttpMethod method = HttpMethod.get,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'divine-Mobile/1.0',
    };

    // Add NIP-98 authentication if available
    if (_authService?.canCreateTokens == true && url != null) {
      final authToken = await _authService!.createAuthToken(
        url: url,
        method: method,
      );

      if (authToken != null) {
        headers['Authorization'] = authToken.authorizationHeader;
        Log.debug(
          '📱 Added NIP-98 auth to request',
          name: 'ApiService',
          category: LogCategory.api,
        );
      } else {
        Log.error(
          'Failed to create NIP-98 auth token',
          name: 'ApiService',
          category: LogCategory.api,
        );
      }
    } else {
      Log.warning(
        'No authentication service available',
        name: 'ApiService',
        category: LogCategory.api,
      );
    }

    return headers;
  }

  /// Test API connectivity
  Future<bool> testConnection() async {
    try {
      Log.debug(
        '📱 Testing API connection to: ${AppConfig.healthUrl}',
        name: 'ApiService',
        category: LogCategory.api,
      );

      final uri = Uri.parse(AppConfig.healthUrl);
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      final isHealthy = response.statusCode == 200;
      debugPrint(
        isHealthy ? '✅ API connection healthy' : '❌ API connection unhealthy',
      );

      if (isHealthy) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('📊 Backend status: ${data['status']}');
        } catch (e) {
          // Ignore JSON parsing errors for health check
        }
      }

      return isHealthy;
    } catch (e) {
      Log.error(
        'API connection test failed: $e',
        name: 'ApiService',
        category: LogCategory.api,
      );
      return false;
    }
  }

  /// Get API configuration info
  Future<Map<String, dynamic>?> getApiConfig() async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/config');
      final response = await _client
          .get(uri, headers: await _getHeaders())
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      Log.error(
        'Failed to get API config: $e',
        name: 'ApiService',
        category: LogCategory.api,
      );
    }
    return null;
  }

  /// Get rate limit status for an endpoint
  RateLimitStatus? getRateLimitStatus(String endpoint) {
    if (_rateLimiter == null) return null;
    return _rateLimiter.getStatus(endpoint);
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}
