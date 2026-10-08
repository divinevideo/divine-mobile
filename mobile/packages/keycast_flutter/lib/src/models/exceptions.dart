// ABOUTME: Custom exceptions for Keycast operations
// ABOUTME: Provides typed exceptions for session, OAuth, RPC, and key errors

import 'package:nostr_sdk/nostr_sdk.dart';

class KeycastException implements Exception {
  KeycastException(this.message);
  final String message;

  @override
  String toString() => 'KeycastException: $message';
}

class SessionExpiredException extends KeycastException {
  SessionExpiredException([String? message])
    : super(message ?? 'Session has expired');
}

class OAuthException extends KeycastException {
  OAuthException(super.message, {this.errorCode});
  final String? errorCode;

  @override
  String toString() => errorCode != null
      ? 'OAuthException [$errorCode]: $message'
      : 'OAuthException: $message';
}

/// OAuth request failed before Keycast could authoritatively accept or reject
/// the token, such as a network transport error, a timeout, or a temporary
/// server error (5xx, 408, 429).
class OAuthNetworkException extends OAuthException {
  OAuthNetworkException([String? message])
    : super(message ?? 'OAuth request failed due to a network error');
}

class RpcException extends KeycastException {
  RpcException(super.message, {this.method});
  final String? method;

  @override
  String toString() => method != null
      ? 'RpcException [$method]: $message'
      : 'RpcException: $message';
}

/// Keycast bounded the RPC itself and gave up: HTTP 504 from `/api/nostr`.
///
/// Both server-side ceilings on that route answer 504 — the handler's own
/// `HTTP_RPC_HANDLER_TIMEOUT` (8s, which keeps the method label on the latency
/// histogram) and the wider tower layer behind it (10s, covering body read and
/// extractors). So 504 is *the* "Keycast ran out of time" signal there,
/// whichever ceiling fired, and it is the only 5xx that says so
/// unambiguously: 503 covers a degraded dependency and 500 an unhandled
/// error, neither of which promises the operation did not happen.
///
/// Carries [TransientSignerFailure] because it means exactly what a local
/// `TimeoutException` from `KeycastRpc.requestTimeout` means — the signing or
/// encryption never produced a result, nothing was published, and a retry is
/// the right response. Only the side of the wire that noticed differs. Without
/// the marker a 504 arrives as a plain non-200 and callers terminalize it,
/// which is strictly worse than the timeout it replaced.
class RpcTimeoutException extends RpcException
    implements TransientSignerFailure {
  RpcTimeoutException(super.message, {super.method});

  @override
  String toString() => method != null
      ? 'RpcTimeoutException [$method]: $message'
      : 'RpcTimeoutException: $message';
}

class InvalidKeyException extends KeycastException {
  InvalidKeyException(super.message);
}

/// Thrown when an RPC is attempted on a KeycastRpc after close().
///
/// Extends [KeycastException] — not [StateError] — deliberately: close racing an
/// in-flight call (e.g. sign-out while a token refresh is parked) is expected
/// teardown, not a programming-invariant violation. The error-handling matrix
/// classifies `StateError` as Crashlytics-reportable, and as an `Error` it also
/// escapes `on Exception` handlers, which would turn routine teardown into an
/// uncaught error. It deliberately stays outside [RpcException] so capability
/// fallbacks do not mistake a closed client for an unsupported method. Without
/// [TransientSignerFailure] it stays terminal: a closed signer is never retried.
class KeycastRpcClosedException extends KeycastException {
  KeycastRpcClosedException([String? message])
    : super(message ?? 'KeycastRpc is closed');
}
