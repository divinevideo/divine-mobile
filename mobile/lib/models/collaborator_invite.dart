// ABOUTME: Typed metadata parsed from a structured collaborator invite DM.
// ABOUTME: Represents local invite UX data, not authoritative collab state.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

class CollaboratorInvite extends Equatable {
  const CollaboratorInvite({
    required this.messageId,
    required this.videoAddress,
    required this.videoKind,
    required this.creatorPubkey,
    required this.videoDTag,
    required this.role,
    this.relayHint,
    this.title,
    this.thumbnailUrl,
  });

  final String messageId;
  final String videoAddress;
  final int videoKind;
  final String creatorPubkey;
  final String videoDTag;
  final String role;
  final String? relayHint;
  final String? title;
  final String? thumbnailUrl;

  /// Whether [video] is the video this invite names: its creator's event with
  /// the invite's d-tag and kind. Old cached videos lack a kind, so only a
  /// known mismatch is rejected rather than guessing their kind.
  bool isForVideo(VideoEvent video) =>
      video.pubkey.toLowerCase() == creatorPubkey.toLowerCase() &&
      video.addressableDTag == videoDTag &&
      (video.eventKind == null || video.eventKind == videoKind);

  /// The pubkey whose kind-34238 response settles the invite on this card.
  ///
  /// A received invite names the viewer. A sent invite names its one
  /// counterparty, because the sending device's copy of the message does not
  /// carry the recipient's `p` tag. Returns null when that is not exactly one
  /// pubkey, so the card falls back to a status that claims nothing.
  static String? collaboratorPubkeyFor({
    required bool isSent,
    required String currentPubkey,
    required List<String> counterpartyPubkeys,
  }) {
    if (!isSent) return currentPubkey.isEmpty ? null : currentPubkey;
    return counterpartyPubkeys.length == 1 ? counterpartyPubkeys.single : null;
  }

  @override
  List<Object?> get props => [
    messageId,
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
