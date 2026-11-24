// ABOUTME: Non-web stub for native Schnorr signing and public-key derivation.
// ABOUTME: Native builds use Dart's compiled VM / isolates directly.

import 'native_schnorr_sign.dart';

/// Always returns `null` off the web.
NativeSchnorrSign? resolveNativeSchnorrSigner() => null;

/// Always returns `null` off the web.
NativePublicKeyDerive? resolveNativePublicKeyDeriver() => null;
