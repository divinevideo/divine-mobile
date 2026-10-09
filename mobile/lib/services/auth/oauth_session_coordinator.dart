// ABOUTME: Single-flight coordinator for Divine/Keycast OAuth session refresh.
// ABOUTME: Owns the dedup futures + timeouts so concurrent 401s, app-resume,
// ABOUTME: and expired-session recovery share one refresh-token exchange.

import 'dart:async';

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Coordinates OAuth session refresh so concurrent callers never race on a
/// one-time-use refresh token.
///
/// Extracted from `AuthService` (#4741, repository tier). Unlike the other
/// collaborators this one is STATEFUL: it owns the two single-flight futures
/// ([_pendingOAuthRefresh]/[_pendingRefresh]) — process-lifetime concurrency
/// state, not per-call snapshots. The facade retains ownership of the
/// `_hasExpiredOAuthSession` flag (written by restore orchestration) and all
/// result application (rebuilding the signer, `signInWithDivineOAuth`), reached
/// here through the injected ports so behavior is preserved exactly.
class OAuthSessionCoordinator {
  OAuthSessionCoordinator({
    required KeycastOAuth? oauthClient,
    required Duration oauthRefreshTimeout,
    required Duration expiredSessionRefreshTimeout,
    required String? Function() currentPubkeyFallback,
    required bool Function() hasExpiredSession,
  }) : _oauthClient = oauthClient,
       _oauthRefreshTimeout = oauthRefreshTimeout,
       _expiredSessionRefreshTimeout = expiredSessionRefreshTimeout,
       _currentPubkeyFallback = currentPubkeyFallback,
       _hasExpiredSession = hasExpiredSession;

  final KeycastOAuth? _oauthClient;
  final Duration _oauthRefreshTimeout;
  final Duration _expiredSessionRefreshTimeout;
  final String? Function() _currentPubkeyFallback;
  final bool Function() _hasExpiredSession;

  Future<bool>? _pendingRefresh;
  Future<KeycastSession?>? _pendingOAuthRefresh;

  /// Runs [attempt] under an outer single-flight, bounded by
  /// [expiredSessionRefreshTimeout], to silently refresh an expired OAuth
  /// session. [attempt] performs the refresh + result application (the caller
  /// wires it to `_tryRefreshOAuthSession`).
  ///
  /// No-ops (returns false) unless [hasExpiredSession] and an OAuth client are
  /// both present. Concurrent callers share the in-flight attempt; the shared
  /// future always releases the slot even on a hung request (#4942).
  Future<bool> refreshExpiredSession({
    required Future<bool> Function() attempt,
  }) {
    if (!_hasExpiredSession() || _oauthClient == null) {
      return Future.value(false);
    }
    final pending = _pendingRefresh;
    if (pending != null) return pending;

    late final Future<bool> refresh;
    refresh = attempt()
        .timeout(
          _expiredSessionRefreshTimeout,
          onTimeout: () {
            Log.warning(
              'tryRefreshExpiredSession: timed out after '
              '${_expiredSessionRefreshTimeout.inMilliseconds}ms — '
              'treating as failed',
              name: 'OAuthSessionCoordinator',
              category: LogCategory.auth,
            );
            return false;
          },
        )
        .whenComplete(() {
          // Only release the slot if it still holds this attempt — signOut
          // may have detached it and a fresh attempt may already be in
          // flight.
          if (identical(_pendingRefresh, refresh)) {
            _pendingRefresh = null;
          }
        });
    return _pendingRefresh = refresh;
  }

  /// Single-flight OAuth session refresh. Every code path that needs a fresh
  /// [KeycastSession] MUST call this instead of `KeycastOAuth.refreshSession()`
  /// directly.
  ///
  /// Guarantees:
  /// - Only one `refreshSession()` call in flight at a time (concurrent
  ///   callers share the same [Future]).
  /// - The shared future is bounded by [oauthRefreshTimeout] and ALWAYS
  ///   releases the single-flight slot, even if the underlying request hangs
  ///   on a dead socket — so the next attempt gets a fresh refresh instead of
  ///   joining a poisoned one (#4942).
  /// - `userPubkey` is bound before the session is persisted, so ownership
  ///   checks on restore stay valid.
  /// - The caller owns result application after any account-currentness checks.
  ///
  /// [expectedOwnerPubkey] binds the refreshed session to a specific account.
  /// Callers that hold a stored session should pass its `userPubkey`;
  /// mid-session callers (401 retry, app resume) may omit it — the method
  /// falls back to [currentPubkeyFallback].
  ///
  /// Returns the refreshed session on success, or `null` when refresh is not
  /// possible or the server rejects the token.
  ///
  /// Throws [OAuthNetworkException] when the refresh cannot reach Keycast,
  /// times out, or gets a temporary server error. The refresh token is
  /// preserved for a later retry in that case.
  Future<KeycastSession?> refreshSession({
    String? expectedOwnerPubkey,
    Duration? timeout,
    Future<KeycastSession?> Function()? storedSessionReader,
    String? caller,
  }) {
    final pending = _pendingOAuthRefresh;
    if (pending != null) {
      return _guardRefreshForCaller(
        pending,
        expectedOwnerPubkey: expectedOwnerPubkey,
        timeout: timeout,
        storedSessionReader: storedSessionReader,
        caller: caller,
      );
    }

    late final Future<KeycastSession?> refresh;
    refresh =
        _doRefreshSession(
              expectedOwnerPubkey: expectedOwnerPubkey,
              storedSessionReader: storedSessionReader,
              caller: caller,
            )
            .timeout(
              _oauthRefreshTimeout,
              onTimeout: () {
                Log.warning(
                  '_refreshOAuthSession: timed out after '
                  '${_oauthRefreshTimeout.inMilliseconds}ms — '
                  'treating as network failure',
                  name: 'OAuthSessionCoordinator',
                  category: LogCategory.auth,
                );
                throw OAuthNetworkException('OAuth refresh timed out');
              },
            )
            .whenComplete(() {
              // Only release the slot if it still holds this attempt — signOut
              // may have detached it and a fresh attempt may already be in
              // flight.
              if (identical(_pendingOAuthRefresh, refresh)) {
                _pendingOAuthRefresh = null;
              }
            });
    return _pendingOAuthRefresh = refresh;
  }

  Future<KeycastSession?> _doRefreshSession({
    String? expectedOwnerPubkey,
    Future<KeycastSession?> Function()? storedSessionReader,
    String? caller,
  }) async {
    final oauthClient = _oauthClient;
    if (oauthClient == null) return null;
    try {
      if (expectedOwnerPubkey != null &&
          storedSessionReader != null &&
          !await _storedOwnerMatches(
            expectedOwnerPubkey,
            storedSessionReader,
            caller,
          )) {
        return null;
      }

      final pubkey = expectedOwnerPubkey ?? _currentPubkeyFallback();
      final refreshed = await oauthClient.refreshSession(userPubkey: pubkey);
      if (refreshed == null || !refreshed.hasRpcAccess) return null;

      Log.info(
        '_refreshOAuthSession: succeeded '
        '(userPubkey=${refreshed.userPubkey != null ? "bound" : "unbound"})',
        name: 'OAuthSessionCoordinator',
        category: LogCategory.auth,
      );
      return refreshed;
    } on OAuthNetworkException {
      rethrow;
    } catch (e) {
      Log.error(
        '_refreshOAuthSession: failed: $e',
        name: 'OAuthSessionCoordinator',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  Future<KeycastSession?> _guardRefreshForCaller(
    Future<KeycastSession?> refresh, {
    String? expectedOwnerPubkey,
    Duration? timeout,
    Future<KeycastSession?> Function()? storedSessionReader,
    String? caller,
  }) async {
    if (expectedOwnerPubkey != null &&
        storedSessionReader != null &&
        !await _storedOwnerMatches(
          expectedOwnerPubkey,
          storedSessionReader,
          caller,
        )) {
      return null;
    }

    final guardedRefresh = timeout == null
        ? refresh
        : refresh.timeout(
            timeout,
            onTimeout: () {
              Log.warning(
                '_refreshOAuthSession: timed out after '
                '${timeout.inMilliseconds}ms — treating as network failure',
                name: 'OAuthSessionCoordinator',
                category: LogCategory.auth,
              );
              throw OAuthNetworkException('OAuth refresh timed out');
            },
          );
    final refreshed = await guardedRefresh;
    if (expectedOwnerPubkey != null &&
        refreshed != null &&
        refreshed.userPubkey != expectedOwnerPubkey) {
      _logOwnerMismatch(
        caller,
        expectedOwnerPubkey,
        refreshed.userPubkey,
        'refreshed',
      );
      return null;
    }
    return refreshed;
  }

  Future<bool> _storedOwnerMatches(
    String expectedOwnerPubkey,
    Future<KeycastSession?> Function() storedSessionReader,
    String? caller,
  ) async {
    final activeSession = await _oauthClient?.getSession();
    if (activeSession != null &&
        activeSession.userPubkey != expectedOwnerPubkey) {
      _logOwnerMismatch(
        caller,
        expectedOwnerPubkey,
        activeSession.userPubkey,
        'active',
      );
      return false;
    }
    final storedSession = await storedSessionReader();
    if (storedSession != null &&
        storedSession.userPubkey != expectedOwnerPubkey) {
      _logOwnerMismatch(
        caller,
        expectedOwnerPubkey,
        storedSession.userPubkey,
        'stored',
      );
      return false;
    }
    return true;
  }

  void _logOwnerMismatch(
    String? caller,
    String expectedOwnerPubkey,
    String? actualOwnerPubkey,
    String source,
  ) {
    Log.warning(
      '${caller ?? '_refreshOAuthSession'}: refusing $source OAuth session '
      'for owner ${pubkeyForLogs(expectedOwnerPubkey)} because it belongs to ${pubkeyForLogs(actualOwnerPubkey)}',
      name: 'OAuthSessionCoordinator',
      category: LogCategory.auth,
    );
  }

  /// [TokenRefreshCallback] passed to [KeycastRpc] so it can recover from
  /// mid-session 401s without caller involvement.
  ///
  /// Delegates to [refreshSession] which deduplicates concurrent callers —
  /// multiple in-flight RPC 401s and app-resume refresh all share a single
  /// refresh token exchange.
  Future<String?> refreshAccessToken() async {
    final KeycastSession? refreshed;
    try {
      refreshed = await refreshSession();
    } on OAuthNetworkException {
      return null;
    }
    return refreshed?.accessToken;
  }

  /// Returns an access token only when the stored OAuth session belongs to
  /// [expectedOwnerPubkey].
  ///
  /// Expired sessions are checked through [storedSessionReader] before the
  /// single-flight refresh starts, preventing a refresh token from one account
  /// being rebound to another account. Concurrent refreshes share the same
  /// operation via [refreshSession].
  Future<String?> accessTokenForOwner({
    required String expectedOwnerPubkey,
    required Future<KeycastSession?> Function() storedSessionReader,
  }) async {
    final oauthClient = _oauthClient;
    if (oauthClient == null) return null;

    final activeSession = await oauthClient.getSession();
    if (activeSession != null) {
      if (activeSession.userPubkey != expectedOwnerPubkey) return null;
      return activeSession.accessToken;
    }

    final storedSession = await storedSessionReader();
    if (storedSession != null &&
        storedSession.userPubkey != expectedOwnerPubkey) {
      return null;
    }

    final refreshed = await refreshSession(
      expectedOwnerPubkey: expectedOwnerPubkey,
    );
    if (refreshed?.userPubkey != expectedOwnerPubkey) return null;
    return refreshed?.accessToken;
  }

  /// Detaches any in-flight refresh so a post-sign-out login starts a fresh
  /// attempt instead of joining one issued for the outgoing session.
  ///
  /// The futures cannot be cancelled, but their completion handlers only
  /// release the slot they still own (identical check), so a late completion
  /// cannot clobber a newer attempt. Deliberately does NOT touch the facade's
  /// expired-session flag — sign-out clears the futures but not that flag.
  void detach() {
    _pendingOAuthRefresh = null;
    _pendingRefresh = null;
  }
}
