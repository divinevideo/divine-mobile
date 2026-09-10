// ABOUTME: Confirmation sheet for taking one recipient's badge award back,
// ABOUTME: spelling out what a NIP-09 deletion request can and cannot reach.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Asks the badge issuer to confirm taking an award back from one recipient.
///
/// [isViewer] switches the body: taking a badge back from yourself also takes
/// your own pin down, which the general copy cannot promise because anyone
/// else's profile badge list is their event, not ours.
///
/// Resolves to `true` only when the user confirms; dismissing the sheet
/// resolves to `null`.
Future<bool?> showBadgeRevokeConfirmation(
  BuildContext context, {
  required bool isViewer,
}) {
  final l10n = context.l10n;
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: l10n.badgeDetailRevokeTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              isViewer
                  ? l10n.badgeDetailRevokeSelfBody
                  : l10n.badgeDetailRevokeBody,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DivineButton(
                    label: l10n.commonCancel,
                    type: DivineButtonType.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: l10n.badgeDetailRevokeConfirm,
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
