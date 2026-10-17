import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/live/live_room_view.dart';

class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({
    required this.roomId,
    required this.sessionId,
    this.initialRoom,
    this.initialSession,
    super.key,
  });

  static const String routeName = 'liveRoom';
  static const String pathPattern = '/live/room/:roomId/session/:sessionId';

  static String pathFor(String roomId, String sessionId) =>
      RoutePaths.liveRoomFor(roomId, sessionId);

  final String roomId;
  final String sessionId;
  final LiveRoom? initialRoom;
  final LiveSession? initialSession;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  Future<_LiveRoomPayload?>? _payloadFuture;
  Object? _dependencyKey;
  Future<void> _pendingClose = Future<void>.value();

  LiveRoomBloc? _liveRoomBloc;
  LiveChatBloc? _liveChatBloc;
  AppLifecycleListener? _lifecycleListener;
  String? _activePayloadKey;
  String? _syncedChatSessionAddress;

  @override
  Widget build(BuildContext context) {
    ref.watch(currentAuthStateProvider);
    final dependencyKey = (
      widget.roomId,
      widget.sessionId,
      widget.initialRoom,
      widget.initialSession,
      ref.watch(authServiceProvider).currentPublicKeyHex,
      ref.watch(liveRepositoryProvider),
      ref.watch(liveApiServiceProvider),
      ref.watch(liveKitRoomServiceProvider),
      ref.watch(permissionsServiceProvider),
      ref.watch(liveChatRepositoryProvider),
    );
    if (_dependencyKey != dependencyKey) {
      _dependencyKey = dependencyKey;
      _payloadFuture = _restartPayload();
    }
    return FutureBuilder<_LiveRoomPayload?>(
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

        _ensureBlocs(payload);
        final liveRoomBloc = _liveRoomBloc!;
        final liveChatBloc = _liveChatBloc!;
        _syncChatSession(liveRoomBloc, liveChatBloc);

        return MultiBlocProvider(
          providers: [
            BlocProvider<LiveRoomBloc>.value(value: liveRoomBloc),
            BlocProvider<LiveChatBloc>.value(value: liveChatBloc),
          ],
          child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
            buildWhen: (previous, current) =>
                previous.sessionAddress != current.sessionAddress,
            builder: (context, state) {
              final liveRoomBloc = _liveRoomBloc;
              final liveChatBloc = _liveChatBloc;
              if (liveRoomBloc != null && liveChatBloc != null) {
                _syncChatSession(liveRoomBloc, liveChatBloc);
              }

              return const LiveRoomView();
            },
          ),
        );
      },
    );
  }

  Future<_LiveRoomPayload?> _restartPayload() async {
    final roomBloc = _liveRoomBloc;
    final chatBloc = _liveChatBloc;
    _liveRoomBloc = null;
    _liveChatBloc = null;
    _activePayloadKey = null;
    _syncedChatSessionAddress = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _pendingClose = _pendingClose.then((_) async {
      await roomBloc?.close();
      await chatBloc?.close();
    });
    await _pendingClose;
    if (!mounted) return null;
    return _loadPayload();
  }

  void _syncChatSession(LiveRoomBloc liveRoomBloc, LiveChatBloc liveChatBloc) {
    final sessionAddress = liveRoomBloc.state.sessionAddress;
    if (sessionAddress == null) {
      return;
    }

    if (_syncedChatSessionAddress == sessionAddress &&
        liveChatBloc.state.sessionAddress == sessionAddress) {
      return;
    }

    _syncedChatSessionAddress = sessionAddress;
    if (liveChatBloc.state.sessionAddress == sessionAddress) {
      return;
    }

    liveChatBloc.add(LiveChatStarted(sessionAddress: sessionAddress));
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    unawaited(_liveRoomBloc?.close());
    unawaited(_liveChatBloc?.close());
    super.dispose();
  }

  void _ensureBlocs(_LiveRoomPayload payload) {
    final payloadKey =
        '${payload.room.address}:${widget.sessionId}:${payload.role.name}';
    if (_activePayloadKey == payloadKey &&
        _liveRoomBloc != null &&
        _liveChatBloc != null) {
      return;
    }

    _activePayloadKey = payloadKey;
    _lifecycleListener?.dispose();
    unawaited(_liveRoomBloc?.close());
    unawaited(_liveChatBloc?.close());

    final liveRoomBloc =
        LiveRoomBloc(
          liveRepository: ref.read(liveRepositoryProvider),
          liveApiService: ref.read(liveApiServiceProvider),
          liveKitRoomService: ref.read(liveKitRoomServiceProvider),
          permissionsService: ref.read(permissionsServiceProvider),
          currentUserPubkey:
              ref.read(authServiceProvider).currentPublicKeyHex ?? '',
        )..add(
          LiveRoomJoinRequested(
            room: payload.room,
            role: payload.role,
            sessionId: widget.sessionId,
          ),
        );
    final liveChatBloc = LiveChatBloc(
      liveChatRepository: ref.read(liveChatRepositoryProvider),
    );

    _liveRoomBloc = liveRoomBloc;
    _liveChatBloc = liveChatBloc;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        liveRoomBloc.add(
          LiveRoomAppForegroundChanged(state == AppLifecycleState.resumed),
        );
      },
    );
  }

  Future<_LiveRoomPayload?> _loadPayload() async {
    final currentUserPubkey =
        ref.read(authServiceProvider).currentPublicKeyHex ?? '';
    final initialRoom = widget.initialRoom?.id == widget.roomId
        ? widget.initialRoom
        : null;
    if (initialRoom != null) {
      return _LiveRoomPayload(
        room: initialRoom,
        role: _deriveRole(
          room: initialRoom,
          sessions:
              widget.initialSession == null ||
                  widget.initialSession!.id != widget.sessionId
              ? const <LiveSession>[]
              : <LiveSession>[widget.initialSession!],
          currentUserPubkey: currentUserPubkey,
        ),
      );
    }

    final repository = ref.read(liveRepositoryProvider);
    final room = await repository.fetchRoom(widget.roomId);
    if (room == null) {
      return null;
    }

    final sessions = await repository.fetchSessions(
      roomAddress: room.address,
      sessionId: widget.sessionId,
    );
    return _LiveRoomPayload(
      room: room,
      role: _deriveRole(
        room: room,
        sessions: sessions,
        currentUserPubkey: currentUserPubkey,
      ),
    );
  }

  LiveRole _deriveRole({
    required LiveRoom room,
    required List<LiveSession> sessions,
    required String currentUserPubkey,
  }) {
    if (room.hostPubkey == currentUserPubkey) {
      return LiveRole.host;
    }

    final isSpeaker = sessions.any(
      (session) => session.speakerPubkeys.contains(currentUserPubkey),
    );
    return isSpeaker ? LiveRole.speaker : LiveRole.audience;
  }
}

class _LiveRoomPayload {
  const _LiveRoomPayload({
    required this.room,
    required this.role,
  });

  final LiveRoom room;
  final LiveRole role;
}
