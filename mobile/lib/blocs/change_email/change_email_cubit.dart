// ABOUTME: Cubit driving the change-email form for Keycast-held accounts
// ABOUTME: Loads the current address, validates the form, starts the change

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

part 'change_email_state.dart';

/// Form logic for changing the email address of an account created with
/// email/password.
///
/// Submitting does not change the address: Keycast mails a confirmation link to
/// the new address and a confirm/cancel link to the old one, and swaps them
/// only after both are confirmed. The screen says so rather than reporting a
/// change that has not happened yet.
class ChangeEmailCubit extends Cubit<ChangeEmailState> {
  ChangeEmailCubit({required AccountCredentialsRepository repository})
    : _repository = repository,
      super(const ChangeEmailState());

  final AccountCredentialsRepository _repository;
  Future<void>? _currentEmailLoad;

  /// Read the address Keycast has on file. A failure is not surfaced: the form
  /// still works without it, so there is nothing for the user to act on.
  Future<void> loadCurrentEmail() async {
    final existingLoad = _currentEmailLoad;
    if (existingLoad != null) {
      await existingLoad;
      return;
    }

    final load = _loadCurrentEmail();
    _currentEmailLoad = load;
    await load;
  }

  Future<void> _loadCurrentEmail() async {
    final status = await _repository.fetchAccountStatus();
    if (isClosed) return;
    final email = status?.email;
    if (email == null || email.isEmpty) return;
    emit(state.copyWith(currentEmail: email));
  }

  void updateNewEmail(String value) {
    emit(
      state.copyWith(
        newEmail: value,
        status: ChangeEmailStatus.editing,
        clearNewEmailError: true,
        clearFailureReason: true,
      ),
    );
  }

  void updatePassword(String value) {
    emit(
      state.copyWith(
        password: value,
        passwordMissing: false,
        status: ChangeEmailStatus.editing,
        clearFailureReason: true,
      ),
    );
  }

  /// Validate and start the change. Field errors keep the form in `editing`;
  /// only a server verdict moves it to `requestSent` or `failure`.
  Future<void> submit() async {
    if (state.isSubmitting) return;

    final currentEmailLoad = _currentEmailLoad;
    if (currentEmailLoad != null) {
      await currentEmailLoad;
      if (isClosed || state.isSubmitting) return;
    }

    final newEmail = state.newEmail.trim();
    final emailError = _newEmailError(newEmail);
    final passwordMissing = state.password.isEmpty;

    if (emailError != null || passwordMissing) {
      emit(
        state.copyWith(
          status: ChangeEmailStatus.editing,
          newEmailError: emailError,
          clearNewEmailError: emailError == null,
          passwordMissing: passwordMissing,
          clearFailureReason: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ChangeEmailStatus.submitting,
        clearFailureReason: true,
      ),
    );

    final result = await _repository.changeEmail(
      newEmail: newEmail,
      password: state.password,
    );
    if (isClosed) return;

    if (result.success) {
      emit(state.copyWith(status: ChangeEmailStatus.requestSent));
      return;
    }

    final reason = _reasonFrom(result.failure);
    Log.warning(
      'Email change refused: $reason'
      '${result.error == null ? '' : ' (${result.error})'}',
      name: 'ChangeEmailCubit',
      category: LogCategory.auth,
    );
    emit(
      state.copyWith(status: ChangeEmailStatus.failure, failureReason: reason),
    );
  }

  NewEmailFieldError? _newEmailError(String newEmail) {
    final formatError = switch (Validators.emailError(newEmail)) {
      EmailValidationError.missing => NewEmailFieldError.missing,
      EmailValidationError.invalid => NewEmailFieldError.invalid,
      null => null,
    };
    if (formatError != null) return formatError;

    // Case-insensitive because Keycast normalizes the address before comparing,
    // so "ME@x.com" is the same account as "me@x.com" and would come back as an
    // accepted no-op.
    final current = state.currentEmail;
    if (current != null &&
        current.trim().toLowerCase() == newEmail.toLowerCase()) {
      return NewEmailFieldError.sameAsCurrent;
    }
    return null;
  }

  ChangeEmailFailureReason _reasonFrom(ChangeEmailFailure? failure) {
    return switch (failure) {
      ChangeEmailFailure.wrongPassword =>
        ChangeEmailFailureReason.wrongPassword,
      ChangeEmailFailure.invalidEmail => ChangeEmailFailureReason.invalidEmail,
      ChangeEmailFailure.needsSignIn => ChangeEmailFailureReason.needsSignIn,
      ChangeEmailFailure.passwordNotSet =>
        ChangeEmailFailureReason.passwordNotSet,
      ChangeEmailFailure.rateLimited => ChangeEmailFailureReason.rateLimited,
      ChangeEmailFailure.network => ChangeEmailFailureReason.network,
      ChangeEmailFailure.server ||
      ChangeEmailFailure.unknown ||
      null => ChangeEmailFailureReason.unknown,
    };
  }
}
