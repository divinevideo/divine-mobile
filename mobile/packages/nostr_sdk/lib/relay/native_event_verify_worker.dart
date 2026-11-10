// ABOUTME: Relay-event verify worker for the web build, where there is no
// ABOUTME: Isolate.spawn. Checks signatures with the browser's native BigInt
// ABOUTME: (web/nostr_crypto.js) instead of Dart's software BigInt, which
// ABOUTME: costs ~89 ms per check on the main thread once compiled to JS.

import 'dart:async';

import '../event.dart';
import 'event_verify_isolate.dart';
import 'native_schnorr_verifier_stub.dart'
    if (dart.library.js_interop) 'native_schnorr_verifier_web.dart';
import 'native_schnorr_verify.dart';

final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');
final _hex128 = RegExp(r'^[0-9a-fA-F]{128}$');

/// [EventVerifyWorker] backed by a platform-native BIP-340 verifier.
///
/// The event id is still recomputed in Dart; only the elliptic-curve check is
/// delegated. If the native backend ever fails (as opposed to rejecting a
/// signature), the worker stops using it and verifies in Dart from then on,
/// so a broken backend costs speed, never correctness.
class NativeEventVerifyWorker implements EventVerifyWorker {
  /// Creates a worker that delegates signature checks to [verifySchnorr].
  NativeEventVerifyWorker(NativeSchnorrVerify verifySchnorr)
    : _verifySchnorr = verifySchnorr;

  /// Returns a worker using the platform's native verifier.
  ///
  /// Throws [UnsupportedError] when the platform has none (every non-web
  /// build, or a web page where `nostr_crypto.js` failed to load). The relay
  /// pool then keeps verifying inline, exactly as it did before.
  static Future<EventVerifyWorker> spawn() async {
    final verifier = resolveNativeSchnorrVerifier();
    if (verifier == null) {
      throw UnsupportedError('No native Schnorr verifier on this platform');
    }
    return NativeEventVerifyWorker(verifier);
  }

  NativeSchnorrVerify? _verifySchnorr;
  bool _closed = false;
  final Set<Completer<bool>> _pending = {};

  /// Whether signature checks still go to the native verifier. Becomes
  /// `false` after the first backend failure.
  bool get usesNativeVerifier => _verifySchnorr != null;

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) {
    if (_closed) {
      throw StateError('NativeEventVerifyWorker has been closed');
    }
    final completer = Completer<bool>();
    _pending.add(completer);
    unawaited(
      _verify(eventJson).then((result) {
        _pending.remove(completer);
        if (!completer.isCompleted) completer.complete(result);
      }),
    );
    return completer.future;
  }

  Future<bool> _verify(Map<String, dynamic> eventJson) async {
    final Event event;
    try {
      event = Event.fromJson(eventJson);
    } on Object catch (_) {
      return false;
    }
    // Malformed hex is a bad event, not a backend failure; reject it here so
    // a throw from the native verifier always means the backend broke.
    if (!_hex64.hasMatch(event.pubkey) ||
        !_hex64.hasMatch(event.id) ||
        !_hex128.hasMatch(event.sig)) {
      return false;
    }
    if (!event.isValid) return false;

    final native = _verifySchnorr;
    if (native != null) {
      try {
        return await native(
          pubkey: event.pubkey,
          message: event.id,
          signature: event.sig,
        );
      } on Object catch (_) {
        _verifySchnorr = null;
      }
    }
    return event.isSigned;
  }

  /// Fails any pending [verify] futures so their callers fall back to inline
  /// verification instead of waiting. Idempotent.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'NativeEventVerifyWorker closed before the verify completed',
          ),
        );
      }
    }
    _pending.clear();
  }
}
