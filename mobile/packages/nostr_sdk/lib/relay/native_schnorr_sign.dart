// ABOUTME: Signature of a platform-native BIP-340 Schnorr signer and pubkey
// ABOUTME: deriver. Implemented on web via noble-secp256k1 (web/nostr_crypto.js).

import 'native_schnorr_signer_stub.dart'
    if (dart.library.js_interop) 'native_schnorr_signer_web.dart'
    as impl;

/// Computes a 64-byte hex BIP-340 Schnorr signature of 32-byte hex [message]
/// under 32-byte hex [privateKey] with optional 32-byte hex [auxRand].
typedef NativeSchnorrSign =
    Future<String> Function({
      required String privateKey,
      required String message,
      String? auxRand,
    });

/// Derives the 32-byte hex BIP-340 x-only public key for 32-byte hex
/// [privateKey].
typedef NativePublicKeyDerive = String Function({required String privateKey});

/// Returns the platform's native BIP-340 signer, or `null` when unavailable.
NativeSchnorrSign? resolveNativeSchnorrSigner() =>
    impl.resolveNativeSchnorrSigner();

/// Returns the platform's native BIP-340 public-key deriver, or `null` when
/// unavailable.
NativePublicKeyDerive? resolveNativePublicKeyDeriver() =>
    impl.resolveNativePublicKeyDeriver();
