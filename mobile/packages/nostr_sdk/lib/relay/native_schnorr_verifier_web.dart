// ABOUTME: Web binding to globalThis.divineNostrCrypto (web/nostr_crypto.js),
// ABOUTME: which checks BIP-340 signatures with noble-secp256k1.

import 'dart:js_interop';

import 'native_schnorr_verify.dart';

@JS('divineNostrCrypto')
external _DivineNostrCrypto? get _divineNostrCrypto;

extension type _DivineNostrCrypto._(JSObject _) implements JSObject {
  @JS('verifySchnorr')
  external JSAny? get verifySchnorrMember;

  @JS('verifySchnorr')
  external JSPromise<JSBoolean> verifySchnorr(_VerifySchnorrArgs args);
}

extension type _VerifySchnorrArgs._(JSObject _) implements JSObject {
  external factory _VerifySchnorrArgs({
    String pubkey,
    String message,
    String signature,
  });
}

/// Returns the page's native BIP-340 verifier, or `null` when
/// `web/nostr_crypto.js` did not load.
NativeSchnorrVerify? resolveNativeSchnorrVerifier() {
  final crypto = _divineNostrCrypto;
  if (crypto == null || !crypto.verifySchnorrMember.isA<JSFunction>()) {
    return null;
  }
  return ({
    required String pubkey,
    required String message,
    required String signature,
  }) async {
    final result = await crypto
        .verifySchnorr(
          _VerifySchnorrArgs(
            pubkey: pubkey,
            message: message,
            signature: signature,
          ),
        )
        .toDart;
    return result.toDart;
  };
}
