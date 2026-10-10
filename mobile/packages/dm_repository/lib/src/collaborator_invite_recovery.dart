// ABOUTME: Shared collaborator-invite queue models, tag constants, and parser.
// ABOUTME: Used by DmRepository queue recovery and app-layer invite UI.

import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

/// Shared collaborator-invite tag names used across publish, parse, and retry
/// flows.
abstract final class CollaboratorInviteTags {
  /// Marker tag name identifying app-specific metadata.
  static const String markerName = 'divine';

  /// Marker tag value identifying collaborator invites.
  static const String markerValue = 'collab-invite';

  /// Addressable-event tag name.
  static const String address = 'a';

  /// Public-key tag name.
  static const String pubkey = 'p';

  /// Collaborator role tag name.
  static const String role = 'role';

  /// Canonical collaborator role value.
  static const String collaboratorRole = 'Collaborator';

  /// Invite title tag name.
  static const String title = 'title';

  /// Invite thumbnail tag name.
  static const String thumbnail = 'thumb';

  /// Acceptance status tag value.
  static const String acceptedStatus = 'accepted';
}

/// Structured collaborator-invite metadata parsed from a queued rumor event.
class CollaboratorInviteRumorMetadata extends Equatable {
  /// Creates parsed collaborator-invite metadata.
  const CollaboratorInviteRumorMetadata({
    required this.videoAddress,
    required this.videoKind,
    required this.creatorPubkey,
    required this.videoDTag,
    required this.role,
    this.relayHint,
    this.title,
    this.thumbnailUrl,
  });

  /// Full Nostr address for the invited video.
  final String videoAddress;

  /// Kind component extracted from [videoAddress].
  final int videoKind;

  /// Creator pubkey extracted from [videoAddress].
  final String creatorPubkey;

  /// Stable d-tag extracted from [videoAddress].
  final String videoDTag;

  /// Collaborator role carried by the rumor.
  final String role;

  /// Relay hint from the address tag, when present.
  final String? relayHint;

  /// Human-readable video title, when present.
  final String? title;

  /// Video thumbnail URL, when present.
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [
    videoAddress,
    videoKind,
    creatorPubkey,
    videoDTag,
    role,
    relayHint,
    title,
    thumbnailUrl,
  ];
}

/// A queued collaborator invite that can still be recovered from
/// `outgoing_dms`.
class PendingCollaboratorInvite extends Equatable {
  /// Creates a recoverable collaborator invite view model.
  const PendingCollaboratorInvite({
    required this.rumorId,
    required this.collaboratorPubkey,
    required this.creatorPubkey,
    required this.videoAddress,
    required this.recipientWrapStatus,
    required this.selfWrapStatus,
    required this.retryCount,
    required this.queuedAt,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
    this.lastError,
  });

  /// Rumor event id used to recover the original queued send.
  final String rumorId;

  /// Collaborator who should receive the invite.
  final String collaboratorPubkey;

  /// Creator who sent the invite.
  final String creatorPubkey;

  /// Full address of the invited video.
  final String videoAddress;

  /// Human-readable video title, when present.
  final String? title;

  /// Video thumbnail URL, when present.
  final String? thumbnailUrl;

  /// Relay hint captured when the invite was built.
  final String? relayHint;

  /// Queue status for the collaborator-directed wrap.
  final OutgoingWrapStatus recipientWrapStatus;

  /// Queue status for the self-wrap copy.
  final OutgoingWrapStatus selfWrapStatus;

  /// Number of retry attempts recorded for this queue row.
  final int retryCount;

  /// Original queue timestamp.
  final DateTime queuedAt;

  /// Last raw transport error captured for the queue row, if any.
  final String? lastError;

  /// Whether the collaborator-directed wrap still needs recovery.
  ///
  /// Only a wrap still in progress does: `sent` is done, and recovery refuses
  /// the terminal `blocked` and `cancelled`.
  bool get requiresRecipientRecovery =>
      recipientWrapStatus == OutgoingWrapStatus.pending ||
      recipientWrapStatus == OutgoingWrapStatus.failed;

  @override
  List<Object?> get props => [
    rumorId,
    collaboratorPubkey,
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    recipientWrapStatus,
    selfWrapStatus,
    retryCount,
    queuedAt,
    lastError,
  ];
}

/// Groups pending collaborator invites by video so the UI can render one
/// banner per invited video.
class PendingCollaboratorInviteGroup extends Equatable {
  /// Creates a grouped pending-invite view.
  const PendingCollaboratorInviteGroup({
    required this.creatorPubkey,
    required this.videoAddress,
    required this.invites,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
  });

  /// Creator who owns the invited video.
  final String creatorPubkey;

  /// Full address of the invited video.
  final String videoAddress;

  /// Human-readable video title, when present.
  final String? title;

  /// Video thumbnail URL, when present.
  final String? thumbnailUrl;

  /// Relay hint captured from the source invite, when present.
  final String? relayHint;

  /// Recoverable invites associated with this video.
  final List<PendingCollaboratorInvite> invites;

  /// Number of pending collaborator invites for the video.
  int get inviteCount => invites.length;

  /// All collaborator pubkeys represented in [invites].
  Set<String> get collaboratorPubkeys =>
      invites.map((invite) => invite.collaboratorPubkey).toSet();

  @override
  List<Object?> get props => [
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    invites,
  ];
}

/// Aggregate result for a collaborator-invite retry attempt.
class CollaboratorInviteRetrySummary extends Equatable {
  /// Creates a retry summary.
  const CollaboratorInviteRetrySummary({
    required this.attemptedCount,
    required this.successCount,
    required this.failureCount,
    this.blockedCount = 0,
  });

  /// Number of invites considered for retry.
  final int attemptedCount;

  /// Number of invites successfully recovered.
  final int successCount;

  /// Number of invites that failed transiently and remain queued for a later
  /// retry. Excludes [blockedCount], which is terminal, not "still needs to
  /// send".
  final int failureCount;

  /// Number of invites that will never be sent: the recipient is not an
  /// approved DM recipient (a confirmed #176 policy block), or the invite is
  /// addressed to its own creator (#8363). They are never retryable, so they
  /// are surfaced apart from [failureCount].
  final int blockedCount;

  /// Whether every attempted recovery succeeded.
  bool get allSucceeded => attemptedCount == successCount;

  @override
  List<Object?> get props => [
    attemptedCount,
    successCount,
    failureCount,
    blockedCount,
  ];
}

/// Parses collaborator-invite metadata from a rumor event.
CollaboratorInviteRumorMetadata? parseCollaboratorInviteRumor(
  Event rumorEvent,
) {
  return parseCollaboratorInviteRumorTags(rumorEvent.tags);
}

/// Parses collaborator-invite metadata from rumor tags.
CollaboratorInviteRumorMetadata? parseCollaboratorInviteRumorTags(
  List<List<String>> tags,
) {
  if (!tags.any(_isInviteMarker)) return null;

  final addressTag = _firstWhereOrNull(tags, _isAddressTag);
  if (addressTag == null) return null;

  final parsedAddress = _parseAddress(addressTag[1]);
  if (parsedAddress == null) return null;

  final pTagValues = tags
      .where(
        (tag) => tag.length >= 2 && tag[0] == CollaboratorInviteTags.pubkey,
      )
      .map((tag) => tag[1])
      .where(NostrHexUtils.isValidPubkey)
      .toList(growable: false);
  if (pTagValues.isNotEmpty &&
      !pTagValues.contains(parsedAddress.creatorPubkey)) {
    return null;
  }

  final role =
      _tagValue(tags, CollaboratorInviteTags.role) ??
      CollaboratorInviteTags.collaboratorRole;
  if (role != CollaboratorInviteTags.collaboratorRole) return null;

  return CollaboratorInviteRumorMetadata(
    videoAddress: parsedAddress.videoAddress,
    videoKind: parsedAddress.videoKind,
    creatorPubkey: parsedAddress.creatorPubkey,
    videoDTag: parsedAddress.videoDTag,
    role: role,
    relayHint: _nonEmpty(addressTag.length >= 3 ? addressTag[2] : null),
    title: _tagValue(tags, CollaboratorInviteTags.title),
    thumbnailUrl: _tagValue(tags, CollaboratorInviteTags.thumbnail),
  );
}

bool _isInviteMarker(List<String> tag) {
  return tag.length >= 2 &&
      tag[0] == CollaboratorInviteTags.markerName &&
      tag[1] == CollaboratorInviteTags.markerValue;
}

bool _isAddressTag(List<String> tag) {
  return tag.length >= 2 && tag[0] == CollaboratorInviteTags.address;
}

({String videoAddress, int videoKind, String creatorPubkey, String videoDTag})?
_parseAddress(String value) {
  final parts = value.split(':');
  if (parts.length < 3) return null;

  final kind = int.tryParse(parts[0]);
  final creatorPubkey = parts[1];
  final dTag = parts.sublist(2).join(':');
  if (kind == null ||
      !NostrHexUtils.isValidPubkey(creatorPubkey) ||
      dTag.isEmpty) {
    return null;
  }

  return (
    videoAddress: value,
    videoKind: kind,
    creatorPubkey: creatorPubkey,
    videoDTag: dTag,
  );
}

String? _tagValue(List<List<String>> tags, String name) {
  for (final tag in tags) {
    if (tag.length < 2 || tag[0] != name) continue;
    return _nonEmpty(tag[1]);
  }
  return null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
