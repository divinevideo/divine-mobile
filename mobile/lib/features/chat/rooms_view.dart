// ABOUTME: Mobile-first channel list inside Messages, grouped by community.
// ABOUTME: Shows public-room context and clear full-row conversation targets.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/public_room_notice.dart';
import 'package:openvine/l10n/l10n.dart';

class RoomsView extends StatelessWidget {
  const RoomsView({
    required this.communities,
    required this.onRoomSelected,
    super.key,
  });

  final List<ChatCommunity> communities;
  final void Function(String communityId, String channelId) onRoomSelected;

  @override
  Widget build(BuildContext context) => Material(
    // The inbox paints a colored box above its ancestor Material. Keep the
    // channel rows on their own Material so their ink remains visible.
    type: MaterialType.transparency,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const PageStorageKey('messages-rooms'),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final community in communities) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    community.name,
                    style: VineTheme.titleLargeFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.messagesPublicTestRooms,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final channel in community.channels)
                DivineListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.vineColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '#',
                      style: VineTheme.titleLargeFont(
                        color: context.vineColors.accentPositive,
                      ),
                    ),
                  ),
                  title: channel,
                  subtitle: context.l10n.listVisibilityPublic,
                  onTap: () => onRoomSelected(community.id, channel),
                ),
            ],
            if (communities.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.messagesNoRooms),
              ),
            const PublicRoomNotice(),
          ],
        ),
      ),
    ),
  );
}
