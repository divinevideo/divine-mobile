// ABOUTME: Reads, remembers and nudges the email confirmation of Keycast
// ABOUTME: accounts, so a known-unconfirmed account stays known across restarts.

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a Keycast account still has to confirm its email.
enum EmailConfirmationKind {
  /// No answer yet: no Keycast session, or the status check failed.
  unknown,

  /// The account has an email Keycast has not seen confirmed.
  unconfirmed,

  /// The email is confirmed.
  confirmed,

  /// The account has no email at all, for example because another person
  /// confirmed the address it had claimed.
  missing,
}

/// The confirmation state of a Keycast account's email.
class EmailConfirmation extends Equatable {
  const EmailConfirmation._(this.kind, {this.email});

  /// No answer is available.
  const EmailConfirmation.unknown() : this._(EmailConfirmationKind.unknown);

  /// [email] is waiting for its owner to click the confirmation link.
  const EmailConfirmation.unconfirmed(String email)
    : this._(EmailConfirmationKind.unconfirmed, email: email);

  /// [email] is confirmed.
  const EmailConfirmation.confirmed([String? email])
    : this._(EmailConfirmationKind.confirmed, email: email);

  /// The account has no email to confirm.
  const EmailConfirmation.missing() : this._(EmailConfirmationKind.missing);

  /// Maps Keycast's account status to a confirmation state.
  factory EmailConfirmation.fromKeycast(KeycastAccountStatus? status) {
    if (status == null) return const EmailConfirmation.unknown();
    if (status.email.isEmpty) return const EmailConfirmation.missing();
    if (status.emailVerified) return EmailConfirmation.confirmed(status.email);
    return EmailConfirmation.unconfirmed(status.email);
  }

  /// What Keycast reported when the account signed up or signed in.
  factory EmailConfirmation.fromSignIn({
    required String email,
    required bool emailVerified,
  }) => emailVerified
      ? EmailConfirmation.confirmed(email)
      : EmailConfirmation.unconfirmed(email);

  final EmailConfirmationKind kind;

  /// The address this state is about, when the account has one.
  final String? email;

  @override
  List<Object?> get props => [kind, email];
}

/// Reads and nudges the email confirmation of the signed-in Keycast account.
///
/// [readAccessToken] supplies the bearer token bound to the signed-in account.
/// A missing token is no signal at all, so it reads as unknown: an account
/// signed in with a local key or a bunker never gets a confirmation nudge.
///
/// The last answer for each account is kept in [preferences] under a key that
/// embeds the account's public key, so the state of one account can never be
/// read as another's.
class EmailConfirmationRepository {
  EmailConfirmationRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
    required SharedPreferences preferences,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken,
       _preferences = preferences;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;
  final SharedPreferences _preferences;

  static String _cacheKey(String account) => 'email_confirmation_$account';

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

  /// The last confirmation state remembered for [account], or unknown.
  EmailConfirmation remembered(String account) {
    final raw = _preferences.getString(_cacheKey(account));
    if (raw == null) return const EmailConfirmation.unknown();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const EmailConfirmation.unknown();
    }
    if (decoded is! Map<String, dynamic>) {
      return const EmailConfirmation.unknown();
    }
    final kindName = decoded['kind'];
    final email = decoded['email'];
    final kind = kindName is String
        ? EmailConfirmationKind.values.asNameMap()[kindName]
        : null;
    final address = email is String ? email : null;
    return switch (kind) {
      EmailConfirmationKind.unconfirmed when address != null =>
        EmailConfirmation.unconfirmed(address),
      EmailConfirmationKind.confirmed => EmailConfirmation.confirmed(address),
      EmailConfirmationKind.missing => const EmailConfirmation.missing(),
      _ => const EmailConfirmation.unknown(),
    };
  }

  /// Remembers [confirmation] for [account]. An unknown answer is not stored.
  Future<void> remember(String account, EmailConfirmation confirmation) async {
    if (confirmation.kind == EmailConfirmationKind.unknown) return;
    await _preferences.setString(
      _cacheKey(account),
      jsonEncode({
        'kind': confirmation.kind.name,
        'email': confirmation.email,
      }),
    );
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
