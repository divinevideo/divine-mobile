// ABOUTME: NIP-98 authenticated client for the Divine supporter Worker API.
// ABOUTME: Keeps store proof private and maps canonical account responses.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Stable failure categories returned by the supporter API client.
enum SupporterApiFailureKind {
  /// The current signer cannot authenticate the request.
  unauthorized,

  /// The store transaction is already bound to another Divine account.
  ownershipConflict,

  /// The Worker or its upstream verification dependency is unavailable.
  unavailable,

  /// The response did not match the versioned API contract.
  invalidResponse,

  /// The request failed for another HTTP or transport reason.
  requestFailed,
}

/// Exception raised by the supporter Worker API client.
class SupporterApiException implements Exception {
  /// Creates a typed supporter API failure.
  const SupporterApiException(this.kind, this.message, {this.statusCode});

  /// The stable category used by repository and Cubit state mapping.
  final SupporterApiFailureKind kind;

  /// A safe, user-facing diagnostic that excludes store proof.
  final String message;

  /// The HTTP status when the server returned one.
  final int? statusCode;

  @override
  String toString() => 'SupporterApiException($kind): $message';
}

/// Canonical private supporter state returned by `GET /v1/me` and claim.
class SupporterAccountSnapshot {
  /// Creates a canonical account snapshot.
  const SupporterAccountSnapshot({
    required this.entitlement,
    required this.status,
    this.paidThrough,
    this.graceThrough,
    this.haloVisible = false,
    this.discoveryVisible = false,
    this.foundingHistoryVisible = false,
    this.foundingSupporter = false,
    this.experimentalTrials = const <String>[],
  });

  /// The canonical entitlement mapped to the app's common model.
  final SupporterEntitlement entitlement;

  /// Canonical status, including billing grace and verification uncertainty.
  final SupporterServerStatus status;

  /// The verified paid-through instant, when present.
  final DateTime? paidThrough;

  /// The verified billing-grace deadline, when present.
  final DateTime? graceThrough;

  /// Whether the supporter opted into the avatar halo.
  final bool haloVisible;

  /// Whether the supporter opted into directory/showcase discovery.
  final bool discoveryVisible;

  /// Whether founding-supporter history may be shown publicly.
  final bool foundingHistoryVisible;

  /// Whether the account is eligible for founding recognition.
  final bool foundingSupporter;

  /// Feature-specific experimental trials enabled for this account.
  final List<String> experimentalTrials;

  /// Parses the normalized `/v1/me` response.
  factory SupporterAccountSnapshot.fromJson(Map<String, dynamic> json) {
    final entitlementJson = json['entitlement'];
    final entitlement = entitlementJson is Map<String, dynamic>
        ? SupporterEntitlement.fromJson(entitlementJson)
        : SupporterEntitlement.inactive;
    final recognition = json['recognition'];
    final recognitionJson = recognition is Map<String, dynamic>
        ? recognition
        : const <String, dynamic>{};
    final trials = json['experimentalTrials'];

    return SupporterAccountSnapshot(
      entitlement: entitlement,
      status: SupporterServerStatus.fromValue(json['status']),
      paidThrough: _parseDate(json['paidThroughAt']),
      graceThrough: _parseDate(json['graceThroughAt']),
      haloVisible: recognitionJson['haloVisible'] as bool? ?? false,
      discoveryVisible: recognitionJson['discoveryVisible'] as bool? ?? false,
      foundingHistoryVisible:
          recognitionJson['foundingHistoryVisible'] as bool? ?? false,
      foundingSupporter: json['foundingSupporter'] as bool? ?? false,
      experimentalTrials: trials is List
          ? trials.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  static DateTime? _parseDate(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}

/// Canonical status values understood by mobile clients.
enum SupporterServerStatus {
  /// At least one verified transaction is paid and active.
  active,

  /// Store billing grace preserves supporter benefits temporarily.
  grace,

  /// No verified entitlement currently grants active benefits.
  expired,

  /// Verification is temporarily inconclusive; do not revoke known benefits.
  unknown;

  /// Parses the server's lowercase status value.
  static SupporterServerStatus fromValue(Object? value) {
    return switch (value) {
      'active' => SupporterServerStatus.active,
      'grace' => SupporterServerStatus.grace,
      'expired' => SupporterServerStatus.expired,
      _ => SupporterServerStatus.unknown,
    };
  }
}

/// Minimum proof envelope sent to `POST /v1/purchases/claim`.
///
/// The proof map is intentionally opaque to the UI and analytics. Store
/// adapters provide only the fields required by the Worker contract.
class SupporterPurchaseClaim {
  /// Creates an account-bound claim request.
  const SupporterPurchaseClaim({
    required this.store,
    required this.productId,
    required this.idempotencyKey,
    required this.proof,
  });

  /// Store identifier, such as `apple` or `google`.
  final String store;

  /// Store product identifier.
  final String productId;

  /// Client-generated retry key scoped to this purchase attempt.
  final String idempotencyKey;

  /// Minimum encrypted-at-rest proof required by the Worker.
  final Map<String, dynamic> proof;

  /// Serializes the version-one claim body without logging its contents.
  Map<String, dynamic> toJson() => {
    'store': store,
    'product_id': productId,
    'idempotency_key': idempotencyKey,
    'proof': proof,
  };
}

/// A NIP-98 Authorization header and the pubkey that signed it.
typedef SupporterAuthHeader = ({String authorizationHeader, String pubkey});

/// Provides NIP-98 authentication for an exact request.
typedef SupporterAuthHeaderProvider = Future<SupporterAuthHeader?> Function({
  required String url,
  required HttpMethod method,
  String? payload,
});

/// NIP-98 authenticated client for the version-one supporter Worker API.
class SupporterApiClient {
  /// Creates a client with an injectable HTTP transport and signer.
  SupporterApiClient({
    required Uri baseUri,
    required SupporterAuthHeaderProvider authHeaderProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _baseUri = _trimBaseUri(baseUri),
       _authHeaderProvider = authHeaderProvider,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUri;
  final SupporterAuthHeaderProvider _authHeaderProvider;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Fetches canonical private state for the authenticated Divine account.
  Future<SupporterAccountSnapshot> fetchMe({
    required String expectedPubkey,
  }) async {
    final response = await _send(
      HttpMethod.get,
      '/v1/me',
      expectedPubkey: expectedPubkey,
    );
    return _decodeSnapshot(response);
  }

  /// Claims a store purchase for the pubkey represented by the NIP-98 signer.
  Future<SupporterAccountSnapshot> claimPurchase(
    SupporterPurchaseClaim claim, {
    required String expectedPubkey,
  }) async {
    final body = jsonEncode(claim.toJson());
    final response = await _send(
      HttpMethod.post,
      '/v1/purchases/claim',
      body: body,
      expectedPubkey: expectedPubkey,
    );
    return _decodeSnapshot(response);
  }

  /// Updates recognition preferences without changing payment state.
  Future<SupporterAccountSnapshot> updateRecognition({
    required String expectedPubkey,
    required bool haloVisible,
    required bool discoveryVisible,
    required bool foundingHistoryVisible,
  }) async {
    final body = jsonEncode({
      'halo_visible': haloVisible,
      'discovery_visible': discoveryVisible,
      'founding_history_visible': foundingHistoryVisible,
    });
    final response = await _send(
      HttpMethod.patch,
      '/v1/me/recognition',
      body: body,
      expectedPubkey: expectedPubkey,
    );
    return _decodeSnapshot(response);
  }

  /// Closes the owned HTTP transport.
  void dispose() => _httpClient.close();

  Future<http.Response> _send(
    HttpMethod method,
    String path, {
    String? body,
    String? expectedPubkey,
  }) async {
    final uri = _baseUri.resolve(path.substring(1));
    final auth = await _authHeaderProvider(
      url: uri.toString(),
      method: method,
      payload: body,
    );
    if (auth == null ||
        (expectedPubkey != null && auth.pubkey != expectedPubkey)) {
      throw const SupporterApiException(
        SupporterApiFailureKind.unauthorized,
        'Sign in to manage supporter status.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': auth.authorizationHeader,
    };
    if (body != null) headers['Content-Type'] = 'application/json';

    try {
      final response = await (switch (method) {
        HttpMethod.get => _httpClient.get(uri, headers: headers),
        HttpMethod.post => _httpClient.post(uri, headers: headers, body: body),
        HttpMethod.patch => _httpClient.patch(
          uri,
          headers: headers,
          body: body,
        ),
        _ => throw const SupporterApiException(
          SupporterApiFailureKind.requestFailed,
          'Unsupported supporter API method.',
        ),
      }).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw _exceptionForStatus(response.statusCode, response.body);
    } on SupporterApiException {
      rethrow;
    } on TimeoutException {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is unavailable. Try again later.',
      );
    } on Object {
      throw const SupporterApiException(
        SupporterApiFailureKind.unavailable,
        'Supporter verification is unavailable. Try again later.',
      );
    }
  }

  SupporterAccountSnapshot _decodeSnapshot(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return SupporterAccountSnapshot.fromJson(decoded);
    } on Object {
      throw const SupporterApiException(
        SupporterApiFailureKind.invalidResponse,
        'Supporter verification returned an invalid response.',
      );
    }
  }

  SupporterApiException _exceptionForStatus(int statusCode, String body) {
    String? errorCode;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) errorCode = error['code'] as String?;
      }
    } on FormatException {
      // Error classification still falls back to the HTTP status.
    }
    final kind = switch ((statusCode, errorCode)) {
      (_, 'ownership_conflict') => SupporterApiFailureKind.ownershipConflict,
      (401 || 403, _) => SupporterApiFailureKind.unauthorized,
      (408 || 409 || 429 || >= 500, _) => SupporterApiFailureKind.unavailable,
      _ => SupporterApiFailureKind.requestFailed,
    };
    final message = switch (kind) {
      SupporterApiFailureKind.unauthorized =>
        'Sign in to manage supporter status.',
      SupporterApiFailureKind.ownershipConflict =>
        'This store purchase belongs to another Divine account.',
      SupporterApiFailureKind.unavailable =>
        'Supporter verification is unavailable. Try again later.',
      _ => 'The supporter request could not be completed.',
    };
    return SupporterApiException(kind, message, statusCode: statusCode);
  }

  static Uri _trimBaseUri(Uri uri) {
    final text = uri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$text/');
  }
}
