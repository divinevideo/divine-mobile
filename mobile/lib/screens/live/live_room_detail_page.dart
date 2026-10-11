import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/router/route_paths.dart';
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

  static String pathFor(String roomId) => RoutePaths.liveRoomDetailFor(roomId);

  final String roomId;
  final LiveRoom? initialRoom;
  final LiveSession? initialSession;

  @override
  ConsumerState<LiveRoomDetailPage> createState() => _LiveRoomDetailPageState();
}

class _LiveRoomDetailPageState extends ConsumerState<LiveRoomDetailPage> {
  Future<_LiveRoomDetailPayload?>? _payloadFuture;
  Object? _dependencyKey;

  @override
  Widget build(BuildContext context) {
    final dependencyKey = (
      widget.roomId,
      widget.initialRoom,
      widget.initialSession,
      ref.watch(liveRepositoryProvider),
    );
    if (_dependencyKey != dependencyKey) {
      _dependencyKey = dependencyKey;
      _payloadFuture = _loadPayload();
    }
    return FutureBuilder<_LiveRoomDetailPayload?>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: context.vineColors.surface,
            body: const Center(
              child: DivineCircularProgressIndicator(color: VineTheme.primary),
            ),
          );
        }

        final payload = snapshot.data;
        if (payload == null) {
          return Scaffold(
            backgroundColor: context.vineColors.surface,
            appBar: AppBar(backgroundColor: context.vineColors.surface),
            body: Center(
              child: Text(
                context.l10n.liveRoomUnavailable,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurface,
                ),
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
    final initialRoom = widget.initialRoom?.id == widget.roomId
        ? widget.initialRoom
        : null;
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

    final room = await repository.fetchRoom(widget.roomId);
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
