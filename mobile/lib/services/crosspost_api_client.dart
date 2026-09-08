// ABOUTME: HTTP client for Bluesky crosspost settings via keycast API
// ABOUTME: Fetches status and toggles crossposting for a user's account link

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/models/atproto_provisioning_state.dart';

/// Response model for crosspost status from keycast's `AtprotoStatusResponse`.
class CrosspostStatus {
  const CrosspostStatus({
    required this.crosspostEnabled,
    required this.provisioningState,
    this.username,
    this.handle,
    this.did,
    this.provisioningError,
  });

  /// Builds a status from keycast's `AtprotoStatusResponse` JSON shape:
  /// `{enabled, state, did, error, username}`.
  ///
  /// `username` is the bare local part; the displayable Bluesky handle is
  /// `<username>.divine.video`.
  factory CrosspostStatus.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    return CrosspostStatus(
      crosspostEnabled: json['enabled'] as bool? ?? false,
      provisioningState: AtprotoProvisioningState.fromWireName(
        json['state'] as String?,
      ),
      username: username,
      handle: username == null ? null : '$username.$_handleDomain',
      did: json['did'] as String?,
      provisioningError: json['error'] as String?,
    );
  }

  static const _handleDomain = 'divine.video';

  final bool crosspostEnabled;
  final AtprotoProvisioningState provisioningState;

  /// The bare local part of the user's `.divine.video` handle, or `null` when
  /// the user has not yet claimed a username. Enabling crossposting requires a
  /// claimed username, so `null` here means the toggle cannot succeed yet.
  final String? username;
  final String? handle;
  final String? did;
  final String? provisioningError;
}

/// Reads the active account's bound access token, re-validating the owner
/// pubkey across the await so a request cannot authenticate as the wrong
/// account after a mid-flight switch. See
/// [AuthService.getBoundDivineAccessToken]. #8825.
typedef CrosspostAccessTokenReader = Future<String?> Function();

/// Client for keycast crosspost API endpoints.
class CrosspostApiClient {
  CrosspostApiClient({
    required CrosspostAccessTokenReader accessTokenReader,
    required String serverUrl,
    http.Client? httpClient,
  }) : _accessTokenReader = accessTokenReader,
       _serverUrl = serverUrl,
       _httpClient = httpClient ?? http.Client();

  final CrosspostAccessTokenReader _accessTokenReader;
  final String _serverUrl;
  final http.Client _httpClient;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _accessTokenReader();
    if (token == null) {
      throw const CrosspostApiException('Not authenticated', statusCode: 401);
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch the current crosspost status for the authenticated user.
  ///
  /// The bearer token identifies the user, so no pubkey is part of the path.
  /// keycast returns 200 for any authenticated user (no account link yields
  /// `enabled:false, state:null`); the 404 branch is a tolerant fallback
  /// rather than the expected "no account" signal.
  ///
  /// Throws [CrosspostApiException] when unauthenticated or on a non-200,
  /// non-404 response.
  Future<CrosspostStatus> getStatus() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_serverUrl/api/user/atproto/status');
    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode == 404) {
      // No account link exists — return disabled default
      return const CrosspostStatus(
        crosspostEnabled: false,
        provisioningState: AtprotoProvisioningState.notLinked,
      );
    }

    if (response.statusCode != 200) {
      throw CrosspostApiException(
        'Failed to fetch crosspost status',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CrosspostStatus.fromJson(json);
  }

  /// Toggle crossposting for [pubkey].
  Future<CrosspostStatus> setCrosspost({
    required String pubkey,
    required bool enabled,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_serverUrl/api/account/$pubkey/crosspost');
    final response = await _httpClient.put(
      uri,
      headers: headers,
      body: jsonEncode({'enabled': enabled}),
    );

    if (response.statusCode != 200) {
      throw CrosspostApiException(
        'Failed to update crosspost setting',
        statusCode: response.statusCode,
        kind: CrosspostApiErrorKind.fromStatusCode(response.statusCode),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CrosspostStatus.fromJson(json);
  }
}

/// The actionable category of a crosspost API failure, so callers can react
/// without pattern-matching on raw status codes or message strings.
enum CrosspostApiErrorKind {
  /// The user has not claimed a `.divine.video` username yet, so crossposting
  /// cannot be enabled. keycast surfaces this as `400` ("Username must be
  /// claimed").
  usernameNotClaimed,

  /// Provisioning is temporarily unavailable (`503`); the caller should offer
  /// a retry rather than a permanent failure.
  unavailable,

  /// Any other failure.
  generic;

  factory CrosspostApiErrorKind.fromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return CrosspostApiErrorKind.usernameNotClaimed;
      case 503:
        return CrosspostApiErrorKind.unavailable;
      default:
        return CrosspostApiErrorKind.generic;
    }
  }
}

class CrosspostApiException implements Exception {
  const CrosspostApiException(
    this.message, {
    this.statusCode,
    this.kind = CrosspostApiErrorKind.generic,
  });

  final String message;
  final int? statusCode;
  final CrosspostApiErrorKind kind;

  /// Deliberately omits [message]: it can carry a connection URL or a bearer
  /// token, and this text reaches logs. Mirrors the sibling
  /// CrosspostingApiException. #8825.
  @override
  String toString() =>
      'CrosspostApiException(status: ${statusCode ?? 'none'}, '
      'kind: ${kind.name})';
}
