import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/live/widgets/live_local_media_controls.dart';
import 'package:openvine/screens/live/widgets/live_speaker_queue_sheet.dart';
import 'package:openvine/services/content_moderation_types.dart';

class LiveHostControlsSheet extends ConsumerStatefulWidget {
  const LiveHostControlsSheet({super.key});

  @override
  ConsumerState<LiveHostControlsSheet> createState() =>
      _LiveHostControlsSheetState();
}

class _LiveHostControlsSheetState extends ConsumerState<LiveHostControlsSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _statusController;

  @override
  void initState() {
    super.initState();
    final state = context.read<LiveRoomBloc>().state;
    _titleController = TextEditingController(
      text: state.room?.title ?? '',
    );
    _statusController = TextEditingController(
      text: state.room?.visibility.nostrStatusValue ?? 'open',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, state) {
          final cameraButtonLabel = _cameraMediaButtonLabel(
            cameraEnabled: state.mediaState.cameraEnabled,
            cameraBusy: state.mediaState.cameraBusy,
            requestedCameraEnabled: state.mediaState.requestedCameraEnabled,
          );
          final microphoneButtonLabel = _microphoneMediaButtonLabel(
            microphoneEnabled: state.mediaState.microphoneEnabled,
            microphoneBusy: state.mediaState.microphoneBusy,
            requestedMicrophoneEnabled:
                state.mediaState.requestedMicrophoneEnabled,
          );
          final cameraBusy = _isCameraStarting(
            state.mediaState.cameraBusy,
            state.mediaState.requestedCameraEnabled,
          );
          final microphoneBusy = _isMicrophoneStarting(
            state.mediaState.microphoneBusy,
            state.mediaState.requestedMicrophoneEnabled,
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Host controls',
                    style: VineTheme.headlineSmallFont(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep the stage tight, work the raised hands, and degrade cleanly when the network gets weird.',
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _HostSection(
                    title: 'Room details',
                    children: [
                      TextField(
                        controller: _titleController,
                        style: VineTheme.bodyMediumFont(),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'Update the room title',
                          filled: true,
                          fillColor: VineTheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _statusController,
                        style: VineTheme.bodyMediumFont(),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          hintText: 'open, private, or closed',
                          filled: true,
                          fillColor: VineTheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DivineButton(
                        label: 'Update title/status',
                        type: DivineButtonType.secondary,
                        expanded: true,
                        onPressed: () {
                          final currentRoom = state.room;
                          if (currentRoom == null) {
                            return;
                          }

                          final nextTitle = _titleController.text.trim();
                          final nextStatus = _statusController.text.trim();
                          context.read<LiveRoomBloc>().add(
                            UpdateRoomMetadataRequested(
                              title: nextTitle.isEmpty
                                  ? currentRoom.title
                                  : nextTitle,
                              visibility: nextStatus.isEmpty
                                  ? currentRoom.visibility
                                  : LiveRoomVisibility.fromNostrStatus(
                                      nextStatus,
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.canPublish) ...[
                    LiveLocalMediaControls(
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
                    const SizedBox(height: 20),
                  ],
                  _HostSection(
                    title: 'Moderation',
                    children: [
                      DivineButton(
                        label: 'Manage participants',
                        type: DivineButtonType.secondary,
                        expanded: true,
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: VineTheme.surfaceBackground,
                            isScrollControlled: true,
                            builder: (_) => BlocProvider.value(
                              value: context.read<LiveRoomBloc>(),
                              child: LiveSpeakerQueueSheet(
                                hostPubkey: state.room?.hostPubkey ?? '',
                                presence: state.visiblePresence,
                                speakerPubkeys: state.speakerPubkeys,
                                onPromote: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    PromoteSpeakerRequested(pubkey),
                                  );
                                },
                                onApprove: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    ApproveRaisedHandRequested(pubkey),
                                  );
                                },
                                onDeny: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    DenyRaisedHandRequested(pubkey),
                                  );
                                },
                                onDemote: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    DemoteSpeakerRequested(pubkey),
                                  );
                                },
                                onRemove: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    HideParticipantLocallyRequested(pubkey),
                                  );
                                },
                                onMuteChat: (pubkey) {
                                  context.read<LiveRoomBloc>().add(
                                    HideChatLocallyRequested(pubkey),
                                  );
                                },
                                onReport: (pubkey) {
                                  unawaited(_reportUser(pubkey));
                                },
                                onBlock: (pubkey) {
                                  unawaited(_blockUser(pubkey));
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _HostSection(
                    title: 'Session',
                    children: [
                      DivineButton(
                        label: 'End session',
                        type: DivineButtonType.error,
                        expanded: true,
                        onPressed: () async {
                          final liveRoomBloc = context.read<LiveRoomBloc>();
                          final navigator = Navigator.of(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                backgroundColor: VineTheme.surfaceContainerHigh,
                                title: Text(
                                  'End this live session?',
                                  style: VineTheme.titleMediumFont(),
                                ),
                                content: Text(
                                  'This ends the room for everyone and closes the stage.',
                                  style: VineTheme.bodyMediumFont(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop(false);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop(true);
                                    },
                                    child: const Text('End session'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (!mounted || confirmed != true) {
                            return;
                          }

                          liveRoomBloc.add(const EndSessionRequested());
                          navigator.pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _cameraMediaButtonLabel({
    required bool cameraEnabled,
    required bool cameraBusy,
    required bool requestedCameraEnabled,
  }) {
    if (_isCameraStarting(cameraBusy, requestedCameraEnabled)) {
      return 'Starting camera...';
    }

    return cameraEnabled ? 'Turn camera off' : 'Turn camera on';
  }

  String _microphoneMediaButtonLabel({
    required bool microphoneEnabled,
    required bool microphoneBusy,
    required bool requestedMicrophoneEnabled,
  }) {
    if (_isMicrophoneStarting(microphoneBusy, requestedMicrophoneEnabled)) {
      return 'Starting microphone...';
    }

    return microphoneEnabled ? 'Turn mic off' : 'Turn mic on';
  }

  bool _isCameraStarting(bool cameraBusy, bool requestedCameraEnabled) {
    return cameraBusy && requestedCameraEnabled;
  }

  bool _isMicrophoneStarting(
    bool microphoneBusy,
    bool requestedMicrophoneEnabled,
  ) {
    return microphoneBusy && requestedMicrophoneEnabled;
  }

  Future<void> _reportUser(String pubkey) async {
    try {
      final service = await ref.read(contentReportingServiceProvider.future);
      final result = await service.reportUser(
        userPubkey: pubkey,
        reason: ContentFilterReason.other,
        details: 'Reported from live room moderation',
        relatedEventIds: const <String>[],
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? 'User reported' : 'Failed to report user',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report user: $error')),
      );
    }
  }

  Future<void> _blockUser(String pubkey) async {
    try {
      final currentUserPubkey =
          ref.read(authServiceProvider).currentPublicKeyHex ?? '';
      final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
      await blocklistRepository.blockUser(
        pubkey,
        ourPubkey: currentUserPubkey,
      );

      if (!mounted) {
        return;
      }

      final liveRoomBloc = context.read<LiveRoomBloc>();
      liveRoomBloc
        ..add(HideChatLocallyRequested(pubkey))
        ..add(HideParticipantLocallyRequested(pubkey));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to block user: $error')),
      );
    }
  }
}

class _HostSection extends StatelessWidget {
  const _HostSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
