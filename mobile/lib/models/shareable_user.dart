// ABOUTME: Cached recipient identity shared by the share sheet and its recents store.

import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// A recipient and their locally resolved display identity.
@immutable
class ShareableUser {
  const ShareableUser({
    required this.pubkey,
    this.displayName,
    this.handle,
    this.picture,
  });

  /// Builds a shareable user from a (possibly missing) [profile].
  ///
  /// Uses `displayNip05` — the full `@username.divine.video` form the
  /// find-people design calls for (Figma node `13945:91140`) — rather than
  /// `UserProfile.handle`, which shortens divine identifiers to `@username`
  /// and prefixes external ones into a doubled `@alice@example.com`. Falls
  /// back to the kind-0 `name`, then to `null` when the profile carries
  /// neither, so the row can drop its handle line entirely.
  factory ShareableUser.fromProfile(String pubkey, UserProfile? profile) {
    return ShareableUser(
      pubkey: pubkey,
      displayName: profile?.bestDisplayName,
      handle:
          _handleFromDisplayNip05(profile?.displayNip05) ??
          _handleFromName(profile?.name),
      picture: profile?.picture,
    );
  }

  /// [displayNip05] as a handle when it is already handle-shaped.
  static String? _handleFromDisplayNip05(String? displayNip05) {
    final trimmed = displayNip05?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        RegExp(r'\s').hasMatch(trimmed) ||
        !trimmed.contains('@') ||
        trimmed == '@') {
      return null;
    }
    return trimmed;
  }

  /// [name] as a handle: `@`-prefixed unless it already reads as one.
  ///
  /// A kind-0 `name` is free-form and often email-shaped
  /// (`dana@nostrplebs.com`) or already prefixed (`@dana`). Prefixing those
  /// would produce the doubled `@dana@nostrplebs.com` that this factory
  /// avoids for external NIP-05.
  static String? _handleFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    final sanitized = UserProfile.sanitizeDisplayName(name);
    return sanitized.contains('@') ? sanitized : '@$sanitized';
  }

  final String pubkey;

  /// Populate from `UserProfile.bestDisplayName`, never the raw kind-0
  /// fields: this renders directly in the share sheet and find-people list,
  /// where a lone UTF-16 surrogate crashes the paragraph builder.
  final String? displayName;

  /// Handle for the user (e.g. `@alice.divine.video` or `alice@example.com`).
  ///
  /// Populate via [ShareableUser.fromProfile]. `null` means the profile has
  /// no `nip05` and no `name`, and the find-people row then renders no
  /// secondary line at all rather than falling back to an npub.
  final String? handle;
  final String? picture;

  /// Whether the share row has enough user-visible data for a recipient tile.
  bool get hasVisibleIdentity =>
      displayName != null || handle != null || picture != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareableUser &&
          runtimeType == other.runtimeType &&
          pubkey == other.pubkey &&
          displayName == other.displayName &&
          handle == other.handle &&
          picture == other.picture;

  @override
  int get hashCode => Object.hash(pubkey, displayName, handle, picture);
}
