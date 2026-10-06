import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/widgets/live_chat_panel.dart';
import 'package:openvine/screens/live/widgets/live_host_controls_sheet.dart';
import 'package:openvine/screens/live/widgets/live_local_media_controls.dart';
import 'package:openvine/screens/live/widgets/live_room_error_banner.dart';
import 'package:openvine/screens/live/widgets/live_room_stage.dart';
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
      backgroundColor: context.vineColors.surface,
      appBar: AppBar(
        backgroundColor: context.vineColors.surface,
        leading: DivineIconButton(
          icon: DivineIconName.arrowLeft,
          tooltip: context.l10n.commonBack,
          type: DivineIconButtonType.ghostSecondary,
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
              state.room?.title ?? context.l10n.liveLiveRoom,
              style: VineTheme.titleLargeFont(
                color: context.vineColors.onSurface,
              ),
            );
          },
        ),
      ),
      body: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, roomState) {
          final mediaState = roomState.mediaState;
          final cameraButtonLabel = _cameraMediaButtonLabel(
            context,
            mediaState,
          );
          final microphoneButtonLabel = _microphoneMediaButtonLabel(
            context,
            mediaState,
          );
          final cameraBusy = _isCameraStarting(mediaState);
          final microphoneBusy = _isMicrophoneStarting(mediaState);

          return switch (roomState.status) {
            LiveRoomStatus.initial || LiveRoomStatus.loading => const Center(
              child: DivineCircularProgressIndicator(color: VineTheme.primary),
            ),
            LiveRoomStatus.failure => Center(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  liveRoomErrorLabel(context, roomState.error),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
            LiveRoomStatus.ready => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomState.error != null) ...[
                    LiveRoomErrorBanner(
                      message: liveRoomErrorLabel(context, roomState.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LiveRoomStage(
                    speakerPubkeys: roomState.speakerPubkeys,
                    audienceCount:
                        roomState.session?.audienceCount ??
                        roomState.presence.length,
                    statusLabel: switch (roomState.mediaState.status) {
                      LiveMediaConnectionStatus.disconnected =>
                        context.l10n.relaySettingsDisconnected,
                      LiveMediaConnectionStatus.connecting =>
                        context.l10n.commonLoading,
                      LiveMediaConnectionStatus.connected =>
                        context.l10n.relaySettingsConnected,
                      LiveMediaConnectionStatus.reconnecting =>
                        context.l10n.liveConnectionLooksShaky,
                      LiveMediaConnectionStatus.audioOnly =>
                        context.l10n.liveLiveAudioOnly,
                      LiveMediaConnectionStatus.failed =>
                        context.l10n.authFailedToConnect,
                    },
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
                        label: context.l10n.liveHostControls,
                        type: DivineButtonType.secondary,
                        size: DivineButtonSize.small,
                        onPressed: () async {
                          await VineBottomSheet.show<void>(
                            context: context,
                            scrollable: false,
                            showHeader: false,
                            body: BlocProvider.value(
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
        'https://divine.video${RoutePaths.liveRoomFor(room.id, session.id)}';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: roomUrl,
          subject: context.l10n.liveRoomShareSubject(room.title),
        ),
      );
    } catch (_) {
      // Ignore share errors here and fall through to clipboard copy.
    }

    await Clipboard.setData(ClipboardData(text: roomUrl));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.liveRoomLinkCopiedToClipboard)),
    );
  }
}

String _cameraMediaButtonLabel(
  BuildContext context,
  LiveMediaState mediaState,
) {
  if (_isCameraStarting(mediaState)) {
    return context.l10n.liveStartingCamera;
  }

  return mediaState.cameraEnabled
      ? context.l10n.liveTurnCameraOff
      : context.l10n.liveTurnCameraOn;
}

String _microphoneMediaButtonLabel(
  BuildContext context,
  LiveMediaState mediaState,
) {
  if (_isMicrophoneStarting(mediaState)) {
    return context.l10n.liveStartingMicrophone;
  }

  return mediaState.microphoneEnabled
      ? context.l10n.liveTurnMicOff
      : context.l10n.liveTurnMicOn;
}

bool _isCameraStarting(LiveMediaState mediaState) {
  return mediaState.cameraBusy && mediaState.requestedCameraEnabled;
}

bool _isMicrophoneStarting(LiveMediaState mediaState) {
  return mediaState.microphoneBusy && mediaState.requestedMicrophoneEnabled;
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
            label: context.l10n.liveShareRoom,
            type: DivineButtonType.secondary,
            onPressed: onShareRoom,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: DivineButton(
            label: canPublish
                ? context.l10n.liveYouAreOnStage
                : currentUserHandRaised
                ? context.l10n.liveLowerHand
                : context.l10n.liveRaiseHand,
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
        color: context.vineColors.surfaceContainerHigh,
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
                  context.l10n.liveParticipants,
                  style: VineTheme.titleLargeFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.liveRoleCounts(
                    hostCount,
                    moderatorCount,
                    speakerCount,
                    audienceCount,
                  ),
                  textAlign: TextAlign.end,
                  softWrap: true,
                  style: VineTheme.labelMediumFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orderedPresence.isEmpty)
            Text(
              context.l10n.liveNoOneHasJoinedTheRoomYet,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: orderedPresence
                  .map((member) {
                    final roleLabel = switch (member.role) {
                      LiveRole.host => context.l10n.liveHost,
                      LiveRole.moderator => context.l10n.liveModerator,
                      LiveRole.speaker => context.l10n.liveSpeaker,
                      LiveRole.audience =>
                        speakerPubkeys.contains(member.pubkey)
                            ? context.l10n.liveSpeaker
                            : context.l10n.liveAudience,
                    };
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.vineColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.vineColors.outlineMuted,
                        ),
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
                                  style: VineTheme.labelLargeFont(
                                    color: context.vineColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _LiveRoleChip(label: roleLabel),
                                    if (member.handRaised)
                                      _LiveRoleChip(
                                        label: context.l10n.liveHandRaised,
                                      ),
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
          color: context.vineColors.onSurfaceVariant,
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
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.liveHandRaisedDescription,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
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
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.liveConnectionLooksShaky,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.liveAudioOnlySuggestion,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DivineButton(
              label: context.l10n.liveSwitchToAudioOnly,
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
