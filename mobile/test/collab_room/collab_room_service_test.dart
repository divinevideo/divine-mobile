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
  fileHash: '1111111111111111111111111111111111111111111111111111111111111111',
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
  CollabRoomMemberStatus kaiStatus = CollabRoomMemberStatus.declined,
}) => CollabRoomSnapshot(
  revision: revision,
  phase: phase,
  members: [
    const CollabRoomMember(
      pubkey: _author,
      status: CollabRoomMemberStatus.joined,
    ),
    CollabRoomMember(pubkey: _sam, status: samStatus),
    CollabRoomMember(pubkey: _kai, status: kaiStatus),
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
      registerFallbackValue(_metadata);
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
        () => dm.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);
      when(
        () => dm.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          backgroundDelivery: any(named: 'backgroundDelivery'),
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
          backgroundDelivery: any(named: 'backgroundDelivery'),
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
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('refused'));

        await expectLater(
          service().createRoom([_sam]),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test('takes back an invite that only waits in the queue', () async {
        // The device reads the room back only from a message a relay took,
        // and the user is told it failed: the queue must not deliver it
        // later, beside the invite a second try sends.
        when(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'offline',
            retryablePending: true,
            queuedRumorId: 'queued',
          ),
        );

        await expectLater(
          service().createRoom([_sam]),
          throwsA(isA<CollabRoomException>()),
        );
        verify(() => dm.cancelOutgoingSend(rumorId: 'queued')).called(1);
      });

      test('keeps a room that reached someone, queue and all', () async {
        when(
          () => dm.sendMessage(
            recipientPubkey: _kai,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'offline',
            retryablePending: true,
            queuedRumorId: 'queued',
          ),
        );

        final roomId = await service().createRoom([_sam, _kai]);

        expect(roomId, isNotEmpty);
        verifyNever(
          () => dm.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
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
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await expectLater(
          service().join(room),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test('takes back an answer that only waits in the queue', () async {
        when(
          () => dm.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'offline',
            retryablePending: true,
            queuedRumorId: 'queued',
          ),
        );

        await expectLater(
          service().join(room),
          throwsA(isA<CollabRoomException>()),
        );
        verify(() => dm.cancelOutgoingSend(rumorId: 'queued')).called(1);
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

      test('calls off a room everyone left with everyone it had', () async {
        final empty = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(samStatus: CollabRoomMemberStatus.left),
          ),
        ]))!;

        await service().publish(
          empty,
          empty.toSnapshot(revision: 1, phase: CollabRoomPhase.cancelled),
        );

        // Sent to nobody, the call-off would never reach the author's own
        // record of the room and it would stay open there.
        expect(sentMessages().map((s) => s.$1), unorderedEquals([_sam, _kai]));
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
            backgroundDelivery: any(named: 'backgroundDelivery'),
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
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await expectLater(
          service().publish(room, room.toSnapshot(revision: 1)),
          throwsA(isA<CollabRoomException>()),
        );
      });

      test(
        'takes back an update that only waits in the queue, so the next one '
        'still goes out',
        () async {
          final roomService = service();
          when(
            () => dm.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
              backgroundDelivery: any(named: 'backgroundDelivery'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure(
              'offline',
              retryablePending: true,
              queuedRumorId: 'queued',
            ),
          );

          await expectLater(
            roomService.publish(room, room.toSnapshot(revision: 1)),
            throwsA(isA<CollabRoomException>()),
          );
          verify(() => dm.cancelOutgoingSend(rumorId: 'queued')).called(1);

          when(
            () => dm.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
              backgroundDelivery: any(named: 'backgroundDelivery'),
            ),
          ).thenAnswer(
            (invocation) async =>
                _sent(invocation.namedArguments[#recipientPubkey] as String),
          );
          await expectLater(
            roomService.publish(room, room.toSnapshot(revision: 1)),
            completes,
          );
        },
      );

      test('rejects a concurrent update built on an older snapshot', () async {
        final roomService = service();
        final sending = Completer<void>();
        final firstDelivery = Completer<NIP17SendResult>();
        when(
          () => dm.sendMessage(
            recipientPubkey: _sam,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: true,
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        ).thenAnswer((_) {
          sending.complete();
          return firstDelivery.future;
        });

        final first = roomService.publish(
          room,
          room.toSnapshot(
            revision: 1,
            phase: CollabRoomPhase.recording,
          ),
        );
        await sending.future;
        final stale = expectLater(
          roomService.publish(room, room.toSnapshot(revision: 1)),
          throwsA(isA<CollabRoomException>()),
        );
        firstDelivery.complete(_sent(_sam));
        await Future.wait([first, stale]);

        expect(sentMessages().map((message) => message.$1), [_sam]);
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

    group('reinvite', () {
      test('invites someone back and tells the others', () async {
        final room = (await roomFrom([
          _message(
            from: _author,
            to: _sam,
            type: CollabRoomMessageType.invite,
            snapshot: _lobby(samStatus: CollabRoomMemberStatus.joined),
          ),
        ]))!;
        final askedBack = room.toSnapshot(
          revision: 1,
          members: [
            for (final member in room.members)
              if (member.pubkey == _kai)
                member.copyWith(status: CollabRoomMemberStatus.invited)
              else
                member,
          ],
        );

        await service().reinvite(room, _kai, askedBack);

        final sent = sentMessages();
        expect(sent.map((s) => s.$1), [_kai, _sam]);
        expect(
          sent.first.$2,
          anyElement(equals(['collab-room', _roomId, 'invite', _kai])),
        );
        expect(
          sent.last.$2,
          anyElement(equals(['collab-room', _roomId, 'state', _sam])),
        );
      });
    });

    group('sendPart', () {
      void stubUpload() =>
          when(
            () => videos.uploadVideo(
              videoFile: any(named: 'videoFile'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => (url: 'https://media.example/a', metadata: _metadata),
          );

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
          _message(from: _sam, to: _author, type: CollabRoomMessageType.join),
        ]))!;
        stubUpload();
        when(
          () => videos.sendUploadedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            url: any(named: 'url'),
            metadata: any(named: 'metadata'),
            extraTags: any(named: 'extraTags'),
          ),
        ).thenAnswer((_) async => _sent(_author));

        await service().sendPart(room, File('part.mp4'));

        final captured = verify(
          () => videos.sendUploadedVideo(
            recipientPubkey: _author,
            url: 'https://media.example/a',
            metadata: _metadata,
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
            snapshot: _lobby(
              phase: CollabRoomPhase.recording,
              samStatus: CollabRoomMemberStatus.joined,
            ),
          ),
        ]))!;
        stubUpload();
        when(
          () => videos.sendUploadedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            url: any(named: 'url'),
            metadata: any(named: 'metadata'),
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
            snapshot: _lobby(
              phase: CollabRoomPhase.recording,
              samStatus: CollabRoomMemberStatus.joined,
            ),
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

      test('shares a download between preview and composition', () async {
        final roomService = service();
        final files = await Future.wait([
          roomService.partFile(_roomId, part),
          roomService.partFile(_roomId, part),
        ]);
        expect(decrypted, hasLength(1));
        expect(files.first.path, files.last.path);
        expect(await files.last.readAsBytes(), [1, 2, 3]);
      });

      test(
        'rejects an invalid ciphertext hash before reading the part',
        () async {
          const invalidPart = CollabRoomPart(
            pubkey: _sam,
            url: 'https://media.example/sam',
            metadata: DmFileMetadata(
              fileType: 'video/mp4',
              encryptionAlgorithm: 'aes-gcm',
              decryptionKey: 'key',
              decryptionNonce: 'nonce',
              fileHash: 'invalid',
            ),
          );
          await expectLater(
            service().partFile(_roomId, invalidPart),
            throwsA(isA<CollabRoomException>()),
          );
          expect(decrypted, isEmpty);
        },
      );

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
      test(
        'retries the posted snapshot for a recipient without a copy',
        () async {
          const address = '34236:$_author:d';
          final recording = _lobby(
            phase: CollabRoomPhase.recording,
            samStatus: CollabRoomMemberStatus.joined,
            kaiStatus: CollabRoomMemberStatus.joined,
          );
          final posted = service().markPosted(_roomId, address);
          scheduleMicrotask(() {
            history.add([
              _message(
                from: _author,
                to: _sam,
                type: CollabRoomMessageType.invite,
                snapshot: recording,
              ),
              _message(
                from: _author,
                to: _sam,
                type: CollabRoomMessageType.state,
                createdAt: 2,
                snapshot: CollabRoomSnapshot(
                  revision: 1,
                  phase: CollabRoomPhase.posted,
                  members: recording.members,
                  videoAddress: address,
                ),
              ),
            ]);
          });
          await posted;

          final (recipient, tags) = sentMessages().single;
          final state = tags.firstWhere(
            (tag) => tag.first == 'collab-room-state',
          );
          expect(recipient, _kai);
          expect(CollabRoomSnapshot.decode(state[1])?.videoAddress, address);
          expect(CollabRoomSnapshot.decode(state[1])?.revision, 1);
        },
      );

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
            backgroundDelivery: any(named: 'backgroundDelivery'),
          ),
        );
      });
    });
  });
}
