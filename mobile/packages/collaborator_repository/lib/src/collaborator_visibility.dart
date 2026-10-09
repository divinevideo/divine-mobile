// ABOUTME: View-model for status-aware collaborator rendering.
// ABOUTME: Combines tagged pubkeys with per-pubkey status + viewer context.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Encapsulates the inputs needed by collaborator-rendering surfaces
/// (avatar row, metadata section, edit dialog) so the filter / decoration /
/// pending-count logic lives in one place rather than being recomputed
/// surface-by-surface.
///
/// Construct with the default constructor when the status pipeline is
/// available; use [CollaboratorVisibility.fallback] when the repository is
/// gated off (Nostr not ready, no addressable id, no current user).
@immutable
class CollaboratorVisibility extends Equatable {
  const CollaboratorVisibility({
    required this.taggedPubkeys,
    required this.statusByPubkey,
    required this.currentUserPubkey,
    required this.creatorPubkey,
    this.isResolved = false,
  });

  /// Acceptance status that cannot be looked up, treated as not yet loaded:
  /// the author sees every invitee as pending and everyone else sees nothing,
  /// so an unconfirmed collaborator is never credited publicly (#6907).
  const CollaboratorVisibility.fallback({
    required this.taggedPubkeys,
    this.currentUserPubkey = '',
    this.creatorPubkey = '',
  }) : statusByPubkey = const {},
       isResolved = false;

  /// Pubkeys tagged with the `'collaborator'` role on the latest
  /// creator-authored video event.
  final List<String> taggedPubkeys;

  /// Per-collaborator status as derived by the repository. Empty in
  /// fallback mode.
  final Map<String, CollaboratorStatus> statusByPubkey;

  /// Hex pubkey of the currently signed-in user. Empty when unknown.
  final String currentUserPubkey;

  /// Hex pubkey of the video's author.
  final String creatorPubkey;

  /// Whether the acceptance query has finished. Non-author viewers render
  /// nothing until this is true — see [visiblePubkeys].
  final bool isResolved;

  /// True when the current user authored the video. Always false when the
  /// current user is unknown.
  bool get isInviterView =>
      currentUserPubkey.isNotEmpty &&
      _samePubkey(currentUserPubkey, creatorPubkey);

  /// Status for [pubkey]. Returns [CollaboratorStatus.pending] when no entry
  /// exists, including in fallback mode.
  CollaboratorStatus statusFor(String pubkey) {
    final directStatus = statusByPubkey[pubkey];
    if (directStatus != null) return directStatus;

    final normalizedPubkey = pubkey.toLowerCase();
    for (final entry in statusByPubkey.entries) {
      if (entry.key.toLowerCase() == normalizedPubkey) return entry.value;
    }
    return CollaboratorStatus.pending;
  }

  /// Pubkeys to render.
  ///
  /// - Author's own video: every tagged pubkey, minus one the current user
  ///   has locally ignored. Unconfirmed entries stay visible and are greyed
  ///   via [isPendingForInviter] — the author needs to see who they invited.
  /// - Everyone else: only confirmed collaborators, and only once
  ///   [isResolved]. A creator can tag any pubkey, so rendering an
  ///   unconfirmed one publicly credits someone who never accepted — or who
  ///   explicitly ignored (#6907). Before the query resolves nothing renders
  ///   at all, so an unconfirmed name is never shown even briefly.
  List<String> get visiblePubkeys {
    if (isInviterView) {
      return [
        for (final pubkey in taggedPubkeys)
          if (!_isHiddenByCurrentUserIgnore(pubkey)) pubkey,
      ];
    }
    if (!isResolved) return const [];
    return [
      for (final pubkey in taggedPubkeys)
        if (statusFor(pubkey) == CollaboratorStatus.confirmed) pubkey,
    ];
  }

  /// Whether [pubkey] should render a "pending" decoration. Only true on
  /// the inviter's own video for collaborators that haven't accepted yet.
  bool isPendingForInviter(String pubkey) {
    if (!isInviterView) return false;
    return statusFor(pubkey) == CollaboratorStatus.pending;
  }

  /// Count of pending collaborators visible on the inviter's view. Zero
  /// for any other viewer.
  int get pendingCount {
    if (!isInviterView) return 0;
    return visiblePubkeys.where(isPendingForInviter).length;
  }

  bool _isHiddenByCurrentUserIgnore(String pubkey) =>
      _samePubkey(pubkey, currentUserPubkey) &&
      statusFor(pubkey) == CollaboratorStatus.ignored;

  static bool _samePubkey(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  @override
  List<Object?> get props => [
    taggedPubkeys,
    statusByPubkey,
    currentUserPubkey,
    creatorPubkey,
    isResolved,
  ];
}
