// ABOUTME: Confirmation view for unblocking a user
// ABOUTME: Shows explanation and cancel/unblock buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/more_sheet/bullet_point.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation view for unblocking a user.
class UnblockConfirmationView extends StatelessWidget {
  /// Creates an unblock confirmation view.
  const UnblockConfirmationView({
    required this.displayName,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// The display name of the user to unblock.
  final String displayName;

  /// Called when the cancel button is pressed.
  final VoidCallback onCancel;

  /// Called when the unblock button is pressed.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const ValueKey('unblock_confirmation'),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            context.l10n.profileUnblockTitle(displayName),
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Explanation content
          Text(
            context.l10n.profileUnblockExplanation,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            spacing: 14,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BulletPoint(context.l10n.profileUnblockBulletShowPosts),
              BulletPoint(context.l10n.profileUnblockBulletCanView),
              BulletPoint(context.l10n.profileUnblockBulletNoNotify),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://divine.video/safety')),
            child: Text.rich(
              TextSpan(
                text: context.l10n.profileLearnMoreAt,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: 'divine.video/safety',
                    style:
                        VineTheme.bodyLargeFont(
                          color: context.vineColors.onSurface,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: context.vineColors.accentPositive,
                          decorationThickness: 2,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Button row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: DivineButton(
                    label: context.l10n.profileCancelButton,
                    onPressed: onCancel,
                    type: DivineButtonType.secondary,
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: context.l10n.profileUnblockButton,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
