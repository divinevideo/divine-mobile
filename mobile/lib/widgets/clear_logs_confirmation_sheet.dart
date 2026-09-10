// ABOUTME: Confirmation bottom sheet shown before clearing the captured logs
// ABOUTME: Returns true if the user confirms, false/null if they back out

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shows a confirmation bottom sheet before clearing the in-memory log buffer.
///
/// Returns `true` if the user confirmed, `false` or `null` if they cancelled
/// (including tapping outside the sheet).
Future<bool?> showClearLogsConfirmation(BuildContext context) {
  final l10n = context.l10n;
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: l10n.supportClearLogsConfirmTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          spacing: 16,
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
                label: l10n.supportClearLogsConfirmButton,
                type: DivineButtonType.error,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
