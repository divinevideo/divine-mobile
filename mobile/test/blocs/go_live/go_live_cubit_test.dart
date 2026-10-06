import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockEvent extends Mock implements Event {}

class _MockLiveRepository extends Mock implements LiveRepository {}

void main() {
  group('GoLiveCubit', () {
    late _MockLiveApiService mockApiService;
    late _MockLiveRepository mockRepository;
    late LiveRoomDraftResponse createdRoomDraftResponse;
    late LiveRoomDraftResponse existingActiveRoomDraftResponse;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const roomDraft = LiveRoom(
      id: 'room-abc',
      hostPubkey: hostPubkey,
      title: 'Divine Live',
      summary: 'Public room for creators',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );

    setUpAll(() {
      registerFallbackValue(roomDraft);
      registerFallbackValue(
        LiveSession(
          id: 'session-abc',
          roomId: roomDraft.id,
          status: LiveSessionStatus.live,
          startedAt: DateTime.utc(2026, 4, 6, 12),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey],
          audienceCount: 0,
        ),
      );
    });

    setUp(() {
      mockApiService = _MockLiveApiService();
      mockRepository = _MockLiveRepository();
      createdRoomDraftResponse = const LiveRoomDraftResponse(
        status: LiveRoomDraftStatus.created,
        room: roomDraft,
        activeSession: null,
      );
      existingActiveRoomDraftResponse = LiveRoomDraftResponse(
        status: LiveRoomDraftStatus.existingActive,
        room: roomDraft,
        activeSession: LiveSession(
          id: 'session-existing',
          roomId: roomDraft.id,
          status: LiveSessionStatus.live,
          startedAt: DateTime.utc(2026, 4, 6, 12),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey],
          audienceCount: 7,
        ),
      );

      when(
        () => mockApiService.createRoomDraft(
          title: 'Divine Live',
          summary: 'Public room for creators',
        ),
      ).thenAnswer((_) async => createdRoomDraftResponse);
      when(
        () => mockRepository.publishRoom(roomDraft),
      ).thenAnswer((_) async => _MockEvent());
      when(
        () => mockRepository.publishSession(
          session: any(named: 'session'),
          roomAddress: roomDraft.address,
          hostPubkey: hostPubkey,
        ),
      ).thenAnswer((_) async => _MockEvent());
      when(
        () => mockApiService.startSession(
          roomId: roomDraft.id,
          sessionId: 'session-abc',
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockApiService.endSession(
          roomId: roomDraft.id,
          sessionId: 'session-abc',
        ),
      ).thenAnswer((_) async {});
    });

    test('title updates drive form validity', () {
      final cubit = GoLiveCubit(
        liveApiService: mockApiService,
        liveRepository: mockRepository,
        currentUserPubkey: hostPubkey,
      );

      expect(cubit.state.isValid, isFalse);

      cubit.titleChanged('Divine Live');

      expect(cubit.state.title, 'Divine Live');
      expect(cubit.state.isValid, isTrue);
    });

    blocTest<GoLiveCubit, GoLiveState>(
      'submit validates the title before creating a room',
      build: () => GoLiveCubit(
        liveApiService: mockApiService,
        liveRepository: mockRepository,
        currentUserPubkey: hostPubkey,
      ),
      act: (cubit) => cubit.submit(),
      expect: () => <GoLiveState>[
        const GoLiveState(
          titleError: 'Enter a title to go live.',
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockApiService.createRoomDraft(
            title: any(named: 'title'),
            summary: any(named: 'summary'),
          ),
        );
      },
    );

    blocTest<GoLiveCubit, GoLiveState>(
      'submit creates a room draft, publishes the room and session, and marks success',
      build: () {
        final cubit = GoLiveCubit(
          liveApiService: mockApiService,
          liveRepository: mockRepository,
          currentUserPubkey: hostPubkey,
          now: () => DateTime.utc(2026, 4, 6, 12),
          sessionIdBuilder: () => 'session-abc',
        );
        cubit.titleChanged('Divine Live');
        cubit.summaryChanged('Public room for creators');
        return cubit;
      },
      act: (cubit) => cubit.submit(),
      expect: () => <dynamic>[
        isA<GoLiveState>().having(
          (state) => state.status,
          'status',
          GoLiveStatus.submitting,
        ),
        isA<GoLiveState>()
            .having((state) => state.status, 'status', GoLiveStatus.success)
            .having((state) => state.room, 'room', roomDraft)
            .having((state) => state.session?.id, 'session.id', 'session-abc'),
      ],
      verify: (_) {
        verify(
          () => mockApiService.createRoomDraft(
            title: 'Divine Live',
            summary: 'Public room for creators',
          ),
        ).called(1);
        verify(() => mockRepository.publishRoom(roomDraft)).called(1);
        verify(
          () => mockRepository.publishSession(
            session: any(named: 'session'),
            roomAddress: roomDraft.address,
            hostPubkey: hostPubkey,
          ),
        ).called(1);
        verify(
          () => mockApiService.startSession(
            roomId: roomDraft.id,
            sessionId: 'session-abc',
          ),
        ).called(1);
      },
    );

    test('backend failure never announces a live session', () async {
      when(
        () => mockApiService.startSession(
          roomId: roomDraft.id,
          sessionId: 'session-abc',
        ),
      ).thenThrow(StateError('backend unavailable'));
      final cubit = GoLiveCubit(
        liveApiService: mockApiService,
        liveRepository: mockRepository,
        currentUserPubkey: hostPubkey,
        initialTitle: 'Divine Live',
        initialSummary: 'Public room for creators',
        sessionIdBuilder: () => 'session-abc',
      );
      await cubit.submit();
      expect(cubit.state.status, GoLiveStatus.failure);
      verifyNever(
        () => mockRepository.publishSession(
          session: any(named: 'session'),
          roomAddress: any(named: 'roomAddress'),
          hostPubkey: any(named: 'hostPubkey'),
        ),
      );
      await cubit.close();
    });

    for (final failRoom in <bool>[true, false]) {
      test(
        'failed ${failRoom ? 'room' : 'session'} publication fails submission',
        () async {
          if (failRoom) {
            when(
              () => mockRepository.publishRoom(any()),
            ).thenAnswer((_) async => null);
          } else {
            when(
              () => mockRepository.publishSession(
                session: any(named: 'session'),
                roomAddress: roomDraft.address,
                hostPubkey: hostPubkey,
              ),
            ).thenAnswer((_) async => null);
          }
          final cubit = GoLiveCubit(
            liveApiService: mockApiService,
            liveRepository: mockRepository,
            currentUserPubkey: hostPubkey,
            initialTitle: 'Divine Live',
            initialSummary: 'Public room for creators',
            sessionIdBuilder: () => 'session-abc',
          );
          await cubit.submit();
          expect(cubit.state.status, GoLiveStatus.failure);
          if (failRoom) {
            verifyNever(
              () => mockApiService.startSession(
                roomId: any(named: 'roomId'),
                sessionId: any(named: 'sessionId'),
              ),
            );
          } else {
            verify(
              () => mockApiService.endSession(
                roomId: roomDraft.id,
                sessionId: 'session-abc',
              ),
            ).called(1);
          }
          await cubit.close();
        },
      );
    }

    blocTest<GoLiveCubit, GoLiveState>(
      'submit skips publish and start when the API reports an existing active session',
      build: () {
        when(
          () => mockApiService.createRoomDraft(
            title: 'Divine Live',
            summary: 'Public room for creators',
          ),
        ).thenAnswer((_) async => existingActiveRoomDraftResponse);

        final cubit = GoLiveCubit(
          liveApiService: mockApiService,
          liveRepository: mockRepository,
          currentUserPubkey: hostPubkey,
          now: () => DateTime.utc(2026, 4, 6, 12),
          sessionIdBuilder: () => 'session-should-not-be-used',
        );
        cubit.titleChanged('Divine Live');
        cubit.summaryChanged('Public room for creators');
        return cubit;
      },
      act: (cubit) => cubit.submit(),
      expect: () => <dynamic>[
        isA<GoLiveState>().having(
          (state) => state.status,
          'status',
          GoLiveStatus.submitting,
        ),
        isA<GoLiveState>()
            .having((state) => state.status, 'status', GoLiveStatus.success)
            .having((state) => state.room, 'room', roomDraft)
            .having(
              (state) => state.session?.id,
              'session.id',
              'session-existing',
            ),
      ],
      verify: (_) {
        verify(
          () => mockApiService.createRoomDraft(
            title: 'Divine Live',
            summary: 'Public room for creators',
          ),
        ).called(1);
        verifyNever(() => mockRepository.publishRoom(any()));
        verifyNever(
          () => mockRepository.publishSession(
            session: any(named: 'session'),
            roomAddress: any(named: 'roomAddress'),
            hostPubkey: any(named: 'hostPubkey'),
          ),
        );
        verifyNever(
          () => mockApiService.startSession(
            roomId: any(named: 'roomId'),
            sessionId: any(named: 'sessionId'),
          ),
        );
      },
    );
  });
}
