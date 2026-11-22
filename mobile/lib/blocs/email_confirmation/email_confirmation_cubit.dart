// ABOUTME: Tracks whether the signed-in account still has to confirm its email
// ABOUTME: and drives the resend action shown on the profile and in Messages.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';

part 'email_confirmation_state.dart';

/// App-wide email confirmation state for the signed-in account.
///
/// Accounts can sign in before confirming their email. Until they do, the
/// profile shows a confirmation note and direct messages stay locked. This
/// cubit is created once above the app and pointed at the signed-in account
/// with [loadFor] whenever that account changes.
class EmailConfirmationCubit extends Cubit<EmailConfirmationState>
    with CloseGuardedEmit<EmailConfirmationState> {
  EmailConfirmationCubit({required EmailConfirmationRepository repository})
    : _repository = repository,
      super(const EmailConfirmationState());

  final EmailConfirmationRepository _repository;

  /// Forgets the previous account and checks [account], the signed-in
  /// account's public key, or nobody when it is null.
  Future<void> loadFor(String? account) async {
    if (account == state.account) return refresh();
    emitIfOpen(EmailConfirmationState(account: account));
    await refresh();
  }

  /// Re-checks the confirmation with Keycast.
  ///
  /// An unknown answer keeps the last known state, so a dropped connection
  /// neither unlocks DMs nor hides the note.
  Future<void> refresh() async {
    final account = state.account;
    if (account == null) return;
    final confirmation = await _repository.fetchStatus();
    if (state.account != account) return;
    if (confirmation.kind == EmailConfirmationKind.unknown) return;
    emitIfOpen(
      state.copyWith(
        status: confirmation.kind == EmailConfirmationKind.unconfirmed
            ? EmailConfirmationStatus.unconfirmed
            : EmailConfirmationStatus.confirmed,
        email: confirmation.email,
      ),
    );
  }

  /// Asks Keycast to send a fresh confirmation link.
  Future<void> resend() async {
    final account = state.account;
    if (account == null) return;
    if (state.resendStatus == EmailConfirmationResendStatus.sending) return;
    emitIfOpen(
      state.copyWith(resendStatus: EmailConfirmationResendStatus.sending),
    );
    final accepted = await _repository.resend();
    if (state.account != account) return;
    emitIfOpen(
      state.copyWith(
        resendStatus: accepted
            ? EmailConfirmationResendStatus.sent
            : EmailConfirmationResendStatus.failed,
      ),
    );
  }
}
