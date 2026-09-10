// ABOUTME: Shared confirmation dialog for deleting the signed-in user's video.
// ABOUTME: Keeps owner-delete confirmation copy and styling consistent.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';

Future<bool> showOwnerVideoDeleteConfirmationDialog(
  BuildContext context,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.vineColors.card,
      title: Text(
        dialogContext.l10n.shareMenuDeleteVideo,
        style: TextStyle(color: context.vineColors.primaryText),
      ),
      content: Text(
        dialogContext.l10n.shareMenuDeleteConfirmation,
        style: TextStyle(color: context.vineColors.primaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => dialogContext.popModalIfMounted(false),
          child: Text(dialogContext.l10n.shareMenuCancel),
        ),
        TextButton(
          onPressed: () => dialogContext.popModalIfMounted(true),
          style: TextButton.styleFrom(foregroundColor: VineTheme.error),
          child: Text(dialogContext.l10n.shareMenuDelete),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
