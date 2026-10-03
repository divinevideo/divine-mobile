// ABOUTME: Context that marks a full-screen reel as opened from a DM thread.
// ABOUTME: Drives the in-player reply/reaction bar.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Identifies the DM conversation a full-screen reel was opened from, so the
/// player can show a reply/reaction bar that threads back into that chat.
///
/// Fields are plain strings / lists plus the immutable [sharedVideoRef] value
/// object, so the context survives travel through go_router `extra` (an
/// in-process object reference). It is intentionally `null` for reels opened
/// from the feed or profile (no bar) and lost on a web hard-reload (the player
/// still works, just without the bar).
class DmReplyContext extends Equatable {
  const DmReplyContext({
    required this.conversationId,
    required this.participantPubkeys,
    required this.isGroup,
    required this.sharedReelMessageId,
    required this.messageAuthorPubkey,
    required this.hintName,
    required this.isOwnMessage,
    this.sharedVideoRef,
  });

  /// Deterministic conversation id (matches `DmMessage.conversationId`).
  final String conversationId;

  /// Other participants in the conversation (excludes the current user).
  final List<String> participantPubkeys;

  /// Whether this is a group conversation (3+ participants).
  final bool isGroup;

  /// The kind-14 rumor id of the DM message that shared this reel. Replies
  /// thread under it and quick reactions target it.
  final String sharedReelMessageId;

  /// Author of the shared-reel message. It does not choose who a quick
  /// reaction is sent to: that is every other participant of
  /// [conversationId].
  final String messageAuthorPubkey;

  /// Display name used in the composer hint (peer name or group subject).
  final String hintName;

  /// Whether the current user authored the shared-reel message
  /// (drives the "Reply to yourself…" hint).
  final bool isOwnMessage;

  /// Structured reference to the reel the reply is about, when the shared-reel
  /// message carries one. Lets a reel reply self-carry the video's NIP-18 `q`
  /// citation so the reply stays linked to the video across devices and other
  /// Nostr clients. `null` for legacy URL-only shares the reply can't cite.
  final DmSharedVideoRef? sharedVideoRef;

  /// Whether a structured video reference is available to cite on a reply.
  bool get hasSharedVideoRef => sharedVideoRef != null;

  @override
  List<Object?> get props => [
    conversationId,
    participantPubkeys,
    isGroup,
    sharedReelMessageId,
    messageAuthorPubkey,
    hintName,
    isOwnMessage,
    sharedVideoRef,
  ];
}
