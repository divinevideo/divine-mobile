import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart' show DmMessage;

const author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const roomId = '0123456789abcdef0123456789abcdef';

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
], ownerPubkey: owner).single;
