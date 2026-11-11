// ABOUTME: Non-web stand-in for the native Schnorr verifier. Native builds
// ABOUTME: verify relay events in a background isolate instead.

import 'native_schnorr_verify.dart';

/// Returns the platform's native BIP-340 verifier, or `null` when there is
/// none. Outside the web there never is.
NativeSchnorrVerify? resolveNativeSchnorrVerifier() => null;
