import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/gallery_save_utils.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
/// Handles shared gallery-save logic for both actions (DRY).
class VideoMetadataClassicBottomBar extends ConsumerWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataClassicBottomBar({super.key});

  Future<void> _onPost(BuildContext context, WidgetRef ref) async {
    await saveToGallery(context, ref);
    if (!context.mounted) return;

    await ref.read(videoEditorProvider.notifier).postVideo(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Padding(
        padding: const .fromLTRB(16, 0, 16, 4),
        child: _PostButton(onTap: () => _onPost(context, ref)),
      ),
    );
  }
}

/// Filled button to publish the video to the feed.
class _PostButton extends ConsumerWidget {
  /// Creates a post button.
  const _PostButton({required this.onTap});

  /// Called when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    // Fade buttons when form is invalid
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isValidToPost ? 1 : 0.32,
      child: Semantics(
        identifier: 'post_button',
        label: context.l10n.videoMetadataPostSemanticLabel,
        hint: context.l10n.videoMetadataPublishVideoHint,
        button: true,
        enabled: isValidToPost,
        excludeSemantics: true,
        onTap: isValidToPost ? onTap : null,
        child: DivineButton(
          onPressed: isValidToPost ? onTap : null,
          expanded: true,
          label: context.l10n.videoMetadataClassicDoneButton,
        ),
      ),
    );
  }
}
