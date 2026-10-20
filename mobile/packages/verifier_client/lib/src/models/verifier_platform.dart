// ABOUTME: VerifierPlatform model — one entry of the verifier's platform list.
// ABOUTME: Mirrors the PlatformInfo shape returned by GET /platforms.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A platform the verifier can check identity claims against.
///
/// Mirrors `PlatformInfo` in
/// `divine-identify-verification-service/src/types.ts`, keyed by the
/// platform identifier used in NIP-39 `i` tags.
@immutable
class VerifierPlatform extends Equatable {
  /// Creates a [VerifierPlatform].
  const VerifierPlatform({
    required this.key,
    required this.label,
    required this.supported,
    this.oauth,
  });

  /// Parses one entry of the `platforms` map returned by `GET /platforms`.
  factory VerifierPlatform.fromJson(String key, Map<String, dynamic> json) {
    return VerifierPlatform(
      key: key,
      label: json['label'] as String? ?? key,
      supported: json['supported'] as bool? ?? false,
      // Anything but a bool is read as no answer, so a malformed value falls
      // back to [oauthPlatforms] rather than failing the whole list.
      oauth: switch (json['oauth']) {
        final bool value => value,
        _ => null,
      },
    );
  }

  /// Platform identifier as used in the `i` tag (e.g. `github`).
  final String key;

  /// Human-readable name for display (e.g. `Twitter / X`).
  final String label;

  /// Whether the verifier can currently check this platform.
  ///
  /// The service reports `false` when a platform's credentials are missing —
  /// Discord without its bot token, for example — so an unsupported platform
  /// must not be offered even though it appears in the response.
  final bool supported;

  /// Whether the verifier has this platform's sign-in turned on.
  ///
  /// Null when the verifier's answer does not say: platforms without a
  /// sign-in carry no `oauth` key, and nor does a verifier older than the
  /// flag.
  final bool? oauth;

  /// Whether this platform can be linked through an OAuth login instead of a
  /// proof post.
  ///
  /// Needs both halves: a flow the app can start ([oauthPlatforms]) and the
  /// verifier having it turned on ([oauth]). When [oauth] is unknown, the
  /// first half decides on its own, as it did before the verifier said.
  bool get supportsOAuth => oauthPlatforms.contains(key) && (oauth ?? true);

  /// Platforms the verifier exposes an OAuth flow for.
  ///
  /// Mirrors the switch in
  /// `divine-identify-verification-service/src/routes/auth.ts` — every other
  /// platform is proof-post only. Whether a deployment has one turned on is
  /// [oauth].
  static const oauthPlatforms = <String>{
    'twitter',
    'bluesky',
    'youtube',
    'tiktok',
  };

  @override
  List<Object?> get props => [key, label, supported, oauth];
}
