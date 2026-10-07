// ABOUTME: Preserves typed account cleanup failures through login outcomes.
// ABOUTME: Retires tentative session state when storage cleanup cannot finish.

part of '../auth_service.dart';

extension _AccountCleanupFailure on AuthService {
  /// An interrupted non-destructive identity sweep stays an entry gate, but
  /// must not tear down the same established live account during refresh.
  bool _canDeferPendingCleanupForLiveSession(
    SharedPreferences prefs, {
    required String incomingPubkey,
    required NostrIdentity? establishedSession,
    required NostrIdentity? tentativeIdentity,
    required SecureKeyContainer expectedKeyContainer,
  }) {
    if (tentativeIdentity == null ||
        !identical(_currentIdentity, tentativeIdentity) ||
        !identical(_currentKeyContainer, expectedKeyContainer) ||
        establishedSession?.pubkey != incomingPubkey ||
        currentPublicKeyHex != incomingPubkey ||
        (_authState != AuthState.authenticated &&
            _authState != AuthState.authenticating) ||
        prefs.getString('current_user_pubkey_hex') != incomingPubkey) {
      return false;
    }
    // getString casts its cached value. A non-string marker must take the
    // existing fail-closed path without catching unrelated TypeErrors here.
    if (prefs.get(PendingAccountCleanup.storageKey) is! String) return false;
    try {
      final pending = PendingAccountCleanup.read(prefs);
      return pending != null &&
          pending.userPubkey == incomingPubkey &&
          pending.isIdentityChange &&
          !pending.deleteUserData;
    } on FormatException {
      // Malformed JSON enters the existing typed cleanup-failure path.
      return false;
      // PendingAccountCleanup.read deliberately rejects persisted invalid
      // intent shapes with StateError; only that parser contract is handled.
      // ignore: avoid_catching_errors
    } on StateError {
      // read() rejects null/invalid intent shape with StateError.
      return false;
    }
  }

  AuthResult _authFailureResult(Object error) =>
      error is UserDataCleanupException
      ? const AuthResult(
          success: false,
          failureReason: AuthFailureReason.accountCleanupFailed,
        )
      : AuthResult.failure(_lastError!);

  void _resetTentativeSessionAfterCleanupFailure() {
    _lastFailureReason = AuthFailureReason.accountCleanupFailed;
    // Storage cleanup must finish before any incoming identity becomes live.
    // Terms acceptance cannot repair a refused cache removal.
    _currentIdentity = null;
    _currentKeyContainer = null;
    _currentProfile = null;
    _authSource = AuthenticationSource.none;
    _profileController.add(null);
    _setAuthState(AuthState.unauthenticated);
  }
}
