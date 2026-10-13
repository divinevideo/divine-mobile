// ABOUTME: VerificationResult model — verifier API response per claim.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Result of asking the verifier to re-check a single identity claim.
@immutable
class VerificationResult extends Equatable {
  /// Creates a [VerificationResult] from explicit fields.
  const VerificationResult({
    required this.platform,
    required this.identity,
    required this.verified,
    required this.checkedAt,
    required this.cached,
    this.error,
    this.code,
    this.canonicalProof,
    this.canonicalIdentity,
  });

  /// Parses a [VerificationResult] from the verifier API JSON shape.
  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      platform: json['platform'] as String,
      identity: json['identity'] as String,
      verified: json['verified'] as bool,
      checkedAt: json['checked_at'] as int,
      cached: json['cached'] as bool? ?? false,
      error: json['error'] as String?,
      code: json['code'] as String?,
      canonicalProof: _nonEmptyString(json['canonical_proof']),
      canonicalIdentity: _nonEmptyString(json['canonical_identity']),
    );
  }

  /// Platform identifier the result is for (e.g. `github`).
  final String platform;

  /// Platform-specific identity (handle, account ID).
  final String identity;

  /// Whether the verifier confirmed the claim.
  final bool verified;

  /// Unix epoch seconds when the verifier last checked the claim.
  final int checkedAt;

  /// True when the result was served from the verifier's KV cache.
  final bool cached;

  /// Free-form error string when [verified] is false. Not a stable key.
  final String? error;

  /// Stable machine-readable reason the claim isn't verified, when the verifier
  /// sends one. Most codes are rejections, but `temporarily_unavailable` means
  /// the claim couldn't be checked right now: no verdict either way.
  ///
  /// Unlike [error], this is safe to branch on: the service treats these as a
  /// fixed vocabulary. It is null for platforms that have not adopted codes and
  /// for any deployment older than them, so a caller must have a fallback —
  /// and must keep it for values a newer service invents.
  final String? code;

  /// The proof to publish instead of the one sent, when the verifier
  /// confirmed the claim and reduced the proof to a simpler stable form: a
  /// TikTok share or photo link becomes its post number, for example.
  ///
  /// Null when the proof sent was already in that form, on a rejection, and
  /// from deployments older than the field.
  final String? canonicalProof;

  /// The account to publish instead of the one sent, when the verifier
  /// confirmed the claim and tidied the account: a Mastodon `@user@server`
  /// becomes `server/@user`, for example.
  ///
  /// Null when the account sent was already in that form, on a rejection,
  /// and from deployments older than the field.
  final String? canonicalIdentity;

  @override
  List<Object?> get props => [
    platform,
    identity,
    verified,
    checkedAt,
    cached,
    error,
    code,
    canonicalProof,
    canonicalIdentity,
  ];
}

// A clean value is optional extra, so a malformed one is ignored rather than
// failing the parse: in a batch that would fail every claim's result.
String? _nonEmptyString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
