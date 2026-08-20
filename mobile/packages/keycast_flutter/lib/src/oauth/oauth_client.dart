// ABOUTME: Keycast OAuth client for authentication flow
// ABOUTME: Handles authorization URL generation, callback parsing, token
// exchange, and headless auth

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/src/crypto/key_utils.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/account_status.dart';
import 'package:keycast_flutter/src/oauth/callback_result.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/oauth/pkce.dart';
import 'package:keycast_flutter/src/oauth/token_response.dart';
import 'package:keycast_flutter/src/storage/keycast_storage.dart';

/// Storage key for session credentials
const _storageKeySession = 'keycast_session';

/// Storage key for authorization handle (for silent re-auth when session
/// expires)
const _storageKeyHandle = 'keycast_auth_handle';

/// Storage key for refresh token (stored separately so it survives session
/// clear)
const _storageKeyRefreshToken = 'keycast_refresh_token';

Map<String, dynamic> _decodeJsonObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw const FormatException('Expected a JSON object');
}

String _responseErrorCode(Map<String, dynamic> json, String fallback) =>
    json['code']?.toString() ?? json['error']?.toString() ?? fallback;

String _responseErrorMessage(Map<String, dynamic> json, String fallback) =>
    json['message']?.toString() ??
    json['error_description']?.toString() ??
    json['error']?.toString() ??
    fallback;

KeycastAuthFailure _failureForStatusCode(int statusCode) {
  if (statusCode == 409) {
    return KeycastAuthFailure.emailAlreadyRegistered;
  }
  if (statusCode == 401 || statusCode == 404) {
    return KeycastAuthFailure.expiredVerification;
  }
  if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
    return KeycastAuthFailure.temporary;
  }
  return KeycastAuthFailure.unknown;
}

class KeycastOAuth {
  KeycastOAuth({
    required this.config,
    http.Client? httpClient,
    KeycastStorage? storage,
    this.requestTimeout = defaultRequestTimeout,
  }) : _client = httpClient ?? http.Client(),
       _storage = storage ?? MemoryKeycastStorage();

  /// Default timeout applied to every Keycast HTTP request.
  ///
  /// Without a bound, a dead socket (e.g. Android Doze killing the
  /// connection while backgrounded) hangs the request forever and wedges
  /// every caller awaiting it.
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  final OAuthConfig config;
  final http.Client _client;
  final KeycastStorage _storage;

  /// Maximum time to wait for any single HTTP request before failing
  /// with a [TimeoutException].
  final Duration requestTimeout;

  // Invalidates in-flight refresh saves after logout clears credential storage.
  int _storageEpoch = 0;

  /// Get stored session from storage
  /// Returns null if no session or session is expired
  Future<KeycastSession?> getSession() async {
    final json = await _storage.read(_storageKeySession);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final session = KeycastSession.fromJson(data);
      if (session.isExpired) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Get stored authorization handle (for silent re-auth when session expires)
  Future<String?> getAuthorizationHandle() async {
    return _storage.read(_storageKeyHandle);
  }

  /// Clear the local session, keeping the authorization handle.
  ///
  /// Also pings the server's logout endpoint, which revokes nothing: keycast's
  /// handler takes no extractors and only returns a cookie-clearing header this
  /// client has no use for, and by this point the tokens it would need to
  /// identify the session are already deleted. The call is kept because the
  /// endpoint may grow a real revocation later; tokens expire on their own
  /// until then. Local logout is complete either way.
  Future<void> logout() async {
    _storageEpoch++;
    await _storage.delete(_storageKeySession);
    await _storage.delete(_storageKeyHandle);
    await _storage.delete(_storageKeyRefreshToken);
    // Best-effort server logout; the local one is already complete. The
    // handler has to be on the future itself — a surrounding try/catch
    // cannot see a rejection that surfaces after logout() has returned.
    _client
        .post(Uri.parse('${config.serverUrl}/api/auth/logout'))
        .timeout(const Duration(seconds: 2))
        .ignore();
  }

  Future<void> _saveSession(KeycastSession session) async {
    await _storage.write(_storageKeySession, jsonEncode(session.toJson()));
    if (session.authorizationHandle != null) {
      await _storage.write(_storageKeyHandle, session.authorizationHandle!);
    }
    if (session.refreshToken != null) {
      await _storage.write(_storageKeyRefreshToken, session.refreshToken!);
    }
  }

  /// Attempt to refresh the session using a stored refresh token.
  ///
  /// Returns the new [KeycastSession] on success, or `null` if refresh
  /// is not possible (no refresh token) or the server rejects the token.
  ///
  /// [userPubkey] is attached to the session before it is persisted so
  /// the saved session is always owner-bound.
  ///
  /// On HTTP error the consumed refresh token is cleared (server may have
  /// rotated it) and the method returns null. On network error or timeout —
  /// including socket errors while the network is unavailable — an
  /// [OAuthNetworkException] is thrown and the token is preserved since the
  /// server may not have consumed it.
  Future<KeycastSession?> refreshSession({String? userPubkey}) async {
    final refreshEpoch = _storageEpoch;
    final refreshToken = await _storage.read(_storageKeyRefreshToken);
    if (refreshToken == null) return null;

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(config.tokenUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
              'client_id': config.clientId,
            }),
          )
          .timeout(requestTimeout);
    } catch (error) {
      // Network error or timeout — server may not have consumed the
      // token, keep it so the next attempt can retry the refresh.
      throw OAuthNetworkException('Refresh request failed: $error');
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tokenResponse = TokenResponse.fromJson(json);
      var session = KeycastSession.fromTokenResponse(
        tokenResponse,
        grantType: KeycastSession.refreshTokenGrant,
      );
      if (userPubkey != null && userPubkey.isNotEmpty) {
        session = session.copyWith(userPubkey: userPubkey);
      }
      if (refreshEpoch != _storageEpoch) {
        return null;
      }
      await _saveSession(session);
      return session;
    }

    // HTTP error — server consumed the token, clear it
    await _storage.delete(_storageKeyRefreshToken);
    return null;
  }

  /// Get an active session, refreshing if the current one is expired.
  ///
  /// Tries [getSession] first. If that returns `null` (no session stored or
  /// token expired), falls back to [refreshSession] to obtain a fresh token.
  /// Returns `null` only when no session can be recovered at all because no
  /// refresh token is available or the server rejects the token.
  ///
  /// Throws [OAuthNetworkException] when the refresh cannot reach Keycast or
  /// times out. The refresh token is preserved for a later retry in that case.
  ///
  /// [userPubkey] is forwarded to [refreshSession] so the saved session
  /// is owner-bound when a refresh is needed.
  Future<KeycastSession?> getSessionOrRefresh({String? userPubkey}) async {
    final session = await getSession();
    if (session != null) return session;
    return refreshSession(userPubkey: userPubkey);
  }

  /// Generate authorization URL for OAuth flow
  /// Automatically uses stored authorization handle for silent re-auth if available
  ///
  /// [prompt] - OAuth 2.0 prompt parameter:
  ///   - 'login': Force fresh login (ignore existing session)
  ///   - 'consent': Force consent screen even if previously approved
  ///   - 'none': Silent auth only, fail if interaction required
  Future<(String url, String verifier)> getAuthorizationUrl({
    String? nsec,
    String scope = 'policy:social',
    bool defaultRegister = true,
    String? authorizationHandle,
    String? prompt,
  }) async {
    String? byokPubkey;
    if (nsec != null) {
      byokPubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
      if (byokPubkey == null) {
        return ('', '');
      }
    }

    final verifier = Pkce.generateVerifier(nsec: nsec);
    final challenge = Pkce.generateChallenge(verifier);

    final params = <String, String>{
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'scope': scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'default_register': defaultRegister.toString(),
    };

    if (byokPubkey != null) {
      params['byok_pubkey'] = byokPubkey;
    }

    final handle = authorizationHandle ?? await getAuthorizationHandle();
    if (handle != null) {
      params['authorization_handle'] = handle;
    }

    if (prompt != null) {
      params['prompt'] = prompt;
    }

    final uri = Uri.parse(config.authorizeUrl).replace(queryParameters: params);
    return (uri.toString(), verifier);
  }

  /// Parse callback URL and extract authorization code
  /// PKCE provides security - state parameter is not required
  CallbackResult parseCallback(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;

    if (params.containsKey('error')) {
      return CallbackError(
        error: params['error']!,
        description: params['error_description'],
      );
    }

    if (params.containsKey('code')) {
      return CallbackSuccess(code: params['code']!);
    }

    return const CallbackError(
      error: 'invalid_response',
      description: 'Missing code or error in callback URL',
    );
  }

  /// Exchange authorization code for tokens
  /// Automatically saves session to storage after successful exchange
  ///
  /// Throws [TimeoutException] if the server does not respond within
  /// [requestTimeout].
  Future<TokenResponse> exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final response = await _client
        .post(
          Uri.parse(config.tokenUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'grant_type': 'authorization_code',
            'code': code,
            'client_id': config.clientId,
            'redirect_uri': config.redirectUri,
            'code_verifier': verifier,
          }),
        )
        .timeout(requestTimeout);

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = json['error'] as String? ?? 'unknown_error';
      final description = json['error_description'] as String?;
      throw OAuthException(
        description ?? 'Token exchange failed',
        errorCode: error,
      );
    }

    final tokenResponse = TokenResponse.fromJson(json);

    // Auto-save session and authorization handle to storage
    final session = KeycastSession.fromTokenResponse(tokenResponse);
    await _saveSession(session);

    return tokenResponse;
  }

  // ===========================================================================
  // HEADLESS AUTHENTICATION METHODS
  // Native login/register flows without browser redirects
  // ===========================================================================

  /// Register a new user with email and password (headless flow)
  ///
  /// Returns [HeadlessRegisterResult] with device_code for email verification
  /// polling.
  /// After registration, poll [pollForCode] until email is verified, then
  /// [exchangeCode].
  ///
  /// [nsec] - Optional: import existing Nostr key instead of generating new one
  /// [marketingConsent] - Whether the user opted in to marketing
  /// communications at sign-up. Recorded on the account by keycast.
  Future<(HeadlessRegisterResult, String verifier)> headlessRegister({
    required String email,
    required String password,
    String scope = 'policy:social',
    String? nsec,
    String? state,
    bool marketingConsent = false,
  }) async {
    String? byokPubkey;
    if (nsec != null) {
      byokPubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
    }

    final verifier = Pkce.generateVerifier(nsec: nsec);
    final challenge = Pkce.generateChallenge(verifier);

    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'scope': scope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'marketing_consent': marketingConsent,
      };

      if (byokPubkey != null) {
        body['nsec'] = nsec;
      }

      if (state != null) {
        body['state'] = state;
      }

      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      // Check for non-success status codes first
      if (response.statusCode == 404) {
        return (
          HeadlessRegisterResult.error(
            'Registration endpoint not available. Please try again later.',
            code: 'endpoint_not_found',
          ),
          verifier,
        );
      }

      if (response.statusCode >= 500) {
        return (
          HeadlessRegisterResult.error(
            'Server error (${response.statusCode}). Please try again later.',
            code: 'server_error',
          ),
          verifier,
        );
      }

      // Try to parse JSON response
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return (
          HeadlessRegisterResult.error(
            'Invalid server response. Status: ${response.statusCode}',
            code: 'invalid_response',
          ),
          verifier,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return (HeadlessRegisterResult.fromJson(json), verifier);
      }

      // Handle error responses - preserve error code for client-side handling
      final errorCode = json['code'] as String? ?? 'registration_failed';
      final description =
          json['error'] as String? ?? json['message'] as String? ?? errorCode;

      return (
        HeadlessRegisterResult.error(description, code: errorCode),
        verifier,
      );
    } on TimeoutException {
      return (
        HeadlessRegisterResult.error(
          'Request timed out. Check your internet connection and try again.',
          code: 'timeout',
        ),
        verifier,
      );
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return (
          HeadlessRegisterResult.error(
            'Cannot connect to server. Check your internet connection.',
            code: 'connection_error',
          ),
          verifier,
        );
      }
      return (
        HeadlessRegisterResult.error(
          'Network error: $e',
          code: 'network_error',
        ),
        verifier,
      );
    }
  }

  /// Login existing user with email and password (headless flow)
  ///
  /// Returns [HeadlessLoginResult] with authorization code directly (no polling needed).
  /// After login, call [exchangeCode] with the returned code and verifier.
  Future<(HeadlessLoginResult, String verifier)> headlessLogin({
    required String email,
    required String password,
    String scope = 'policy:social',
    String? state,
  }) async {
    final verifier = Pkce.generateVerifier();
    final challenge = Pkce.generateChallenge(verifier);

    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'scope': scope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      };

      if (state != null) {
        body['state'] = state;
      }

      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      // Check for non-success status codes first
      if (response.statusCode == 404) {
        return (
          HeadlessLoginResult.error(
            'Login endpoint not available. Please try again later.',
            code: 'endpoint_not_found',
          ),
          verifier,
        );
      }

      if (response.statusCode >= 500) {
        return (
          HeadlessLoginResult.error(
            'Server error (${response.statusCode}). Please try again later.',
            code: 'server_error',
          ),
          verifier,
        );
      }

      // Try to parse JSON response
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return (
          HeadlessLoginResult.error(
            'Invalid server response. Status: ${response.statusCode}',
            code: 'invalid_response',
          ),
          verifier,
        );
      }

      if (response.statusCode == 200) {
        return (HeadlessLoginResult.fromJson(json), verifier);
      }

      // Keycast sends the machine code in `code` and the human message in
      // `error`; earlier code read them swapped, dropping the code entirely.
      final errorCode = json['code'] as String? ?? 'login_failed';
      final description =
          json['error'] as String? ??
          json['error_description'] as String? ??
          json['message'] as String? ??
          'Login failed';

      return (
        HeadlessLoginResult.error(description, code: errorCode),
        verifier,
      );
    } on TimeoutException {
      return (
        HeadlessLoginResult.error(
          'Request timed out. Check your internet connection and try again.',
          code: 'timeout',
        ),
        verifier,
      );
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return (
          HeadlessLoginResult.error(
            'Cannot connect to server. Check your internet connection.',
            code: 'connection_error',
          ),
          verifier,
        );
      }
      return (
        HeadlessLoginResult.error('Network error: $e', code: 'network_error'),
        verifier,
      );
    }
  }

  /// Poll for email verification completion
  ///
  /// Call this after [headlessRegister] to wait for the user to verify their email.
  /// Returns [PollResult.complete] with authorization code when verified.
  /// Returns [PollResult.pending] if still waiting.
  /// Returns [PollResult.error] if something went wrong.
  Future<PollResult> pollForCode(String deviceCode) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${config.serverUrl}/api/oauth/poll',
            ).replace(queryParameters: {'device_code': deviceCode}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final json = _decodeJsonObject(response.body);
        final code = json['code'] as String?;
        if (code != null) {
          return PollResult.complete(code);
        }
        return PollResult.pending();
      }

      if (response.statusCode == 202) {
        // Still pending
        return PollResult.pending();
      }

      // Error
      try {
        final json = _decodeJsonObject(response.body);
        final errorCode = _responseErrorCode(json, 'poll_failed');
        final description = _responseErrorMessage(json, 'Polling failed');
        return PollResult.error(
          description,
          errorCode: errorCode,
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      } catch (_) {
        return PollResult.error(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      }
    } catch (e) {
      return PollResult.error(
        'Network error: $e',
        failure: KeycastAuthFailure.network,
      );
    }
  }

  /// Send a password reset link to the provided email address
  Future<ForgotPasswordResult> sendPasswordResetEmail(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(requestTimeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ForgotPasswordResult.fromJson(json);
      }

      // Handle server-side errors
      final error = json['error'] as String? ?? 'reset_failed';
      final description =
          json['message'] ??
          json['error_description'] ??
          'Failed to send reset email';
      return ForgotPasswordResult.error('$error: $description');
    } catch (e) {
      return ForgotPasswordResult.error('Network error: $e');
    }
  }

  /// Reset password using token from email link
  Future<ResetPasswordResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'new_password': newPassword}),
          )
          .timeout(requestTimeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResetPasswordResult.fromJson(json);
      }

      // Handle server-side errors
      final message = json['message']?.toString() ?? 'Failed to reset password';
      return ResetPasswordResult.error(message);
    } catch (e) {
      return ResetPasswordResult.error('Network error: $e');
    }
  }

  /// Verify email using token from email link
  Future<VerifyEmailResult> verifyEmail({required String token}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/verify-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _decodeJsonObject(response.body);
        return VerifyEmailResult.fromJson(
          json,
          statusCode: response.statusCode,
        );
      }

      // Handle server-side errors
      try {
        final json = _decodeJsonObject(response.body);
        final message = _responseErrorMessage(json, 'Failed to verify email');
        return VerifyEmailResult.error(
          message,
          errorCode: _responseErrorCode(json, 'verify_email_failed'),
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      } catch (_) {
        return VerifyEmailResult.error(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      }
    } on FormatException catch (e) {
      return VerifyEmailResult.error('Invalid server response: $e');
    } catch (e) {
      return VerifyEmailResult.error(
        'Network error: $e',
        failure: KeycastAuthFailure.network,
      );
    }
  }

  /// Fetch the current account status from Keycast, including the durable
  /// approved-minor flag (`verified_minor`, keycast#263).
  ///
  /// Requires an active bearer [token]. Returns the parsed
  /// [KeycastAccountStatus], or null on any non-200 response, timeout, or
  /// network/parse error — callers treat null as "unknown / not a minor".
  Future<KeycastAccountStatus?> getAccountStatus(String token) async =>
      (await _probeAccount(token))?.status;

  /// Verify a pending registration with the 6-digit PIN from the email.
  ///
  /// Submits `{device_code, pin}` to `/api/headless/verify-pin`. On success the
  /// server finalizes verification and returns the OAuth authorization code
  /// synchronously in [VerifyPinResult.code]; the caller exchanges it via
  /// [exchangeCode] using the registration verifier (Redis-independent — no
  /// polling needed).
  ///
  /// Never throws for expected failures (mirrors [headlessRegister] /
  /// [verifyEmail]): a wrong / expired / locked PIN, a malformed response, or a
  /// network error all return a [VerifyPinResult] carrying a [VerifyPinError].
  Future<VerifyPinResult> verifyPin({
    required String deviceCode,
    required String pin,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/verify-pin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_code': deviceCode, 'pin': pin}),
          )
          .timeout(requestTimeout);

      // Endpoint absent — mirror the endpoint_not_found handling in
      // headlessRegister / headlessLogin. Checked before JSON parsing because
      // a 404 body is typically non-JSON (proxy/CDN HTML), which would
      // otherwise be misread as a server error.
      if (response.statusCode == 404) {
        return VerifyPinResult.failure(
          VerifyPinError.unavailable,
          description: 'verify-pin endpoint not available (404)',
        );
      }

      if (response.statusCode >= 500) {
        return VerifyPinResult.failure(
          VerifyPinError.server,
          description: 'Server error (${response.statusCode})',
        );
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return VerifyPinResult.failure(
          VerifyPinError.server,
          description: 'Invalid server response (${response.statusCode})',
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final code = json['code'] as String?;
        if (code != null && code.isNotEmpty) {
          return VerifyPinResult.success(code);
        }
        return VerifyPinResult.alreadyCompleted();
      }

      // Honor `code` first (then `error`), matching the 2xx success path and
      // the register/login helpers, so a keycast response that carries the
      // failure identifier under `code` is classified correctly.
      final errorCode = _responseErrorCode(json, '');
      final description = _responseErrorMessage(json, errorCode);
      return VerifyPinResult.failure(
        _classifyPinError(response.statusCode, errorCode),
        description: description,
      );
    } on TimeoutException {
      return VerifyPinResult.failure(
        VerifyPinError.network,
        description: 'Request timed out',
      );
    } catch (e) {
      return VerifyPinResult.failure(
        VerifyPinError.network,
        description: 'Network error: $e',
      );
    }
  }

  /// Map an HTTP status + server error code to a [VerifyPinError].
  ///
  /// Known keycast PIN error codes are matched first (typed), so a generic
  /// OAuth/request error such as `invalid_request` is classified as
  /// [VerifyPinError.unavailable] rather than masquerading as a wrong PIN.
  /// Status-code hints and substring matching are kept only as a last-resort
  /// fallback for when the endpoint returns a bare/opaque failure — preserving
  /// tolerance of keycast's anti-enumeration posture.
  static VerifyPinError _classifyPinError(int statusCode, String errorCode) {
    final code = errorCode.toLowerCase();

    // 1) Known keycast PIN error codes take precedence over any heuristic.
    const expiredCodes = {'pin_expired', 'expired', 'code_expired'};
    const lockedCodes = {
      'pin_locked',
      'locked',
      'too_many_attempts',
      'pin_attempts_exceeded',
    };
    const invalidCodes = {
      'pin_invalid',
      'invalid_pin',
      'incorrect_pin',
      'wrong_pin',
    };
    // Generic OAuth/request errors are NOT wrong-PIN signals — route them to
    // unavailable so they can't fall through to the bare 400/401 -> invalid
    // rule below.
    const unavailableCodes = {
      'endpoint_not_found',
      'not_found',
      'pin_unavailable',
      'invalid_request',
      'bad_request',
      'unsupported_grant_type',
    };
    if (expiredCodes.contains(code)) return VerifyPinError.expired;
    if (lockedCodes.contains(code)) return VerifyPinError.locked;
    if (invalidCodes.contains(code)) return VerifyPinError.invalid;
    if (unavailableCodes.contains(code)) return VerifyPinError.unavailable;
    if (statusCode == 409 || code == 'email_already_exists') {
      return VerifyPinError.emailAlreadyRegistered;
    }

    // 2) Status-code hints for a bare/opaque failure.
    if (statusCode == 423 || statusCode == 429) return VerifyPinError.locked;
    if (statusCode == 410) return VerifyPinError.expired;

    // 3) Last-resort substring / bare-status fallback. A generic invalid_request
    //    was already routed to unavailable above, so it never reaches the
    //    400/401 -> invalid rule here.
    if (code.contains('lock') || code.contains('attempt')) {
      return VerifyPinError.locked;
    }
    if (code.contains('expired')) return VerifyPinError.expired;
    if (statusCode == 400 ||
        statusCode == 401 ||
        code.contains('invalid') ||
        code.contains('pin')) {
      return VerifyPinError.invalid;
    }
    // Any other unclassified 4xx: the PIN path is unavailable here, so steer
    // the user to the email link / resend rather than claiming an incorrect PIN.
    return VerifyPinError.unavailable;
  }

  /// Request a fresh verification email (link + PIN) for [email].
  ///
  /// Posts to `/api/auth/resend-verification`. The server always responds with
  /// success to avoid email enumeration and rate-limits to one send per
  /// 5 minutes; callers surface their own client-side cooldown.
  Future<ResendVerificationResult> resendVerification(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/resend-verification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return ResendVerificationResult.fromJson(json);
        } catch (_) {
          // A 2xx with a non-JSON body still means the request was accepted.
          return ResendVerificationResult(success: true);
        }
      }
      return ResendVerificationResult.failure(
        _resendErrorFor(response.statusCode),
      );
    } catch (_) {
      return ResendVerificationResult.failure(ResendVerificationError.network);
    }
  }

  /// Request a fresh link + PIN for a pending headless verification session.
  ///
  /// Posts to `/api/headless/resend-pin` with the active `device_code`, which
  /// lets keycast re-arm the pending `oauth_codes` row used by headless
  /// registration. Use [resendVerification] for users-table email-token flows.
  ///
  /// Never throws. A 404 (route absent on this server build) is reported as
  /// [ResendVerificationError.unavailable] so the UI can steer the user to the
  /// PIN instead of offering a retry that can never succeed.
  Future<ResendVerificationResult> resendHeadlessVerification(
    String deviceCode,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/resend-pin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_code': deviceCode}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return ResendVerificationResult.fromJson(json);
        } catch (_) {
          // A 2xx with a non-JSON body still means the request was accepted.
          return ResendVerificationResult(success: true);
        }
      }
      return ResendVerificationResult.failure(
        _resendErrorFor(response.statusCode),
      );
    } catch (_) {
      return ResendVerificationResult.failure(ResendVerificationError.network);
    }
  }

  static ResendVerificationError _resendErrorFor(int statusCode) {
    if (statusCode == 404) return ResendVerificationError.unavailable;
    if (statusCode >= 500) return ResendVerificationError.server;
    return ResendVerificationError.declined;
  }

  /// The server's own `message` (falling back to `error`) from a JSON error
  /// body, or null when the body is absent or not JSON.
  static String? _errorMessageFrom(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['message'] as String? ?? json['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// One `DELETE /api/user/account` attempt carrying [authorization].
  Future<http.Response> _sendAccountDeletion(
    String url,
    String authorization,
  ) {
    return _client
        .delete(
          Uri.parse(url),
          headers: {
            'Authorization': authorization,
            'Content-Type': 'application/json',
          },
        )
        .timeout(requestTimeout);
  }

  /// The NIP-98 proof for [url], or null when [signer] cannot produce one.
  ///
  /// Swallows a throwing signer so the 403 that triggered the retry stays the
  /// response the caller sees, rather than a misleading network error.
  static Future<String?> _signDeletionProof(
    Future<String?> Function(String url) signer,
    String url,
  ) async {
    try {
      return await signer(url);
    } catch (_) {
      return null;
    }
  }

  /// Delete the user's account permanently from Keycast
  ///
  /// This is a destructive action that cannot be undone.
  ///
  /// Authorization uses the bearer [token]. Keycast's `DELETE /user/account`
  /// hands the header straight to UCAN validation, which strips a `Bearer `
  /// prefix and rejects every other scheme — so a NIP-98 proof is answered
  /// with 401 before it is ever read.
  ///
  /// [nip98Signer] is therefore a **retry** credential, used only after a
  /// **403**: that is the code the server returns once it has read and refused
  /// a credential, which is the case a proof-of-key would cure. It receives
  /// the exact request URL and returns the base64 event body (without the
  /// `Nostr ` scheme), or null if it cannot sign. The URL is passed in rather
  /// than rebuilt by the caller because NIP-98 binds the signature to it: any
  /// divergence makes the server reject the proof. Keycast closed keycast#323
  /// by preserving the first-party fact across refresh rotation instead of
  /// accepting proofs on this route, so until that changes the retry cannot
  /// succeed — which is why neither its status nor a throw out of it may
  /// displace the refusal the bearer attempt already earned.
  ///
  /// Returns [DeleteAccountResult] with success status.
  Future<DeleteAccountResult> deleteAccount(
    String token, {
    Future<String?> Function(String url)? nip98Signer,
  }) async {
    try {
      final url = '${config.serverUrl}/api/user/account';

      var response = await _sendAccountDeletion(url, 'Bearer $token');

      if (response.statusCode == 403 && nip98Signer != null) {
        final proof = await _signDeletionProof(nip98Signer, url);
        if (proof != null) {
          // Best-effort, in both directions. Only a 200 supersedes the 403,
          // and a timeout or dropped socket on the retry must not escape to
          // the network-error handler below: either would discard the refusal
          // the server actually sent, and `requiresReauthentication` is the
          // only thing the UI branches on — so the user would be told to check
          // their connection after the irreversible vanish had gone out.
          try {
            final retry = await _sendAccountDeletion(url, 'Nostr $proof');
            if (retry.statusCode == 200) {
              response = retry;
            }
          } catch (_) {
            // Keep the refusal the bearer attempt already earned.
          }
        }
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Clear local session after successful deletion
        await _storage.delete(_storageKeySession);
        await _storage.delete(_storageKeyHandle);
        await _storage.delete(_storageKeyRefreshToken);
        return DeleteAccountResult.fromJson(json);
      }

      if (response.statusCode == 401) {
        return DeleteAccountResult.error(
          'Unauthorized: invalid or expired token',
          requiresReauthentication: true,
        );
      }

      if (response.statusCode == 403) {
        // The credential was read and refused: neither user-signed nor
        // carrying the server's first-party fact. The proof-of-key retry above
        // has already had its turn, so re-authenticating is what is left — this
        // must never be reported as a connectivity problem. The server's prose
        // is what separates the two refusals, in the log; the UI reads only
        // `requiresReauthentication`, which 401 and 403 both set.
        return DeleteAccountResult.error(
          _errorMessageFrom(response) ??
              'Account deletion requires signing in again',
          requiresReauthentication: true,
        );
      }

      if (response.statusCode == 404) {
        return DeleteAccountResult.error('Account not found');
      }

      if (response.statusCode >= 500) {
        return DeleteAccountResult.error(
          'Server error (${response.statusCode}). Please try again later.',
        );
      }

      // Try to parse error response
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String? ?? 'deletion_failed';
        final message = json['message'] as String? ?? 'Account deletion failed';
        return DeleteAccountResult.error('$error: $message');
      } catch (_) {
        return DeleteAccountResult.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return DeleteAccountResult.error(
          'Cannot connect to server. Check your internet connection.',
        );
      }
      return DeleteAccountResult.error('Network error: $e');
    }
  }

  /// What Keycast reports about the account behind [token].
  ///
  /// `null` when the probe itself could not be answered — a timeout, a dropped
  /// connection, or a 5xx. Callers must not read that as a verdict either way.
  ///
  /// `GET /api/user/account` applies no email-verification or minor gate of its
  /// own, so it answers for exactly the accounts an export refuses, and it
  /// carries the account state as fields rather than as prose. `status` is null
  /// only when an authenticated 200 did not parse.
  Future<({bool authenticated, KeycastAccountStatus? status})?> _probeAccount(
    String token,
  ) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${config.serverUrl}/api/user/account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        return (authenticated: false, status: null);
      }
      if (response.statusCode != 200) return null;

      try {
        return (
          authenticated: true,
          status: KeycastAccountStatus.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        return (authenticated: true, status: null);
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolve a 401 or 403 export refusal against the account status [probe].
  ///
  /// Keycast's refusal bodies are English prose it owns and can reword per
  /// deployment, and both codes are overloaded, so the discriminator is the
  /// structured account state rather than the message.
  static ExportKeyFailure _classifyRefusal(
    int statusCode,
    ({bool authenticated, KeycastAccountStatus? status})? probe,
  ) {
    // A probe that never answered proves nothing, so neither refusal may be
    // reported as a verdict.
    if (probe == null) return ExportKeyFailure.unknown;
    if (!probe.authenticated) return ExportKeyFailure.needsSignIn;

    // The token still authenticates, so what a 401 rejected was the password.
    if (statusCode == 401) return ExportKeyFailure.wrongPassword;

    // An authenticated 200 whose body would not parse carries no account state
    // at all, so it proves no more than a probe that never answered. Reading it
    // as the custody denial would tell a user Divine manages their keys on a
    // response that says nothing of the kind.
    final status = probe.status;
    if (status == null) return ExportKeyFailure.unknown;

    // Mirrors the server's own order: the verified_minor custody refusal runs
    // ahead of the email check, so a minor whose email is also unverified is a
    // policy denial rather than a verification prompt. That refusal is worded
    // uniformly on purpose and leaks no account state, which is why the state
    // is read from the endpoint that is meant to carry it.
    if (status.verifiedMinor) return ExportKeyFailure.denied;
    return status.emailVerified
        ? ExportKeyFailure.denied
        : ExportKeyFailure.emailUnverified;
  }

  /// Export the account's own signing key from Keycast.
  ///
  /// For an account created with email/password, Keycast holds the key and
  /// NIP-46 exposes no method that returns key material, so this endpoint is
  /// the only way the owner can reach their nsec. It takes the same bearer
  /// [token] as every other `/api/user/*` call — Keycast tries `Authorization`
  /// before the browser cookie — plus the account [password], which the handler
  /// verifies itself. The web flow's separate `/api/user/verify-password` step
  /// only gates its own UI and is not needed here.
  ///
  /// Keycast enforces its preconditions server-side: the email must be
  /// verified, and a `verified_minor` account is refused before any key
  /// material is touched. Calling this does not move either check on-device.
  ///
  /// `nsec` is the only encoding Keycast will produce — it rejects any other
  /// `format` with a 400 — so the request pins it rather than taking it from
  /// the caller.
  ///
  /// On success [ExportKeyResult.key] is raw key material. Never log it, and
  /// never write it anywhere but the destination the user asked for.
  Future<ExportKeyResult> exportKey(String token, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/user/export-key'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'password': password, 'format': 'nsec'}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final key = json['key'] as String?;
        if (key == null || key.isEmpty) {
          return ExportKeyResult.failure(
            ExportKeyFailure.unknown,
            message: 'Keycast returned no key',
          );
        }
        return ExportKeyResult.success(key);
      }

      final message = _errorMessageFrom(response);

      // Each refusal code covers two unrelated causes — 401 is a wrong password
      // or a stale token, 403 is an unverified email or the verified_minor
      // custody denial — and the response body discriminates neither. Re-asking
      // the account endpoint separates them from structured fields instead.
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ExportKeyResult.failure(
          _classifyRefusal(response.statusCode, await _probeAccount(token)),
          message: message,
        );
      }

      if (response.statusCode == 404) {
        return ExportKeyResult.failure(
          ExportKeyFailure.noKey,
          message: message,
        );
      }

      // Keycast imposes no limit on this endpoint today, but anything in front
      // of it can, and this is the one refusal whose remedy is to wait rather
      // than to act — it must not fall through to the generic failure.
      if (response.statusCode == 429) {
        return ExportKeyResult.failure(
          ExportKeyFailure.rateLimited,
          message: message,
        );
      }

      if (response.statusCode >= 500) {
        return ExportKeyResult.failure(
          ExportKeyFailure.server,
          message: message ?? 'Server error (${response.statusCode})',
        );
      }

      return ExportKeyResult.failure(
        ExportKeyFailure.unknown,
        message: message ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ExportKeyResult.failure(
        ExportKeyFailure.network,
        message: 'Network error: $e',
      );
    }
  }

  /// Change the account password for the session behind [token].
  ///
  /// Keycast verifies [currentPassword] itself and re-hashes [newPassword]; the
  /// existing session stays valid, so nothing here signs the user out.
  ///
  /// A 401 means either the current password was wrong or the token is no
  /// longer accepted, and the body says which is which no more clearly than the
  /// export endpoint's does. The account probe separates them from structured
  /// state, exactly as [exportKey] does.
  Future<ChangePasswordResult> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/user/change-password'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return ChangePasswordResult.success();
      }

      final message = _errorMessageFrom(response);

      if (response.statusCode == 401) {
        final probe = await _probeAccount(token);
        return ChangePasswordResult.failure(
          switch (probe) {
            // A probe that never answered proves nothing, so neither cause may
            // be reported as a verdict.
            null => ChangePasswordFailure.unknown,
            // The token still authenticates, so what the 401 rejected was the
            // submitted current password.
            (authenticated: true, status: _) =>
              ChangePasswordFailure.wrongPassword,
            _ => ChangePasswordFailure.needsSignIn,
          },
          message: message,
        );
      }

      // The server enforces its own minimum on the new password. The client
      // checks the same rule first, so this is the disagreement case — a server
      // that raised its minimum — and must say so rather than read as a fault.
      if (response.statusCode == 400) {
        return ChangePasswordResult.failure(
          ChangePasswordFailure.weakPassword,
          message: message,
        );
      }

      if (response.statusCode == 429) {
        return ChangePasswordResult.failure(
          ChangePasswordFailure.rateLimited,
          message: message,
        );
      }

      if (response.statusCode >= 500) {
        return ChangePasswordResult.failure(
          ChangePasswordFailure.server,
          message: message ?? 'Server error (${response.statusCode})',
        );
      }

      return ChangePasswordResult.failure(
        ChangePasswordFailure.unknown,
        message: message ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ChangePasswordResult.failure(
        ChangePasswordFailure.network,
        message: 'Network error: $e',
      );
    }
  }

  /// Start a self-serve email change for the session behind [token].
  ///
  /// Keycast re-verifies [password], then mails a confirmation link to
  /// [newEmail] and a confirm/cancel link to the address on file. The address
  /// changes only once **both** are confirmed, so a success here means the
  /// request was accepted — never that the email has changed.
  ///
  /// The endpoint answers 200 for an address that is already registered as
  /// well, without sending anything, so that it cannot be used to probe for
  /// accounts. That case is indistinguishable from an accepted change by
  /// design; callers must not try to tell them apart.
  Future<ChangeEmailResult> changeEmail({
    required String token,
    required String newEmail,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/user/change-email'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'new_email': newEmail, 'password': password}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return ChangeEmailResult.success();
      }

      final message = _errorMessageFrom(response);

      if (response.statusCode == 401) {
        final probe = await _probeAccount(token);
        return ChangeEmailResult.failure(
          switch (probe) {
            null => ChangeEmailFailure.unknown,
            (authenticated: true, status: _) =>
              ChangeEmailFailure.wrongPassword,
            _ => ChangeEmailFailure.needsSignIn,
          },
          message: message,
        );
      }

      if (response.statusCode == 400) {
        return ChangeEmailResult.failure(
          ChangeEmailFailure.invalidEmail,
          message: message,
        );
      }

      if (response.statusCode == 429) {
        return ChangeEmailResult.failure(
          ChangeEmailFailure.rateLimited,
          message: message,
        );
      }

      if (response.statusCode >= 500) {
        return ChangeEmailResult.failure(
          ChangeEmailFailure.server,
          message: message ?? 'Server error (${response.statusCode})',
        );
      }

      return ChangeEmailResult.failure(
        ChangeEmailFailure.unknown,
        message: message ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ChangeEmailResult.failure(
        ChangeEmailFailure.network,
        message: 'Network error: $e',
      );
    }
  }

  void close() {
    _client.close();
  }
}
