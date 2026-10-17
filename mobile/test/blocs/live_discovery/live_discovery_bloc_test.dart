import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_bloc.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

void main() {
  group('LiveDiscoveryBloc', () {
    late _MockLiveRepository mockRepository;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const roomOne = LiveRoom(
      id: 'room-live',
      hostPubkey: hostPubkey,
      title: 'Divine Live',
      summary: 'A live room',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    const roomTwo = LiveRoom(
      id: 'room-planned',
      hostPubkey: hostPubkey,
      title: 'Coming Soon',
      summary: 'An upcoming room',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final liveSession = LiveSession(
      id: 'session-live',
      roomId: roomOne.id,
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 12),
      endedAt: null,
      speakerPubkeys: const <String>[hostPubkey],
      audienceCount: 42,
    );
    final plannedSession = LiveSession(
      id: 'session-planned',
      roomId: roomTwo.id,
      hostPubkey: roomTwo.hostPubkey,
      status: LiveSessionStatus.planned,
      startedAt: DateTime.utc(2026, 4, 7, 12),
      endedAt: null,
      speakerPubkeys: const <String>[hostPubkey],
      audienceCount: 0,
    );

    setUp(() {
      mockRepository = _MockLiveRepository();
    });

    blocTest<LiveDiscoveryBloc, LiveDiscoveryState>(
      'emits loading then success with active and upcoming rooms grouped by session status',
      setUp: () {
        when(
          () => mockRepository.fetchPublicRooms(),
        ).thenAnswer((_) async => const <LiveRoom>[roomOne, roomTwo]);
        when(
          () => mockRepository.fetchSessions(),
        ).thenAnswer((_) async => <LiveSession>[liveSession, plannedSession]);
      },
      build: () => LiveDiscoveryBloc(liveRepository: mockRepository),
      act: (bloc) => bloc.add(const LiveDiscoveryRequested()),
      expect: () => <dynamic>[
        const LiveDiscoveryState(status: LiveDiscoveryStatus.loading),
        isA<LiveDiscoveryState>()
            .having(
              (state) => state.status,
              'status',
              LiveDiscoveryStatus.success,
            )
            .having(
              (state) => state.activeRooms,
              'activeRooms',
              const <LiveRoom>[roomOne],
            )
            .having(
              (state) => state.upcomingRooms,
              'upcomingRooms',
              const <LiveRoom>[roomTwo],
            ),
      ],
      verify: (_) {
        verify(() => mockRepository.fetchPublicRooms()).called(1);
        verify(() => mockRepository.fetchSessions()).called(1);
      },
    );

    blocTest<LiveDiscoveryBloc, LiveDiscoveryState>(
      'matches active and upcoming rooms by full room address when hosts reuse the same room id',
      setUp: () {
        const sharedRoomOne = LiveRoom(
          id: 'shared-room',
          hostPubkey: hostPubkey,
          title: 'Host one',
          summary: 'First host room',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        );
        const sharedRoomTwo = LiveRoom(
          id: 'shared-room',
          hostPubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          title: 'Host two',
          summary: 'Second host room',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        );
        final sharedLiveSession = LiveSession(
          id: 'session-live-shared',
          roomId: sharedRoomOne.id,
          hostPubkey: sharedRoomOne.hostPubkey,
          status: LiveSessionStatus.live,
          startedAt: DateTime.utc(2026, 4, 6, 13),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey],
          audienceCount: 11,
        );
        final sharedPlannedSession = LiveSession(
          id: 'session-planned-shared',
          roomId: sharedRoomTwo.id,
          hostPubkey: sharedRoomTwo.hostPubkey,
          status: LiveSessionStatus.planned,
          startedAt: DateTime.utc(2026, 4, 7, 13),
          endedAt: null,
          speakerPubkeys: <String>[sharedRoomTwo.hostPubkey],
          audienceCount: 0,
        );

        when(
          () => mockRepository.fetchPublicRooms(),
        ).thenAnswer(
          (_) async => const <LiveRoom>[sharedRoomOne, sharedRoomTwo],
        );
        when(
          () => mockRepository.fetchSessions(),
        ).thenAnswer(
          (_) async => <LiveSession>[sharedLiveSession, sharedPlannedSession],
        );
      },
      build: () => LiveDiscoveryBloc(liveRepository: mockRepository),
      act: (bloc) => bloc.add(const LiveDiscoveryRequested()),
      expect: () => <dynamic>[
        const LiveDiscoveryState(status: LiveDiscoveryStatus.loading),
        isA<LiveDiscoveryState>()
            .having(
              (state) => state.activeRooms.map((room) => room.title).toList(),
              'activeRooms',
              const <String>['Host one'],
            )
            .having(
              (state) => state.upcomingRooms.map((room) => room.title).toList(),
              'upcomingRooms',
              const <String>['Host two'],
            ),
      ],
    );

    blocTest<LiveDiscoveryBloc, LiveDiscoveryState>(
      'emits loading then failure when the repository throws',
      setUp: () {
        when(
          () => mockRepository.fetchPublicRooms(),
        ).thenThrow(Exception('network down'));
      },
      build: () => LiveDiscoveryBloc(liveRepository: mockRepository),
      act: (bloc) => bloc.add(const LiveDiscoveryRequested()),
      expect: () => <dynamic>[
        const LiveDiscoveryState(status: LiveDiscoveryStatus.loading),
        isA<LiveDiscoveryState>()
            .having(
              (state) => state.status,
              'status',
              LiveDiscoveryStatus.failure,
            )
            .having(
              (state) => state.error,
              'error',
              LiveDiscoveryError.loadFailed,
            ),
      ],
      errors: () => [isA<Exception>()],
    );
  });
}
