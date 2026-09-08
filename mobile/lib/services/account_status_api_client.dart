// ABOUTME: NIP-98 authenticated client for the current account's Funnelcake enforcement status.
// ABOUTME: Validates account ownership and keeps transport failures distinct from status values.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';

enum FunnelcakeAccountStatus { active, suspended, banned }

enum AccountStatusApiFailureKind {
  unauthorized,
  unavailable,
  invalidResponse,
  requestFailed,
}

class AccountStatusApiException implements Exception {
  const AccountStatusApiException(this.kind, this.message, {this.statusCode});

  final AccountStatusApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AccountStatusApiException($kind): $message';
}

typedef AccountStatusAuthHeaderProvider = Future<String?> Function({
  required String url,
  required HttpMethod method,
});

class AccountStatusApiClient {
  AccountStatusApiClient({
    required Uri baseUri,
    required AccountStatusAuthHeaderProvider authHeaderProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _baseUri = baseUri,
       _authHeaderProvider = authHeaderProvider,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUri;
  final AccountStatusAuthHeaderProvider _authHeaderProvider;
  final http.Client _httpClient;
  final Duration _timeout;

  Future<FunnelcakeAccountStatus> fetchStatus({
    required String expectedPubkey,
  }) async {
    final uri = _baseUri.resolve('/api/users/$expectedPubkey/status');
    final authorization = await _authHeaderProvider(
      url: uri.toString(),
      method: HttpMethod.get,
    );
    if (authorization == null) {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.unauthorized,
        'The current account could not sign the status request.',
      );
    }

    late http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: {'Authorization': authorization})
          .timeout(_timeout);
    } on TimeoutException {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.unavailable,
        'The account status request timed out.',
      );
    } on http.ClientException {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.requestFailed,
        'The account status request failed.',
      );
    }

    if (response.statusCode != 200) {
      throw AccountStatusApiException(
        switch (response.statusCode) {
          401 || 403 => AccountStatusApiFailureKind.unauthorized,
          503 => AccountStatusApiFailureKind.unavailable,
          _ => AccountStatusApiFailureKind.requestFailed,
        },
        'The account status endpoint returned ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.invalidResponse,
        'The account status response was not valid JSON.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.invalidResponse,
        'The account status response was not an object.',
      );
    }

    final responsePubkey = decoded['pubkey'];
    final status = decoded['status'];
    if (responsePubkey is! String ||
        responsePubkey.toLowerCase() != expectedPubkey.toLowerCase() ||
        status is! String) {
      throw const AccountStatusApiException(
        AccountStatusApiFailureKind.invalidResponse,
        'The account status response did not match the requested account.',
      );
    }

    return switch (status) {
      'active' => FunnelcakeAccountStatus.active,
      'suspended' => FunnelcakeAccountStatus.suspended,
      'banned' => FunnelcakeAccountStatus.banned,
      _ => throw const AccountStatusApiException(
        AccountStatusApiFailureKind.invalidResponse,
        'The account status response contained an unknown status.',
      ),
    };
  }

  void dispose() => _httpClient.close();
}
