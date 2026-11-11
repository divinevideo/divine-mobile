// Fast Nostr signature checks for the web build.
//
// Dart's BigInt is emulated in software once compiled to JavaScript, so a
// BIP-340 check costs ~89 ms on the main thread. noble-secp256k1 uses the
// browser's native BigInt and WebCrypto SHA-256 instead.
//
// Read by packages/nostr_sdk/lib/relay/native_schnorr_verifier_web.dart.
// Takes named fields so the argument order cannot be swapped by mistake:
// noble's order is (signature, message, publicKey).
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
});
