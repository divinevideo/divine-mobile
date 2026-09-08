// ABOUTME: Flutter wrapper for Zendesk Support (native SDK + REST API fallback)
// ABOUTME: Provides ticket creation via native iOS/Android SDKs or REST API for desktop

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

typedef JwtIdentityRefresh = Future<bool> Function({
  required Nip98AuthService nip98Service,
  required String relayManagerUrl,
});

class ZendeskAttachmentUploadException implements Exception {
  const ZendeskAttachmentUploadException();
}

/// Service for interacting with Zendesk Support SDK
class ZendeskSupportService {
  static const MethodChannel _channel = MethodChannel(
    'com.openvine/zendesk_support',
  );
  static const Duration _jwtRefreshReuseWindow = Duration(minutes: 4);
  static const Duration _initializationTimeout = Duration(seconds: 10);

  /// Crash reporting for this static utility. See [VideoThumbnailService.crashReporter]
  /// for why a static seam remains here (#4743).
  static CrashReporter crashlytics = const SilentCrashReporter();

  static bool _initialized = false;
  static Completer<void> _initializationCompleter = Completer<void>();

  /// Check if Zendesk is available (credentials configured and initialized)
  static bool get isAvailable => _initialized;

  /// Current user identity info (for REST API fallback)
  static String? _userName;
  static String? _userEmail;
  static String? _userNpub;

  /// Stored references for JWT refresh (set at login, used by _ensureFreshJwt)
  static Nip98AuthService? _nip98Service;
  static String? _relayManagerUrl;
  static DateTime? _lastJwtRefreshAt;
  static DateTime Function() _now = DateTime.now;
  static JwtIdentityRefresh? _jwtIdentityRefreshOverride;

  /// Public accessors for user identity (used by reserved username requests)
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static String? get userNpub => _userNpub;

  /// Reset all static state. Only for use in tests.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _userName = null;
    _userEmail = null;
    _userNpub = null;
    _clearAuthContext();
    _now = DateTime.now;
    _jwtIdentityRefreshOverride = null;
    _initializationCompleter = Completer<void>();
  }

  @visibleForTesting
  static void setTestHooks({
    DateTime Function()? now,
    JwtIdentityRefresh? jwtIdentityRefresh,
  }) {
    if (now != null) {
      _now = now;
    }
    _jwtIdentityRefreshOverride = jwtIdentityRefresh;
  }

  static void _clearAuthContext() {
    _nip98Service = null;
    _relayManagerUrl = null;
    _lastJwtRefreshAt = null;
  }

  static List<Map<String, dynamic>>? _sanitizeCustomFields(
    List<Map<String, dynamic>>? customFields,
  ) {
    if (customFields == null) return null;
    return [
      for (final field in customFields)
        {
          ...field,
          if (field['value'] is String)
            'value': sanitizeDiagnosticText(field['value'] as String),
        },
    ];
  }

  /// Initialize Zendesk SDK
  ///
  /// Call once at app startup. Returns true if initialization successful.
  /// Returns false if credentials missing or initialization fails.
  /// App continues to work with email fallback when returns false.
  static Future<bool> initialize({
    required String appId,
    required String clientId,
    required String zendeskUrl,
  }) async {
    // Skip if credentials missing
    if (appId.isEmpty || clientId.isEmpty || zendeskUrl.isEmpty) {
      Log.info(
        'Zendesk credentials not configured - bug reports will use email fallback',
        category: LogCategory.system,
      );
      _completeInitialization();
      return false;
    }

    try {
      final result = await _channel.invokeMethod('initialize', {
        'appId': appId,
        'clientId': clientId,
        'zendeskUrl': zendeskUrl,
      });

      _initialized = (result == true);

      if (_initialized) {
        Log.info(
          '✅ Zendesk initialized successfully',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Zendesk initialization failed - bug reports will use email fallback',
          category: LogCategory.system,
        );
      }

      _completeInitialization();
      return _initialized;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk initialization failed: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      _initialized = false;
      _completeInitialization();
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error initializing Zendesk: $e',
        category: LogCategory.system,
      );
      _initialized = false;
      _completeInitialization();
      return false;
    }
  }

  /// Opens the initialization gate. Safe to call on every exit path of
  /// [initialize], including a repeat call after the SDK is already up.
  static void _completeInitialization() {
    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  }

  /// Blocks until [initialize] has settled, so identity calls made during the
  /// deferred startup phase do not read a [_initialized] that is only
  /// transiently false.
  static Future<void> _awaitInitialization() async {
    try {
      await _initializationCompleter.future.timeout(_initializationTimeout);
    } on TimeoutException {
      Log.warning(
        'Zendesk: initialization did not settle within '
        '${_initializationTimeout.inSeconds}s',
        category: LogCategory.system,
      );
    }
  }

  /// Store user identity for Zendesk tickets.
  ///
  /// Call this after user login. Stores name/email/npub locally.
  /// After calling this, call setAnonymousIdentityWithUserInfo() to set
  /// the native SDK identity, then setJwtIdentity() to upgrade to
  /// authenticated identity. See zendeskIdentitySync provider.
  ///
  /// Returns true always (local storage only).
  static bool setUserIdentity({
    required String npub,
    String? displayName,
    String? nip05,
  }) {
    _userNpub = npub;

    // Determine display name: prefer displayName, fall back to NIP-05, then npub
    final effectiveName = displayName?.isNotEmpty == true
        ? displayName!
        : nip05?.isNotEmpty == true
        ? nip05!
        : _formatNpubForDisplay(npub);

    // Determine email: use NIP-05 if it looks like an email, otherwise create synthetic email
    // NIP-05 format is user@domain which works as email identifier
    // Full npub (63 chars) is within RFC 5321 local-part limit (64 chars)
    final effectiveEmail = nip05?.isNotEmpty == true && nip05!.contains('@')
        ? nip05
        : '$npub@divine.video';

    _userName = effectiveName;
    _userEmail = effectiveEmail;

    Log.info('Zendesk user info stored', category: LogCategory.system);

    return true;
  }

  /// Set anonymous identity on native SDK with user info.
  ///
  /// This provides a baseline identity so createTicket() works immediately
  /// after login without a network call. JWT identity upgrade happens
  /// asynchronously afterward and overrides this when successful.
  static Future<bool> setAnonymousIdentityWithUserInfo() async {
    // Races startup for the same reason setJwtIdentity does: this is the
    // fallback identity the JWT upgrade is allowed to fail back to, so it
    // must not be the one that silently loses the race.
    await _awaitInitialization();

    if (!_initialized) return false;
    if (_userName == null || _userEmail == null) return false;

    try {
      await _channel.invokeMethod('setUserIdentity', {
        'name': _userName,
        'email': _userEmail,
      });
      Log.info(
        'Zendesk SDK: anonymous identity set with user info',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.warning(
        'Zendesk SDK: failed to set anonymous identity: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Clear user identity (call on logout)
  static Future<void> clearUserIdentity() async {
    _userName = null;
    _userEmail = null;
    _userNpub = null;
    _clearAuthContext();
    if (_initialized) {
      try {
        await _channel.invokeMethod('clearUserIdentity');
        Log.info('Zendesk user identity cleared', category: LogCategory.system);
      } catch (e) {
        Log.warning(
          'Error clearing Zendesk identity: $e',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Set anonymous identity (for non-logged-in users)
  ///
  /// Sets a plain anonymous identity without name/email so Zendesk widget works.
  /// Should be called before showing ticket screens if user is not logged in.
  static Future<bool> setAnonymousIdentity() async {
    await _awaitInitialization();
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setAnonymousIdentity');
      Log.info(
        'Zendesk anonymous identity set',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.warning(
        'Error setting Zendesk anonymous identity: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  // Ticket history may open signed out; ticket creation still needs requester info.
  static Future<bool> _setAvailableAnonymousIdentity() {
    if (_userName != null && _userEmail != null) {
      return setAnonymousIdentityWithUserInfo();
    }
    return setAnonymousIdentity();
  }

  // ==========================================================================
  // JWT Authentication (for native SDK ticket history)
  // ==========================================================================

  /// Store auth context for automatic JWT refresh before SDK actions.
  /// Call once at login alongside setUserIdentity/setJwtIdentity.
  /// These references are used by _ensureFreshJwt to refresh the pre-auth
  /// token transparently before any SDK call, avoiding the 5-minute expiry.
  static void storeAuthContext({
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) {
    _nip98Service = nip98Service;
    _relayManagerUrl = relayManagerUrl;
    _lastJwtRefreshAt = null;
  }

  /// Refresh JWT identity before an SDK action.
  /// Gets a fresh pre-auth token and sets it as the SDK identity.
  /// Reuses a recent successful refresh to avoid redundant network work.
  /// No-op if auth context is not stored or SDK not initialized.
  /// Returns true if identity is fresh or refreshed, false if skipped/failed.
  static Future<bool> _ensureFreshJwt() async {
    if (!_initialized || _nip98Service == null || _relayManagerUrl == null) {
      return false;
    }

    final lastJwtRefreshAt = _lastJwtRefreshAt;
    final now = _now();
    if (lastJwtRefreshAt != null &&
        now.difference(lastJwtRefreshAt) < _jwtRefreshReuseWindow) {
      Log.debug(
        'Zendesk JWT refresh skipped - recent token still fresh',
        category: LogCategory.system,
      );
      return true;
    }

    try {
      final refreshJwt = _jwtIdentityRefreshOverride ?? setJwtIdentity;
      final result = await refreshJwt(
        nip98Service: _nip98Service!,
        relayManagerUrl: _relayManagerUrl!,
      );
      if (result) {
        _lastJwtRefreshAt = _now();
        Log.info(
          'Zendesk JWT refreshed before SDK action',
          category: LogCategory.system,
        );
      }
      return result;
    } catch (e) {
      Log.warning(
        'Zendesk JWT refresh failed (will attempt SDK action anyway): $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Fetches a pre-auth token from relay-manager by proving identity via NIP-98.
  ///
  /// The token is HMAC-signed and nonce-bound — it replaces the raw npub
  /// as the Zendesk SDK user_token to prevent impersonation.
  ///
  /// Throws [Exception] if the pre-auth request fails.
  static Future<String> fetchPreAuthToken({
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
    http.Client? httpClient,
  }) async {
    // Signed and requested must be the same string: relay-manager compares
    // the NIP-98 `u` tag to the request URL exactly, and `Uri.parse`
    // normalizes host case, a default port and dot segments.
    //
    // The trailing slash is trimmed first, as the other NIP-98 clients do.
    // `Uri.parse` does not collapse `//`, so a caller-supplied base ending in
    // one would post to `//api/zendesk/pre-auth`. Signed would still equal
    // sent, so NIP-98 passes and only the path is wrong.
    final base = relayManagerUrl.endsWith('/')
        ? relayManagerUrl.substring(0, relayManagerUrl.length - 1)
        : relayManagerUrl;
    final uri = Uri.parse('$base/api/zendesk/pre-auth');
    final url = uri.toString();

    // Clear NIP-98 cache to avoid reusing a token with a stale timestamp.
    // The server requires created_at within 60s, but tokens are cached 10min.
    nip98Service.clearTokenCache();

    final authToken = await nip98Service.createAuthToken(
      url: url,
      method: HttpMethod.post,
    );

    if (authToken == null) {
      throw Exception('Failed to create NIP-98 auth token');
    }

    // Tear-off rather than `httpClient ?? http.Client()`: the top-level
    // `http.post` owns and closes a client per call, so constructing one here
    // to satisfy the fallback would leak it.
    final post = httpClient?.post ?? http.post;
    final response = await post(
      uri,
      headers: {
        'Authorization': authToken.authorizationHeader,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      Log.error(
        'Pre-auth token request failed: ${response.statusCode}',
        category: LogCategory.api,
      );
      throw Exception('Pre-auth request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true || data['token'] == null) {
      throw Exception('Pre-auth response missing token');
    }

    Log.debug(
      'Pre-auth token obtained successfully',
      category: LogCategory.api,
    );

    return data['token'] as String;
  }

  /// Set JWT identity using a pre-auth token obtained via NIP-98.
  ///
  /// Fetches a pre-auth token from relay-manager (proving identity with
  /// the user's private key), then passes it to the Zendesk SDK.
  ///
  /// Returns true if identity was set successfully.
  static Future<bool> setJwtIdentity({
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) async {
    await _awaitInitialization();

    if (!_initialized) {
      Log.warning(
        'Zendesk JWT: SDK not initialized',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final preAuthToken = await fetchPreAuthToken(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      final result = await _channel.invokeMethod('setJwtIdentity', {
        'userToken': preAuthToken,
      });

      if (result == true) {
        Log.info(
          'Zendesk JWT: Identity set with pre-auth token',
          category: LogCategory.system,
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk JWT: Platform error - ${e.code}: ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Zendesk JWT: Error setting identity - $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Format npub for display
  /// CRITICAL: Never truncate Nostr IDs - full npub needed for user identification
  static String _formatNpubForDisplay(String npub) {
    return npub;
  }

  /// Show native Zendesk ticket creation screen
  ///
  /// Presents the native Zendesk UI for creating a support ticket.
  /// Returns true if screen shown, false if Zendesk not initialized.
  ///
  /// If the native SDK returns a `NO_IDENTITY` error, this method
  /// automatically falls back to anonymous identity and retries once.
  static Future<bool> showNewTicketScreen({
    String? subject,
    String? description,
    List<String>? tags,
  }) async {
    await _awaitInitialization();
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket screen',
        category: LogCategory.system,
      );
      return false;
    }

    await _ensureFreshJwt();

    final sanitizedSubject = subject != null
        ? sanitizeDiagnosticText(subject)
        : null;
    final sanitizedDescription = description != null
        ? sanitizeDiagnosticText(description)
        : null;
    try {
      await _channel.invokeMethod('showNewTicket', {
        'subject': sanitizedSubject,
        'description': sanitizedDescription,
        'tags': tags,
      });

      Log.info('Zendesk ticket screen shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket screen: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // NO_IDENTITY: fall back to anonymous identity and retry once.
      if (e.code == 'NO_IDENTITY') {
        Log.info(
          'Retrying ticket screen with anonymous identity fallback',
          category: LogCategory.system,
        );
        final identitySet = await setAnonymousIdentityWithUserInfo();
        if (identitySet) {
          try {
            await _channel.invokeMethod('showNewTicket', {
              'subject': sanitizedSubject,
              'description': sanitizedDescription,
              'tags': tags,
            });
            return true;
          } catch (retryError) {
            Log.error(
              'Retry with anonymous identity also failed: $retryError',
              category: LogCategory.system,
            );
          }
        }
      }
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing Zendesk screen: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Show user's ticket list (support history)
  ///
  /// Presents the native Zendesk UI showing all tickets from this user.
  /// Returns true if screen shown, false if Zendesk not initialized.
  ///
  /// If the native SDK returns a `NO_IDENTITY` error, this method
  /// automatically falls back to anonymous identity and retries once.
  static Future<bool> showTicketListScreen() async {
    await _awaitInitialization();
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    final jwtReady = await _ensureFreshJwt();
    if (!jwtReady) {
      await _setAvailableAnonymousIdentity();
    }

    try {
      await _channel.invokeMethod('showTicketList');
      Log.info('Zendesk ticket list shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // NO_IDENTITY means the native SDK has no identity set.
      // Fall back to anonymous identity and retry once before giving up.
      if (e.code == 'NO_IDENTITY') {
        Log.info(
          'Retrying ticket list with anonymous identity fallback',
          category: LogCategory.system,
        );
        final identitySet = await _setAvailableAnonymousIdentity();
        if (identitySet) {
          try {
            await _channel.invokeMethod('showTicketList');
            return true;
          } catch (retryError) {
            Log.error(
              'Retry with anonymous identity also failed: $retryError',
              category: LogCategory.system,
            );
          }
        }
      }
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing ticket list: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Create a Zendesk ticket programmatically (no UI)
  ///
  /// Creates a support ticket silently in the background without showing any UI.
  /// Useful for automatic content reporting or system-generated tickets.
  /// Returns true if ticket created successfully, false otherwise.
  ///
  /// Platform support:
  /// - iOS: Full support via RequestProvider API (with custom fields)
  /// - Android: Full support via RequestProvider API (with custom fields)
  /// - macOS/Windows: Falls back to REST API
  ///
  /// Custom fields format: [{'id': 12345, 'value': 'some_value'}, ...]
  static Future<bool> createTicket({
    required String subject,
    required String description,
    List<String>? tags,
    int? ticketFormId,
    List<Map<String, dynamic>>? customFields,
    List<String>? attachmentPaths,
  }) async {
    await _awaitInitialization();
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot create ticket',
        category: LogCategory.system,
      );
      return false;
    }

    // Refresh JWT before SDK action. The pre-auth token has a 5-minute TTL,
    // so any delay between login and ticket creation will cause "unauthorized".
    // This gets a fresh token every time, regardless of how long the user waited.
    await _ensureFreshJwt();

    final sanitizedSubject = sanitizeDiagnosticText(subject);
    final sanitizedDescription = sanitizeDiagnosticText(description);
    final sanitizedCustomFields = _sanitizeCustomFields(customFields);
    try {
      final result = await _channel.invokeMethod('createTicket', {
        'subject': sanitizedSubject,
        'description': sanitizedDescription,
        'tags': tags ?? [],
        'ticketFormId': ?ticketFormId,
        if (sanitizedCustomFields != null && sanitizedCustomFields.isNotEmpty)
          'customFields': sanitizedCustomFields,
        if (attachmentPaths != null && attachmentPaths.isNotEmpty)
          'attachmentPaths': attachmentPaths,
      });

      if (result == true) {
        Log.info(
          'Zendesk ticket created successfully: $sanitizedSubject',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to create Zendesk ticket: $sanitizedSubject',
          category: LogCategory.system,
        );
        crashlytics.log(
          'Zendesk SDK returned false for ticket: $sanitizedSubject',
        );
        unawaited(
          crashlytics.recordError(
            Exception('Zendesk SDK returned false'),
            StackTrace.current,
            reason: 'zendesk_sdk_returned_false',
          ),
        );
        return false;
      }
    } on MissingPluginException {
      // Native SDK not available (macOS, Windows, Web)
      // Fall back to REST API
      Log.info(
        'Native createTicket not available, falling back to REST API',
        category: LogCategory.system,
      );
      return createTicketViaApi(
        subject: sanitizedSubject,
        description: sanitizedDescription,
        requesterName: _userName,
        requesterEmail: _userEmail,
        tags: tags,
      );
    } on PlatformException catch (e) {
      if (e.code == 'UPLOAD_FAILED') {
        Log.error(
          'Zendesk attachment upload failed: ${e.message}',
          category: LogCategory.system,
        );
        throw const ZendeskAttachmentUploadException();
      }

      Log.error(
        '❌ Zendesk SDK error: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // JWT pre-auth tokens expire after 5 minutes. If the user reports
      // content later than that, the SDK's JWT callback will fail with
      // "unauthorized". Fall back to anonymous identity (already has
      // name/email from login) and retry before trying the REST API.
      if (e.code == 'CREATE_FAILED' &&
          e.message != null &&
          e.message!.toLowerCase().contains('unauthorized')) {
        Log.info(
          '🔄 JWT expired, retrying with anonymous identity',
          category: LogCategory.system,
        );
        try {
          final anonymousSet = await setAnonymousIdentityWithUserInfo();
          if (anonymousSet) {
            final retryResult = await _channel.invokeMethod('createTicket', {
              'subject': sanitizedSubject,
              'description': sanitizedDescription,
              'tags': tags ?? [],
              'ticketFormId': ?ticketFormId,
              if (sanitizedCustomFields != null &&
                  sanitizedCustomFields.isNotEmpty)
                'customFields': sanitizedCustomFields,
              if (attachmentPaths != null && attachmentPaths.isNotEmpty)
                'attachmentPaths': attachmentPaths,
            });
            if (retryResult == true) {
              Log.info(
                'Zendesk ticket created on retry with anonymous identity',
                category: LogCategory.system,
              );
              return true;
            }
          }
        } catch (retryError) {
          Log.warning(
            'Anonymous identity retry also failed: $retryError',
            category: LogCategory.system,
          );
        }
      }

      // Fall back to REST API on SDK error
      Log.info(
        '🔄 Falling back to REST API after SDK error',
        category: LogCategory.system,
      );
      return createTicketViaApi(
        subject: sanitizedSubject,
        description: sanitizedDescription,
        requesterName: _userName,
        requesterEmail: _userEmail,
        tags: tags,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Unexpected error creating Zendesk ticket: $e',
        category: LogCategory.system,
      );
      crashlytics.log('Zendesk createTicket failed: $sanitizedSubject');
      unawaited(
        crashlytics.recordError(
          e,
          stackTrace,
          reason: 'zendesk_ticket_unexpected_error',
        ),
      );
      return false;
    }
  }

  // ========================================================================
  // REST API Methods (for platforms without native SDK: macOS, Windows, Web)
  //
  // macOS builds are internal-only. These methods require ZENDESK_API_TOKEN
  // (basic auth), which is NOT configured in Codemagic production builds.
  // Internal users report bugs via Slack/GitHub instead.
  // ========================================================================

  /// Check if REST API is available (for platforms without native SDK)
  static bool get isRestApiAvailable => ZendeskConfig.isRestApiConfigured;

  /// Build requester object with optional external_id for JWT identity linking
  static Map<String, dynamic> _buildRequester({String? name, String? email}) {
    final requester = <String, dynamic>{
      'name': name ?? _userName ?? 'Divine App User',
      'email': email ?? _userEmail ?? ZendeskConfig.apiEmail,
    };
    if (_userNpub != null) {
      requester['external_id'] = _userNpub;
    }
    return requester;
  }

  /// Create a Zendesk ticket via REST API (no native SDK required)
  ///
  /// This works on ALL platforms including macOS, Windows, and Web.
  /// Uses the Zendesk Support API with token authentication.
  /// Returns true if ticket created successfully, false otherwise.
  static Future<bool> createTicketViaApi({
    required String subject,
    required String description,
    String? requesterEmail,
    String? requesterName,
    List<String>? tags,
  }) async {
    if (!ZendeskConfig.isRestApiConfigured) {
      Log.error(
        '❌ Zendesk REST API not configured - ZENDESK_API_TOKEN not set in build',
        category: LogCategory.system,
      );
      return false;
    }

    final sanitizedSubject = sanitizeDiagnosticText(subject);
    final sanitizedDescription = sanitizeDiagnosticText(description);
    try {
      Log.info(
        'Creating Zendesk ticket via REST API: $sanitizedSubject',
        category: LogCategory.system,
      );

      final requestBody = {
        'ticket': {
          'subject': sanitizedSubject,
          'comment': {'body': sanitizedDescription},
          'requester': _buildRequester(
            name: requesterName,
            email: requesterEmail,
          ),
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      };

      // Use /api/v2/tickets (agent API) instead of /api/v2/requests (end-user API)
      // to avoid Zendesk's anonymous request email verification (Mar 2026 rollout)
      const apiUrl = '${ZendeskConfig.zendeskUrl}/api/v2/tickets.json';

      // Create Basic Auth header: email/token:api_token
      const credentials =
          '${ZendeskConfig.apiEmail}/token:${ZendeskConfig.apiToken}';
      final encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final ticketId = responseData['ticket']?['id'];
        Log.info(
          '✅ Zendesk ticket created via API: #$ticketId - $sanitizedSubject',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.error(
          'Zendesk API error: ${response.statusCode} - ${response.body}',
          category: LogCategory.system,
        );
        crashlytics.log(
          'Zendesk REST API error ${response.statusCode}: $sanitizedSubject',
        );
        unawaited(
          crashlytics.recordError(
            Exception('Zendesk REST API HTTP error'),
            StackTrace.current,
            reason: 'zendesk_rest_api_http_error',
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception creating Zendesk ticket via API: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      crashlytics.log(
        'Zendesk REST API exception for ticket: $sanitizedSubject',
      );
      unawaited(
        crashlytics.recordError(
          e,
          stackTrace,
          reason: 'zendesk_rest_api_exception',
        ),
      );
      return false;
    }
  }

  /// Create a structured bug report with user-provided fields
  ///
  /// This method submits bug reports via native SDK (iOS/Android) or REST API
  /// (desktop). Using SDK ensures tickets are linked to the user's identity
  /// and visible in "View Past Messages".
  ///
  /// Custom field IDs (configured in Zendesk):
  /// - 14772963437071: ticket_form_id (Bug Report form)
  /// - 14332953477519: Ticket Type (incident)
  /// - 14884176561807: Platform (ios/android/macos/etc)
  /// - 14884157556111: OS Version
  /// - 14884184890511: Build Number
  /// - 14677364166031: Steps to Reproduce
  /// - 14677341431695: Expected Behavior
  static Future<bool> createStructuredBugReport({
    required String subject,
    required String description,
    required String reportId,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? currentScreen,
    String? userPubkey,
    Map<String, int>? errorCounts,
    String? logsSummary,
    List<String>? attachmentPaths,
  }) async {
    Log.info(
      'Creating structured Zendesk bug report: $reportId',
      category: LogCategory.system,
    );

    // Extract platform info for custom fields
    final platform =
        deviceInfo['platform']?.toString().toLowerCase() ?? 'unknown';
    final osVersion =
        deviceInfo['version']?.toString() ??
        deviceInfo['systemVersion']?.toString() ??
        'unknown';
    // appVersion format is "1.2.3+456" - extract build number after +
    final buildNumber = appVersion.contains('+')
        ? appVersion.split('+').last
        : appVersion;

    // Build comprehensive ticket description
    // Lead with subject so Zendesk SDK ticket list preview is recognizable
    // (SDK shows first line of description body, not the subject field)
    final effectiveSubject = subject.isNotEmpty
        ? subject
        : 'Bug Report: $reportId';
    // Every contributed value is sanitized here, before assembly, rather than
    // once over the finished description. Redaction consumes a bounded run of
    // text around what it matches, so sanitizing the assembled blob lets an
    // unbalanced `{` in one typed field erase the fields printed after it -
    // device info, pubkey, logs - and the ticket arrives empty with nothing
    // saying why. Per-field keeps that blast radius inside the field that
    // caused it. `createTicket` sanitizes the assembled result again as
    // defense in depth; the pass is idempotent.
    final buffer = StringBuffer();
    buffer.writeln(sanitizeDiagnosticText(effectiveSubject));
    buffer.writeln();
    buffer.writeln(sanitizeDiagnosticText(description));
    buffer.writeln();
    buffer.writeln('App Version: ${sanitizeDiagnosticText(appVersion)}');
    buffer.writeln();
    if (stepsToReproduce != null && stepsToReproduce.isNotEmpty) {
      buffer.writeln('### Steps to Reproduce');
      buffer.writeln(sanitizeDiagnosticText(stepsToReproduce));
      buffer.writeln();
    }
    if (expectedBehavior != null && expectedBehavior.isNotEmpty) {
      buffer.writeln('### Expected Behavior');
      buffer.writeln(sanitizeDiagnosticText(expectedBehavior));
      buffer.writeln();
    }
    buffer.writeln('### Device Information');
    deviceInfo.forEach((key, value) {
      // The composed line, not the value alone: the rules match a credential
      // *key* next to its value, so sanitizing `$value` by itself hands them a
      // bare string with no key attached and `sessionKey: <secret>` survives.
      // One line is still a tight enough unit to bound the blast radius.
      buffer.writeln(sanitizeDiagnosticText('- **$key:** $value'));
    });
    if (currentScreen != null) {
      buffer.writeln();
      buffer.writeln(
        '**Current Screen:** ${sanitizeDiagnosticText(currentScreen)}',
      );
    }
    final effectivePubkey = userPubkey ?? _userNpub;
    if (effectivePubkey != null) {
      buffer.writeln('**User Pubkey:** ${pubkeyForLogs(effectivePubkey)}');
    }
    if (errorCounts != null && errorCounts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent Error Summary');
      final sortedErrors = errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedErrors.take(10)) {
        buffer.writeln(
          sanitizeDiagnosticText('- ${entry.key}: ${entry.value} occurrences'),
        );
      }
    }
    if (logsSummary != null && logsSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent Logs (errors/warnings + recent context)');
      buffer.writeln('```');
      buffer.writeln(logsSummary);
      buffer.writeln('```');
    }

    final tags = ['bug_report', 'divine_app', 'mobile', platform];

    // Build custom fields list for SDK
    final customFields = <Map<String, dynamic>>[
      {'id': 14332953477519, 'value': 'incident'}, // Ticket Type
      {'id': 14884176561807, 'value': platform}, // Platform
      {'id': 14884157556111, 'value': osVersion}, // OS Version
      {'id': 14884184890511, 'value': buildNumber}, // Build Number
    ];

    // Add optional text fields if provided
    if (stepsToReproduce != null && stepsToReproduce.isNotEmpty) {
      customFields.add({
        'id': 14677364166031,
        'value': stepsToReproduce,
      }); // Steps to Reproduce
    }
    if (expectedBehavior != null && expectedBehavior.isNotEmpty) {
      customFields.add({
        'id': 14677341431695,
        'value': expectedBehavior,
      }); // Expected Behavior
    }

    // Try native SDK first (iOS/Android) - this links tickets to user identity
    if (_initialized) {
      Log.info(
        '🎫 Using native SDK for bug report (enables View Past Messages)',
        category: LogCategory.system,
      );
      return createTicket(
        subject: effectiveSubject,
        description: buffer.toString(),
        tags: tags,
        ticketFormId: 14772963437071,
        customFields: customFields,
        attachmentPaths: attachmentPaths,
      );
    }

    // Fall back to REST API for desktop platforms (macOS internal builds only)
    Log.info(
      '🎫 Native SDK not available, using REST API fallback',
      category: LogCategory.system,
    );
    return _createTicketWithFormViaApi(
      subject: effectiveSubject,
      description: buffer.toString(),
      tags: tags,
      customFields: customFields,
      ticketFormId: 14772963437071,
      label: 'bug report',
    );
  }

  /// Internal: Create ticket via REST API with form and custom fields
  static Future<bool> _createTicketWithFormViaApi({
    required String subject,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> customFields,
    required int ticketFormId,
    required String label,
  }) async {
    if (!ZendeskConfig.isRestApiConfigured) {
      Log.error(
        '❌ Zendesk REST API not configured - ZENDESK_API_TOKEN not set',
        category: LogCategory.system,
      );
      return false;
    }

    final sanitizedSubject = sanitizeDiagnosticText(subject);
    final sanitizedDescription = sanitizeDiagnosticText(description);
    final sanitizedCustomFields = _sanitizeCustomFields(customFields) ?? [];
    try {
      final requestBody = {
        'ticket': {
          'subject': sanitizedSubject,
          'comment': {'body': sanitizedDescription},
          'requester': _buildRequester(),
          'ticket_form_id': ticketFormId,
          'tags': tags,
          'custom_fields': sanitizedCustomFields,
        },
      };

      const apiUrl = '${ZendeskConfig.zendeskUrl}/api/v2/tickets.json';
      const credentials =
          '${ZendeskConfig.apiEmail}/token:${ZendeskConfig.apiToken}';
      final encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final ticketId = responseData['ticket']?['id'];
        Log.info(
          '✅ Zendesk $label created via API: #$ticketId',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.error(
          'Zendesk API error: ${response.statusCode} - ${response.body}',
          category: LogCategory.system,
        );
        crashlytics.log(
          'Zendesk form API error ${response.statusCode}: $label',
        );
        unawaited(
          crashlytics.recordError(
            Exception('Zendesk form API HTTP error'),
            StackTrace.current,
            reason: 'zendesk_form_api_http_error',
          ),
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception creating Zendesk $label via API: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      crashlytics.log('Zendesk form API exception for: $label');
      unawaited(
        crashlytics.recordError(
          e,
          stackTrace,
          reason: 'zendesk_form_api_exception',
        ),
      );
      return false;
    }
  }

  // ==========================================================================
  // Feature Requests
  // ==========================================================================

  /// Create a feature request ticket
  ///
  /// Custom field IDs (configured in Zendesk):
  /// - 15081095878799: ticket_form_id (Feature Request form)
  /// - 15081108558863: How would this be useful for you?
  /// - 15081142424847: When would you use this?
  static Future<bool> createFeatureRequest({
    required String subject,
    required String description,
    String? usefulness,
    String? whenToUse,
    String? userPubkey,
  }) async {
    Log.info(
      '💡 Creating Zendesk feature request',
      category: LogCategory.system,
    );

    // Build ticket description
    // Lead with subject so Zendesk SDK ticket list preview is recognizable
    // (SDK shows first line of description body, not the subject field)
    final effectiveSubject = subject.isNotEmpty ? subject : 'Feature Request';
    // Per-field, before assembly, for the same reason as the bug report
    // builder: redaction spans lines, so sanitizing the finished blob lets one
    // typed field erase the ones printed after it.
    final buffer = StringBuffer();
    buffer.writeln(sanitizeDiagnosticText(effectiveSubject));
    buffer.writeln();
    buffer.writeln(sanitizeDiagnosticText(description));
    if (usefulness != null && usefulness.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### How would this be useful for you?');
      buffer.writeln(sanitizeDiagnosticText(usefulness));
    }
    if (whenToUse != null && whenToUse.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### When would you use this?');
      // No test distinguishes this call from the whole-ticket pass in
      // `createTicket`, because nothing user-controlled is appended after it -
      // the containment it provides has nothing left to contain. Keep it: it
      // stops being redundant the moment a section is added below.
      buffer.writeln(sanitizeDiagnosticText(whenToUse));
    }
    final effectivePubkey = userPubkey ?? _userNpub;
    if (effectivePubkey != null) {
      buffer.writeln();
      buffer.writeln('**User Pubkey:** ${pubkeyForLogs(effectivePubkey)}');
    }

    final tags = ['feature_request', 'divine_app', 'mobile'];

    // Build custom fields list
    final customFields = <Map<String, dynamic>>[];
    if (usefulness != null && usefulness.isNotEmpty) {
      customFields.add({
        'id': 15081108558863,
        'value': usefulness,
      }); // How would this be useful for you?
    }
    if (whenToUse != null && whenToUse.isNotEmpty) {
      customFields.add({
        'id': 15081142424847,
        'value': whenToUse,
      }); // When would you use this?
    }

    // Try native SDK first (iOS/Android) - this links tickets to user identity
    if (_initialized) {
      Log.info(
        '💡 Using native SDK for feature request (enables View Past Messages)',
        category: LogCategory.system,
      );
      return createTicket(
        subject: effectiveSubject,
        description: buffer.toString(),
        tags: tags,
        ticketFormId: 15081095878799,
        customFields: customFields,
      );
    }

    // Fall back to REST API for desktop platforms (macOS internal builds only)
    Log.info(
      '💡 Native SDK not available, using REST API fallback',
      category: LogCategory.system,
    );
    return _createTicketWithFormViaApi(
      subject: effectiveSubject,
      description: buffer.toString(),
      tags: tags,
      customFields: customFields,
      ticketFormId: 15081095878799,
      label: 'feature request',
    );
  }
}
