import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmFileMetadata, DmMessage;
import 'package:openvine/collab_room/bloc/collab_room_part_cubit.dart';
import 'package:openvine/collab_room/collab_room_service.dart';

import '../view/collab_room_test_fixtures.dart' show joinMessage;

class _MockCollabRoomService extends Mock implements CollabRoomService {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _roomId = '0123456789abcdef0123456789abcdef';

const CollabRoomUpload _upload = CollabRoomUpload(
  fileUrl: 'https://media.example/part',
  fileMetadata: DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: 'key',
    decryptionNonce: 'nonce',
    fileHash: 'hash',
  ),
);

CollabRoom _room(
  CollabRoomPhase phase, {
  CollabRoomMemberStatus memberStatus = CollabRoomMemberStatus.joined,
}) => foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([_author, _sam]),
    senderPubkey: _author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: _roomId,
      type: CollabRoomMessageType.invite,
      recipientPubkey: _sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: phase,
        members: [
          const CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
            cell: 0,
          ),
          CollabRoomMember(
            pubkey: _sam,
            status: memberStatus,
          ),
        ],
      ),
    ),
  ),
  if (memberStatus == CollabRoomMemberStatus.joined)
    joinMessage(from: _sam, to: _author, room: _roomId),
], ownerPubkey: _sam).single;

void main() {
  group(CollabRoomPartCubit, () {
    late _MockCollabRoomService service;
    final video = File('part.mp4');

    setUpAll(() {
      registerFallbackValue(_room(CollabRoomPhase.recording));
      registerFallbackValue(File(''));
    });

    setUp(() {
      service = _MockCollabRoomService();
    });

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'hands the part in while the room films',
      setUp: () {
        when(
          () => service.watchRoom(_roomId),
        ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.recording)));
        when(
          () => service.uploadPart(video, onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async => _upload);
        when(
          () => service.handInPart(any(), _upload),
        ).thenAnswer((_) async {});
      },
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const [
        CollabRoomPartState(status: CollabRoomPartStatus.sending),
        CollabRoomPartState(
          status: CollabRoomPartStatus.sending,
          uploadProgress: 0,
        ),
        CollabRoomPartState(
          status: CollabRoomPartStatus.sending,
          uploadProgress: 1,
        ),
        CollabRoomPartState(
          status: CollabRoomPartStatus.sent,
          uploadProgress: 1,
        ),
      ],
      verify: (_) => verify(() => service.handInPart(any(), _upload)).called(1),
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'sends the part uploaded ahead instead of uploading it again',
      setUp: () {
        when(
          () => service.watchRoom(_roomId),
        ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.recording)));
        when(
          () => service.uploadPart(video, onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async => _upload);
        when(
          () => service.handInPart(any(), _upload),
        ).thenAnswer((_) async {});
      },
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) async {
        cubit.prepare(video);
        await cubit.send(video);
      },
      verify: (_) => verify(
        () => service.uploadPart(video, onProgress: any(named: 'onProgress')),
      ).called(1),
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'uploads again on the next Send after a file read failed',
      setUp: () {
        when(
          () => service.watchRoom(_roomId),
        ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.recording)));
        var attempts = 0;
        when(
          () => service.uploadPart(video, onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async {
          if (attempts++ == 0) {
            throw const FileSystemException('File unavailable');
          }
          return _upload;
        });
        when(
          () => service.handInPart(any(), _upload),
        ).thenAnswer((_) async {});
      },
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) async {
        cubit.prepare(video);
        await cubit.send(video);
        await cubit.send(video);
      },
      expect: () => [
        isA<CollabRoomPartState>().having((s) => s.uploadProgress, 'up', 0),
        isA<CollabRoomPartState>().having(
          (s) => s.status,
          'status',
          CollabRoomPartStatus.sending,
        ),
        isA<CollabRoomPartState>()
            .having((s) => s.status, 'status', CollabRoomPartStatus.failed)
            .having((s) => s.uploadProgress, 'uploadProgress', isNull),
        isA<CollabRoomPartState>().having(
          (s) => s.status,
          'status',
          CollabRoomPartStatus.sending,
        ),
        isA<CollabRoomPartState>().having((s) => s.uploadProgress, 'up', 0),
        isA<CollabRoomPartState>().having((s) => s.uploadProgress, 'up', 1),
        isA<CollabRoomPartState>().having(
          (s) => s.status,
          'status',
          CollabRoomPartStatus.sent,
        ),
      ],
      errors: () => [isA<FileSystemException>()],
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'reports how far the upload got, in whole percents',
      setUp: () =>
          when(
            () =>
                service.uploadPart(video, onProgress: any(named: 'onProgress')),
          ).thenAnswer((invocation) async {
            final onProgress =
                invocation.namedArguments[#onProgress] as void Function(double);
            onProgress(0.004);
            onProgress(0.5);
            return _upload;
          }),
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) async {
        cubit.prepare(video);
        await pumpEventQueue();
      },
      expect: () => const [
        CollabRoomPartState(uploadProgress: 0),
        CollabRoomPartState(uploadProgress: 0.5),
        CollabRoomPartState(uploadProgress: 1),
      ],
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'refuses a part for a room that stopped filming',
      setUp: () => when(
        () => service.watchRoom(_roomId),
      ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.cancelled))),
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const [
        CollabRoomPartState(status: CollabRoomPartStatus.sending),
        CollabRoomPartState(status: CollabRoomPartStatus.failed),
      ],
      errors: () => [isA<CollabRoomException>()],
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'does not send an upload if the host removed the member in the meantime',
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) async {
        var room = _room(CollabRoomPhase.recording);
        final uploading = Completer<void>();
        final upload = Completer<CollabRoomUpload>();
        when(
          () => service.watchRoom(_roomId),
        ).thenAnswer((_) => Stream.value(room));
        when(
          () => service.uploadPart(video, onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) {
          uploading.complete();
          return upload.future;
        });

        final sending = cubit.send(video);
        await uploading.future;
        room = _room(
          CollabRoomPhase.recording,
          memberStatus: CollabRoomMemberStatus.removed,
        );
        upload.complete(_upload);
        await sending;
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomPartStatus.failed);
        verifyNever(() => service.handInPart(any(), _upload));
      },
      errors: () => [isA<CollabRoomException>()],
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartState>(
      'does not send a part twice',
      seed: () => const CollabRoomPartState(status: CollabRoomPartStatus.sent),
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const <CollabRoomPartState>[],
    );
  });
}
