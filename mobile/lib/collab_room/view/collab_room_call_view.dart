// ABOUTME: The call of a Together room on its screen: who takes part, the
// ABOUTME: mute and camera buttons, and someone's live camera in their cell

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_providers.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar_chip.dart';
import 'package:unified_logger/unified_logger.dart';

/// The other people of [room] this device calls: everyone in the room but
/// the account itself.
Set<String> collabRoomCallOthers(CollabRoom room) => {
  for (final member in room.participants)
    if (member.pubkey != room.ownerPubkey) member.pubkey,
};

/// Whether this device takes part in [room]'s call: the room is open, has a
/// call key, the account is in it, and someone else is too.
bool collabRoomCallIsOpen(CollabRoom room) {
  final status = room.me?.status;
  return room.callKey != null &&
      room.phase.isOpen &&
      (room.isAuthor || status == CollabRoomMemberStatus.joined) &&
      collabRoomCallOthers(room).isNotEmpty;
}

/// Offers the room's call and keeps its membership in step with the room.
///
/// The call is the room's [collabRoomCallProvider], which a part's editor
/// shares, so it outlives the camera flow on top of the room.
class CollabRoomCallScope extends ConsumerWidget {
  /// Wraps [child], the room's content, in the call.
  const CollabRoomCallScope({required this.child, super.key});

  /// The room's content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:roomId, :callKey, :me, :open) = context.select((
      CollabRoomCubit cubit,
    ) {
      final room = cubit.state.room;
      return (
        roomId: room?.id,
        callKey: room?.callKey,
        me: room?.ownerPubkey,
        open: room != null && collabRoomCallIsOpen(room),
      );
    });
    if (!open || roomId == null || callKey == null || me == null) {
      return child;
    }
    final call = ref.watch(
      collabRoomCallProvider((roomId: roomId, callKey: callKey, me: me)),
    );
    return BlocProvider.value(
      value: call,
      child: MultiBlocListener(
        listeners: [
          // The author's lobby changes reach the others through the call in
          // a fraction of the time its snapshot takes.
          BlocListener<CollabRoomCubit, CollabRoomState>(
            listenWhen: (previous, current) {
              final room = current.room;
              return room != null &&
                  room.isAuthor &&
                  room.phase == CollabRoomPhase.lobby &&
                  (previous.layout != current.layout ||
                      !listEquals(
                        previous.lobbySeatOrder,
                        current.lobbySeatOrder,
                      ));
            },
            listener: (context, state) => runDetached(
              context.read<CollabRoomCallCubit>().shareLobby(
                layout: state.layout?.name,
                seats: state.lobbySeatOrder,
                revision: state.nextRevision - 1,
              ),
              'share the collab room lobby',
              logName: 'CollabRoomCallScope',
              category: LogCategory.video,
            ),
          ),
          BlocListener<CollabRoomCallCubit, CollabRoomCallState>(
            listenWhen: (previous, current) =>
                current.call.lobby != null &&
                previous.call.lobby != current.call.lobby,
            listener: (context, state) {
              final lobby = state.call.lobby!;
              context.read<CollabRoomCubit>().lobbyHinted(
                from: lobby.from,
                layout: lobby.layout,
                seats: lobby.seats,
                revision: lobby.revision,
              );
            },
          ),
        ],
        child: child,
      ),
    );
  }
}

/// The mute and camera buttons, and where the call stands.
class CollabRoomCallControls extends StatelessWidget {
  /// Creates the controls; shows nothing outside a call.
  const CollabRoomCallControls({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((CollabRoomCallCubit? cubit) => cubit?.state);
    if (state == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cubit = context.read<CollabRoomCallCubit>();
    final colors = context.vineColors;
    final notice = switch (state.status) {
      CollabRoomCallStatus.joining => l10n.collabRoomCallConnecting,
      CollabRoomCallStatus.failed => l10n.collabRoomCallFailed,
      _ when state.cameraFailed => l10n.collabRoomCallCameraFailed,
      _ => null,
    };
    final inCall = state.status == CollabRoomCallStatus.joined;
    // Out of a call that failed or was left, the mic button joins again —
    // say once the camera let go of the microphone.
    final canJoin =
        state.status == CollabRoomCallStatus.idle ||
        state.status == CollabRoomCallStatus.failed;
    final micOn = !canJoin && state.call.micOn;
    return Padding(
      padding: const .only(top: 12),
      child: Column(
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: .center,
            spacing: 16,
            children: [
              DivineIconButton(
                icon: micOn
                    ? DivineIconName.microphone
                    : DivineIconName.microphoneSlash,
                type: micOn
                    ? DivineIconButtonType.secondary
                    : DivineIconButtonType.primary,
                semanticLabel: canJoin
                    ? l10n.collabRoomCallJoin
                    : micOn
                    ? l10n.collabRoomCallMute
                    : l10n.collabRoomCallUnmute,
                onPressed: inCall
                    ? cubit.toggleMic
                    : !canJoin || state.others.isEmpty
                    ? null
                    : () => runDetached(
                        cubit.join(),
                        'rejoin the collab room call',
                        logName: 'CollabRoomCallControls',
                        category: LogCategory.video,
                      ),
              ),
              DivineIconButton(
                icon: state.call.cameraOn
                    ? DivineIconName.videoCamera
                    : DivineIconName.cameraSlash,
                type: state.call.cameraOn
                    ? DivineIconButtonType.primary
                    : DivineIconButtonType.secondary,
                semanticLabel: state.call.cameraOn
                    ? l10n.collabRoomCallCameraOff
                    : l10n.collabRoomCallCameraOn,
                onPressed: inCall ? cubit.toggleCamera : null,
              ),
              if (!canJoin)
                DivineIconButton(
                  icon: DivineIconName.signOut,
                  type: DivineIconButtonType.secondary,
                  semanticLabel: l10n.collabRoomCallLeave,
                  onPressed: cubit.leave,
                ),
            ],
          ),
          if (notice != null)
            // Read out when it changes: a call that failed or a camera that
            // would not turn on happens out of sight of a screen reader.
            Semantics(
              liveRegion: true,
              child: Text(
                notice,
                textAlign: .center,
                style: VineTheme.bodySmallFont(color: colors.secondaryText),
              ),
            ),
        ],
      ),
    );
  }
}

/// Someone's camera in the room's call, filling their cell.
class CollabRoomLiveVideo extends StatefulWidget {
  /// Shows [stream], mirrored for the account's own front camera.
  const CollabRoomLiveVideo({
    required this.stream,
    this.mirror = false,
    super.key,
  });

  /// The camera's stream.
  final MediaStream stream;

  /// Whether to mirror the picture, as a selfie view is.
  final bool mirror;

  @override
  State<CollabRoomLiveVideo> createState() => _CollabRoomLiveVideoState();
}

class _CollabRoomLiveVideoState extends State<CollabRoomLiveVideo> {
  final _renderer = RTCVideoRenderer();
  late final Future<void> _initializing;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initializing = _renderer.initialize();
    runDetached(
      _attach(),
      'show a collab room call video',
      logName: 'CollabRoomLiveVideo',
      category: LogCategory.video,
    );
  }

  Future<void> _attach() async {
    await _initializing;
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(CollabRoomLiveVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    runDetached(
      _initializing.whenComplete(_renderer.dispose),
      'release a collab room call video',
      logName: 'CollabRoomLiveVideo',
      category: LogCategory.video,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    return RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

/// The call button of a part's editor: joins the room's call to talk while
/// editing, or leaves it. Shows nothing outside a part or for a room without a
/// call.
class CollabRoomEditorCallButton extends ConsumerWidget {
  /// Creates the button.
  const CollabRoomEditorCallButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final part = ref.watch(collabRoomPartProvider);
    final id = collabRoomPartCallId(part);
    if (id == null || part == null) return const SizedBox.shrink();
    final room = ref.watch(collabRoomLiveProvider(id.roomId)).value;
    if (room == null ||
        room.ownerPubkey != id.me ||
        room.callKey != id.callKey ||
        room.me?.inviteRevision != part.inviteRevision ||
        !collabRoomCallIsOpen(room)) {
      return const SizedBox.shrink();
    }
    final call = ref.watch(collabRoomCallProvider(id));
    return BlocSelector<CollabRoomCallCubit, CollabRoomCallState, _EditorCall>(
      bloc: call,
      selector: _EditorCall.of,
      builder: (context, phase) {
        final l10n = context.l10n;
        final inCall = phase != _EditorCall.out;
        return VideoEditorToolbarChip(
          icon: inCall ? .microphone : .microphoneSlash,
          loading: phase == _EditorCall.connecting,
          label: switch (phase) {
            _EditorCall.out => l10n.collabRoomCallJoin,
            _EditorCall.connecting => l10n.collabRoomCallConnecting,
            _EditorCall.connected => l10n.collabRoomCallLeave,
          },
          liveRegion: true,
          onTap: () => runDetached(
            inCall ? call.leave() : call.join(),
            inCall
                ? 'leave the collab room call from the editor'
                : 'join the collab room call from the editor',
            logName: 'CollabRoomEditorCallButton',
            category: LogCategory.video,
          ),
        );
      },
    );
  }
}

/// Where the editor's button sees the call: joined only counts once someone
/// can be heard, so the wait for the first connection shows as such.
enum _EditorCall {
  out,
  connecting,
  connected;

  static _EditorCall of(CollabRoomCallState state) => switch (state.status) {
    CollabRoomCallStatus.idle || CollabRoomCallStatus.failed => out,
    CollabRoomCallStatus.joining => connecting,
    CollabRoomCallStatus.joined
        when state.call.peers.values.any((peer) => peer.connected) =>
      connected,
    CollabRoomCallStatus.joined => connecting,
  };
}
