// ABOUTME: Result of an authentication operation — success plus an optional key
// ABOUTME: container, error message, or nostrconnect:// failure reason. Lifted
// ABOUTME: out of auth_service.dart (#4741) so auth/ collaborators can return it
// ABOUTME: without importing the facade (which would be a cycle); re-exported by
// ABOUTME: auth_service.dart so existing consumers keep their import.

import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;
import 'package:nostr_sdk/nostr_sdk.dart' show NostrConnectFailureReason;

enum AuthFailureReason { incorrectPassword, accountCleanupFailed }

/// Result of authentication operations
class AuthResult {
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyContainer,
    this.nostrConnectFailureReason,
    this.failureReason,
  });

  factory AuthResult.success(SecureKeyContainer keyContainer) =>
      AuthResult(success: true, keyContainer: keyContainer);

  factory AuthResult.failure(String errorMessage) =>
      AuthResult(success: false, errorMessage: errorMessage);

  factory AuthResult.incorrectPassword() => const AuthResult(
    success: false,
    errorMessage: 'Incorrect password',
    failureReason: AuthFailureReason.incorrectPassword,
  );

  /// Failure result for the nostrconnect:// flow, carrying a localizable
  /// reason code instead of a raw English string. The UI maps the reason to a
  /// `context.l10n.*` string.
  factory AuthResult.nostrConnectFailure(NostrConnectFailureReason reason) =>
      AuthResult(success: false, nostrConnectFailureReason: reason);

  final bool success;
  final String? errorMessage;
  final SecureKeyContainer? keyContainer;

  /// Set only by the nostrconnect:// failure path; `null` for every other flow.
  final NostrConnectFailureReason? nostrConnectFailureReason;

  /// A localizable reason for authentication failures with actionable UI copy.
  final AuthFailureReason? failureReason;
}
