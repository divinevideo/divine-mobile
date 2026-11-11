// ABOUTME: Signature of a platform-provided BIP-340 verifier, used by the web
// ABOUTME: build to check relay-event signatures with the browser's BigInt.

/// Resolves `true` when [signature] is a valid BIP-340 signature of [message]
/// by [pubkey] (all hex), `false` when it is not.
///
/// Throws, or completes with an error, only when the verifier backend itself
/// fails, so a caller can fall back to its own implementation. Named
/// parameters keep the three hex strings from being passed in the wrong
/// order, which would turn every check into a silent `false`.
typedef NativeSchnorrVerify =
    Future<bool> Function({
      required String pubkey,
      required String message,
      required String signature,
    });
