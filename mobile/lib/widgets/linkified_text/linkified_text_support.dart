import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';

/// Shared helpers for linkified-text renderers.
final class LinkifiedTextSupport {
  const LinkifiedTextSupport._();

  /// Resolves the display label used for profile references.
  ///
  /// The candidates are raw metadata fields, not the sanitizing accessors
  /// ([UserProfile.bestDisplayName] and friends), because this label keeps its
  /// own precedence — display name, then name, then NIP-05. So it sanitizes
  /// the winner itself: an unpaired UTF-16 surrogate in someone's profile name
  /// otherwise reaches the paragraph builder through every mention of them and
  /// crashes the render.
  static String profileDisplayText(WidgetRef ref, String hexPubkey) {
    final profile = ref.watch(userProfileReactiveProvider(hexPubkey)).value;
    final profileText = UserProfile.sanitizeDisplayName(switch (profile) {
      UserProfile(:final displayName?) when displayName.isNotEmpty =>
        displayName,
      UserProfile(:final name?) when name.isNotEmpty => name,
      UserProfile(:final shortDisplayNip05?)
          when shortDisplayNip05.isNotEmpty =>
        shortDisplayNip05,
      _ => UserProfile.defaultDisplayNameFor(hexPubkey),
    });
    return profileText.startsWith('@') ? profileText : '@$profileText';
  }

  /// Matches a plain typed mention against known mentioned profile pubkeys.
  ///
  /// Nostr `p` tags identify mentioned users but do not carry the visible
  /// username. The renderer can still resolve common cases once profiles are
  /// cached by comparing the typed token with the profile's known names.
  static String? profilePubkeyForMention(
    WidgetRef ref,
    String username,
    Iterable<String> profilePubkeys,
  ) {
    final normalizedUsername = _normalizeMentionValue(username);
    if (normalizedUsername.isEmpty) return null;

    for (final pubkey in profilePubkeys) {
      final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
      if (profile == null) continue;

      final values = <String?>[
        ..._profileMentionValues(profile),
        pubkey,
      ];

      final matches = values
          .whereType<String>()
          .map(_normalizeMentionValue)
          .any((value) => value == normalizedUsername);
      if (matches) return pubkey;
    }

    return null;
  }

  /// Returns the unique exact profile match for a typed mention.
  ///
  /// A contains-style search result is not enough to open a profile directly:
  /// `@ann` should not pick `@annie`. This helper only returns a pubkey when
  /// exactly one searched profile has a name, NIP-05, hex key, or npub matching
  /// the typed token after mention normalization.
  static String? exactProfilePubkeyForMention(
    String username,
    Iterable<UserProfile> profiles,
  ) {
    final normalizedUsername = _normalizeMentionValue(username);
    if (normalizedUsername.isEmpty) return null;

    final matches = <String>{};
    for (final profile in profiles) {
      final pubkey = _normalizedHexPubkey(profile.pubkey);
      if (pubkey == null) continue;

      final values = <String?>[
        ..._profileMentionValues(profile),
        pubkey,
        NostrKeyUtils.encodePubKey(pubkey),
      ];

      final isMatch = values
          .whereType<String>()
          .map(_normalizeMentionValue)
          .any((value) => value == normalizedUsername);
      if (isMatch) matches.add(pubkey);
    }

    return matches.length == 1 ? matches.single : null;
  }

  /// Resolves a typed mention through profile search before search navigation.
  ///
  /// Local cache is tried first so cached exact matches open instantly. The
  /// broader repository search is only used when local cache has no unique
  /// exact match.
  static Future<String?> resolveProfilePubkeyForMention(
    ProfileRepository? profileRepository,
    String username,
  ) async {
    if (profileRepository == null) return null;

    final localPubkey = await _exactMentionSearch(
      profileRepository,
      username,
      localOnly: true,
    );
    if (localPubkey != null) return localPubkey;

    return _exactMentionSearch(profileRepository, username);
  }

  /// Recursively disposes gesture recognizers owned by inline spans.
  static void disposeSpans(List<InlineSpan> spans) {
    for (final span in spans) {
      if (span is! TextSpan) continue;
      span.recognizer?.dispose();
      final children = span.children;
      if (children != null) disposeSpans(children);
    }
  }

  static String _normalizeMentionValue(String value) {
    final trimmed = value.trim().toLowerCase();
    final withoutPrefix = trimmed.startsWith('@')
        ? trimmed.substring(1)
        : trimmed;
    return withoutPrefix.replaceAll(RegExp('[^a-z0-9]'), '');
  }

  static List<String?> _profileMentionValues(UserProfile profile) => [
    profile.name,
    profile.displayName,
    profile.divineUsername,
    profile.shortDisplayNip05,
    profile.displayNip05,
    profile.nip05,
    _nip05LocalPart(profile.nip05),
  ];

  static String? _normalizedHexPubkey(String value) {
    final normalized = value.trim().toLowerCase();
    return NostrKeyUtils.isValidKey(normalized) ? normalized : null;
  }

  static String? _nip05LocalPart(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    if (trimmed.startsWith('_@')) {
      return trimmed.substring(2).split('.').first;
    }
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1).split('.').first;
    }
    if (trimmed.contains('@')) {
      return trimmed.split('@').first;
    }
    return null;
  }

  static Future<String?> _exactMentionSearch(
    ProfileRepository profileRepository,
    String username, {
    bool localOnly = false,
  }) async {
    try {
      final profiles = localOnly
          ? await profileRepository.searchCachedProfilesByIdentity(
              query: username,
              limit: 10,
            )
          : await profileRepository.searchUsers(query: username, limit: 10);
      return exactProfilePubkeyForMention(username, profiles);
    } on Object {
      return null;
    }
  }
}
