import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

enum LiveDiscoveryStatus { initial, loading, success, failure }

enum LiveDiscoveryError { loadFailed }

class LiveDiscoveryState extends Equatable {
  const LiveDiscoveryState({
    this.status = LiveDiscoveryStatus.initial,
    this.rooms = const <LiveRoom>[],
    this.activeSessions = const <LiveSession>[],
    this.upcomingSessions = const <LiveSession>[],
    this.error,
  });

  final LiveDiscoveryStatus status;
  final List<LiveRoom> rooms;
  final List<LiveSession> activeSessions;
  final List<LiveSession> upcomingSessions;
  final LiveDiscoveryError? error;

  List<LiveRoom> get activeRooms => _roomsFor(activeSessions);

  List<LiveRoom> get upcomingRooms => _roomsFor(upcomingSessions);

  LiveDiscoveryState copyWith({
    LiveDiscoveryStatus? status,
    List<LiveRoom>? rooms,
    List<LiveSession>? activeSessions,
    List<LiveSession>? upcomingSessions,
    LiveDiscoveryError? error,
    bool clearError = false,
  }) {
    return LiveDiscoveryState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      activeSessions: activeSessions ?? this.activeSessions,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<LiveRoom> _roomsFor(List<LiveSession> sessions) {
    final roomsByAddress = <String, LiveRoom>{
      for (final room in rooms) room.address: room,
    };
    final roomsById = <String, LiveRoom>{
      for (final room in rooms) room.id: room,
    };

    return sessions
        .map(
          (session) =>
              roomsByAddress[session.roomAddressKey] ??
              roomsById[session.roomId],
        )
        .whereType<LiveRoom>()
        .toList(growable: false);
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    rooms,
    activeSessions,
    upcomingSessions,
    error,
  ];
}
