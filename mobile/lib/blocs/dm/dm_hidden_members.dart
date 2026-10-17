// ABOUTME: Which group members the viewer's own lists hide: whose messages
// ABOUTME: and inbox previews collapse, and who is left for a chat without
// ABOUTME: them (#10150).

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';

/// Whether a message renders collapsed until the viewer asks to see it.
///
/// Only a group collapses: blocking one member hides that member, not the
/// room. A one-to-one with a hidden peer stays readable in full, and so does
/// a group with [everyMemberBlocked], which is read-only like a blocked
/// one-to-one. The viewer's own messages never collapse. [isHidden] must
/// answer from the viewer's own lists only (#7345). Collapsing keeps the
/// message on the device, so unblocking shows it again (#7025).
bool dmMessageHiddenByDefault({
  required bool isGroup,
  required bool everyMemberBlocked,
  required String senderPubkey,
  required String currentUserPubkey,
  required bool Function(String pubkey) isHidden,
}) =>
    isGroup &&
    !everyMemberBlocked &&
    senderPubkey.isNotEmpty &&
    !pubkeysEqual(senderPubkey, currentUserPubkey) &&
    isHidden(senderPubkey);

/// Whether an inbox row hides its last message, so neither the preview nor
/// search shows a hidden member's words.
///
/// The same rule as [dmMessageHiddenByDefault], applied to the message the row
/// previews: only a group hides it, never the viewer's own, and not once
/// [everyMemberBlocked], which lists the row under Blocked to be read in full.
bool dmPreviewHidden({
  required DmConversation conversation,
  required String currentUserPubkey,
  required bool everyMemberBlocked,
  required bool Function(String pubkey) isHidden,
}) => dmMessageHiddenByDefault(
  isGroup: conversation.isGroup,
  everyMemberBlocked: everyMemberBlocked,
  senderPubkey: conversation.lastMessageSenderPubkey ?? '',
  currentUserPubkey: currentUserPubkey,
  isHidden: isHidden,
);

/// The counterparties the viewer has not blocked, sorted.
///
/// Sorted like a stored conversation row, the order the inbox uses before
/// deriving an id, so a room opened from here is titled for the same member as
/// the same room opened from the inbox. [isBlockedByUs] must answer from the
/// viewer's own block list only (#7345).
List<String> dmPeersWithoutBlocked({
  required List<String> participantPubkeys,
  required bool Function(String pubkey) isBlockedByUs,
}) => [
  for (final pubkey in participantPubkeys)
    if (!isBlockedByUs(pubkey)) pubkey,
]..sort();
