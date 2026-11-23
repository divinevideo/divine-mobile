part of 'email_confirmation_cubit.dart';

/// Whether the signed-in account's email is confirmed.
enum EmailConfirmationStatus {
  /// Not checked yet, or the account has no Keycast session.
  unknown,

  /// The account signed in before confirming its email.
  unconfirmed,

  /// The email is confirmed.
  confirmed,

  /// The account has no email, so it cannot be recovered by email.
  noEmail,
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
    this.capRefusals = 0,
  });

  /// The state for [account] described by [confirmation].
  factory EmailConfirmationState.fromConfirmation(
    String account,
    EmailConfirmation confirmation, {
    EmailConfirmationResendStatus resendStatus =
        EmailConfirmationResendStatus.idle,
  }) => EmailConfirmationState(
    account: account,
    status: switch (confirmation.kind) {
      EmailConfirmationKind.unknown => EmailConfirmationStatus.unknown,
      EmailConfirmationKind.unconfirmed => EmailConfirmationStatus.unconfirmed,
      EmailConfirmationKind.confirmed => EmailConfirmationStatus.confirmed,
      EmailConfirmationKind.missing => EmailConfirmationStatus.noEmail,
    },
    email: confirmation.email,
    resendStatus: resendStatus,
  );

  /// Public key (hex) of the account this state describes.
  final String? account;

  final EmailConfirmationStatus status;

  /// The address this state is about, when the account has one.
  final String? email;

  final EmailConfirmationResendStatus resendStatus;

  /// How many times Keycast has refused a post, comment or report for this
  /// account because it has not confirmed its email. Each new refusal is one
  /// reminder of why.
  final int capRefusals;

  /// Whether the account must confirm its email before using DMs.
  bool get isUnconfirmed => status == EmailConfirmationStatus.unconfirmed;

  /// Whether the account has no email to sign in or recover with.
  bool get hasNoEmail => status == EmailConfirmationStatus.noEmail;

  EmailConfirmationState copyWith({
    EmailConfirmationResendStatus? resendStatus,
    int? capRefusals,
  }) => EmailConfirmationState(
    account: account,
    status: status,
    email: email,
    resendStatus: resendStatus ?? this.resendStatus,
    capRefusals: capRefusals ?? this.capRefusals,
  );

  @override
  List<Object?> get props => [
    account,
    status,
    email,
    resendStatus,
    capRefusals,
  ];
}
