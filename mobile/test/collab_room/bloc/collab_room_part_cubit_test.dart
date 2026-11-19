import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/bloc/collab_room_part_cubit.dart';
import 'package:openvine/collab_room/collab_room_service.dart';

class _MockCollabRoomService extends Mock implements CollabRoomService {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _roomId = '0123456789abcdef0123456789abcdef';

CollabRoom _room(CollabRoomPhase phase) => foldCollabRooms([
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
        members: const [
          CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
            cell: 0,
          ),
          CollabRoomMember(
            pubkey: _sam,
            status: CollabRoomMemberStatus.joined,
            cell: 1,
          ),
        ],
      ),
    ),
  ),
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

    blocTest<CollabRoomPartCubit, CollabRoomPartStatus>(
      'hands the part in while the room films',
      setUp: () {
        when(
          () => service.watchRoom(_roomId),
        ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.recording)));
        when(() => service.sendPart(any(), video)).thenAnswer((_) async {});
      },
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const [
        CollabRoomPartStatus.sending,
        CollabRoomPartStatus.sent,
      ],
      verify: (_) => verify(() => service.sendPart(any(), video)).called(1),
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartStatus>(
      'refuses a part for a room that stopped filming',
      setUp: () => when(
        () => service.watchRoom(_roomId),
      ).thenAnswer((_) => Stream.value(_room(CollabRoomPhase.cancelled))),
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const [
        CollabRoomPartStatus.sending,
        CollabRoomPartStatus.failed,
      ],
      errors: () => [isA<CollabRoomException>()],
    );

    blocTest<CollabRoomPartCubit, CollabRoomPartStatus>(
      'does not send a part twice',
      seed: () => CollabRoomPartStatus.sent,
      build: () => CollabRoomPartCubit(service: service, roomId: _roomId),
      act: (cubit) => cubit.send(video),
      expect: () => const <CollabRoomPartStatus>[],
    );
  });
}
