// ABOUTME: HTTP client for the Divine crossposter service
// ABOUTME: Manages platform connections and posting-mode preferences

import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/crosspost_models.dart';

export 'package:openvine/models/crosspost_models.dart';

/// Reads an account-bound Divine OAuth access token.
typedef CrosspostingAccessTokenReader = Future<String?> Function();

T? _optionalJsonField<T>(
  Map<String, dynamic> json,
  String field, {
  int? statusCode,
}) {
  final value = json[field];
  if (value == null) return null;
  if (value is T) return value;
  throw CrosspostingApiException(
    'Unexpected type for "$field"',
    statusCode: statusCode,
  );
}

T _requiredJsonField<T>(
  Map<String, dynamic> json,
  String field, {
  int? statusCode,
}) {
  final value = _optionalJsonField<T>(json, field, statusCode: statusCode);
  if (value != null) return value;
  throw CrosspostingApiException(
    'Missing required field "$field"',
    statusCode: statusCode,
  );
}

Map<String, dynamic> _jsonObject(Object? value, String context) {
  if (value is Map<String, dynamic>) return value;
  throw CrosspostingApiException('Unexpected $context shape');
}

/// External platforms the crossposter service can publish to.
enum CrosspostingPlatform {
  instagram('instagram', 'Instagram'),
  tiktok('tiktok', 'TikTok'),
  x('x', 'X'),
  youtube('youtube', 'YouTube');

  const CrosspostingPlatform(this.wireName, this.displayName);

  /// The identifier used in API paths and payloads.
  final String wireName;

  /// Brand name shown in UI. Brand names are not localized.
  final String displayName;

  /// Returns the platform for [wireName], or `null` for unknown values so
  /// new server-side platforms don't break older app builds.
  static CrosspostingPlatform? fromWireName(String wireName) {
    for (final platform in values) {
      if (platform.wireName == wireName) return platform;
    }
    return null;
  }
}

/// Connection state of an external platform account.
enum CrosspostingConnectionStatus {
  connected('connected'),
  needsReauth('needs_reauth'),
  disconnected('disconnected');

  const CrosspostingConnectionStatus(this.wireName);

  final String wireName;

  /// Maps a wire value to a status, treating unknown values as
  /// [disconnected] so the UI offers a fresh connect flow.
  static CrosspostingConnectionStatus fromWireName(String? wireName) {
    for (final status in values) {
      if (status.wireName == wireName) return status;
    }
    return CrosspostingConnectionStatus.disconnected;
  }
}

/// Per-platform posting mode.
enum CrosspostingMode {
  disabled('disabled'),
  manual('manual'),
  automatic('automatic');

  const CrosspostingMode(this.wireName);

  final String wireName;

  /// Maps a wire value to a mode, treating unknown values as [disabled].
  static CrosspostingMode fromWireName(String? wireName) {
    for (final mode in values) {
      if (mode.wireName == wireName) return mode;
    }
    return CrosspostingMode.disabled;
  }
}

/// A platform the crossposter service exposes, from `GET /platforms`.
class CrosspostingPlatformInfo {
  const CrosspostingPlatformInfo({
    required this.platform,
    required this.enabled,
    required this.supportsAutomatic,
  });

  final CrosspostingPlatform platform;
  final bool enabled;
  final bool supportsAutomatic;
}

/// A connected (or previously connected) external account, from
/// `GET /connections`.
class CrosspostingConnection extends Equatable {
  const CrosspostingConnection({
    required this.id,
    required this.platform,
    required this.status,
    this.externalAccountId,
    this.externalAccountName,
  });

  factory CrosspostingConnection.fromJson(
    Map<String, dynamic> json,
    CrosspostingPlatform platform,
  ) {
    return CrosspostingConnection(
      id: _requiredJsonField<String>(json, 'id'),
      platform: platform,
      status: CrosspostingConnectionStatus.fromWireName(
        _optionalJsonField<String>(json, 'status'),
      ),
      externalAccountId: _optionalJsonField<String>(json, 'externalAccountId'),
      externalAccountName: _optionalJsonField<String>(
        json,
        'externalAccountName',
      ),
    );
  }

  final String id;
  final CrosspostingPlatform platform;
  final CrosspostingConnectionStatus status;
  final String? externalAccountId;
  final String? externalAccountName;

  /// Whether the service currently considers this link usable for publishing.
  bool get isConnected => status == CrosspostingConnectionStatus.connected;

  @override
  List<Object?> get props => [
    id,
    platform,
    status,
    externalAccountId,
    externalAccountName,
  ];
}

/// A per-platform posting preference, from `GET /preferences`.
class CrosspostingPreference {
  const CrosspostingPreference({
    required this.platform,
    required this.mode,
    this.connectionId,
  });

  final CrosspostingPlatform platform;
  final CrosspostingMode mode;
  final String? connectionId;
}

/// Result of `POST /connections/{platform}/start` — the OAuth page to open.
class CrosspostingStart {
  const CrosspostingStart({required this.authorizationUrl, this.state});

  final Uri authorizationUrl;

  /// Server-side OAuth state value, when the crossposter includes one.
  ///
  /// The app validates its own `app_state` nonce on the HTTPS callback, so this
  /// value is informational only and must not fail an otherwise valid flow.
  final String? state;
}

/// The actionable category of a crossposter API failure.
enum CrosspostingApiErrorKind {
  /// Setting manual/automatic mode on a platform that isn't connected.
  notConnected,

  /// Missing or expired Divine session.
  unauthorized,

  /// Any other failure.
  generic,
}

/// Thrown by [CrosspostingApiClient] on any non-success response.
class CrosspostingApiException implements Exception {
  const CrosspostingApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.cause,
  });

  final String message;
  final int? statusCode;

  /// Machine-readable error code from the `{error: {code}}` envelope.
  final String? code;

  /// Original transport failure, when this exception wraps one.
  final Object? cause;

  CrosspostingApiErrorKind get kind {
    if (code == 'not_connected') return CrosspostingApiErrorKind.notConnected;
    if (statusCode == 401) return CrosspostingApiErrorKind.unauthorized;
    return CrosspostingApiErrorKind.generic;
  }

  /// Deliberately omits [message] and [cause]: the message can carry a
  /// connection URL and the cause a bearer token, and this text reaches logs.
  /// Pinned by "diagnostic text omits raw messages and transport causes".
  @override
  String toString() =>
      'CrosspostingApiException'
      '(status: ${statusCode ?? 'none'}, code: ${code ?? 'none'})';
}

/// Client for the Divine crossposter service
/// (https://crossposter.divine.video).
///
/// All endpoints authenticate with the same Divine/Keycast bearer token the
/// app already holds for login.divine.video.
class CrosspostingApiClient {
  CrosspostingApiClient({
    required CrosspostingAccessTokenReader accessTokenReader,
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
  }) : _accessTokenReader = accessTokenReader,
       _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client();

  /// The crossposter service, overridable per build with `CROSSPOSTER_URL`
  /// so a local-stack or staging run reaches the same host as the rest of
  /// the app.
  static const String defaultBaseUrl = AppConfig.crossposterBaseUrl;

  static const Duration _timeout = Duration(seconds: 20);
  static const _allowedReturnUrlHosts = {
    'divine.video',
    'www.divine.video',
    'crossposter.divine.video',
  };

  final CrosspostingAccessTokenReader _accessTokenReader;
  final String _baseUrl;
  final http.Client _httpClient;

  /// Releases resources held by the HTTP client.
  void close() => _httpClient.close();

  Future<Map<String, String>> _authHeaders() async {
    final String? token;
    try {
      token = await _accessTokenReader();
    } on OAuthNetworkException catch (error) {
      throw CrosspostingApiException(
        'Not authenticated',
        statusCode: 401,
        code: 'unauthorized',
        cause: error,
      );
    }
    if (token == null) {
      throw const CrosspostingApiException(
        'Not authenticated',
        statusCode: 401,
        code: 'unauthorized',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetches the platforms the service supports.
  ///
  /// Only entries with `enabled: true` are candidates for display; the
  /// caller filters. Unknown platform names are skipped.
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<List<CrosspostingPlatformInfo>> getPlatforms() async {
    final json = await _get('/platforms?format=json');
    final entries = _requiredJsonField<List<dynamic>>(json, 'platforms');
    final platforms = <CrosspostingPlatformInfo>[];
    for (final rawEntry in entries) {
      try {
        final entry = _jsonObject(rawEntry, 'platform entry');
        final platform = CrosspostingPlatform.fromWireName(
          _optionalJsonField<String>(entry, 'platform') ?? '',
        );
        if (platform == null) continue;
        platforms.add(
          CrosspostingPlatformInfo(
            platform: platform,
            enabled: _optionalJsonField<bool>(entry, 'enabled') ?? false,
            supportsAutomatic:
                _optionalJsonField<bool>(entry, 'supportsAutomatic') ?? false,
          ),
        );
      } on CrosspostingApiException {
        continue;
      }
    }
    return platforms;
  }

  /// Fetches the user's platform connections. Unknown platforms are skipped.
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<List<CrosspostingConnection>> getConnections() async {
    final json = await _get('/connections');
    final entries = _requiredJsonField<List<dynamic>>(json, 'connections');
    final connections = <CrosspostingConnection>[];
    for (final rawEntry in entries) {
      try {
        final entry = _jsonObject(rawEntry, 'connection entry');
        final platform = CrosspostingPlatform.fromWireName(
          _optionalJsonField<String>(entry, 'platform') ?? '',
        );
        if (platform == null) continue;
        connections.add(CrosspostingConnection.fromJson(entry, platform));
      } on CrosspostingApiException {
        continue;
      }
    }
    return connections;
  }

  /// Starts the OAuth connect flow for [platform].
  ///
  /// [returnUrl] must be an https URL on divine.video, www.divine.video, or
  /// crossposter.divine.video — the server rejects custom app schemes.
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<CrosspostingStart> startConnection(
    CrosspostingPlatform platform, {
    required Uri returnUrl,
  }) async {
    if (returnUrl.scheme != 'https' ||
        !_allowedReturnUrlHosts.contains(returnUrl.host)) {
      throw const CrosspostingApiException('Invalid return URL');
    }
    final json = await _send(
      'POST',
      '/connections/${platform.wireName}/start',
      body: {'returnUrl': returnUrl.toString()},
    );
    final authorizationUrlValue = _optionalJsonField<String>(
      json,
      'authorizationUrl',
    );
    final authorizationUrl = Uri.tryParse(authorizationUrlValue ?? '');
    if (authorizationUrl == null ||
        authorizationUrl.scheme != 'https' ||
        !authorizationUrl.hasAuthority) {
      throw const CrosspostingApiException(
        'Malformed authorization URL in start response',
      );
    }
    final rawState = json['state'];
    final state = rawState is String && rawState.isNotEmpty ? rawState : null;
    return CrosspostingStart(authorizationUrl: authorizationUrl, state: state);
  }

  /// Disconnects [connectionId] on [platform].
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<void> disconnect(
    CrosspostingPlatform platform,
    String connectionId,
  ) async {
    final encodedConnectionId = Uri.encodeComponent(connectionId);
    await _send(
      'DELETE',
      '/connections/${platform.wireName}/$encodedConnectionId',
    );
  }

  /// Fetches per-platform posting preferences. Unknown platforms are skipped.
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<List<CrosspostingPreference>> getPreferences() async {
    final json = await _get('/preferences');
    final entries = _requiredJsonField<List<dynamic>>(json, 'preferences');
    final preferences = <CrosspostingPreference>[];
    for (final rawEntry in entries) {
      try {
        final entry = _jsonObject(rawEntry, 'preference entry');
        final platform = CrosspostingPlatform.fromWireName(
          _optionalJsonField<String>(entry, 'platform') ?? '',
        );
        if (platform == null) continue;
        preferences.add(
          CrosspostingPreference(
            platform: platform,
            mode: CrosspostingMode.fromWireName(
              _optionalJsonField<String>(entry, 'mode'),
            ),
            connectionId: _optionalJsonField<String>(entry, 'connectionId'),
          ),
        );
      } on CrosspostingApiException {
        continue;
      }
    }
    return preferences;
  }

  /// Sets the posting [mode] for [platform].
  ///
  /// Throws [CrosspostingApiException] on failure — including
  /// `not_connected` (surfaced via [CrosspostingApiException.kind]) when the
  /// platform has no active connection.
  Future<void> setMode(
    CrosspostingPlatform platform,
    CrosspostingMode mode,
  ) async {
    await _send(
      'PUT',
      '/preferences/${platform.wireName}',
      body: {'mode': mode.wireName},
    );
  }

  /// Triggers crossposts of the video [eventId] to [platforms].
  ///
  /// Idempotent server-side: repeat calls return the existing jobs rather
  /// than double-posting.
  ///
  /// Throws [CrosspostingApiException] on failure; [CrosspostingApiException.code]
  /// carries server codes such as `not_owner`, `not_eligible`, and
  /// `not_connected`.
  Future<List<CrosspostJob>> createCrossposts({
    required String eventId,
    required List<String> platforms,
  }) async {
    final json = await _send(
      'POST',
      '/videos/${Uri.encodeComponent(eventId)}/crossposts',
      body: {'platforms': platforms},
    );
    return _parseJobs(json);
  }

  /// Fetches the current crosspost jobs for the video [eventId].
  ///
  /// Throws [CrosspostingApiException] on failure.
  Future<List<CrosspostJob>> getCrossposts({required String eventId}) async {
    final json = await _get(
      '/videos/${Uri.encodeComponent(eventId)}/crossposts',
    );
    return _parseJobs(json);
  }

  List<CrosspostJob> _parseJobs(Map<String, dynamic> json) {
    final jobs = json['jobs'] as List<dynamic>? ?? const [];
    return jobs
        .whereType<Map<String, dynamic>>()
        .map(CrosspostJob.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _request(
      () => _httpClient.get(uri, headers: headers),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'POST' => _request(
        () => _httpClient.post(uri, headers: headers, body: encodedBody),
      ),
      'PUT' => _request(
        () => _httpClient.put(uri, headers: headers, body: encodedBody),
      ),
      'DELETE' => _request(() => _httpClient.delete(uri, headers: headers)),
      _ => throw ArgumentError.value(method, 'method'),
    };
    return _decode(response, allowEmpty: true);
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException catch (error) {
      throw CrosspostingApiException(
        'Crossposter request timed out',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw CrosspostingApiException(
        'Crossposter request failed: ${error.message}',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    bool allowEmpty = false,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response);
    }
    if (allowEmpty && response.body.trim().isEmpty) {
      return const {};
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw CrosspostingApiException(
        'Malformed JSON response',
        statusCode: response.statusCode,
        code: 'malformed_response',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw CrosspostingApiException(
        'Unexpected response shape',
        statusCode: response.statusCode,
        code: 'malformed_response',
      );
    }
    return decoded;
  }

  CrosspostingApiException _errorFromResponse(http.Response response) {
    String? code;
    String message = 'Crossposter request failed';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = _optionalJsonField<Map<String, dynamic>>(
          decoded,
          'error',
          statusCode: response.statusCode,
        );
        if (error != null) {
          code = _optionalJsonField<String>(
            error,
            'code',
            statusCode: response.statusCode,
          );
          message =
              _optionalJsonField<String>(
                error,
                'message',
                statusCode: response.statusCode,
              ) ??
              message;
        }
      }
    } on FormatException {
      // Non-JSON error body (e.g. HTML from an edge proxy) — keep defaults.
    }
    return CrosspostingApiException(
      message,
      statusCode: response.statusCode,
      code: code,
    );
  }
}
