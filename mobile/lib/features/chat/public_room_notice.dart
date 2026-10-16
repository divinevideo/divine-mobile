// ABOUTME: Shared public-test-room disclosure in the room list and conversation.
// ABOUTME: Keeps the privacy boundary visible using Divine's adaptive surfaces.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class PublicRoomNotice extends StatelessWidget {
  const PublicRoomNotice({super.key});

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
            context.l10n.messagesPublicTestDisclosure,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
