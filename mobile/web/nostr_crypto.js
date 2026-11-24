// Fast Nostr BIP-340 crypto for the web build.
//
// Dart's BigInt is emulated in software once compiled to JavaScript, so each
// BIP-340 verify, sign, or pubkey derivation costs ~89-100 ms on the main
// thread. noble-secp256k1 uses the browser's native BigInt and WebCrypto
// SHA-256 instead, bringing operations down to <1 ms.
//
// Read by packages/nostr_sdk/lib/relay/native_schnorr_verifier_web.dart and
// packages/nostr_sdk/lib/relay/native_schnorr_signer_web.dart.
// Takes named fields so argument order cannot be swapped by mistake.
import { etc, schnorr } from './vendor/noble-secp256k1/index.js';

globalThis.divineNostrCrypto = Object.freeze({
  /**
   * Resolves true when `signature` is a valid BIP-340 signature of `message`
   * by `pubkey` (all lowercase hex), false when it is not. Rejects only when
   * the crypto backend itself fails (for example, no WebCrypto), so the
   * caller can fall back to its own verifier.
   */
  verifySchnorr: async ({ pubkey, message, signature }) =>
    schnorr.verifyAsync(
      etc.hexToBytes(signature),
      etc.hexToBytes(message),
      etc.hexToBytes(pubkey),
    ),

  /**
   * Resolves to the 64-byte lowercase hex BIP-340 signature of 32-byte hex
   * `message` using 32-byte hex `privateKey` and optional 32-byte hex
   * `auxRand`.
   */
  signSchnorr: async ({ privateKey, message, auxRand }) =>
    etc.bytesToHex(
      await schnorr.signAsync(
        etc.hexToBytes(message),
        etc.hexToBytes(privateKey),
        auxRand ? etc.hexToBytes(auxRand) : undefined,
      ),
    ),

  /**
   * Returns the 32-byte lowercase hex BIP-340 public key derived from 32-byte
   * hex `privateKey`.
   */
  getPublicKey: ({ privateKey }) =>
    etc.bytesToHex(schnorr.getPublicKey(etc.hexToBytes(privateKey))),
});
