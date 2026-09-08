// ABOUTME: Sends version-two product analytics batches to Funnelcake.
// ABOUTME: Keeps signed user activity separate from anonymous acquisition events.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

sealed class AnalyticsIngestResult {
  const AnalyticsIngestResult();
}

final class AnalyticsIngestAccepted extends AnalyticsIngestResult {
  const AnalyticsIngestAccepted();
}

final class AnalyticsIngestRejected extends AnalyticsIngestResult {
  const AnalyticsIngestRejected({
    required this.statusCode,
    required this.reason,
  });

  final int statusCode;
  final String reason;
}

final class AnalyticsIngestTransientFailure extends AnalyticsIngestResult {
  const AnalyticsIngestTransientFailure(this.reason);

  final String reason;
}

class AnalyticsIngestClient {
  AnalyticsIngestClient({
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String Function() apiBaseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient,
       _nip98 = nip98AuthService,
       _apiBaseUrl = apiBaseUrl,
       _timeout = timeout;

  static const eventsPath = '/api/analytics/events';
  static const anonymousEventsPath = '/api/analytics/events/anonymous';
  static const _logName = 'AnalyticsIngestClient';

  final http.Client _httpClient;
  final Nip98AuthService _nip98;
  final String Function() _apiBaseUrl;
  final Duration _timeout;

  /// The one place a request URI is built.
  ///
  /// Signed batches take their NIP-98 `u` tag from this URI's `toString()`, so
  /// what is signed is what is requested. Composing the string separately
  /// would skip the normalization `Uri.parse` applies, and the ingest API
  /// compares the two exactly.
  Uri _uriFor(String path) {
    final base = _apiBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$trimmed$path');
  }

  Future<AnalyticsIngestResult> publishBatch(
    List<Map<String, Object?>> events, {
    required String subjectPubkey,
  }) async {
    if (events.isEmpty) return const AnalyticsIngestAccepted();

    final uri = _uriFor(eventsPath);
    final url = uri.toString();
    final body = jsonEncode({
      'subject_pubkey': subjectPubkey,
      'events': events,
    });
    final token = await _nip98.createAuthToken(
      url: url,
      method: HttpMethod.post,
      payload: body,
    );
    if (token == null) {
      return const AnalyticsIngestTransientFailure('nip98_token_unavailable');
    }

    return _post(
      uri,
      body,
      authorization: token.authorizationHeader,
    );
  }

  Future<AnalyticsIngestResult> publishAnonymousBatch(
    List<Map<String, Object?>> events,
  ) async {
    if (events.isEmpty) return const AnalyticsIngestAccepted();
    return _post(
      _uriFor(anonymousEventsPath),
      jsonEncode({'events': events}),
    );
  }

  Future<AnalyticsIngestResult> _post(
    Uri uri,
    String body, {
    String? authorization,
  }) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': ?authorization,
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const AnalyticsIngestTransientFailure('timeout');
    } catch (error) {
      return AnalyticsIngestTransientFailure('network_error: $error');
    }

    return _classify(response);
  }

  AnalyticsIngestResult _classify(http.Response response) {
    final status = response.statusCode;
    if (status == 200 || status == 202) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['accepted'] == true) {
          return const AnalyticsIngestAccepted();
        }
        return AnalyticsIngestTransientFailure(
          'not_accepted: ${_boundedReason(response.body)}',
        );
      } catch (error) {
        return AnalyticsIngestTransientFailure('invalid_response: $error');
      }
    }

    if (status < 500 && status != 404 && status != 408 && status != 429) {
      Log.error(
        'Product analytics ingest rejected ($status)',
        name: _logName,
        category: LogCategory.system,
      );
      return AnalyticsIngestRejected(
        statusCode: status,
        reason: _boundedReason(response.body),
      );
    }

    return AnalyticsIngestTransientFailure('http_$status');
  }

  /// Rejection and failure reasons are persisted per queued row, so the raw
  /// server body must be bounded rather than stored in full.
  static String _boundedReason(String body) =>
      body.length <= 500 ? body : body.substring(0, 500);
}
