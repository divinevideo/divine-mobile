// ABOUTME: Custom header widget for video metadata screen with
// ABOUTME: configurable leading widget and consistent styling (no AppBar)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';

/// A custom header widget for video metadata screens.
/// Unlike AppBar, this provides full control over layout and positioning.
class VideoMetadataCaptureAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  /// Creates a custom header for video metadata screens.
  const VideoMetadataCaptureAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Opens the full-screen video preview with a fade transition.
  Future<void> _openPreview(BuildContext context, DivineVideoClip clip) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'video_metadata_preview'),
        pageBuilder: (_, _, _) => VideoMetadataPreviewScreen(clip: clip),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          isProcessing: s.isProcessing,
          finalRenderedClip: s.finalRenderedClip,
        ),
      ),
    );
    final isReady = state.finalRenderedClip != null && !state.isProcessing;

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
                type: .secondary,
                size: .small,
                semanticLabel:
                    context.l10n.videoMetadataClosePostDetailsSemanticLabel,
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: Text(
                context.l10n.videoMetadataPostDetailsTitle,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.onSurface,
                ),
              ),
            ),

            DivineIconButton(
              icon: .eye,
              type: .ghostSecondary,
              size: .small,
              semanticLabel: context.l10n.videoMetadataOpenPreviewSemanticLabel,
              onPressed: isReady
                  ? () => _openPreview(context, state.finalRenderedClip!)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
