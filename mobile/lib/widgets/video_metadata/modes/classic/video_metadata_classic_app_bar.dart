// ABOUTME: Custom header widget for video metadata screen with
// ABOUTME: configurable leading widget and consistent styling (no AppBar)

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';

/// A custom header widget for video metadata screens.
/// Unlike AppBar, this provides full control over layout and positioning.
class VideoMetadataClassicAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates a custom header for video metadata screens.
  const VideoMetadataClassicAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: kToolbarHeight,
        padding: const .symmetric(horizontal: 16),
        child: Row(
          spacing: 16,
          children: [
            Hero(
              tag: VideoEditorConstants.heroBackButtonId,
              child: DivineIconButton(
                icon: .caretLeft,
                type: .ghostSecondary,
                size: .small,
                semanticLabel:
                    context.l10n.videoMetadataClosePostDetailsSemanticLabel,
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .stretch,
                mainAxisAlignment: .center,
                mainAxisSize: .min,
                children: [
                  Text(
                    context.l10n.videoMetadataShareTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                  Text(
                    context.l10n.videoMetadataVideoDetailsSubtitle,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
