part of 'email_confirmation_cubit.dart';

/// Whether the signed-in account's email is confirmed.
enum EmailConfirmationStatus {
  /// Not checked yet, or the account has no Keycast session.
  unknown,

  /// The account signed in before confirming its email.
  unconfirmed,

  /// The email is confirmed, or there is no email to confirm.
  confirmed,
}

/// Progress of a "resend the confirmation email" request.
enum EmailConfirmationResendStatus { idle, sending, sent, failed }

/// State of [EmailConfirmationCubit].
class EmailConfirmationState extends Equatable {
  const EmailConfirmationState({
    this.account,
    this.status = EmailConfirmationStatus.unknown,
    this.email,
    this.resendStatus = EmailConfirmationResendStatus.idle,
  });

  /// Public key (hex) of the account this state describes.
  final String? account;

  final EmailConfirmationStatus status;

  /// The address awaiting confirmation, when [status] is unconfirmed.
  final String? email;

  final EmailConfirmationResendStatus resendStatus;

  /// Whether the account must confirm its email before using DMs.
  bool get isUnconfirmed => status == EmailConfirmationStatus.unconfirmed;

  EmailConfirmationState copyWith({
    EmailConfirmationStatus? status,
    String? email,
    EmailConfirmationResendStatus? resendStatus,
  }) {
    final nextStatus = status ?? this.status;
    return EmailConfirmationState(
      account: account,
      status: nextStatus,
      email: nextStatus == EmailConfirmationStatus.unconfirmed
          ? email ?? this.email
          : null,
      resendStatus: resendStatus ?? this.resendStatus,
    );
  }

  @override
  List<Object?> get props => [account, status, email, resendStatus];
}
