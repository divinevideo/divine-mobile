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
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/utils/detached_future.dart';
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

/// Joins the room's call while the room screen shows, with the microphone on,
/// and keeps who is called in step with who is in the room.
class CollabRoomCallScope extends ConsumerWidget {
  /// Wraps [child], the room's content, in the call.
  const CollabRoomCallScope({required this.child, super.key});

  /// The room's content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:callKey, :me, :open) = context.select((CollabRoomCubit cubit) {
      final room = cubit.state.room;
      return (
        callKey: room?.callKey,
        me: room?.ownerPubkey,
        open: room != null && collabRoomCallIsOpen(room),
      );
    });
    if (!open || callKey == null || me == null) return child;
    final client = ref.watch(nostrServiceProvider);
    return BlocProvider(
      key: ValueKey((callKey, me, client)),
      create: (context) {
        final room = context.read<CollabRoomCubit>().state.room!;
        final cubit = CollabRoomCallCubit(
          me: me,
          callKey: callKey,
          others: collabRoomCallOthers(room),
          createCall: ({required me, required others, required callKey}) =>
              WebRtcCollabRoomCall(
                me: me,
                others: others,
                callKey: callKey,
                transport: NostrCollabRoomCallTransport(client),
              ),
        );
        runDetached(
          cubit.join(),
          'join the collab room call',
          logName: 'CollabRoomCallScope',
          category: LogCategory.video,
        );
        return cubit;
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<CollabRoomCubit, CollabRoomState>(
            listenWhen: (previous, current) =>
                previous.room?.participants != current.room?.participants,
            listener: (context, state) => context
                .read<CollabRoomCallCubit>()
                .othersChanged(collabRoomCallOthers(state.room!)),
          ),
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
                icon: state.call.micOn
                    ? DivineIconName.microphone
                    : DivineIconName.microphoneSlash,
                type: state.call.micOn
                    ? DivineIconButtonType.secondary
                    : DivineIconButtonType.primary,
                semanticLabel: state.call.micOn
                    ? l10n.collabRoomCallMute
                    : l10n.collabRoomCallUnmute,
                onPressed: inCall ? cubit.toggleMic : null,
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
            ],
          ),
          if (notice != null)
            Text(
              notice,
              textAlign: .center,
              style: VineTheme.bodySmallFont(color: colors.secondaryText),
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    runDetached(
      _attach(),
      'show a collab room call video',
      logName: 'CollabRoomLiveVideo',
      category: LogCategory.video,
    );
  }

  Future<void> _attach() async {
    await _renderer.initialize();
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
      _renderer.dispose(),
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
