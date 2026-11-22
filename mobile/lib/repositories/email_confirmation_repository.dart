// ABOUTME: Reads whether the signed-in Keycast account has confirmed its email
// ABOUTME: and asks Keycast to resend the confirmation link.

import 'package:equatable/equatable.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

/// Whether the signed-in account still has to confirm its email.
enum EmailConfirmationKind {
  /// No answer yet: no Keycast session, or the status check failed.
  unknown,

  /// The account has an email Keycast has not seen confirmed.
  unconfirmed,

  /// The email is confirmed, or the account has no email to confirm.
  confirmed,
}

/// The confirmation state of the signed-in account's email.
class EmailConfirmation extends Equatable {
  const EmailConfirmation._(this.kind, {this.email});

  /// No answer is available.
  const EmailConfirmation.unknown() : this._(EmailConfirmationKind.unknown);

  /// [email] is waiting for its owner to click the confirmation link.
  const EmailConfirmation.unconfirmed(String email)
    : this._(EmailConfirmationKind.unconfirmed, email: email);

  /// Nothing left to confirm.
  const EmailConfirmation.confirmed() : this._(EmailConfirmationKind.confirmed);

  /// Maps Keycast's account status to a confirmation state.
  factory EmailConfirmation.fromKeycast(KeycastAccountStatus? status) {
    if (status == null) return const EmailConfirmation.unknown();
    if (status.emailVerified || status.email.isEmpty) {
      return const EmailConfirmation.confirmed();
    }
    return EmailConfirmation.unconfirmed(status.email);
  }

  final EmailConfirmationKind kind;

  /// The address awaiting confirmation. Set only when [kind] is
  /// [EmailConfirmationKind.unconfirmed].
  final String? email;

  @override
  List<Object?> get props => [kind, email];
}

/// Reads and nudges the email confirmation of the signed-in Keycast account.
///
/// [readAccessToken] supplies the bearer token bound to the signed-in account.
/// A missing token is no signal at all, so it reads as unknown: an account
/// signed in with a local key or a bunker never gets a confirmation nudge.
class EmailConfirmationRepository {
  EmailConfirmationRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;

  /// Fetches the current confirmation state from Keycast.
  ///
  /// Never throws: any failure reads as [EmailConfirmation.unknown].
  Future<EmailConfirmation> fetchStatus() async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        return const EmailConfirmation.unknown();
      }
      return EmailConfirmation.fromKeycast(
        await _oauthClient.getAccountStatus(token),
      );
    } on Exception {
      return const EmailConfirmation.unknown();
    }
  }

  /// Asks Keycast to email a fresh confirmation link.
  ///
  /// Returns whether Keycast accepted the request. Keycast answers success
  /// even when it rate-limits the send, so `true` means "requested", not
  /// "delivered".
  Future<bool> resend() async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) return false;
      final result = await _oauthClient.resendVerificationForAccount(token);
      return result.success;
    } on Exception {
      return false;
    }
  }
}
