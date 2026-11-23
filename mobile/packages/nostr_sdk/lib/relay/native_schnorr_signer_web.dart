// ABOUTME: Web bindings to globalThis.divineNostrCrypto (web/nostr_crypto.js)
// ABOUTME: for native-BigInt BIP-340 signing and public-key derivation.

import 'dart:js_interop';

import 'native_schnorr_sign.dart';

@JS('divineNostrCrypto')
external _DivineNostrCrypto? get _divineNostrCrypto;

extension type _DivineNostrCrypto._(JSObject _) implements JSObject {
  @JS('signSchnorr')
  external JSAny? get signSchnorrMember;

  @JS('signSchnorr')
  external JSPromise<JSString> signSchnorr(_SignSchnorrArgs args);

  @JS('getPublicKey')
  external JSAny? get getPublicKeyMember;

  @JS('getPublicKey')
  external JSString getPublicKey(_GetPublicKeyArgs args);
}

extension type _SignSchnorrArgs._(JSObject _) implements JSObject {
  external factory _SignSchnorrArgs({
    String privateKey,
    String message,
    String? auxRand,
  });
}

extension type _GetPublicKeyArgs._(JSObject _) implements JSObject {
  external factory _GetPublicKeyArgs({String privateKey});
}

/// Returns the page's native BIP-340 signer, or `null` when
/// `web/nostr_crypto.js` did not load or lacks `signSchnorr`.
NativeSchnorrSign? resolveNativeSchnorrSigner() {
  final crypto = _divineNostrCrypto;
  if (crypto == null || !crypto.signSchnorrMember.isA<JSFunction>()) {
    return null;
  }
  return ({
    required String privateKey,
    required String message,
    String? auxRand,
  }) async {
    final result = await crypto
        .signSchnorr(
          _SignSchnorrArgs(
            privateKey: privateKey,
            message: message,
            auxRand: auxRand,
          ),
        )
        .toDart;
    return result.toDart;
  };
}

/// Returns the page's native BIP-340 public-key deriver, or `null` when
/// `web/nostr_crypto.js` did not load or lacks `getPublicKey`.
NativePublicKeyDerive? resolveNativePublicKeyDeriver() {
  final crypto = _divineNostrCrypto;
  if (crypto == null || !crypto.getPublicKeyMember.isA<JSFunction>()) {
    return null;
  }
  return ({required String privateKey}) {
    return crypto
        .getPublicKey(_GetPublicKeyArgs(privateKey: privateKey))
        .toDart;
  };
}
