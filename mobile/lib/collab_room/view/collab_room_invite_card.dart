// ABOUTME: The chat card of an invite into a collaborative room: join or
// ABOUTME: turn it down, or open the room once you are in

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/widgets/collab_room_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/collab_room_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// The card an invite into [roomId] shows in a chat.
class CollabRoomInviteCard extends ConsumerWidget {
  /// Creates the card; [isSent] when the account sent the invite.
  const CollabRoomInviteCard({
    required this.roomId,
    required this.isSent,
    super.key,
  });

  /// The room the invite is for.
  final String roomId;

  /// Whether the account sent the invite.
  final bool isSent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(collabRoomServiceProvider);
    return BlocProvider(
      key: ValueKey((service, roomId)),
      create: (_) => CollabRoomCubit(
        service: service,
        roomId: roomId,
        keepsRoomInSync: false,
      ),
      child: _InviteCardView(isSent: isSent),
    );
  }
}

class _InviteCardView extends StatelessWidget {
  const _InviteCardView({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final room = context.select((CollabRoomCubit c) => c.state.room);
    return BlocListener<CollabRoomCubit, CollabRoomState>(
      // Joining from the card goes straight into the room.
      listenWhen: (previous, current) =>
          previous.action == CollabRoomAction.join &&
          previous.actionStatus == CollabRoomActionStatus.busy &&
          current.actionStatus == CollabRoomActionStatus.idle,
      listener: (context, state) => _openRoom(context, state.room!.id),
      child: Align(
        alignment: isSent
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const .symmetric(horizontal: 16, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          padding: const .all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            border: .all(color: colors.outlineMuted),
            borderRadius: .circular(16),
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 12,
            children: [
              if (room != null)
                ExcludeSemantics(
                  child: Row(
                    spacing: 4,
                    children: [
                      for (final member in room.members.where(
                        (m) => m.status.isActive,
                      ))
                        CollabRoomAvatar(pubkey: member.pubkey, size: 28),
                    ],
                  ),
                ),
              Text(
                l10n.collabRoomInviteCardTitle,
                style: VineTheme.titleMediumFont(color: colors.primaryText),
              ),
              Text(
                switch (room?.phase) {
                  CollabRoomPhase.posted => l10n.collabRoomPosted,
                  CollabRoomPhase.cancelled => l10n.collabRoomCancelled,
                  _ => l10n.collabRoomInviteCardBody,
                },
                style: VineTheme.bodyMediumFont(color: colors.onSurfaceVariant),
              ),
              if (room != null) _CardActions(room: room),
            ],
          ),
        ),
      ),
    );
  }

  static void _openRoom(BuildContext context, String roomId) => runDetached(
    CollabRoomRouteData(roomId: roomId).push<void>(context),
    'open the collab room from its invite',
    logName: 'CollabRoomInviteCard',
    category: LogCategory.video,
  );
}

class _CardActions extends StatelessWidget {
  const _CardActions({required this.room});

  final CollabRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CollabRoomCubit>();
    final busy = context.select(
      (CollabRoomCubit c) =>
          c.state.actionStatus == CollabRoomActionStatus.busy,
    );
    final myStatus = room.me?.status;
    if (!room.phase.isOpen) return const SizedBox.shrink();
    if (!room.isAuthor &&
        myStatus == CollabRoomMemberStatus.invited &&
        room.phase == CollabRoomPhase.lobby) {
      return Row(
        spacing: 8,
        children: [
          Expanded(
            child: DivineButton(
              label: l10n.collabRoomJoinButton,
              size: DivineButtonSize.small,
              isLoading: busy,
              onPressed: busy ? null : cubit.join,
            ),
          ),
          Expanded(
            child: DivineButton(
              label: l10n.commonNotNow,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: busy ? null : cubit.decline,
            ),
          ),
        ],
      );
    }
    if (!room.isAuthor && !(myStatus?.isActive ?? false)) {
      return const SizedBox.shrink();
    }
    return DivineButton(
      label: l10n.collabRoomOpenButton,
      type: DivineButtonType.secondary,
      size: DivineButtonSize.small,
      onPressed: () => _InviteCardView._openRoom(context, room.id),
    );
  }
}
