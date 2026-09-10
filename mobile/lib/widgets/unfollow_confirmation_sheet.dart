// ABOUTME: Shared unfollow confirmation bottom sheet used across the app
// ABOUTME: Shows Cancel/Unfollow buttons and returns true if user confirms

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shows a confirmation bottom sheet for unfollowing a user.
///
/// Returns `true` if the user confirmed the unfollow, `false` or `null`
/// if cancelled (including tapping outside the sheet).
Future<bool?> showUnfollowConfirmation(
  BuildContext context, {
  required String displayName,
}) {
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: 'Unfollow $displayName?',
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: context.vineColors.surfaceContainer,
                  foregroundColor: context.vineColors.accentPositive,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  side: BorderSide(
                    color: context.vineColors.outlineMuted,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  context.l10n.commonCancel,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.accentPositive,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  context.l10n.unfollowConfirmButton,
                  style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
