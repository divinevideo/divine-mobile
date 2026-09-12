// ABOUTME: Confirmation sheet for deleting a badge, spelling out what a NIP-09
// ABOUTME: deletion request can and cannot reach.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Asks the badge owner to confirm deleting it.
///
/// Resolves to `true` only when the user confirms; dismissing the sheet
/// resolves to `null`.
Future<bool?> showBadgeDeleteConfirmation(BuildContext context) {
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: context.l10n.badgeDetailDeleteTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              context.l10n.badgeDetailDeleteBody,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DivineButton(
                    label: context.l10n.commonCancel,
                    type: DivineButtonType.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: context.l10n.badgeDetailDeleteConfirm,
                    type: DivineButtonType.error,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
