import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/widgets/live_chat_panel.dart';
import 'package:openvine/screens/live/widgets/live_host_controls_sheet.dart';
import 'package:openvine/screens/live/widgets/live_local_media_controls.dart';
import 'package:openvine/screens/live/widgets/live_room_stage.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:share_plus/share_plus.dart';

class LiveRoomView extends StatefulWidget {
  const LiveRoomView({super.key});

  @override
  State<LiveRoomView> createState() => _LiveRoomViewState();
}

class _LiveRoomViewState extends State<LiveRoomView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go(LiveDiscoveryPage.path);
          },
        ),
        title: BlocBuilder<LiveRoomBloc, LiveRoomState>(
          builder: (context, state) {
            return Text(
              state.room?.title ?? 'Live room',
              style: VineTheme.titleLargeFont(),
            );
          },
        ),
      ),
      body: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, roomState) {
          final mediaState = roomState.mediaState;
          final cameraButtonLabel = _cameraMediaButtonLabel(mediaState);
          final microphoneButtonLabel = _microphoneMediaButtonLabel(mediaState);
          final cameraBusy = _isCameraStarting(mediaState);
          final microphoneBusy = _isMicrophoneStarting(mediaState);

          return switch (roomState.status) {
            LiveRoomStatus.initial || LiveRoomStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
            LiveRoomStatus.failure => Center(
              child: Text(
                roomState.errorMessage ?? 'Unable to open this live room.',
                style: VineTheme.bodyMediumFont(),
              ),
            ),
            LiveRoomStatus.ready => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomState.errorMessage != null) ...[
                    _LiveRoomErrorBanner(message: roomState.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  LiveRoomStage(
                    speakerPubkeys: roomState.speakerPubkeys,
                    audienceCount:
                        roomState.session?.audienceCount ??
                        roomState.presence.length,
                    statusLabel: roomState.mediaState.status.name,
                  ),
                  const SizedBox(height: 16),
                  if (roomState.canPublish &&
                      roomState.mediaState.status ==
                          LiveMediaConnectionStatus.reconnecting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: _LiveNetworkDegradationBanner(),
                    ),
                  _LiveRoomActionRow(
                    canPublish: roomState.canPublish,
                    currentUserHandRaised: roomState.currentUserHandRaised,
                    onShareRoom: () => _shareRoom(context, roomState),
                    onToggleRequestToSpeak: () {
                      if (roomState.canPublish) {
                        return;
                      }

                      context.read<LiveRoomBloc>().add(
                        const ToggleHandRaiseRequested(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _LiveParticipantRoster(
                    presence: roomState.visiblePresence,
                    speakerPubkeys: roomState.speakerPubkeys,
                  ),
                  const SizedBox(height: 16),
                  if (roomState.currentUserHandRaised && !roomState.canPublish)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: _LiveRequestPendingBanner(),
                    ),
                  if (roomState.canPublish)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: LiveLocalMediaControls(
                        cameraButtonLabel: cameraButtonLabel,
                        microphoneButtonLabel: microphoneButtonLabel,
                        onToggleCamera: () {
                          if (cameraBusy) {
                            return;
                          }
                          context.read<LiveRoomBloc>().add(
                            const ToggleCameraRequested(),
                          );
                        },
                        onToggleMicrophone: () {
                          if (microphoneBusy) {
                            return;
                          }
                          context.read<LiveRoomBloc>().add(
                            const ToggleMicrophoneRequested(),
                          );
                        },
                        onSwitchCamera: () {
                          context.read<LiveRoomBloc>().add(
                            const SwitchCameraRequested(),
                          );
                        },
                        onEnableAudioOnly: () {
                          context.read<LiveRoomBloc>().add(
                            const EnableAudioOnlyRequested(),
                          );
                        },
                      ),
                    ),
                  if (roomState.canModerate)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DivineButton(
                        label: 'Host controls',
                        type: DivineButtonType.secondary,
                        size: DivineButtonSize.small,
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: VineTheme.surfaceBackground,
                            isScrollControlled: true,
                            builder: (_) => BlocProvider.value(
                              value: context.read<LiveRoomBloc>(),
                              child: const LiveHostControlsSheet(),
                            ),
                          );
                        },
                      ),
                    ),
                  if (roomState.canModerate) const SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    child: BlocBuilder<LiveChatBloc, LiveChatState>(
                      builder: (context, chatState) {
                        return const LiveChatPanel();
                      },
                    ),
                  ),
                ],
              ),
            ),
          };
        },
      ),
    );
  }

  Future<void> _shareRoom(BuildContext context, LiveRoomState state) async {
    final room = state.room;
    final session = state.session;
    if (room == null || session == null) {
      return;
    }

    final roomUrl =
        'https://divine.video/live/room/${room.id}/session/${session.id}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: roomUrl, subject: 'Live room: ${room.title}'),
      );
    } catch (_) {
      // Ignore share errors here and fall through to clipboard copy.
    }

    await Clipboard.setData(ClipboardData(text: roomUrl));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room link copied to clipboard')),
    );
  }
}

String _cameraMediaButtonLabel(LiveMediaState mediaState) {
  if (_isCameraStarting(mediaState)) {
    return 'Starting camera...';
  }

  return mediaState.cameraEnabled ? 'Turn camera off' : 'Turn camera on';
}

String _microphoneMediaButtonLabel(LiveMediaState mediaState) {
  if (_isMicrophoneStarting(mediaState)) {
    return 'Starting microphone...';
  }

  return mediaState.microphoneEnabled ? 'Turn mic off' : 'Turn mic on';
}

bool _isCameraStarting(LiveMediaState mediaState) {
  return mediaState.cameraBusy && mediaState.requestedCameraEnabled;
}

bool _isMicrophoneStarting(LiveMediaState mediaState) {
  return mediaState.microphoneBusy && mediaState.requestedMicrophoneEnabled;
}

class _LiveRoomErrorBanner extends StatelessWidget {
  const _LiveRoomErrorBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VineTheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VineTheme.error),
      ),
      child: Text(
        message,
        style: VineTheme.bodyMediumFont(color: VineTheme.onErrorContainer),
      ),
    );
  }
}

class _LiveRoomActionRow extends StatelessWidget {
  const _LiveRoomActionRow({
    required this.canPublish,
    required this.currentUserHandRaised,
    required this.onShareRoom,
    required this.onToggleRequestToSpeak,
  });

  final bool canPublish;
  final bool currentUserHandRaised;
  final VoidCallback onShareRoom;
  final VoidCallback onToggleRequestToSpeak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: DivineButton(
            label: 'Share room',
            type: DivineButtonType.secondary,
            onPressed: onShareRoom,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: DivineButton(
            label: canPublish
                ? 'You are on stage'
                : currentUserHandRaised
                ? 'Lower hand'
                : 'Raise hand',
            onPressed: canPublish ? null : onToggleRequestToSpeak,
            expanded: true,
          ),
        ),
      ],
    );
  }
}

class _LiveParticipantRoster extends StatelessWidget {
  const _LiveParticipantRoster({
    required this.presence,
    required this.speakerPubkeys,
  });

  final List<LivePresence> presence;
  final List<String> speakerPubkeys;

  @override
  Widget build(BuildContext context) {
    final orderedPresence = [...presence]
      ..sort((left, right) {
        int roleRank(LivePresence presence) => switch (presence.role) {
          LiveRole.host => 0,
          LiveRole.moderator => 1,
          LiveRole.speaker => 2,
          LiveRole.audience => 3,
        };

        final roleComparison = roleRank(left).compareTo(roleRank(right));
        if (roleComparison != 0) {
          return roleComparison;
        }
        return left.updatedAt.compareTo(right.updatedAt);
      });

    final hostCount = orderedPresence
        .where((member) => member.role == LiveRole.host)
        .length;
    final moderatorCount = orderedPresence
        .where((member) => member.role == LiveRole.moderator)
        .length;
    final speakerCount = orderedPresence
        .where(
          (member) =>
              member.role == LiveRole.speaker ||
              speakerPubkeys.contains(member.pubkey),
        )
        .length;
    final audienceCount = orderedPresence
        .where(
          (member) =>
              member.role == LiveRole.audience &&
              !speakerPubkeys.contains(member.pubkey),
        )
        .length;

    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Participants',
                  style: VineTheme.titleLargeFont(),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$hostCount host, $moderatorCount moderators, $speakerCount speakers, $audienceCount audience',
                  textAlign: TextAlign.end,
                  softWrap: true,
                  style: VineTheme.labelMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orderedPresence.isEmpty)
            Text(
              'No one has joined the room yet.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: orderedPresence
                  .map((member) {
                    final roleLabel = switch (member.role) {
                      LiveRole.host => 'Host',
                      LiveRole.moderator => 'Moderator',
                      LiveRole.speaker => 'Speaker',
                      LiveRole.audience =>
                        speakerPubkeys.contains(member.pubkey)
                            ? 'Speaker'
                            : 'Audience',
                    };
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VineTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: VineTheme.outlineMuted),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.pubkey,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: VineTheme.labelLargeFont(),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _LiveRoleChip(label: roleLabel),
                                    if (member.handRaised)
                                      const _LiveRoleChip(label: 'Hand raised'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _LiveRoleChip extends StatelessWidget {
  const _LiveRoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VineTheme.scrim15,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: VineTheme.labelSmallFont(
          color: VineTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LiveRequestPendingBanner extends StatelessWidget {
  const _LiveRequestPendingBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Your hand is raised. The host can bring you on stage from the speaker queue.',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LiveNetworkDegradationBanner extends StatelessWidget {
  const _LiveNetworkDegradationBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection looks shaky',
              style: VineTheme.titleSmallFont(),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep the room stable by switching to audio only until the network settles.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DivineButton(
              label: 'Switch to audio only',
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: () {
                context.read<LiveRoomBloc>().add(
                  const EnableAudioOnlyRequested(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
