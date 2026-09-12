// ABOUTME: Confirmation view for blocking a user
// ABOUTME: Shows explanation and cancel/block buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/more_sheet/bullet_point.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation view for blocking a user.
class BlockConfirmationView extends StatelessWidget {
  /// Creates a block confirmation view.
  const BlockConfirmationView({
    required this.displayName,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// The display name of the user to block.
  final String displayName;

  /// Called when the cancel button is pressed.
  final VoidCallback onCancel;

  /// Called when the block button is pressed.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const ValueKey('confirmation'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineSticker(sticker: DivineStickerName.blocked),
          const SizedBox(height: 32),
          // Title
          Text(
            context.l10n.profileBlockTitle(displayName),
            style: VineTheme.titleLargeFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Explanation content
          Text(
            context.l10n.profileBlockExplanation,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              spacing: 14,
              children: [
                BulletPoint(context.l10n.profileBlockBulletHidePosts),
                BulletPoint(context.l10n.profileBlockBulletCantView),
                BulletPoint(context.l10n.profileBlockBulletNoNotify),
                BulletPoint(context.l10n.profileBlockBulletYouCanView),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Button row
          Column(
            spacing: 16,
            children: [
              DivineButton(
                label: context.l10n.profileBlockConfirmButton(displayName),
                onPressed: onConfirm,
                expanded: true,
                type: DivineButtonType.error,
              ),
              DivineButton(
                label: context.l10n.profileCancelButton,
                type: DivineButtonType.secondary,
                onPressed: onCancel,
                expanded: true,
              ),
              DivineButton(
                label: context.l10n.profileLearnMore,
                type: DivineButtonType.link,
                onPressed: () =>
                    launchUrl(Uri.parse('https://divine.video/safety')),
                expanded: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
