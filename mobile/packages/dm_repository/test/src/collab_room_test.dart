import 'dart:math';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

const author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const kai = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const stranger =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const roomId = '0123456789abcdef0123456789abcdef';

var _nextId = 0;

String _eventId() => (++_nextId).toRadixString(16).padLeft(64, '0');

const _metadata = DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: 'key',
  decryptionNonce: 'nonce',
  fileHash: 'hash-one',
  originalFileHash: 'plain-one',
  fileSize: 42,
  dimensions: '1080x1920',
);

CollabRoomSnapshot snapshot({
  int revision = 0,
  CollabRoomPhase phase = CollabRoomPhase.lobby,
  List<CollabRoomMember>? members,
  List<CollabRoomPart> parts = const [],
  String? layout,
  String? soundPubkey,
  String? videoAddress,
  String? callKey,
}) => CollabRoomSnapshot(
  revision: revision,
  phase: phase,
  members:
      members ??
      const [
        CollabRoomMember(
          pubkey: author,
          status: CollabRoomMemberStatus.joined,
        ),
        CollabRoomMember(pubkey: sam, status: CollabRoomMemberStatus.invited),
        CollabRoomMember(pubkey: kai, status: CollabRoomMemberStatus.invited),
      ],
  parts: parts,
  layout: layout,
  soundPubkey: soundPubkey,
  videoAddress: videoAddress,
  callKey: callKey,
);

DmMessage roomMessage({
  required String from,
  required String to,
  required CollabRoomMessageType type,
  CollabRoomSnapshot? state,
  int createdAt = 1,
  String room = roomId,
  DmFileMetadata? fileMetadata,
  String content = 'Readable fallback',
  List<List<String>>? tags,
}) => DmMessage(
  id: _eventId(),
  conversationId: DmRepository.computeConversationId([from, to]),
  senderPubkey: from,
  content: content,
  createdAt: createdAt,
  giftWrapId: _eventId(),
  messageKind: type == CollabRoomMessageType.part ? 15 : 14,
  fileMetadata: fileMetadata,
  tags:
      tags ??
      collabRoomTags(
        roomId: room,
        type: type,
        recipientPubkey: to,
        snapshot: state,
      ),
);

DmMessage partMessage({
  required String from,
  int createdAt = 2,
  DmFileMetadata metadata = _metadata,
}) => roomMessage(
  from: from,
  to: author,
  type: CollabRoomMessageType.part,
  createdAt: createdAt,
  fileMetadata: metadata,
  content: 'https://media.example/$from',
);

void main() {
  group('newCollabRoomId', () {
    test('creates a 32 character hex id', () {
      final id = newCollabRoomId(Random(1));
      expect(isValidCollabRoomId(id), isTrue);
      expect(id, hasLength(32));
    });

    test('creates different ids from a secure source', () {
      expect(newCollabRoomId(), isNot(newCollabRoomId()));
    });

    test('rejects malformed ids', () {
      expect(isValidCollabRoomId('ABC'), isFalse);
      expect(isValidCollabRoomId('${roomId}00'), isFalse);
    });
  });

  group(CollabRoomPhase, () {
    test('only lobby and recording are open', () {
      expect(
        CollabRoomPhase.values.where((p) => p.isOpen),
        [CollabRoomPhase.lobby, CollabRoomPhase.recording],
      );
    });
  });

  group(CollabRoomMember, () {
    test('copies with a new status and cell', () {
      const member = CollabRoomMember(
        pubkey: sam,
        status: CollabRoomMemberStatus.invited,
      );
      expect(
        member.copyWith(status: CollabRoomMemberStatus.joined, cell: 2),
        const CollabRoomMember(
          pubkey: sam,
          status: CollabRoomMemberStatus.joined,
          cell: 2,
        ),
      );
      expect(member.copyWith(), member);
    });
  });

  group(CollabRoomMemberStatus, () {
    test('only invited and joined people are active', () {
      expect(
        CollabRoomMemberStatus.values.where((s) => s.isActive),
        [CollabRoomMemberStatus.invited, CollabRoomMemberStatus.joined],
      );
    });
  });

  group(CollabRoomSnapshot, () {
    test('round-trips everything through its JSON', () {
      const part = CollabRoomPart(
        pubkey: sam,
        url: 'https://media.example/sam',
        metadata: _metadata,
      );
      final original = snapshot(
        revision: 4,
        phase: CollabRoomPhase.posted,
        members: const [
          CollabRoomMember(
            pubkey: author,
            status: CollabRoomMemberStatus.joined,
            cell: 0,
          ),
          CollabRoomMember(
            pubkey: sam,
            status: CollabRoomMemberStatus.joined,
            cell: 1,
          ),
        ],
        parts: const [part],
        layout: 'sideBySide',
        soundPubkey: sam,
        videoAddress: '34236:$author:d',
        callKey: 'f' * 64,
      );
      expect(CollabRoomSnapshot.decode(original.encode()), original);
    });

    test('leaves optional fields out of the JSON', () {
      final encoded = snapshot().encode();
      expect(encoded, isNot(contains('layout')));
      expect(encoded, isNot(contains('parts')));
      expect(encoded, isNot(contains('sound')));
    });

    for (final (name, json) in [
      ('not JSON', 'nope'),
      ('not an object', '[]'),
      (
        'a missing revision',
        '{"phase":"lobby","members":[],"aspect":"vertical"}',
      ),
      (
        'an unknown phase',
        '{"rev":0,"phase":"x","members":[],"aspect":"vertical"}',
      ),
      (
        'an unknown aspect ratio',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"wide"}',
      ),
      (
        'no members',
        '{"rev":0,"phase":"lobby","members":[],"aspect":"vertical"}',
      ),
      (
        'a member that is not an object',
        '{"rev":0,"phase":"lobby","members":[1],"aspect":"vertical"}',
      ),
      (
        'a malformed pubkey',
        '{"rev":0,"phase":"lobby","members":[{"p":"x","s":"joined"}],'
            '"aspect":"vertical"}',
      ),
      (
        'a duplicated member',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"},'
            '{"p":"$author","s":"joined"}],"aspect":"vertical"}',
      ),
      (
        'a negative cell',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined",'
            '"cell":-1}],"aspect":"vertical"}',
      ),
      (
        'five people',
        '{"rev":0,"phase":"lobby","members":['
            '{"p":"$author","s":"joined"},{"p":"$sam","s":"joined"},'
            '{"p":"$kai","s":"joined"},{"p":"$stranger","s":"joined"},'
            '{"p":"${'e' * 64}","s":"joined"}],"aspect":"vertical"}',
      ),
      (
        'a part of someone outside the room',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","parts":[{"p":"$sam","url":"https://m/x",'
            '"type":"video/mp4","alg":"aes-gcm","key":"k","nonce":"n",'
            '"x":"h"}]}',
      ),
      (
        'a part served over http',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","parts":[{"p":"$author","url":"http://m/x",'
            '"type":"video/mp4","alg":"aes-gcm","key":"k","nonce":"n",'
            '"x":"h"}]}',
      ),
      (
        'a part that is not a video',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","parts":[{"p":"$author","url":"https://m/x",'
            '"type":"image/png","alg":"aes-gcm","key":"k","nonce":"n",'
            '"x":"h"}]}',
      ),
      (
        'a part that is not an object',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","parts":["x"]}',
      ),
      (
        'a malformed call key',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","call":"x"}',
      ),
      (
        'a malformed sound pubkey',
        '{"rev":0,"phase":"lobby","members":[{"p":"$author","s":"joined"}],'
            '"aspect":"vertical","sound":"x"}',
      ),
    ]) {
      test('rejects $name', () {
        expect(CollabRoomSnapshot.decode(json), isNull);
      });
    }
  });

  group('collabRoomTags', () {
    test('carries the marker, the room tag and the snapshot', () {
      final state = snapshot();
      expect(
        collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.invite,
          recipientPubkey: sam,
          snapshot: state,
        ),
        [
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'invite', sam],
          ['collab-room-state', state.encode()],
        ],
      );
    });

    test('refuses a snapshot on a message that carries none', () {
      expect(
        () => collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.join,
          recipientPubkey: author,
          snapshot: snapshot(),
        ),
        throwsArgumentError,
      );
    });

    test('refuses an invite without a snapshot', () {
      expect(
        () => collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.invite,
          recipientPubkey: sam,
        ),
        throwsArgumentError,
      );
    });

    test('refuses a malformed room id or recipient', () {
      expect(
        () => collabRoomTags(
          roomId: 'x',
          type: CollabRoomMessageType.join,
          recipientPubkey: author,
        ),
        throwsArgumentError,
      );
      expect(
        () => collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.join,
          recipientPubkey: 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('parseCollabRoomMessage', () {
    test('reads an invite with its snapshot', () {
      final state = snapshot();
      final message = roomMessage(
        from: author,
        to: sam,
        type: CollabRoomMessageType.invite,
        state: state,
      );
      final parsed = parseCollabRoomMessage(message, ownerPubkey: sam);
      expect(parseCollabRoomMessage(message, ownerPubkey: sam), parsed);
      expect(parsed?.type, CollabRoomMessageType.invite);
      expect(parsed?.roomId, roomId);
      expect(parsed?.senderPubkey, author);
      expect(parsed?.recipientPubkey, sam);
      expect(parsed?.snapshot, state);
      expect(parsed?.messageId, message.id);
      expect(parsed?.createdAt, 1);
    });

    test('reads a part from its file message', () {
      final parsed = parseCollabRoomMessage(
        partMessage(from: sam),
        ownerPubkey: author,
      );
      expect(parsed?.type, CollabRoomMessageType.part);
      expect(
        parsed?.part,
        const CollabRoomPart(
          pubkey: sam,
          url: 'https://media.example/$sam',
          metadata: _metadata,
        ),
      );
      expect(parsed?.part?.fileHash, 'hash-one');
    });

    test('ignores a message of a conversation the account is not in', () {
      expect(
        parseCollabRoomMessage(
          roomMessage(from: sam, to: author, type: CollabRoomMessageType.join),
          ownerPubkey: kai,
        ),
        isNull,
      );
    });

    test('ignores a recipient that is not the other side', () {
      final message = roomMessage(
        from: sam,
        to: author,
        type: CollabRoomMessageType.join,
        tags: collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.join,
          recipientPubkey: kai,
        ),
      );
      expect(parseCollabRoomMessage(message, ownerPubkey: author), isNull);
    });

    test('ignores a message addressed to its own sender', () {
      final message = roomMessage(
        from: sam,
        to: author,
        type: CollabRoomMessageType.join,
        tags: [
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'join', sam],
        ],
      );
      expect(parseCollabRoomMessage(message, ownerPubkey: author), isNull);
    });

    test('ignores malformed identities', () {
      final message = roomMessage(
        from: sam,
        to: author,
        type: CollabRoomMessageType.join,
      );
      expect(parseCollabRoomMessage(message, ownerPubkey: 'x'), isNull);
    });

    for (final (name, tags) in [
      (
        'no marker',
        <List<String>>[
          ['collab-room', roomId, 'join', author],
        ],
      ),
      (
        'another marker version',
        <List<String>>[
          ['divine', 'collab-room', '2'],
          ['collab-room', roomId, 'join', author],
        ],
      ),
      (
        'no room tag',
        <List<String>>[
          ['divine', 'collab-room', '1'],
        ],
      ),
      (
        'two room tags',
        <List<String>>[
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'join', author],
          ['collab-room', roomId, 'leave', author],
        ],
      ),
      (
        'an unknown type',
        <List<String>>[
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'dance', author],
        ],
      ),
      (
        'a malformed room id',
        <List<String>>[
          ['divine', 'collab-room', '1'],
          ['collab-room', 'x', 'join', author],
        ],
      ),
      (
        'a snapshot on a join',
        <List<String>>[
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'join', author],
          ['collab-room-state', snapshot().encode()],
        ],
      ),
    ]) {
      test('ignores $name', () {
        final message = roomMessage(
          from: sam,
          to: author,
          type: CollabRoomMessageType.join,
          tags: tags,
        );
        expect(parseCollabRoomMessage(message, ownerPubkey: author), isNull);
      });
    }

    test('ignores an invite without a readable snapshot', () {
      final message = roomMessage(
        from: author,
        to: sam,
        type: CollabRoomMessageType.invite,
        tags: [
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'invite', sam],
          ['collab-room-state', '{'],
        ],
      );
      expect(parseCollabRoomMessage(message, ownerPubkey: sam), isNull);
      final bare = roomMessage(
        from: author,
        to: sam,
        type: CollabRoomMessageType.invite,
        tags: [
          ['divine', 'collab-room', '1'],
          ['collab-room', roomId, 'invite', sam],
        ],
      );
      expect(parseCollabRoomMessage(bare, ownerPubkey: sam), isNull);
    });

    test('ignores a part that is not an encrypted video', () {
      expect(
        parseCollabRoomMessage(
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.part,
            content: 'https://media.example/x',
          ),
          ownerPubkey: author,
        ),
        isNull,
      );
      expect(
        parseCollabRoomMessage(
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.part,
            fileMetadata: _metadata,
            content: 'http://media.example/x',
          ),
          ownerPubkey: author,
        ),
        isNull,
      );
    });

    test('ignores a text message claiming to be a part', () {
      final message = DmMessage(
        id: _eventId(),
        conversationId: DmRepository.computeConversationId([sam, author]),
        senderPubkey: sam,
        content: 'https://media.example/x',
        createdAt: 1,
        giftWrapId: _eventId(),
        fileMetadata: _metadata,
        tags: collabRoomTags(
          roomId: roomId,
          type: CollabRoomMessageType.part,
          recipientPubkey: author,
        ),
      );
      expect(parseCollabRoomMessage(message, ownerPubkey: author), isNull);
    });
  });

  group('foldCollabRoom', () {
    test('needs an invite to place the account in a room', () {
      expect(
        foldCollabRooms([
          roomMessage(from: sam, to: author, type: CollabRoomMessageType.join),
        ], ownerPubkey: author),
        isEmpty,
      );
      expect(foldCollabRoom(roomId, const [], ownerPubkey: author), isNull);
    });

    group('as the author', () {
      List<DmMessage> invites({int createdAt = 1}) => [
        for (final member in [sam, kai])
          roomMessage(
            from: author,
            to: member,
            type: CollabRoomMessageType.invite,
            state: snapshot(),
            createdAt: createdAt,
          ),
      ];

      test('lists everyone it invited, itself first', () {
        final room = foldCollabRooms(
          invites(),
          ownerPubkey: author,
        ).single;
        expect(room.isAuthor, isTrue);
        expect(room.authorPubkey, author);
        expect(room.id, roomId);
        expect(room.phase, CollabRoomPhase.lobby);
        expect(room.members.map((m) => m.pubkey), [author, sam, kai]);
        expect(room.me?.status, CollabRoomMemberStatus.joined);
        expect(room.participants.map((m) => m.pubkey), [author]);
        expect(room.needsBroadcast, isFalse);
        expect(room.soundPubkey, author);
        expect(room.aspectRatio, 'vertical');
        expect(room.layout, isNull);
      });

      test('folds in answers and parts, newest answer winning', () {
        final room = foldCollabRooms([
          ...invites(),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
          roomMessage(
            from: kai,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
          roomMessage(
            from: kai,
            to: author,
            type: CollabRoomMessageType.leave,
            createdAt: 3,
          ),
          partMessage(from: sam, createdAt: 4),
        ], ownerPubkey: author).single;
        expect(
          room.members.map((m) => m.status),
          [
            CollabRoomMemberStatus.joined,
            CollabRoomMemberStatus.joined,
            CollabRoomMemberStatus.left,
          ],
        );
        expect(room.parts.keys, [sam]);
        expect(room.participants.map((m) => m.pubkey), [author, sam]);
        expect(room.needsBroadcast, isTrue);
        expect(room.updatedAt, 4);
      });

      test('asks back someone who left: only their newer answers count', () {
        final askedBack = snapshot(revision: 2);
        List<DmMessage> history({bool rejoined = false}) => [
          ...invites(),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.leave,
            createdAt: 3,
          ),
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: askedBack,
            createdAt: 4,
          ),
          if (rejoined)
            roomMessage(
              from: sam,
              to: author,
              type: CollabRoomMessageType.join,
              createdAt: 5,
            ),
        ];
        CollabRoomMemberStatus? samIn(List<DmMessage> messages, String owner) =>
            foldCollabRooms(
              messages,
              ownerPubkey: owner,
            ).single.members.firstWhere((m) => m.pubkey == sam).status;

        // The earlier leave no longer counts, on either side.
        expect(samIn(history(), author), CollabRoomMemberStatus.invited);
        expect(samIn(history(), sam), CollabRoomMemberStatus.invited);
        expect(
          samIn(history(rejoined: true), author),
          CollabRoomMemberStatus.joined,
        );
      });

      test('keeps someone it removed out, whatever they send', () {
        final removed = snapshot(
          revision: 1,
          members: const [
            CollabRoomMember(
              pubkey: author,
              status: CollabRoomMemberStatus.joined,
            ),
            CollabRoomMember(
              pubkey: sam,
              status: CollabRoomMemberStatus.removed,
            ),
          ],
        );
        final room = foldCollabRooms([
          ...invites(),
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.state,
            state: removed,
            createdAt: 2,
          ),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 3,
          ),
          partMessage(from: sam, createdAt: 4),
        ], ownerPubkey: author).single;
        expect(room.members.last.status, CollabRoomMemberStatus.removed);
        expect(room.parts, isEmpty);
        expect(room.needsBroadcast, isFalse);
      });

      test('records a decline and ignores snapshots members send', () {
        final messages = [
          ...invites(),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.decline,
            createdAt: 2,
          ),
          roomMessage(
            from: kai,
            to: author,
            type: CollabRoomMessageType.state,
            state: snapshot(revision: 9, phase: CollabRoomPhase.cancelled),
            createdAt: 3,
          ),
        ];
        final room = foldCollabRooms(messages, ownerPubkey: author).single;
        expect(room.members[1].status, CollabRoomMemberStatus.declined);
        expect(room.phase, CollabRoomPhase.lobby);
        expect(
          foldCollabRooms(messages, ownerPubkey: author).single,
          room,
        );
      });

      test('asks for a broadcast when only a part is new', () {
        final joined = snapshot(
          revision: 1,
          members: const [
            CollabRoomMember(
              pubkey: author,
              status: CollabRoomMemberStatus.joined,
            ),
            CollabRoomMember(
              pubkey: sam,
              status: CollabRoomMemberStatus.joined,
            ),
          ],
        );
        final messages = [
          ...invites(),
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.state,
            state: joined,
            createdAt: 2,
          ),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
        ];
        final before = foldCollabRooms(messages, ownerPubkey: author).single;
        expect(before.needsBroadcast, isFalse);
        expect(before.allPartsIn, isFalse);
        final after = foldCollabRooms([
          ...messages,
          partMessage(from: sam, createdAt: 3),
        ], ownerPubkey: author).single;
        expect(after.needsBroadcast, isTrue);
        expect(after.parts.keys, [sam]);
        expect(after.allPartsIn, isFalse);
        expect(after, isNot(before));
      });

      test('ignores messages from people it never invited', () {
        final room = foldCollabRooms([
          ...invites(),
          roomMessage(
            from: stranger,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
          partMessage(from: stranger, createdAt: 3),
        ], ownerPubkey: author).single;
        expect(room.members.map((m) => m.pubkey), isNot(contains(stranger)));
        expect(room.parts, isEmpty);
      });

      test('reads its newest snapshot back', () {
        final recording = snapshot(
          revision: 2,
          phase: CollabRoomPhase.recording,
          layout: 'stacked',
          soundPubkey: sam,
          members: const [
            CollabRoomMember(
              pubkey: author,
              status: CollabRoomMemberStatus.joined,
              cell: 0,
            ),
            CollabRoomMember(
              pubkey: sam,
              status: CollabRoomMemberStatus.joined,
              cell: 1,
            ),
          ],
        );
        final room = foldCollabRooms([
          ...invites(),
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.state,
            state: recording,
            createdAt: 3,
          ),
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.state,
            state: snapshot(revision: 1),
            createdAt: 4,
          ),
        ], ownerPubkey: author).single;
        expect(room.snapshot, recording);
        expect(room.layout, 'stacked');
        expect(room.soundPubkey, sam);
        expect(room.memberInCell(1)?.pubkey, sam);
        expect(room.memberInCell(2), isNull);
      });

      test('a closed room never asks for a broadcast', () {
        final room = foldCollabRooms([
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(phase: CollabRoomPhase.cancelled),
          ),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
        ], ownerPubkey: author).single;
        expect(room.needsBroadcast, isFalse);
      });
    });

    group('as a member', () {
      test('learns the room from the invite', () {
        final room = foldCollabRooms([
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(),
          ),
        ], ownerPubkey: sam).single;
        expect(room.isAuthor, isFalse);
        expect(room.authorPubkey, author);
        expect(room.me?.status, CollabRoomMemberStatus.invited);
        expect(room.needsBroadcast, isFalse);
      });

      test('sees its own answer and part before the author confirms', () {
        final room = foldCollabRooms([
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(),
          ),
          roomMessage(
            from: sam,
            to: author,
            type: CollabRoomMessageType.join,
            createdAt: 2,
          ),
          partMessage(from: sam, createdAt: 3),
        ], ownerPubkey: sam).single;
        expect(room.me?.status, CollabRoomMemberStatus.joined);
        expect(room.parts.keys, [sam]);
      });

      test('ignores snapshots from anyone but the author', () {
        final room = foldCollabRooms([
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(),
          ),
          roomMessage(
            from: kai,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(revision: 9, phase: CollabRoomPhase.cancelled),
            createdAt: 2,
          ),
        ], ownerPubkey: sam).single;
        expect(room.authorPubkey, author);
        expect(room.phase, CollabRoomPhase.lobby);
      });

      test('drops a room whose snapshot no longer lists it', () {
        final rooms = foldCollabRooms([
          roomMessage(
            from: author,
            to: sam,
            type: CollabRoomMessageType.invite,
            state: snapshot(
              members: const [
                CollabRoomMember(
                  pubkey: author,
                  status: CollabRoomMemberStatus.joined,
                ),
              ],
            ),
          ),
        ], ownerPubkey: sam);
        expect(rooms, isEmpty);
      });
    });

    test('sorts rooms newest first', () {
      const other = 'ffffffffffffffffffffffffffffffff';
      final rooms = foldCollabRooms([
        roomMessage(
          from: author,
          to: sam,
          type: CollabRoomMessageType.invite,
          state: snapshot(),
        ),
        roomMessage(
          from: author,
          to: sam,
          type: CollabRoomMessageType.invite,
          state: snapshot(),
          room: other,
          createdAt: 5,
        ),
      ], ownerPubkey: author);
      expect(rooms.map((r) => r.id), [other, roomId]);
    });
  });

  group('CollabRoom.toSnapshot', () {
    test('publishes the folded view with its changes', () {
      final room = foldCollabRooms([
        roomMessage(
          from: author,
          to: sam,
          type: CollabRoomMessageType.invite,
          state: snapshot(),
        ),
        roomMessage(
          from: sam,
          to: author,
          type: CollabRoomMessageType.join,
          createdAt: 2,
        ),
        partMessage(from: sam, createdAt: 3),
      ], ownerPubkey: author).single;
      final next = room.toSnapshot(
        revision: 1,
        phase: CollabRoomPhase.recording,
        layout: 'grid',
        aspectRatio: 'square',
        soundPubkey: sam,
        videoAddress: '34236:$author:d',
      );
      expect(next.revision, 1);
      expect(next.phase, CollabRoomPhase.recording);
      expect(next.layout, 'grid');
      expect(next.aspectRatio, 'square');
      expect(next.soundPubkey, sam);
      expect(next.videoAddress, '34236:$author:d');
      expect(next.callKey, room.callKey);
      expect(next.members, room.members);
      expect(next.parts.map((p) => p.pubkey), [sam]);
    });

    test('keeps a left member out of the published parts', () {
      final room = foldCollabRooms([
        roomMessage(
          from: author,
          to: sam,
          type: CollabRoomMessageType.invite,
          state: snapshot(),
        ),
      ], ownerPubkey: author).single;
      final next = room.toSnapshot(
        revision: 1,
        members: room.members
            .map(
              (member) => member.pubkey == sam
                  ? member.copyWith(status: CollabRoomMemberStatus.left)
                  : member,
            )
            .toList(),
        parts: {
          sam: const CollabRoomPart(
            pubkey: sam,
            url: 'https://media.example/sam',
            metadata: _metadata,
          ),
        },
      );
      expect(next.parts, isEmpty);
    });
  });
}
