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

  /// Points the cubit at [account], the signed-in account's public key, or
  /// nobody when it is null, then checks it with Keycast.
  ///
  /// Starts from the last answer remembered for the account, so an account
  /// known to be unconfirmed is locked from the first frame rather than only
  /// once the network answers.
  Future<void> loadFor(String? account) async {
    if (account == state.account) return refresh();
    emitIfOpen(
      account == null
          ? const EmailConfirmationState()
          : EmailConfirmationState.fromConfirmation(
              account,
              _repository.remembered(account),
            ),
    );
    await refresh();
  }

  /// Re-checks the confirmation with Keycast.
  ///
  /// An unknown answer keeps the last known state, so a dropped connection
  /// neither unlocks DMs nor hides the note. Confirmation only moves forward:
  /// an answer saying an address is unconfirmed is dropped once that same
  /// address is known to be confirmed, because it was read before the link
  /// was clicked.
  Future<void> refresh() async {
    final account = state.account;
    if (account == null) return;
    final confirmation = await _repository.fetchStatus(account);
    if (state.account != account) return;
    if (confirmation.kind == EmailConfirmationKind.unknown) return;
    final isStale =
        state.status == EmailConfirmationStatus.confirmed &&
        confirmation.kind == EmailConfirmationKind.unconfirmed &&
        confirmation.email == state.email;
    if (isStale) return;
    emitIfOpen(
      EmailConfirmationState.fromConfirmation(
        account,
        confirmation,
        resendStatus: state.resendStatus,
      ),
    );
    await _repository.remember(account, confirmation);
  }

  /// Keycast refused to sign a direct message for [refusedAccount] because it
  /// sees that account's email as unconfirmed.
  ///
  /// Keycast is the authority, so the account locks again even if the app
  /// had it as confirmed, and then re-checks. A refusal naming another
  /// account is dropped: it arrived after a switch. A signer built from a
  /// session that was not yet bound to its account names nobody, and its
  /// refusal is taken as the signed-in account's.
  Future<void> markUnconfirmedByKeycast(String? refusedAccount) async {
    final account = state.account;
    final email = state.email;
    if (account == null) return;
    if (refusedAccount != null && refusedAccount != account) return;
    if (email != null && !state.isUnconfirmed) {
      final confirmation = EmailConfirmation.unconfirmed(email);
      emitIfOpen(
        EmailConfirmationState.fromConfirmation(
          account,
          confirmation,
          resendStatus: state.resendStatus,
        ),
      );
      await _repository.remember(account, confirmation);
    }
    await refresh();
  }

  /// Keycast refused a post, comment or report because [refusedAccount] used
  /// up the hourly allowance that applies until it confirms its email.
  ///
  /// Dropped when [refusedAccount] names another account, as for
  /// [markUnconfirmedByKeycast].
  void reportCapReached(String? refusedAccount) {
    final account = state.account;
    if (account == null) return;
    if (refusedAccount != null && refusedAccount != account) return;
    emitIfOpen(state.copyWith(capRefusals: state.capRefusals + 1));
  }

  /// Asks Keycast to send a fresh confirmation link.
  ///
  /// When [account] is given, the request is dropped unless that account is
  /// still the signed-in one, so a reminder left over from a previous account
  /// cannot resend for whoever signed in after it.
  Future<void> resend({String? account}) async {
    final current = state.account;
    if (current == null) return;
    if (account != null && account != current) return;
    if (state.resendStatus == EmailConfirmationResendStatus.sending) return;
    emitIfOpen(
      state.copyWith(resendStatus: EmailConfirmationResendStatus.sending),
    );
    final accepted = await _repository.resend(current);
    if (state.account != current) return;
    emitIfOpen(
      state.copyWith(
        resendStatus: accepted
            ? EmailConfirmationResendStatus.sent
            : EmailConfirmationResendStatus.failed,
      ),
    );
  }
}
