import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_event.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_state.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';

export 'package:openvine/blocs/live_discovery/live_discovery_event.dart';
export 'package:openvine/blocs/live_discovery/live_discovery_state.dart';

class LiveDiscoveryBloc extends Bloc<LiveDiscoveryEvent, LiveDiscoveryState> {
  LiveDiscoveryBloc({
    required LiveRepository liveRepository,
  }) : _liveRepository = liveRepository,
       super(const LiveDiscoveryState()) {
    on<LiveDiscoveryRequested>(_onRequested);
  }

  final LiveRepository _liveRepository;

  Future<void> _onRequested(
    LiveDiscoveryRequested event,
    Emitter<LiveDiscoveryState> emit,
  ) async {
    if (!event.force && state.status == LiveDiscoveryStatus.loading) {
      return;
    }

    emit(
      state.copyWith(
        status: LiveDiscoveryStatus.loading,
        clearErrorMessage: true,
      ),
    );

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _liveRepository.fetchPublicRooms(),
        _liveRepository.fetchSessions(),
      ]);
      final rooms = results[0] as List<LiveRoom>;
      final sessions = results[1] as List<LiveSession>;
      final activeSessions = sessions
          .where((session) => session.status == LiveSessionStatus.live)
          .toList(growable: false);
      final activeRoomIds = activeSessions
          .map((session) => session.roomAddressKey)
          .toSet();
      final upcomingSessions = sessions
          .where(
            (session) =>
                session.status == LiveSessionStatus.planned &&
                !activeRoomIds.contains(session.roomAddressKey),
          )
          .toList(growable: false);

      emit(
        state.copyWith(
          status: LiveDiscoveryStatus.success,
          rooms: rooms,
          activeSessions: activeSessions,
          upcomingSessions: upcomingSessions,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: LiveDiscoveryStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }
}
