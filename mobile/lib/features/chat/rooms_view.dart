// ABOUTME: Displays Concord POC channels grouped by community inside Messages.
// ABOUTME: Makes public test-room access explicit before opening a conversation.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
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
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('messages-rooms'),
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.messagesPublicTestRooms,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.messagesPublicTestDisclosure),
          ],
        ),
      ),
      if (communities.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.messagesNoRooms),
        ),
      for (final community in communities) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              community.name,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ),
        for (final channel in community.channels)
          ListTile(
            title: Text('#$channel'),
            subtitle: Text(context.l10n.listVisibilityPublic),
            onTap: () => onRoomSelected(community.id, channel),
          ),
      ],
    ],
  );
}
