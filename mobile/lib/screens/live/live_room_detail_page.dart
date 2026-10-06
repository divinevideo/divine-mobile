import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/screens/live/live_room_detail_view.dart';

class LiveRoomDetailPage extends ConsumerStatefulWidget {
  const LiveRoomDetailPage({
    required this.roomId,
    this.initialRoom,
    this.initialSession,
    super.key,
  });

  static const String routeName = 'liveRoomDetail';
  static const String pathPattern = '/live/room/:roomId';

  static String pathFor(String roomId) => '/live/room/$roomId';

  final String roomId;
  final LiveRoom? initialRoom;
  final LiveSession? initialSession;

  @override
  ConsumerState<LiveRoomDetailPage> createState() => _LiveRoomDetailPageState();
}

class _LiveRoomDetailPageState extends ConsumerState<LiveRoomDetailPage> {
  late final Future<_LiveRoomDetailPayload?> _payloadFuture = _loadPayload();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LiveRoomDetailPayload?>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: VineTheme.surfaceBackground,
            body: Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
          );
        }

        final payload = snapshot.data;
        if (payload == null) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceBackground,
            appBar: AppBar(backgroundColor: VineTheme.surfaceBackground),
            body: Center(
              child: Text(
                'Room unavailable.',
                style: VineTheme.bodyMediumFont(),
              ),
            ),
          );
        }

        return LiveRoomDetailView(
          room: payload.room,
          session: payload.session,
          recording: payload.recording,
        );
      },
    );
  }

  Future<_LiveRoomDetailPayload?> _loadPayload() async {
    final repository = ref.read(liveRepositoryProvider);
    final initialRoom = widget.initialRoom;
    if (initialRoom != null) {
      final recording = widget.initialSession?.hasEnded == true
          ? await repository.fetchRecording(roomId: initialRoom.id)
          : null;
      return _LiveRoomDetailPayload(
        room: initialRoom,
        session: widget.initialSession,
        recording: recording,
      );
    }

    final rooms = await repository.fetchPublicRooms();
    final room = rooms.where((item) => item.id == widget.roomId).firstOrNull;
    if (room == null) {
      return null;
    }

    final sessions = await repository.fetchSessions(roomAddress: room.address);
    final session =
        sessions.where((item) => item.isLive).firstOrNull ??
        sessions.firstOrNull;
    final recording = session?.hasEnded == true
        ? await repository.fetchRecording(roomId: room.id)
        : null;
    return _LiveRoomDetailPayload(
      room: room,
      session: session,
      recording: recording,
    );
  }
}

class _LiveRoomDetailPayload {
  const _LiveRoomDetailPayload({
    required this.room,
    required this.session,
    required this.recording,
  });

  final LiveRoom room;
  final LiveSession? session;
  final LiveRoomRecording? recording;
}
