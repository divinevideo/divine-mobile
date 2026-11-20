import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart' show DmMessage;

const author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const roomId = '0123456789abcdef0123456789abcdef';

/// [from]'s own Join of [room], sent to [to]: a member's device counts the
/// member in only once they said so.
DmMessage joinMessage({
  required String from,
  required String to,
  required String room,
  int createdAt = 2,
}) => DmMessage(
  id: '3' * 64,
  conversationId: DmRepository.computeConversationId([from, to]),
  senderPubkey: from,
  content: 'text',
  createdAt: createdAt,
  giftWrapId: '4' * 64,
  tags: collabRoomTags(
    roomId: room,
    type: CollabRoomMessageType.join,
    recipientPubkey: to,
  ),
);

/// [owner]'s view of a two-person room [author] invited [sam] into.
CollabRoom twoPersonRoom({
  required String owner,
  CollabRoomPhase phase = CollabRoomPhase.lobby,
  CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.invited,
}) => foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([author, sam]),
    senderPubkey: author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: roomId,
      type: CollabRoomMessageType.invite,
      recipientPubkey: sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: phase,
        members: [
          const CollabRoomMember(
            pubkey: author,
            status: CollabRoomMemberStatus.joined,
          ),
          CollabRoomMember(pubkey: sam, status: samStatus),
        ],
      ),
    ),
  ),
  if (samStatus == CollabRoomMemberStatus.joined)
    joinMessage(from: sam, to: author, room: roomId),
], ownerPubkey: owner).single;
