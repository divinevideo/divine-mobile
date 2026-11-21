// ABOUTME: The camera's Together tab: start a room with up to three friends,
// ABOUTME: or go back into a room you are already in

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_rooms_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/widgets/collab_room_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/router/routes/collab_room_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// The Together tab: explains the mode, invites friends into a new room, and
/// lists the rooms the account is still in.
class VideoRecorderTogetherStack extends ConsumerWidget {
  /// Creates the Together tab.
  const VideoRecorderTogetherStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(collabRoomServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => CollabRoomsCubit(service: service),
      child: const _TogetherView(),
    );
  }
}

class _TogetherView extends StatelessWidget {
  const _TogetherView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return BlocListener<CollabRoomsCubit, CollabRoomsState>(
      listenWhen: (previous, current) =>
          previous.createStatus != current.createStatus,
      listener: (context, state) {
        switch (state.createStatus) {
          case .created:
            runDetached(
              CollabRoomRouteData(
                roomId: state.createdRoomId!,
              ).push<void>(context),
              'open the new collab room',
              logName: 'VideoRecorderTogetherStack',
              category: LogCategory.video,
            );
          case .failed:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.collabRoomCreateFailed)),
            );
          case .idle:
          case .creating:
            break;
        }
      },
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const .symmetric(horizontal: 24, vertical: 32),
          children: [
            Text(
              l10n.collabRoomLobbyTitle,
              style: VineTheme.titleLargeFont(color: colors.primaryText),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.collabRoomLobbyBody,
              style: VineTheme.bodyMediumFont(color: colors.secondaryText),
            ),
            const SizedBox(height: 24),
            const _InviteButton(),
            const _RoomList(),
          ],
        ),
      ),
    );
  }
}

class _InviteButton extends ConsumerWidget {
  const _InviteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creating = context.select(
      (CollabRoomsCubit cubit) => cubit.state.createStatus == .creating,
    );
    return DivineButton(
      label: context.l10n.collabRoomLobbyInvite,
      leadingIcon: DivineIconName.userPlus,
      expanded: true,
      isLoading: creating,
      onPressed: creating ? null : () => _invite(context, ref),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final cubit = context.read<CollabRoomsCubit>();
    final picked = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: context.l10n.collabRoomInvitePickerTitle,
      maxCount: collabRoomMaxParticipants - 1,
      excludeViewerPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
    );
    if (picked == null || picked.isEmpty) return;
    await cubit.create([for (final profile in picked) profile.pubkey]);
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList();

  @override
  Widget build(BuildContext context) {
    final rooms = context.select((CollabRoomsCubit cubit) => cubit.state.rooms);
    if (rooms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const .only(top: 32),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Text(
            context.l10n.collabRoomLobbyRooms,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          for (final room in rooms) _RoomTile(room: room),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});

  final CollabRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final title = room.isAuthor
        ? l10n.collabRoomTileHosting
        : l10n.collabRoomTileGuest;
    final subtitle = switch (room.phase) {
      CollabRoomPhase.recording => l10n.collabRoomPhaseRecording,
      _ when room.isAuthor && room.participants.length > 1 =>
        l10n.collabRoomPhaseReady,
      _
          when !room.isAuthor &&
              room.me?.status == CollabRoomMemberStatus.joined =>
        l10n.collabRoomPhaseWaitingForHost,
      // The room waits for this guest, not for others.
      _
          when !room.isAuthor &&
              room.me?.status == CollabRoomMemberStatus.invited =>
        l10n.collabRoomPhaseInvited,
      _ => l10n.collabRoomPhaseLobby,
    };
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: colors.surfaceContainer,
          borderRadius: .circular(16),
          child: InkWell(
            borderRadius: .circular(16),
            onTap: () =>
                CollabRoomRouteData(roomId: room.id).push<void>(context),
            child: Padding(
              padding: const .all(12),
              child: Row(
                spacing: 12,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 64,
                      height: 32,
                      child: Stack(
                        children: [
                          for (final (index, member)
                              in room.members
                                  .where((m) => m.status.isActive)
                                  .take(collabRoomMaxParticipants)
                                  .indexed)
                            Positioned(
                              left: index * 10.0,
                              child: CollabRoomAvatar(
                                pubkey: member.pubkey,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          title,
                          style: VineTheme.titleSmallFont(
                            color: colors.primaryText,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: VineTheme.bodySmallFont(
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: colors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
