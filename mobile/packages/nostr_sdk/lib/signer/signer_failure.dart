import 'dart:async';

import 'package:http/http.dart' show ClientException;

/// Marker for a [NostrSigner] failure that happened *instead of* the
/// operation, and that is expected to clear on its own.
///
/// Implementing it is a promise about two things at once:
///
/// * **Nothing happened.** The signer produced no signature, ciphertext or
///   plaintext, and no side effect a retry could duplicate.
/// * **It is worth retrying.** The cause is infrastructural — a bounded
///   server giving up, a saturated pool — not a refusal, a policy decision,
///   or bad input, all of which would fail again identically.
///
/// Callers use it to keep durable work retryable instead of terminalizing it.
/// A remote-signer transport that surfaces its own timeout as an *error*
/// rather than as a Dart [TimeoutException] should carry this marker, so the
/// caller classifies it the same way it already classifies running out of
/// patience locally — the two mean the same thing and only differ in which
/// side of the wire noticed first.
///
/// The marker lives on the signer contract rather than in any one transport
/// package so consumers can branch on it without depending on the transport
/// that produced it.
abstract interface class TransientSignerFailure {}

/// Whether [error], thrown by a [NostrSigner] call, means the signer did not
/// answer: it ran out of time, or it could not be reached at all.
///
/// True for a [TransientSignerFailure] (a remote signer that bounded itself
/// and gave up), a local [TimeoutException], and a `package:http`
/// [ClientException], which is how an HTTP remote signer such as Keycast
/// reports a failed DNS lookup, a refused or reset connection, or a connect
/// cancelled because the client was closed.
///
/// These are states of a phone on a bad network, not defects, so error
/// reporters log them and leave them out of crash reports (the "Network / IO"
/// row of the error-handling matrix). The classification says nothing about
/// retrying: unlike [TransientSignerFailure], a transport failure does not
/// promise that the request never reached the signer, so each caller keeps
/// its own retry and queue handling.
///
/// A refusal the signer did answer with, and any programming error such as a
/// [StateError] or [TypeError], stays outside it and is still reported.
bool isUnreachableSignerFailure(Object error) =>
    error is TransientSignerFailure ||
    error is TimeoutException ||
    error is ClientException;
