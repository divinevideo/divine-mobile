// ABOUTME: Resolves readable profile links without changing signed metadata.
// ABOUTME: Keeps ownership checks and self-website replacement in one place.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:profile_repository/profile_repository.dart';

/// Presentation data derived from confirmed username ownership.
class ProfileLink extends Equatable {
  /// Creates resolved profile-link presentation data.
  const ProfileLink({required this.url, this.username, this.website});

  /// A working key-based link while ownership is unknown.
  factory ProfileLink.fallback(String pubkey, UserProfile? profile) =>
      ProfileLink(
        url: buildProfileUrl(null, Nip19.encodePubKey(pubkey)),
        website: profile?.website,
      );

  /// Canonical public URL for this account.
  final String url;

  /// Confirmed canonical Divine username, when available.
  final String? username;

  /// Custom website, replacing only a verified redundant self-link.
  final String? website;

  @override
  List<Object?> get props => [url, username, website];
}

/// Composes public ownership reads with exact-claim NIP-05 verification.
///
/// Callbacks keep the package independent of app providers and Flutter types.
class ProfileLinkResolver {
  /// Creates a resolver backed by public ownership reads.
  const ProfileLinkResolver({
    required Future<bool> Function(String pubkey, String claim) verifyClaim,
    required Future<DivineUsernameLookup> Function(String pubkey)
    lookupUsername,
  }) : _verifyClaim = verifyClaim,
       _lookupUsername = lookupUsername;

  final Future<bool> Function(String pubkey, String claim) _verifyClaim;
  final Future<DivineUsernameLookup> Function(String pubkey) _lookupUsername;

  /// Resolves links for the exact displayed account and metadata.
  Future<ProfileLink> resolve({
    required String pubkey,
    required UserProfile? profile,
  }) async {
    final fallback = ProfileLink.fallback(pubkey, profile);
    // Metadata from a previous route must never provide another account's name.
    if (profile != null &&
        profile.pubkey.toLowerCase() != pubkey.toLowerCase()) {
      return ProfileLink.fallback(pubkey, null);
    }
    String? username;
    try {
      final claim = profile?.nip05;
      if (claim == null || claim.trim().isEmpty) {
        final lookup = await _lookupUsername(pubkey);
        if (lookup is DivineUsernameFound) username = lookup.canonical;
      } else if (profile?.divineUsername != null &&
          await _verifyClaim(pubkey, claim)) {
        username = profile!.divineUsername;
      }
    } on Object {
      // Network and unavailable-dependency errors must leave a working URL.
      return fallback;
    }
    if (username == null) return fallback;
    final validation = validateDivineUsername(username);
    if (validation is! DivineUsernameValid) return fallback;
    final canonical = validation.normalized;
    final url = 'https://$canonical.divine.video';
    return ProfileLink(
      url: url,
      username: canonical,
      website: _isSelfLink(profile?.website, pubkey) ? url : profile?.website,
    );
  }
}

bool _isSelfLink(String? website, String pubkey) {
  if (website == null || website.trim().isEmpty) return false;
  final raw = website.trim();
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null ||
      !{'https', 'http'}.contains(uri.scheme) ||
      !{'divine.video', 'www.divine.video'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  final match = RegExp(r'^/profile/([^/]+)/?$').firstMatch(uri.path);
  if (match == null) return false;
  final identifier = match.group(1)!;
  if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(identifier)) {
    return identifier.toLowerCase() == pubkey.toLowerCase();
  }
  if (!identifier.toLowerCase().startsWith('npub1')) return false;
  try {
    return Nip19.decode(identifier).toLowerCase() == pubkey.toLowerCase();
  } on Object {
    return false;
  }
}
