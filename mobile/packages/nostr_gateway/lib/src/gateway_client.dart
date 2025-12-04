import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:nostr_gateway/src/exceptions/exceptions.dart';
import 'package:nostr_gateway/src/models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template gateway_client}
/// REST client for Nostr Gateway API
/// {@endtemplate}
class GatewayClient {
  /// {@macro gateway_client}
  GatewayClient({String? gatewayUrl, Dio? dio})
    : gatewayUrl = gatewayUrl ?? defaultGatewayUrl,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: requestTimeout,
              receiveTimeout: requestTimeout,
            ),
          );

  /// {@macro gateway_client}
  static const String defaultGatewayUrl = 'https://gateway.divine.video';
  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 10);
  /// URL of the Nostr Gateway API
  final String gatewayUrl;
  /// HTTP client
  final Dio _dio;

  /// Internal method to handle HTTP requests with consistent error handling
  Future<Response<Map<String, dynamic>>> _doRequest(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final url = '$gatewayUrl$path';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: queryParameters,
      );

      if (response.statusCode != 200) {
        throw GatewayException(
          'HTTP ${response.statusCode}: ${response.data}',
          statusCode: response.statusCode,
        );
      }

      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        throw GatewayException(
          'HTTP ${e.response!.statusCode}: ${e.response!.data}',
          statusCode: e.response!.statusCode,
        );
      } else {
        throw GatewayException('Network error: ${e.message}');
      }
    } on Exception catch (e) {
      throw GatewayException('Error parsing response: $e');
    }
  }

  /// Query events using NIP-01 filter via REST gateway
  Future<GatewayResponse> query(Filter filter) async {
    final filterJson = filter.toJson();
    final encoded = base64Url.encode(utf8.encode(jsonEncode(filterJson)));

    final response = await _doRequest(
      '/query',
      queryParameters: {'filter': encoded},
    );

    return GatewayResponse.fromJson(response.data!);
  }

  /// Get profile (kind 0) by pubkey
  Future<Event?> getProfile(String pubkey) async {
    final response = await _doRequest('/profile/$pubkey');

    final gatewayResponse = GatewayResponse.fromJson(response.data!);

    return gatewayResponse.events.isEmpty
        ? null
        : gatewayResponse.events.first;
  }

  /// Get single event by ID
  Future<Event?> getEvent(String eventId) async {
    final response = await _doRequest('/event/$eventId');

    final gatewayResponse = GatewayResponse.fromJson(response.data!);

    return gatewayResponse.events.isEmpty
        ? null
        : gatewayResponse.events.first;
  }

  /// Dispose of HTTP client resources
  void dispose() {
    _dio.close();
  }
}
