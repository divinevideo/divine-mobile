// ABOUTME: Display model for a candidate person in the people-list picker.
// ABOUTME: Captures relationship flags (following/follower/mutual); list
// ABOUTME: membership is read live from PeopleListsBloc, not stored here.

import 'package:equatable/equatable.dart';

/// A candidate person shown in the add-people-to-list picker.
///
/// Each candidate is keyed by full-hex Nostr [pubkey] and carries
/// optional display metadata and relationship flags sourced from the
/// authenticated user's following / followers sets.
class PeopleListCandidate extends Equatable {
  /// Creates a candidate row.
  const PeopleListCandidate({
    required this.pubkey,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.isFollowing = false,
    this.isFollower = false,
  });

  /// Full-hex Nostr pubkey. Never truncated.
  final String pubkey;

  /// Display name from the candidate's Kind 0 profile, if known.
  ///
  /// `null` means the profile has not been fetched yet — the UI should
  /// render a fallback derived from [pubkey].
  final String? displayName;

  /// Handle for the candidate (e.g. `@alice` or `@alice.divine.video`).
  ///
  /// `null` means the handle has not been fetched or the profile has no
  /// `nip05` / `name` field.
  final String? handle;

  /// Avatar image URL, or `null` if the candidate has none.
  final String? avatarUrl;

  /// Whether the authenticated user currently follows this pubkey.
  final bool isFollowing;

  /// Whether this pubkey currently follows the authenticated user.
  final bool isFollower;

  /// Whether the authenticated user and this candidate mutually follow.
  bool get isMutual => isFollowing && isFollower;

  /// Returns a copy with the provided fields replaced.
  PeopleListCandidate copyWith({
    String? displayName,
    String? handle,
    String? avatarUrl,
    bool? isFollowing,
    bool? isFollower,
  }) {
    return PeopleListCandidate(
      pubkey: pubkey,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
    );
  }

  @override
  List<Object?> get props => [
    pubkey,
    displayName,
    handle,
    avatarUrl,
    isFollowing,
    isFollower,
  ];
}
