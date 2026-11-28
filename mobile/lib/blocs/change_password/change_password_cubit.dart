// ABOUTME: Cubit driving the change-password form for Keycast-held accounts
// ABOUTME: Validates the fields, then asks the repository to change the password

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

part 'change_password_state.dart';

/// Form logic for changing the password of an account created with
/// email/password.
///
/// The password never leaves this cubit's state and the repository call: it is
/// not logged, not cached, and dropped when the screen closes.
class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit({required AccountCredentialsRepository repository})
    : _repository = repository,
      super(const ChangePasswordState());

  final AccountCredentialsRepository _repository;

  void updateCurrentPassword(String value) {
    emit(
      state.copyWith(
        currentPassword: value,
        currentPasswordMissing: false,
        status: ChangePasswordStatus.editing,
        clearFailureReason: true,
      ),
    );
  }

  void updateNewPassword(String value) {
    emit(
      state.copyWith(
        newPassword: value,
        status: ChangePasswordStatus.editing,
        clearNewPasswordError: true,
        clearConfirmPasswordError: true,
        clearFailureReason: true,
      ),
    );
  }

  void updateConfirmPassword(String value) {
    emit(
      state.copyWith(
        confirmPassword: value,
        status: ChangePasswordStatus.editing,
        clearConfirmPasswordError: true,
        clearFailureReason: true,
      ),
    );
  }

  /// Validate and submit. Field errors keep the form in `editing`; only a
  /// server verdict moves it to `success` or `failure`.
  Future<void> submit() async {
    if (state.isSubmitting) return;

    final currentMissing = state.currentPassword.isEmpty;
    final newPasswordError = Validators.passwordError(state.newPassword);
    final confirmPasswordError = Validators.confirmPasswordError(
      state.confirmPassword,
      password: state.newPassword,
    );

    if (currentMissing ||
        newPasswordError != null ||
        confirmPasswordError != null) {
      emit(
        state.copyWith(
          status: ChangePasswordStatus.editing,
          currentPasswordMissing: currentMissing,
          newPasswordError: newPasswordError,
          confirmPasswordError: confirmPasswordError,
          clearNewPasswordError: newPasswordError == null,
          clearConfirmPasswordError: confirmPasswordError == null,
          clearFailureReason: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ChangePasswordStatus.submitting,
        clearFailureReason: true,
      ),
    );

    final result = await _repository.changePassword(
      currentPassword: state.currentPassword,
      newPassword: state.newPassword,
    );
    if (isClosed) return;

    if (result.success) {
      emit(state.copyWith(status: ChangePasswordStatus.success));
      return;
    }

    final reason = _reasonFrom(result.failure);
    Log.warning(
      'Password change refused: $reason'
      '${result.error == null ? '' : ' (${result.error})'}',
      name: 'ChangePasswordCubit',
      category: LogCategory.auth,
    );
    emit(
      state.copyWith(
        status: ChangePasswordStatus.failure,
        failureReason: reason,
      ),
    );
  }

  ChangePasswordFailureReason _reasonFrom(ChangePasswordFailure? failure) {
    return switch (failure) {
      ChangePasswordFailure.wrongPassword =>
        ChangePasswordFailureReason.wrongCurrentPassword,
      ChangePasswordFailure.weakPassword =>
        ChangePasswordFailureReason.weakPassword,
      ChangePasswordFailure.needsSignIn =>
        ChangePasswordFailureReason.needsSignIn,
      ChangePasswordFailure.passwordNotSet =>
        ChangePasswordFailureReason.passwordNotSet,
      ChangePasswordFailure.rateLimited =>
        ChangePasswordFailureReason.rateLimited,
      ChangePasswordFailure.network => ChangePasswordFailureReason.network,
      // A fault on Keycast's side is not something the user can act on any
      // differently from an unclassified refusal.
      ChangePasswordFailure.server ||
      ChangePasswordFailure.unknown ||
      null => ChangePasswordFailureReason.unknown,
    };
  }
}
