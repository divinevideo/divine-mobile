// ABOUTME: Preserves typed account cleanup failures through login outcomes.
// ABOUTME: Retires tentative session state when storage cleanup cannot finish.

part of '../auth_service.dart';

extension _AccountCleanupFailure on AuthService {
  AuthResult _authFailureResult(Object error) =>
      error is UserDataCleanupException
      ? const AuthResult(
          success: false,
          failureReason: AuthFailureReason.accountCleanupFailed,
        )
      : AuthResult.failure(_lastError!);

  void _resetTentativeSessionAfterCleanupFailure() {
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
