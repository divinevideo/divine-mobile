// ABOUTME: Cubit behind "Email me a link" for accounts created with Google or
// ABOUTME: Apple, which have no password until they set one from that link

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

/// Where a request for a password-setup link stands.
enum PasswordSetupStatus {
  /// Nothing asked for yet.
  idle,

  /// The request is on its way to Keycast.
  sending,

  /// Keycast accepted it; the link goes to the account's email.
  sent,

  /// The session can no longer authorize it; only signing in again helps.
  needsSignIn,

  /// The request never reached a verdict. Asking again may work.
  failed,
}

/// Asks Keycast to email a link that sets a first password.
///
/// An account created with Google or Apple has no password, and Keycast only
/// starts that setup for a request carrying the account's own session, so the
/// public "Forgot password" form cannot do it.
class PasswordSetupCubit extends Cubit<PasswordSetupStatus>
    with CloseGuardedEmit<PasswordSetupStatus> {
  PasswordSetupCubit({required AccountCredentialsRepository repository})
    : _repository = repository,
      super(PasswordSetupStatus.idle);

  final AccountCredentialsRepository _repository;

  /// Request the link. Ignored while a request is running or once one was
  /// accepted, so a double tap sends one email.
  Future<void> requestLink() async {
    if (state == PasswordSetupStatus.sending ||
        state == PasswordSetupStatus.sent) {
      return;
    }
    emit(PasswordSetupStatus.sending);
    final result = await _repository.requestPasswordSetup();
    emitIfOpen(switch (result) {
      PasswordSetupRequestResult.requested => PasswordSetupStatus.sent,
      PasswordSetupRequestResult.needsSignIn => PasswordSetupStatus.needsSignIn,
      PasswordSetupRequestResult.failed => PasswordSetupStatus.failed,
    });
  }
}
