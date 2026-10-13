// ABOUTME: Confirming a verifier sign-in (#113): the start secret, the values
// ABOUTME: hashed from it, and what the verifier answers when it counts a link.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// The hashes a sign-in shares with the verifier and its web page.
///
/// They take the 43-character base64url strings, not raw bytes, so every
/// client computes the same values from what it keeps.
abstract final class SignInSecrets {
  /// A new start secret: 32 random bytes as 43 base64url characters.
  static String newSecret([Random? random]) {
    final source = random ?? Random.secure();
    return _base64Url(List<int>.generate(32, (_) => source.nextInt(256)));
  }

  /// What the start sends in place of the secret.
  static String startCheckFor(String startSecret) =>
      _hash('divine-signin-start:$startSecret');

  /// The value the confirming claim carries, tied to the code and the start.
  static String confirmBindingFor(String code, String startCheck) =>
      _hash('divine-signin-confirm:$code:$startCheck');

  static String _hash(String text) =>
      _base64Url(sha256.convert(utf8.encode(text)).bytes);

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

/// A sign-in the verifier now counts.
class SignInConfirmation extends Equatable {
  /// Creates a [SignInConfirmation].
  const SignInConfirmation({required this.platform, required this.identity});

  /// The platform key, such as `bluesky`.
  final String platform;

  /// The account the verifier linked.
  final String identity;

  @override
  List<Object?> get props => [platform, identity];
}
