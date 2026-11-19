// ABOUTME: The collaborative room's UI: the layout with each person's cell,
// ABOUTME: the people in the room, and the host's or member's next step

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/collab_room/view/collab_room_call_view.dart';
import 'package:openvine/collab_room/view/collab_room_navigation.dart';
import 'package:openvine/collab_room/view/widgets/collab_room_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_cell_shape_widgets.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_controls.dart';
import 'package:unified_logger/unified_logger.dart';

/// The room screen under its [CollabRoomCubit].
class CollabRoomView extends StatelessWidget {
  /// Creates the view; reached through `CollabRoomPage`.
  const CollabRoomView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((CollabRoomCubit c) => c.state.status);
    return _RoomListeners(
      child: Scaffold(
        backgroundColor: context.vineColors.background,
        appBar: DiVineAppBar(
          title: l10n.collabRoomTitle,
          showBackButton: true,
          backButtonSemanticLabel: l10n.commonBack,
        ),
        body: switch (status) {
          CollabRoomStatus.loading => const Center(
            child: DivineCircularProgressIndicator(),
          ),
          CollabRoomStatus.missing => _Message(text: l10n.collabRoomMissing),
          CollabRoomStatus.ready => const _RoomContent(),
        },
      ),
    );
  }
}

/// Reports failed actions and opens the post screen once the video is put
/// together.
class _RoomListeners extends ConsumerWidget {
  const _RoomListeners({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CollabRoomCubit, CollabRoomState>(
          listenWhen: (previous, current) =>
              previous.actionStatus != current.actionStatus &&
              current.actionStatus == CollabRoomActionStatus.failed,
          listener: (context, state) => _showSnackBar(
            context,
            context.l10n.collabRoomActionFailed,
          ),
        ),
        BlocListener<CollabRoomCubit, CollabRoomState>(
          listenWhen: (previous, current) =>
              previous.composeStatus != current.composeStatus,
          listener: (context, state) async {
            switch (state.composeStatus) {
              case CollabRoomComposeStatus.done:
                await openCollabRoomPost(
                  context,
                  ref,
                  state.room!,
                  state.composedClip!,
                );
              case CollabRoomComposeStatus.failed:
                _showSnackBar(context, context.l10n.collabRoomComposeFailed);
              case CollabRoomComposeStatus.idle:
              case CollabRoomComposeStatus.running:
                break;
            }
          },
        ),
      ],
      child: child,
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const .all(24),
        child: Text(
          text,
          textAlign: .center,
          style: VineTheme.bodyLargeFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// The space between the room's content and the screen's sides.
const _sides = EdgeInsets.symmetric(horizontal: 16);

class _RoomContent extends StatelessWidget {
  const _RoomContent();

  @override
  Widget build(BuildContext context) {
    return CollabRoomCallScope(
      child: ListView(
        // The room ends in buttons, which must clear the system navigation.
        // The sides are padded per row, so the layout row can scroll from
        // edge to edge.
        padding: .only(
          top: 8,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: const [
          Padding(padding: _sides, child: _LayoutPreview()),
          Padding(padding: _sides, child: CollabRoomCallControls()),
          SizedBox(height: 16),
          Padding(padding: _sides, child: _Notice()),
          _LayoutChoices(),
          SizedBox(height: 16),
          Padding(padding: _sides, child: _Members()),
          SizedBox(height: 24),
          Padding(padding: _sides, child: _Actions()),
        ],
      ),
    );
  }
}

/// The video's frame with each person in their cell: their finished part
/// once it is in, their avatar until then.
class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview();

  static const double _maxHeight = 420;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollabRoomCubit>().state;
    final room = state.room!;
    final frame = room.phase == CollabRoomPhase.lobby
        ? state.aspectRatio
        : room.frameAspectRatio;
    final layout = state.layout;
    final cells =
        layout?.cells(aspectRatio: frame.value, gap: collabRoomCellGap) ??
        const [
          (
            rect: Rect.fromLTWH(0, 0, 1, 1),
            shape: SplitScreenCellShape.rectangle,
          ),
        ];
    CollabRoomMember? occupant(int cell) => room.phase == CollabRoomPhase.lobby
        ? state.lobbySeats.elementAtOrNull(cell)
        : room.memberInCell(cell);
    final canSwapSeats =
        room.isAuthor &&
        room.phase == CollabRoomPhase.lobby &&
        state.lobbySeats.length >= collabRoomMinParticipants;
    final canPickSound =
        room.isAuthor && room.phase == CollabRoomPhase.recording;
    final call = context.select(
      (CollabRoomCallCubit? cubit) => cubit?.state.call,
    );
    MediaStream? liveVideo(CollabRoomMember? member) {
      if (member == null || call == null) return null;
      if (member.pubkey == room.ownerPubkey) return call.localVideo;
      final peer = call.peers[member.pubkey];
      return peer != null && peer.connected && peer.cameraOn
          ? peer.stream
          : null;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      child: Center(
        child: AspectRatio(
          aspectRatio: frame.value,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              Rect inFrame(Rect rect) => Rect.fromLTWH(
                rect.left * size.width,
                rect.top * size.height,
                rect.width * size.width,
                rect.height * size.height,
              );
              return ClipRRect(
                borderRadius: .circular(12),
                child: ColoredBox(
                  // Fixed media chrome: the gaps are part of the video.
                  color: VineTheme.backgroundColor,
                  child: Stack(
                    children: [
                      for (final (index, (:rect, :shape)) in cells.indexed)
                        Positioned.fromRect(
                          // Keyed by who sits there, so a swap moves a
                          // person's live camera and avatar to their new cell
                          // instead of reloading both in the old one.
                          key: ValueKey(occupant(index)?.pubkey ?? index),
                          rect: inFrame(rect),
                          child: _Cell(
                            shape: shape,
                            covered: [
                              for (final above in cells.skip(index + 1))
                                if (inFrame(above.rect) case final aboveRect
                                    when aboveRect.overlaps(inFrame(rect)))
                                  above.shape.pathIn(
                                    aboveRect.shift(-inFrame(rect).topLeft),
                                  ),
                            ],
                            member: occupant(index),
                            isOwn: occupant(index)?.pubkey == room.ownerPubkey,
                            liveVideo: liveVideo(occupant(index)),
                            isMuted:
                                call?.peers[occupant(index)?.pubkey]?.micOn ==
                                false,
                            thumbnailPath: state
                                .partFiles[occupant(index)?.pubkey]
                                ?.thumbnailPath,
                            hasPart: room.parts.containsKey(
                              occupant(index)?.pubkey,
                            ),
                            hasSound:
                                room.phase == CollabRoomPhase.recording &&
                                occupant(index)?.pubkey ==
                                    state.effectiveSoundPubkey,
                            isSelected: state.selectedSeat == index,
                            tapLabel: canSwapSeats
                                ? context.l10n.collabRoomSwapSeatSemanticLabel
                                : context.l10n.collabRoomSoundSemanticLabel,
                            onTap: canSwapSeats && occupant(index) != null
                                ? () => context
                                      .read<CollabRoomCubit>()
                                      .seatTapped(index)
                                : canPickSound &&
                                      room.parts.containsKey(
                                        occupant(index)?.pubkey,
                                      )
                                ? () => context
                                      .read<CollabRoomCubit>()
                                      .soundPicked(occupant(index)!.pubkey)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.shape,
    required this.covered,
    required this.member,
    required this.isOwn,
    required this.liveVideo,
    required this.isMuted,
    required this.thumbnailPath,
    required this.hasPart,
    required this.hasSound,
    required this.isSelected,
    required this.tapLabel,
    required this.onTap,
  });

  /// The cell's shape in its rect.
  final SplitScreenCellShape shape;

  /// The outlines of the cells on top of this one, in its own coordinates:
  /// the badges keep clear of them.
  final List<Path> covered;

  final CollabRoomMember? member;
  final bool isOwn;

  /// The person's camera in the room's call, while on.
  final MediaStream? liveVideo;

  /// Whether the person muted their microphone in the call.
  final bool isMuted;
  final String? thumbnailPath;
  final bool hasPart;
  final bool hasSound;

  /// Whether the author picked this seat to swap.
  final bool isSelected;

  /// What tapping the cell does, for screen readers.
  final String tapLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final member = this.member;
    final thumbnail = thumbnailPath;
    final colors = context.vineColors;
    final live = liveVideo;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        Offset badgeAt(Alignment corner) => splitScreenBadgeOffset(
          shape: shape,
          cell: constraints.biggest,
          badge: _Badge.size,
          corner: corner,
          covered: covered,
        ).offset;
        return Stack(
          fit: .expand,
          children: [
            if (live != null)
              ExcludeSemantics(
                child: CollabRoomLiveVideo(stream: live, mirror: isOwn),
              )
            else if (thumbnail != null)
              ExcludeSemantics(child: Image.file(File(thumbnail), fit: .cover))
            else
              ColoredBox(
                color: isOwn
                    ? colors.surfaceContainerHigh
                    : colors.surfaceContainer,
                child: member == null
                    ? null
                    : Center(
                        child: ExcludeSemantics(
                          child: CollabRoomAvatar(pubkey: member.pubkey),
                        ),
                      ),
              ),
            if (hasPart && thumbnail == null)
              Positioned.fromRect(
                rect: badgeAt(Alignment.topLeft) & _Badge.size,
                child: const _Badge(icon: DivineIconName.check),
              ),
            if (hasSound)
              Positioned.fromRect(
                rect: badgeAt(Alignment.topRight) & _Badge.size,
                child: const _Badge(icon: DivineIconName.speakerHigh),
              ),
            if (isMuted)
              Positioned.fromRect(
                rect: badgeAt(Alignment.bottomRight) & _Badge.size,
                child: Semantics(
                  label: context.l10n.collabRoomCallMuted,
                  child: const _Badge(icon: DivineIconName.microphoneSlash),
                ),
              ),
            // Always there, only coloured when selected: a ring that came
            // and went would change the tree and restart the live video.
            SplitScreenCellOutline(
              shape: shape,
              color: isSelected ? colors.accentBrand : VineTheme.transparent,
              width: 3,
            ),
          ],
        );
      },
    );
    final onTap = this.onTap;
    // The same widgets whether the cell can be tapped, is selected or changes
    // shape, so a live video in it keeps playing instead of starting over
    // black. Cut to the cell's shape outside the tap target, so a tap off the
    // shape reaches the cell underneath.
    return SplitScreenCellClip(
      shape: shape,
      child: Semantics(
        button: onTap != null,
        selected: onTap != null && (hasSound || isSelected),
        label: onTap == null ? null : tapLabel,
        child: GestureDetector(onTap: onTap, child: content),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  /// The badge's size: its icon and the padding around it.
  static const size = Size.square(24);

  final DivineIconName icon;

  @override
  Widget build(BuildContext context) {
    // Fixed media chrome: the badge sits over footage.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: VineTheme.scrim50,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const .all(4),
          child: DivineIcon(icon: icon, size: 16, color: VineTheme.whiteText),
        ),
      ),
    );
  }
}

/// One line on where the room stands and what comes next.
class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CollabRoomCubit>().state;
    final room = state.room!;
    final myStatus = room.me?.status;
    final text = switch (room.phase) {
      CollabRoomPhase.posted => l10n.collabRoomPosted,
      CollabRoomPhase.cancelled => l10n.collabRoomCancelled,
      _ when myStatus == CollabRoomMemberStatus.declined =>
        l10n.collabRoomDeclinedYou,
      _ when myStatus != null && !myStatus.isActive =>
        l10n.collabRoomRemovedYou,
      CollabRoomPhase.lobby when room.isAuthor => l10n.collabRoomStartHint,
      CollabRoomPhase.lobby when myStatus == CollabRoomMemberStatus.invited =>
        l10n.collabRoomInviteCardBody,
      CollabRoomPhase.lobby => l10n.collabRoomWaitingForHost,
      CollabRoomPhase.recording when room.isAuthor && !state.layoutFits =>
        l10n.collabRoomPickNewLayout,
      CollabRoomPhase.recording
          when !room.parts.containsKey(room.ownerPubkey) =>
        l10n.collabRoomFilmHint,
      CollabRoomPhase.recording when room.isAuthor && !room.allPartsIn =>
        l10n.collabRoomComposeWaiting,
      CollabRoomPhase.recording when room.isAuthor => l10n.collabRoomSoundHint,
      CollabRoomPhase.recording => l10n.collabRoomPartSent,
    };
    return Text(
      text,
      textAlign: .center,
      style: VineTheme.bodyMediumFont(color: context.vineColors.secondaryText),
    );
  }
}

/// The layouts the host can pick: before filming, or once the people in the
/// room no longer fit the one picked.
class _LayoutChoices extends StatelessWidget {
  const _LayoutChoices();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollabRoomCubit>().state;
    final room = state.room!;
    final shows =
        room.isAuthor &&
        (room.phase == CollabRoomPhase.lobby ||
            (room.phase == CollabRoomPhase.recording && !state.layoutFits));
    final choices = state.layoutChoices;
    if (!shows || choices.isEmpty) return const SizedBox.shrink();
    final frame = room.phase == CollabRoomPhase.lobby
        ? state.aspectRatio
        : room.frameAspectRatio;
    final busy = state.actionStatus == CollabRoomActionStatus.busy;
    return Padding(
      padding: const .only(top: 16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          if (room.phase == CollabRoomPhase.lobby)
            Padding(
              padding: _sides,
              child: Text(
                context.l10n.collabRoomSwapSeatHint,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
          Padding(
            padding: _sides,
            child: Text(
              context.l10n.collabRoomPickLayout,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
          SizedBox(
            height: SplitScreenPresetPicker.tileHeight,
            child: ListView.separated(
              scrollDirection: .horizontal,
              padding: _sides,
              itemCount: choices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final preset = choices[index];
                return SplitScreenPresetTile(
                  preset: preset,
                  frameAspectRatio: frame.value,
                  isSelected:
                      preset ==
                      (room.phase == CollabRoomPhase.lobby
                          ? state.layout
                          : null),
                  // A lobby pick shows at once and is sent with the lobby's
                  // next message; only a pick while filming waits its turn.
                  onTap: busy && room.phase != CollabRoomPhase.lobby
                      ? () {}
                      : () => context.read<CollabRoomCubit>().layoutPicked(
                          preset,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Everyone the room was opened to, with where they stand.
class _Members extends StatelessWidget {
  const _Members();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollabRoomCubit>().state;
    final room = state.room!;
    return Column(
      spacing: 8,
      children: [
        for (final member in room.members)
          _MemberRow(
            member: member,
            room: room,
            canRemove:
                room.isAuthor &&
                room.phase.isOpen &&
                member.pubkey != room.authorPubkey &&
                member.status.isActive &&
                state.actionStatus != CollabRoomActionStatus.busy,
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.room,
    required this.canRemove,
  });

  final CollabRoomMember member;
  final CollabRoom room;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final status = room.parts.containsKey(member.pubkey)
        ? l10n.collabRoomStatusPartIn
        : switch (member.status) {
            CollabRoomMemberStatus.invited => l10n.collabRoomStatusInvited,
            CollabRoomMemberStatus.joined => l10n.collabRoomStatusJoined,
            CollabRoomMemberStatus.declined => l10n.collabRoomStatusDeclined,
            CollabRoomMemberStatus.left => l10n.collabRoomStatusLeft,
            CollabRoomMemberStatus.removed => l10n.collabRoomStatusRemoved,
          };
    final role = [
      if (member.pubkey == room.ownerPubkey) l10n.collabRoomYou,
      if (member.pubkey == room.authorPubkey) l10n.collabRoomHost,
    ].join(' · ');
    return Row(
      spacing: 12,
      children: [
        ExcludeSemantics(
          child: CollabRoomAvatar(pubkey: member.pubkey, size: 36),
        ),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                UserName.fromPubKey(
                  member.pubkey,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: VineTheme.titleSmallFont(color: colors.primaryText),
                ),
                Text(
                  [if (role.isNotEmpty) role, status].join(' · '),
                  style: VineTheme.bodySmallFont(color: colors.secondaryText),
                ),
              ],
            ),
          ),
        ),
        if (canRemove)
          DivineButton(
            label: l10n.collabRoomRemoveMember,
            type: DivineButtonType.ghostSecondary,
            size: DivineButtonSize.small,
            onPressed: () =>
                context.read<CollabRoomCubit>().removeMember(member.pubkey),
          ),
      ],
    );
  }
}

/// The buttons for the next step, by role and phase.
class _Actions extends ConsumerWidget {
  const _Actions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = context.watch<CollabRoomCubit>().state;
    final room = state.room!;
    final cubit = context.read<CollabRoomCubit>();
    final busy = state.actionStatus == CollabRoomActionStatus.busy;
    final myStatus = room.me?.status;
    if (!room.phase.isOpen ||
        (!room.isAuthor && !(myStatus?.isActive ?? false))) {
      return const SizedBox.shrink();
    }
    final hasCell = room.cellAspectRatioOf(room.ownerPubkey) != null;
    final filming = room.phase == CollabRoomPhase.recording;
    final hasOwnPart = room.parts.containsKey(room.ownerPubkey);
    final composing = state.composeStatus == CollabRoomComposeStatus.running;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        if (!room.isAuthor && myStatus == CollabRoomMemberStatus.invited) ...[
          DivineButton(
            label: l10n.collabRoomJoinButton,
            isLoading: busy && state.action == CollabRoomAction.join,
            onPressed: busy ? null : cubit.join,
          ),
          DivineButton(
            label: l10n.commonNotNow,
            type: DivineButtonType.secondary,
            onPressed: busy ? null : cubit.decline,
          ),
        ],
        if (room.isAuthor && room.phase == CollabRoomPhase.lobby)
          DivineButton(
            label: l10n.collabRoomStartButton,
            isLoading: busy && state.action == CollabRoomAction.start,
            onPressed: state.canStart ? cubit.start : null,
          ),
        if (filming && hasCell)
          DivineButton(
            label: hasOwnPart
                ? l10n.collabRoomRefilmPartButton
                : l10n.collabRoomFilmPartButton,
            leadingIcon: DivineIconName.videoCamera,
            type: hasOwnPart || room.isAuthor
                ? DivineButtonType.secondary
                : DivineButtonType.primary,
            onPressed: composing ? null : () => _filmPart(context, ref, room),
          ),
        if (room.isAuthor && filming)
          DivineButton(
            label: composing
                ? l10n.collabRoomComposing
                : l10n.collabRoomComposeButton,
            isLoading: composing,
            onPressed: state.canCompose ? cubit.compose : null,
          ),
        if (!room.isAuthor && myStatus == CollabRoomMemberStatus.joined)
          DivineButton(
            label: l10n.collabRoomLeaveButton,
            type: DivineButtonType.tertiary,
            onPressed: busy ? null : cubit.leave,
          ),
        if (room.isAuthor)
          DivineButton(
            label: l10n.collabRoomCancelButton,
            type: DivineButtonType.ghostSecondary,
            onPressed: busy || composing ? null : () => _confirmCancel(context),
          ),
      ],
    );
  }

  /// Films the part with the call paused: the camera and microphone belong
  /// to the recorder meanwhile.
  Future<void> _filmPart(
    BuildContext context,
    WidgetRef ref,
    CollabRoom room,
  ) async {
    final call = context.read<CollabRoomCallCubit?>();
    await call?.leave();
    if (!context.mounted) return;
    await openCollabRoomPartRecorder(context, ref, room);
    if (call != null && !call.isClosed) await call.join();
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final cubit = context.read<CollabRoomCubit>();
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    await VineBottomSheetPrompt.show(
      context: context,
      sticker: DivineStickerName.stopSign,
      title: l10n.collabRoomCancelConfirmTitle,
      subtitle: l10n.collabRoomCancelConfirmBody,
      primaryButtonText: l10n.collabRoomCancelButton,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () {
        navigator.pop();
        runDetached(
          cubit.cancel(),
          'call off the collab room',
          logName: 'CollabRoomView',
          category: LogCategory.video,
        );
      },
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: navigator.pop,
    );
  }
}
