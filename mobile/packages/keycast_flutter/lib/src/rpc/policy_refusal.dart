// ABOUTME: Typed Keycast signing refusals for accounts that have not confirmed
// ABOUTME: their email, and the process-wide stream that reports them.

import 'dart:async';
import 'dart:convert';

import 'package:keycast_flutter/src/models/exceptions.dart';

/// Why Keycast refused to sign for an account that has not confirmed its
/// email.
enum KeycastPolicyRefusalKind {
  /// Direct messages wait for email confirmation (`EMAIL_NOT_CONFIRMED`).
  emailNotConfirmed,

  /// The account used up an hourly allowance for posts, comments or reports
  /// that applies until it confirms (`UNCONFIRMED_RATE_LIMITED`).
  unconfirmedRateLimited,
}

/// One signing refusal from Keycast.
class KeycastPolicyRefusal {
  const KeycastPolicyRefusal(this.kind, {this.owner, this.retryAfter});

  final KeycastPolicyRefusalKind kind;

  /// Public key (hex) of the account whose signer was refused, or null when
  /// the signer was not told its owner. A refusal can arrive after another
  /// account has signed in, so this is what ties it to the right account.
  final String? owner;

  /// How long until the allowance frees up, when Keycast said.
  final Duration? retryAfter;
}

/// Keycast refused a direct message because the account's email is not
/// confirmed.
class EmailNotConfirmedException extends RpcException {
  EmailNotConfirmedException(super.message, {super.method});
}

/// Keycast refused a post, comment or report because an account that has not
/// confirmed its email used up its hourly allowance.
class UnconfirmedRateLimitedException extends RpcException {
  UnconfirmedRateLimitedException(
    super.message, {
    super.method,
    this.retryAfter,
  });

  /// How long until the allowance frees up, when Keycast said.
  final Duration? retryAfter;
}

/// Reports every [KeycastPolicyRefusal] from any `KeycastRpc` in the process.
///
/// Signing happens deep inside publishing, commenting and reporting, where no
/// screen is listening. This stream lets the app explain the refusal once, in
/// one place, instead of at every call site.
abstract final class KeycastPolicyRefusals {
  static final StreamController<KeycastPolicyRefusal> _controller =
      StreamController<KeycastPolicyRefusal>.broadcast();

  /// Refusals as they happen.
  static Stream<KeycastPolicyRefusal> get stream => _controller.stream;

  /// Classifies a non-200 RPC response, reports it when it is one of the
  /// confirmation refusals, and returns the exception to throw for it, or
  /// null when it is not one.
  static RpcException? classify({
    required String body,
    required String? retryAfterHeader,
    required String method,
    String? owner,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final code = decoded['code'];
    final message = decoded['error'] is String
        ? decoded['error'] as String
        : 'Refused by Keycast';
    switch (code) {
      case 'EMAIL_NOT_CONFIRMED':
        _controller.add(
          KeycastPolicyRefusal(
            KeycastPolicyRefusalKind.emailNotConfirmed,
            owner: owner,
          ),
        );
        return EmailNotConfirmedException(message, method: method);
      case 'UNCONFIRMED_RATE_LIMITED':
        final seconds = int.tryParse(retryAfterHeader?.trim() ?? '');
        final retryAfter = seconds == null ? null : Duration(seconds: seconds);
        _controller.add(
          KeycastPolicyRefusal(
            KeycastPolicyRefusalKind.unconfirmedRateLimited,
            owner: owner,
            retryAfter: retryAfter,
          ),
        );
        return UnconfirmedRateLimitedException(
          message,
          method: method,
          retryAfter: retryAfter,
        );
      default:
        return null;
    }
  }
}
