import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/bloc/collab_rooms_cubit.dart';
import 'package:openvine/collab_room/collab_room_service.dart';

class _MockCollabRoomService extends Mock implements CollabRoomService {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

var _nextId = 0;
String _eventId() => (++_nextId).toRadixString(16).padLeft(64, '0');

CollabRoom _room(
  String roomId, {
  CollabRoomPhase phase = CollabRoomPhase.lobby,
  CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.invited,
  String owner = _author,
}) => foldCollabRooms([
  DmMessage(
    id: _eventId(),
    conversationId: DmRepository.computeConversationId([_author, _sam]),
    senderPubkey: _author,
    content: 'text',
    createdAt: 1,
    giftWrapId: _eventId(),
    tags: collabRoomTags(
      roomId: roomId,
      type: CollabRoomMessageType.invite,
      recipientPubkey: _sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: phase,
        members: [
          const CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
          ),
          CollabRoomMember(pubkey: _sam, status: samStatus),
        ],
      ),
    ),
  ),
], ownerPubkey: owner).single;

void main() {
  group(CollabRoomsCubit, () {
    late _MockCollabRoomService service;
    late StreamController<List<CollabRoom>> rooms;

    setUp(() {
      service = _MockCollabRoomService();
      rooms = StreamController<List<CollabRoom>>();
      when(service.watchRooms).thenAnswer((_) => rooms.stream);
    });

    tearDown(() => rooms.close());

    blocTest<CollabRoomsCubit, CollabRoomsState>(
      'lists only the open rooms the account is still in',
      build: () => CollabRoomsCubit(service: service),
      act: (_) => rooms.add([
        _room('0' * 32),
        _room('1' * 32, phase: CollabRoomPhase.posted),
        _room(
          '2' * 32,
          owner: _sam,
          samStatus: CollabRoomMemberStatus.declined,
        ),
        _room('3' * 32, owner: _sam),
      ]),
      verify: (cubit) => expect(
        cubit.state.rooms.map((r) => r.id),
        ['0' * 32, '3' * 32],
      ),
    );

    blocTest<CollabRoomsCubit, CollabRoomsState>(
      'creates a room with the people picked',
      setUp: () => when(
        () => service.createRoom([_sam]),
      ).thenAnswer((_) async => '4' * 32),
      build: () => CollabRoomsCubit(service: service),
      act: (cubit) => cubit.create([_sam]),
      expect: () => const [
        CollabRoomsState(createStatus: CollabRoomsCreateStatus.creating),
        CollabRoomsState(
          createStatus: CollabRoomsCreateStatus.created,
          createdRoomId: '44444444444444444444444444444444',
        ),
      ],
    );

    blocTest<CollabRoomsCubit, CollabRoomsState>(
      'reports invites that could not be sent',
      setUp: () => when(
        () => service.createRoom([_sam]),
      ).thenThrow(const CollabRoomException('offline')),
      build: () => CollabRoomsCubit(service: service),
      act: (cubit) => cubit.create([_sam]),
      expect: () => const [
        CollabRoomsState(createStatus: CollabRoomsCreateStatus.creating),
        CollabRoomsState(createStatus: CollabRoomsCreateStatus.failed),
      ],
      errors: () => [isA<CollabRoomException>()],
    );

    blocTest<CollabRoomsCubit, CollabRoomsState>(
      'ignores an empty pick',
      build: () => CollabRoomsCubit(service: service),
      act: (cubit) => cubit.create(const []),
      expect: () => const <CollabRoomsState>[],
    );
  });
}
