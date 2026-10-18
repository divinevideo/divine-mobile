// ABOUTME: HTTP API service for communicating with the Divine backend
import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/services/consent_upload.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

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
    required String relayManagerBaseUrl,
    required String appVersion,
    http.Client? client,
    Nip98AuthService? authService,
    Duration requestTimeout = _defaultTimeout,
  }) : _relayManagerBaseUrl = relayManagerBaseUrl,
       _client = client ?? http.Client(),
       _authService = authService,
       _appVersion = appVersion,
       _requestTimeout = requestTimeout;

  /// Relay-manager worker base URL (minor-account-review endpoints live
  /// there, not on the main backend — divine-relay-manager#108). Injected
  /// from EnvironmentConfig.relayManagerApiUrl so staging/local builds and
  /// the developer environment switcher never send signed minor-review
  /// traffic to the production worker.
  final String _relayManagerBaseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for multipart uploads. A consent video over a slow link
  /// can legitimately exceed the shared [_defaultTimeout]; this applies only to
  /// the parent-consent upload so no other request is slowed down.
  static const Duration _uploadTimeout = Duration(seconds: 120);

  final http.Client _client;
  final Nip98AuthService? _authService;

  final String _appVersion;
  final Duration _requestTimeout;

  /// Get current account restriction and minor-account review status.
  Future<Map<String, dynamic>> getMinorAccountReviewStatus() async {
    Log.debug(
      'Fetching minor-account review status',
      name: 'ApiService',
      category: LogCategory.api,
    );

    try {
      final uri = Uri.parse(
        '$_relayManagerBaseUrl/v1/account/moderation-status',
      );
      final response = await _request(
        () async =>
            _client.get(uri, headers: await _getHeaders(url: uri.toString())),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw ApiException(
        'Failed to get minor-account review status',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } on TimeoutException {
      throw const ApiException('Request timeout for moderation status');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during moderation status request: $e');
    }
  }

  /// Starts or resumes the existing private Greenlight review for this account.
  Future<Map<String, dynamic>> startGreenlight() async {
    final uri = Uri.parse(
      '$_relayManagerBaseUrl/v1/minor-review-cases/greenlight',
    );
    const body = '{}';
    final response = await _request(
      () async => _client.post(
        uri,
        headers: await _getHeaders(
          url: uri.toString(),
          method: HttpMethod.post,
          payload: body,
        ),
        body: body,
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        'Could not start Greenlight review',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Submit parent contact email for an open minor-account review case.
  Future<void> submitMinorAccountReviewParentContact({
    required String caseId,
    required String email,
  }) async {
    Log.debug(
      'Submitting parent contact for case $caseId',
      name: 'ApiService',
      category: LogCategory.api,
    );

    try {
      final uri = Uri.parse(
        '$_relayManagerBaseUrl/v1/minor-review-cases/$caseId/parent-contact',
      );
      final requestBody = jsonEncode({'email': email});
      final response = await _request(
        () async => _client.post(
          uri,
          headers: await _getHeaders(
            url: uri.toString(),
            method: HttpMethod.post,
            payload: requestBody,
          ),
          body: requestBody,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ApiException(
        'Failed to submit parent contact',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } on TimeoutException {
      throw const ApiException('Request timeout for parent contact submission');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during parent contact submission: $e');
    }
  }

  /// Submit a recorded parental consent video plus parent email for an open
  /// minor-account review case. The video is uploaded as multipart/form-data.
  ///
  /// The NIP-98 payload tag binds the exact multipart body, including the email
  /// and video. Freeze the body before signing and send that same snapshot.
  /// The server verifies its streamed hash before completing the private video.
  Future<void> submitMinorAccountReviewParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
  }) async {
    Log.debug(
      'Submitting parent consent video for case $caseId',
      name: 'ApiService',
      category: LogCategory.api,
    );

    try {
      final uri = Uri.parse(
        '$_relayManagerBaseUrl/v1/minor-review-cases/$caseId/parent-consent',
      );

      // Fail fast with an accurate message rather than letting the multipart
      // stream error surface later as an ambiguous network failure.
      final file = File(videoPath);
      if (!file.existsSync()) {
        throw ApiException(
          'Parent consent video not found or unreadable at $videoPath',
        );
      }

      // relay-manager rejects a video part that is not labelled video/* with
      // a 415, and http defaults file parts to application/octet-stream. The
      // camera writes MP4 on both platforms.
      final multipart = http.MultipartRequest('POST', uri)
        ..fields['email'] = email
        ..files.add(
          await http.MultipartFile.fromPath(
            'video',
            videoPath,
            contentType: MediaType('video', 'mp4'),
          ),
        );

      final upload = await ConsentUpload.prepare(multipart);
      // A timeout does not cancel the underlying request. Its own finally
      // retains the snapshot until the transport finishes reading it.
      var transportOwnsSnapshot = false;
      final http.Response response;
      try {
        final token = await _authService?.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.post,
          payloadHash: upload.payloadHash,
          reuseCached: false,
        );
        if (token == null) {
          throw const ApiException('Could not authenticate consent upload');
        }
        upload.request.headers.addAll({
          'Accept': 'application/json',
          ...buildDivineClientHeaders(appVersion: _appVersion),
          'Authorization': token.authorizationHeader,
        });
        transportOwnsSnapshot = true;
        response = await _request(
          () async {
            try {
              return await _client
                  .send(upload.request)
                  .then(http.Response.fromStream);
            } finally {
              await upload.dispose();
            }
          },
          timeout: _uploadTimeout,
        );
      } finally {
        if (!transportOwnsSnapshot) await upload.dispose();
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ApiException(
        'Failed to submit parent consent video',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } on TimeoutException {
      throw const ApiException(
        'Request timeout for parent consent video submission',
      );
    } on FileSystemException catch (e) {
      throw ApiException('Failed to read parent consent video: $e');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Failed to submit parent consent video: $e',
      );
    }
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) => request().timeout(timeout ?? _requestTimeout);

  /// Get standard headers for API requests
  Future<Map<String, String>> _getHeaders({
    String? url,
    HttpMethod method = HttpMethod.get,
    String? payload,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...buildDivineClientHeaders(appVersion: _appVersion),
    };

    // Add NIP-98 authentication if available
    if (_authService?.canCreateTokens == true && url != null) {
      final authToken = await _authService!.createAuthToken(
        url: url,
        method: method,
        payload: payload,
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

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}
