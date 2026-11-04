// ABOUTME: IdentityClaim model — a single platform attestation request.
// ABOUTME: Mirrors the verifier service's VerifyClaim payload shape.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A single claim that a Nostr pubkey owns an external identity on a
/// supported platform.
///
/// Mirrors the verifier service's `VerifyClaim` shape in
/// `divine-identify-verification-service/src/types.ts`.
@immutable
class IdentityClaim extends Equatable {
  /// Creates an [IdentityClaim] for [pubkey] on [platform] with [identity]
  /// and [proof].
  const IdentityClaim({
    required this.pubkey,
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// 64-character lowercase hex pubkey.
  final String pubkey;

  /// Platform identifier accepted by the verifier.
  ///
  /// Mobile filters against [supportedPlatforms] before batching claims so
  /// unsupported NIP-39 tags cannot 400 the whole verifier request. Keep this
  /// in sync with
  /// `divine-identify-verification-service/src/utils/validation.ts:3`.
  final String platform;

  /// Platform-specific user identifier (handle, account ID).
  final String identity;

  /// Proof material (URL, post ID, OAuth token reference, …) — opaque
  /// to mobile.
  final String proof;

  /// Platforms accepted by the verifier service.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:3`.
  static const supportedPlatforms = <String>{
    'github',
    'twitter',
    'mastodon',
    'telegram',
    'bluesky',
    'discord',
    'youtube',
    'tiktok',
  };

  /// Proof value written into the `i` tag of an OAuth-linked claim.
  ///
  /// OAuth leaves no public post to point at, so the tag carries this
  /// sentinel and the verifier confirms the claim from its own OAuth cache
  /// (`divine-identify-verification-service/src/routes/verify.ts`). It
  /// matches what the verifier's web UI writes, so a claim linked on one
  /// surface re-verifies on the other.
  ///
  /// The verifier keeps a confirmed sign-in for the lifetime it reports.
  /// After that it answers the claim unverified with the reason code
  /// `signin_expired`; it does not fall through to a proof-post check, which
  /// could not resolve this sentinel anyway. So an OAuth link has to be
  /// renewed by signing in again to stay verified. This is service-side
  /// behaviour, identical on web.
  static const String oauthProof = 'oauth';

  static final RegExp _hexPubkeyPattern = RegExp(r'^[0-9a-fA-F]+$');
  static final RegExp _invalidServerTextPattern = RegExp(
    r'''[<>"'{}|\\^`;]''',
  );
  static final RegExp _controlCharacterPattern = RegExp(r'[\x00-\x1f\x7f]');

  /// Maximum verifier-accepted identity/proof length.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:16,24`.
  static const int maxServerTextLength = 500;

  /// Whether [value] is a verifier-accepted 64-character hex pubkey.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:7`.
  static bool isServerValidPubkey(String value) =>
      value.length == 64 && _hexPubkeyPattern.hasMatch(value);

  /// Whether [value] is a verifier-accepted platform.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:5`.
  static bool isServerValidPlatform(String value) =>
      supportedPlatforms.contains(value);

  /// Whether [value] is a verifier-accepted identity string.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:24-28`.
  static bool isServerValidIdentity(String value) => _isServerValidText(value);

  /// Whether [value] is a verifier-accepted proof string.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:16-21`.
  static bool isServerValidProof(String value) => _isServerValidText(value);

  /// Whether this claim matches the verifier's request validation contract.
  ///
  /// Mirrors
  /// `divine-identify-verification-service/src/utils/validation.ts:62-78`.
  bool get isServerValid {
    if (!isServerValidPubkey(pubkey)) return false;
    if (!isServerValidPlatform(platform)) return false;
    if (!isServerValidIdentity(identity)) return false;
    if (platform == 'bluesky' && proof.trim().isEmpty) return true;
    return isServerValidProof(proof);
  }

  /// Serializes this claim to the verifier API JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'pubkey': pubkey,
    'platform': platform,
    'identity': identity,
    'proof': proof,
  };

  @override
  List<Object?> get props => [pubkey, platform, identity, proof];

  static bool _isServerValidText(String value) {
    if (value.isEmpty || value.length > maxServerTextLength) return false;
    if (_invalidServerTextPattern.hasMatch(value)) return false;
    if (_controlCharacterPattern.hasMatch(value)) return false;
    return true;
  }
}
