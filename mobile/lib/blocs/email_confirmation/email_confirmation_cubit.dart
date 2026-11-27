// ABOUTME: Tracks whether the signed-in account still has to confirm its email
// ABOUTME: and drives the resend action shown on the profile and in Messages.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';
import 'package:openvine/services/account_state_write_barrier.dart';

part 'email_confirmation_state.dart';

/// App-wide email confirmation state for the signed-in account.
///
/// Accounts can sign in before confirming their email. Until they do, the
/// profile shows a confirmation note and direct messages stay locked. This
/// cubit is created once above the app and pointed at the signed-in account
/// with [loadFor] whenever that account changes.
class EmailConfirmationCubit extends Cubit<EmailConfirmationState>
    with CloseGuardedEmit<EmailConfirmationState> {
  EmailConfirmationCubit({
    required EmailConfirmationRepository repository,
    AccountStateWriteBarrier? accountWrites,
  }) : _repository = repository,
       _accountWrites = accountWrites,
       super(const EmailConfirmationState());

  final EmailConfirmationRepository _repository;
  final AccountStateWriteBarrier? _accountWrites;
  Object? _accountSession = Object();
  Future<void> Function()? _closeAccountWrites;

  /// Points the cubit at [account], the signed-in account's public key, or
  /// nobody when it is null, then checks it with Keycast.
  ///
  /// Starts from the last answer remembered for the account, so an account
  /// known to be unconfirmed is locked from the first frame rather than only
  /// once the network answers.
  Future<void> loadFor(String? account) async {
    if (isClosed) return;
    if (account == state.account) return refresh();

    final closePrevious = _closeAccountWrites;
    final session = _accountSession = Object();
    _closeAccountWrites = account == null
        ? null
        : _accountWrites?.register(account, () async {
            if (!identical(_accountSession, session)) return;
            // Cleanup can start while auth still reports this account. Keep
            // its identity until auth changes, but retire its email work now.
            _accountSession = null;
            emitIfOpen(EmailConfirmationState(account: account));
          });
    emitIfOpen(
      account == null
          ? const EmailConfirmationState()
          : EmailConfirmationState.fromConfirmation(
              account,
              _repository.remembered(account),
            ),
    );
    if (closePrevious != null) await closePrevious();
    if (identical(_accountSession, session)) await refresh();
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
    final session = _accountSession;
    if (account == null || session == null) return;
    final confirmation = await _repository.fetchStatus(account);
    if (!identical(_accountSession, session)) return;
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
    if (identical(_accountSession, session)) {
      await _repository.remember(account, confirmation);
    }
  }

  /// Keycast refused to sign a direct message for [refusedAccount] because it
  /// sees that account's email as unconfirmed.
  ///
  /// Keycast is the authority, so the account locks again even if the app
  /// had it as confirmed or has not learned its address yet, and then
  /// re-checks. A refusal that does not name the signed-in account is dropped:
  /// it arrived after a switch or from an unbound signer.
  Future<void> markUnconfirmedByKeycast(String? refusedAccount) async {
    final account = state.account;
    final email = state.email;
    final session = _accountSession;
    if (account == null || session == null) return;
    if (refusedAccount == null || refusedAccount != account) return;
    if (!state.isUnconfirmed) {
      if (email != null) {
        final confirmation = EmailConfirmation.unconfirmed(email);
        emitIfOpen(
          EmailConfirmationState.fromConfirmation(
            account,
            confirmation,
            resendStatus: state.resendStatus,
          ),
        );
        if (identical(_accountSession, session)) {
          await _repository.remember(account, confirmation);
        }
      } else {
        emitIfOpen(
          EmailConfirmationState(
            account: account,
            status: EmailConfirmationStatus.unconfirmed,
            resendStatus: state.resendStatus,
          ),
        );
      }
    }
    if (identical(_accountSession, session)) await refresh();
  }

  /// Keycast refused a post, comment or report because [refusedAccount] used
  /// up the hourly allowance that applies until it confirms its email.
  ///
  /// Dropped unless [refusedAccount] names the signed-in account, as for
  /// [markUnconfirmedByKeycast].
  void reportCapReached(String? refusedAccount) {
    final account = state.account;
    if (account == null || _accountSession == null) return;
    if (refusedAccount == null || refusedAccount != account) return;
    emitIfOpen(state.copyWith(capRefusals: state.capRefusals + 1));
  }

  /// Asks Keycast to send a fresh confirmation link.
  ///
  /// When [account] is given, the request is dropped unless that account is
  /// still the signed-in one, so a reminder left over from a previous account
  /// cannot resend for whoever signed in after it.
  Future<void> resend({String? account}) async {
    final current = state.account;
    final session = _accountSession;
    if (current == null || session == null) return;
    if (account != null && account != current) return;
    if (state.resendStatus == EmailConfirmationResendStatus.sending) return;
    emitIfOpen(
      state.copyWith(resendStatus: EmailConfirmationResendStatus.sending),
    );
    final accepted = await _repository.resend(current);
    if (!identical(_accountSession, session)) return;
    emitIfOpen(
      state.copyWith(
        resendStatus: accepted
            ? EmailConfirmationResendStatus.sent
            : EmailConfirmationResendStatus.failed,
      ),
    );
  }

  @override
  Future<void> close() async {
    _accountSession = null;
    final closeAccountWrites = _closeAccountWrites;
    _closeAccountWrites = null;
    await super.close();
    await closeAccountWrites?.call();
  }
}
