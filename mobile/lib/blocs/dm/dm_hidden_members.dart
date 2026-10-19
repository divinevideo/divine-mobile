// ABOUTME: Which group members the viewer's own lists hide: whose messages
// ABOUTME: and inbox previews collapse, how a group's inbox row reads without
// ABOUTME: them, and who is left for a chat without them (#10150).

import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';

/// Whether the viewer has blocked every other participant.
///
/// Such a thread reads like a blocked one-to-one: listed under Blocked, shown
/// in full, and its preview not hidden. False with no other participant, where
/// `every` would be vacuously true. [isBlockedByUs] must answer from the
/// viewer's own block list only (#7345).
bool dmEveryPeerBlocked({
  required List<String> participantPubkeys,
  required String currentUserPubkey,
  required bool Function(String pubkey) isBlockedByUs,
}) {
  final peers = participantPubkeys.where(
    (pubkey) => !pubkeysEqual(pubkey, currentUserPubkey),
  );
  return peers.isNotEmpty && peers.every(isBlockedByUs);
}

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
/// previews: only a group hides it, never the viewer's own, and not once every
/// other member is blocked ([dmEveryPeerBlocked]), which lists the row under
/// Blocked to be read in full. The inbox projection, the row and search all
/// ask here, so they cannot disagree. [isHidden] and [isBlockedByUs] must
/// answer from the viewer's own lists only (#7345).
bool dmPreviewHidden({
  required DmConversation conversation,
  required String currentUserPubkey,
  required bool Function(String pubkey) isHidden,
  required bool Function(String pubkey) isBlockedByUs,
}) =>
    // Every member is asked about last: a one-to-one, or a group the viewer or
    // a visible member wrote last, is settled without walking its members.
    dmMessageHiddenByDefault(
      isGroup: conversation.isGroup,
      everyMemberBlocked: false,
      senderPubkey: conversation.lastMessageSenderPubkey ?? '',
      currentUserPubkey: currentUserPubkey,
      isHidden: isHidden,
    ) &&
    !dmEveryPeerBlocked(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentUserPubkey,
      isBlockedByUs: isBlockedByUs,
    );

/// [conversations] as the viewer's inbox reads them once the members they hide
/// are set aside, so a hidden member's messages neither mark a group unread nor
/// move it up (#10150).
///
/// A row whose last message [dmPreviewHidden] hides takes its newest message by
/// anyone else — preview, time and sender — and turns read unless someone the
/// viewer still sees wrote after both the read cursor and the viewer's own
/// newest message. A group with no visible activity keeps its stored, hidden
/// preview, turns read, and sorts at its stable creation time instead of the
/// hidden sender's latest message. Read state only turns from unread to read.
/// Every other row, and every row once its member is no longer hidden, is
/// returned as stored without a query; so is the list itself when no row needs
/// reading, which leaves a one-to-one inbox exactly as it was. Otherwise the
/// result is sorted newest first, as [DmRepository.mergeAndSort] sorts,
/// keeping the stored order between rows that tie.
///
/// The Messages list and its badge both read through this, so they cannot
/// disagree about which groups are unread. [isHidden] and [isBlockedByUs] must
/// answer from the viewer's own lists only (#7345).
Future<List<DmConversation>> dmConversationsAsSeen({
  required List<DmConversation> conversations,
  required String currentUserPubkey,
  required bool Function(String pubkey) isHidden,
  required bool Function(String pubkey) isBlockedByUs,
  required DmRepository dmRepository,
}) async {
  final excludedSenders = <String, Set<String>>{
    for (final conversation in conversations)
      if (dmPreviewHidden(
        conversation: conversation,
        currentUserPubkey: currentUserPubkey,
        isHidden: isHidden,
        isBlockedByUs: isBlockedByUs,
      ))
        conversation.id: {
          for (final pubkey in conversation.participantPubkeys)
            if (!pubkeysEqual(pubkey, currentUserPubkey) && isHidden(pubkey))
              pubkey,
        },
  };
  if (excludedSenders.isEmpty) return conversations;

  final activity = await dmRepository.visibleActivityExcluding(
    excludedSenders,
  );
  final seen = [
    for (final conversation in conversations)
      switch (activity[conversation.id]) {
        null => conversation,
        final visible => _withVisibleActivity(conversation, visible),
      },
  ];
  mergeSort(
    seen,
    compare: (a, b) => b.effectiveTimestamp.compareTo(a.effectiveTimestamp),
  );
  return seen;
}

DmConversation _withVisibleActivity(
  DmConversation conversation,
  DmVisibleActivity visible,
) {
  final isRead = conversation.isRead || !visible.hasUnread;
  final timestamp = visible.lastMessageTimestamp;
  if (timestamp == null) {
    return conversation.copyWith(
      // A null timestamp identifies synthetic "no thread" rows in Blocked.
      // Keep this real thread reachable while giving it a stable sort time.
      lastMessageTimestamp: conversation.createdAt,
      isRead: isRead,
    );
  }
  return conversation.copyWith(
    lastMessageContent: visible.lastMessageContent,
    lastMessageTimestamp: timestamp,
    lastMessageSenderPubkey: visible.lastMessageSenderPubkey,
    isRead: isRead,
  );
}

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
