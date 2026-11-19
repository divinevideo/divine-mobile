import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/dm_video_send_service.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _kai = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _roomId = '0123456789abcdef0123456789abcdef';

const _metadata = DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: 'key',
  decryptionNonce: 'nonce',
  fileHash: 'hash',
);

var _nextId = 0;
String _eventId() => (++_nextId).toRadixString(16).padLeft(64, '0');

DmMessage _message({
  required String from,
  required String to,
  required CollabRoomMessageType type,
  CollabRoomSnapshot? snapshot,
  int createdAt = 1,
}) => DmMessage(
  id: _eventId(),
  conversationId: DmRepository.computeConversationId([from, to]),
  senderPubkey: from,
  content: type == CollabRoomMessageType.part
      ? 'https://media.example/$from'
      : 'text',
  createdAt: createdAt,
  giftWrapId: _eventId(),
  messageKind: type == CollabRoomMessageType.part ? 15 : 14,
  fileMetadata: type == CollabRoomMessageType.part ? _metadata : null,
  tags: collabRoomTags(
    roomId: _roomId,
    type: type,
    recipientPubkey: to,
    snapshot: snapshot,
  ),
);

CollabRoomSnapshot _lobby({
  int revision = 0,
  CollabRoomPhase phase = CollabRoomPhase.lobby,
  CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.invited,
}) => CollabRoomSnapshot(
  revision: revision,
  phase: phase,
  members: [
    const CollabRoomMember(
      pubkey: _author,
      status: CollabRoomMemberStatus.joined,
    ),
    CollabRoomMember(pubkey: _sam, status: samStatus),
    const CollabRoomMember(
      pubkey: _kai,
      status: CollabRoomMemberStatus.declined,
    ),
  ],
);

NIP17SendResult _sent(String recipient) => NIP17SendResult.success(
  rumorEventId: _eventId(),
  messageEventId: _eventId(),
  recipientPubkey: recipient,
);

void main() {
  group(CollabRoomService, () {
    late _MockDmRepository dm;
    late _MockDmVideoSendService videos;
    late StreamController<List<DmMessage>> history;
    late Directory storage;
    late List<DmMessage> decrypted;
    late String owner;

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() {
      dm = _MockDmRepository();
      videos = _MockDmVideoSendService();
      history = StreamController<List<DmMessage>>.broadcast();
      storage = Directory.systemTemp.createTempSync('collab_room_service');
      decrypted = [];
      owner = _author;
      when(() => dm.userPubkey).thenAnswer((_) => owner);
      when(dm.watchCollabRoomMessages).thenAnswer((_) => history.stream);
      when(
        () => dm.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (invocation) async =>
            _sent(invocation.namedArguments[#recipientPubkey] as String),
      );
    });

    tearDown(() async {
      await history.close();
      if (storage.existsSync()) storage.deleteSync(recursive: true);
    });

    CollabRoomService service() => CollabRoomService(
      dmRepository: dm,
      videoSendService: videos,
      decryptPart: (message) async {
        decrypted.add(message);
        return [1, 2, 3];
      },
      l10n: lookupAppLocalizations(const Locale('en')),
      storageDirectory: () async => storage,
    );

    /// Emits [messages] as the account's room history, once listened to.
    Future<CollabRoom?> roomFrom(List<DmMessage> messages) {
      final room = service().watchRoom(_roomId).first;
      scheduleMicrotask(() => history.add(messages));
      return room;
    }

    List<(String, List<List<String>>)> sentMessages() => [
      for (final call in verify(
        () => dm.sendMessage(
          recipientPubkey: captureAny(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: captureAny(named: 'additionalTags'),
          skipNip04Fallback: true,
        ),
      ).captured.slices(2))
        (call[0] as String, call[1] as List<List<String>>),
    ];

    group('watchRooms', () {
      test('folds the room history into rooms', () async {
        final rooms = service().watchRooms().first;
        scheduleMicrotask(
          () => history.add([
            _message(
              from: _author,
              to: _sam,
              type: CollabRoomMessageType.invite,
              snapshot: _lobby(),
            ),
          ]),
        );
        expect((await rooms).single.id, _roomId);
      });

      test('has no rooms without an account', () async {
        owner = '';
        expect(await service().watchRooms().first, isEmpty);
      });
    });

    group('createRoom', () {
      test('invites everyone with the lobby snapshot', () async {
        final roomId = await service().createRoom([_sam, _kai]);

        expect(isValidCollabRoomId(roomId), isTrue);
        final sent = sentMessages();
        expect(sent.map((s) => s.$1), [_sam, _kai]);
        final parsed = parseCollabRoomMessage(
          DmMessage(
            id: _eventId(),
            conversationId: DmRepository.computeConversationId([
              _author,
              _sam,
            ]),
            senderPubkey: _author,
            content: 'text',
            createdAt: 1,
            giftWrapId: _eventId(),
            tags: sent.first.$2,
          ),
          ownerPubkey: _author,
        );
        expect(parsed?.type, CollabRoomMessageType.invite);
        expect(parsed?.roomId, roomId);
        expect(parsed?.snapshot?.callKey, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(
          parsed?.snapshot?.members.map((m) => (m.pubkey, m.status)),
          [
            (_author, CollabRoomMemberStatus.joined),
            (_sam, CollabRoomMemberStatus.invited),
            (_kai, CollabRoomMemberStatus.invited),
          ],
        );
      });

      for (final (name, invitees) in [
        ('nobody', <String>[]),
        ('the same person twice', [_sam, _sam]),
        ('the author', [_author]),
        ('four people', [_sam, _kai, 'd' * 64, 'e' * 64]),
        ('a malformed pubkey', ['x']),
      ]) {
        test('refuses $name', () {
          expect(
            () => service().createRoom(invitees),
            throwsArgumentError,
          );
        });
      }

      test('throws when no invite could be delivered', () async {
        when(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('refused'));

        await expectLater(
          service().createRoom([_sam]),
          throwsA(isA<CollabRoomException>()),
        );
      });
    });

    group('answers', () {
      late CollabRoom room;

      setUp(() async {
        owner = _sam;
        room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(),
          ),
        ]))!;
      });

      for (final (name, answer, type) in [
        ('join', (CollabRoomService s, CollabRoom r) => s.join(r), 'join'),
        (
          'decline',
          (CollabRoomService s, CollabRoom r) => s.decline(r),
          'decline',
        ),
        ('leave', (CollabRoomService s, CollabRoom r) => s.leave(r), 'leave'),
      ]) {
        test('sends a $name to the author', () async {
          await answer(service(), room);
          final (recipient, tags) = sentMessages().single;
          expect(recipient, _author);
          expect(
            tags,
            anyElement(equals(['collab-room', _roomId, type, _author])),
          );
        });
      }

      test('throws when the answer was not delivered', () async {
        when(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await expectLater(
          service().join(room),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test('refuses an answer from the author', () async {
        owner = _author;
        final own = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(),
          ),
        ]))!;
        expect(() => service().join(own), throwsStateError);
      });
    });

    group('publish', () {
      late CollabRoom room;

      setUp(() async {
        room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(),
          ),
        ]))!;
      });

      test('sends the snapshot to everyone still in the room', () async {
        await service().publish(
          room,
          room.toSnapshot(revision: 1, phase: CollabRoomPhase.recording),
        );

        final sent = sentMessages();
        expect(sent.map((s) => s.$1), [_sam]);
        expect(
          sent.single.$2,
          anyElement(equals(['collab-room', _roomId, 'state', _sam])),
        );
      });

      test('tells someone it takes out of the room, once', () async {
        final removed = room.toSnapshot(
          revision: 1,
          members: [
            for (final member in room.members)
              member.copyWith(
                status: member.pubkey == _sam
                    ? CollabRoomMemberStatus.removed
                    : null,
              ),
          ],
        );
        await service().publish(room, removed);
        expect(sentMessages().map((s) => s.$1), [_sam]);
      });

      test('sends nothing when nobody else is in the room', () async {
        final alone = room.toSnapshot(
          revision: 1,
          members: [room.members.first],
        );
        final soloRoom = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(samStatus: CollabRoomMemberStatus.declined),
          ),
        ]))!;
        await service().publish(soloRoom, alone);
        verifyNever(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        );
      });

      test('throws when the update reached nobody', () async {
        when(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await expectLater(
          service().publish(room, room.toSnapshot(revision: 1)),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test('refuses a publish from a member', () async {
        owner = _sam;
        final memberRoom = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(),
          ),
        ]))!;
        expect(
          () => service().publish(
            memberRoom,
            memberRoom.toSnapshot(revision: 1),
          ),
          throwsStateError,
        );
      });
    });

    group('sendPart', () {
      test('sends a member part to the author as a video message', () async {
        owner = _sam;
        final room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(
              phase: CollabRoomPhase.recording,
              samStatus: CollabRoomMemberStatus.joined,
            ),
          ),
        ]))!;
        when(
          () => videos.sendVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            extraTags: any(named: 'extraTags'),
          ),
        ).thenAnswer((_) async => _sent(_author));

        await service().sendPart(room, File('part.mp4'));

        final captured = verify(
          () => videos.sendVideo(
            recipientPubkey: _author,
            videoFile: any(named: 'videoFile'),
            mimeType: 'video/mp4',
            extraTags: captureAny(named: 'extraTags'),
          ),
        ).captured;
        expect(
          captured.single,
          anyElement(equals(['collab-room', _roomId, 'part', _author])),
        );
      });

      test('throws when the member part was not delivered', () async {
        owner = _sam;
        final room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(samStatus: CollabRoomMemberStatus.joined),
          ),
        ]))!;
        when(
          () => videos.sendVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            extraTags: any(named: 'extraTags'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await expectLater(
          service().sendPart(room, File('part.mp4')),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test('uploads the author part and publishes it to everyone', () async {
        final room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(samStatus: CollabRoomMemberStatus.joined),
          ),
        ]))!;
        when(
          () => videos.uploadVideo(
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async => (url: 'https://media.example/a', metadata: _metadata),
        );

        await service().sendPart(room, File('part.mp4'));

        final (recipient, tags) = sentMessages().single;
        expect(recipient, _sam);
        final state = tags.firstWhere((t) => t.first == 'collab-room-state');
        final snapshot = CollabRoomSnapshot.decode(state[1])!;
        expect(snapshot.revision, 1);
        expect(snapshot.parts.single.pubkey, _author);
        expect(snapshot.parts.single.url, 'https://media.example/a');
      });

      test('throws when the author part could not be uploaded', () async {
        final room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(),
          ),
        ]))!;
        when(
          () => videos.uploadVideo(
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          service().sendPart(room, File('part.mp4')),
          throwsA(isA<CollabRoomException>()),
        );
      });
    });

    group('partFile', () {
      const part = CollabRoomPart(
        pubkey: _sam,
        url: 'https://media.example/sam',
        metadata: _metadata,
      );

      test('decrypts a part once and keeps it', () async {
        final first = await service().partFile(_roomId, part);
        final second = await service().partFile(_roomId, part);

        expect(first.path, second.path);
        expect(first.readAsBytesSync(), [1, 2, 3]);
        expect(decrypted, hasLength(1));
        expect(decrypted.single.content, part.url);
        expect(decrypted.single.fileMetadata, _metadata);
        expect(first.path, contains(_author));
      });

      test('deletes the parts of a room', () async {
        final file = await service().partFile(_roomId, part);
        await service().deleteRoomFiles(_roomId);
        expect(file.existsSync(), isFalse);
      });

      test('refuses a malformed room id', () {
        expect(
          () => service().partFile('../x', part),
          throwsArgumentError,
        );
      });
    });

    group('markPosted', () {
      test('publishes the posted video to everyone', () async {
        final posted = service().markPosted(_roomId, '34236:$_author:d');
        scheduleMicrotask(
          () => history.add([
            _message(
              from: _author,
              to: _sam,
              type: CollabRoomMessageType.invite,
              snapshot: _lobby(
                phase: CollabRoomPhase.recording,
                samStatus: CollabRoomMemberStatus.joined,
              ),
            ),
          ]),
        );
        await posted;

        final tags = sentMessages().single.$2;
        final state = tags.firstWhere((t) => t.first == 'collab-room-state');
        final snapshot = CollabRoomSnapshot.decode(state[1])!;
        expect(snapshot.phase, CollabRoomPhase.posted);
        expect(snapshot.videoAddress, '34236:$_author:d');
      });

      test('does nothing for a room the account does not host', () async {
        owner = _sam;
        final posted = service().markPosted(_roomId, '34236:$_author:d');
        scheduleMicrotask(
          () => history.add([
            _message(
              from: _author,
              to: _sam,
              type: CollabRoomMessageType.invite,
              snapshot: _lobby(),
            ),
          ]),
        );
        await posted;
        verifyNever(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        );
      });
    });
  });
}
