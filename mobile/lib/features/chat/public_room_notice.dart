// ABOUTME: Shared public-room disclosure in the room list and conversation.
// ABOUTME: Keeps the privacy boundary visible using Divine's adaptive surfaces.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class PublicRoomNotice extends StatelessWidget {
  const PublicRoomNotice({this.isTest = true, super.key});
  final bool isTest;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.vineColors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DivineIcon(
          icon: DivineIconName.globe,
          size: 20,
          color: context.vineColors.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isTest
                ? context.l10n.messagesPublicTestDisclosure
                : context.l10n.messagesPublicRoomsDisclosure,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
