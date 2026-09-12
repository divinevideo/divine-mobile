import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/gallery_save_utils.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
/// Handles shared gallery-save logic for both actions (DRY).
class VideoMetadataCaptureBottomBar extends ConsumerWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataCaptureBottomBar({super.key});

  void _showStatusSnackBar(
    BuildContext context, {
    required String label,
    required bool error,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: DivineSnackbarContainer(
          label: label,
          error: error,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed != null
              ? () {
                  onActionPressed();
                  scaffoldMessenger.hideCurrentSnackBar();
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _onSaveForLater(BuildContext context, WidgetRef ref) async {
    // Gallery save runs first, before the alreadyInProgress guard below: the
    // Save-for-later button is disabled while a draft save is in flight, so a
    // concurrent tap landing here is a narrow race, not the common path.
    await saveToGallery(context, ref);

    final notifier = ref.read(videoEditorProvider.notifier);

    final outcome = await notifier.saveAsDraft(enforceCreateNewDraft: true);

    // A save was already in flight (the button is normally disabled
    // meanwhile); there's nothing to report or navigate.
    if (outcome == DraftSaveOutcome.alreadyInProgress) return;
    if (!context.mounted) return;

    final draftSaved = outcome == DraftSaveOutcome.saved;
    final router = GoRouter.of(context);

    _showStatusSnackBar(
      context,
      label: draftSaved
          ? context.l10n.videoMetadataSavedToLibrarySnackbar
          : context.l10n.videoMetadataFailedToSaveSnackbar,
      error: !draftSaved,
      actionLabel: context.l10n.videoMetadataGoToLibraryButton,
      onActionPressed: () => router.push(LibraryScreen.draftsPath),
    );

    if (draftSaved) {
      // The draft is written, so a render still in flight has nothing left to
      // contribute — the reopened draft renders again. Dropping it here rather
      // than before the save keeps a failed save from stranding the user on a
      // screen whose preview waits forever on a render that no longer exists.
      // Cancelling bumps the render generation synchronously, and that is what
      // makes the late completion discard itself instead of running
      // autosaveChanges() and rewriting the autosave row saveAsDraft just
      // removed; awaiting it would mean waiting for the very render the user is
      // walking away from.
      unawaited(notifier.cancelRenderVideo());
      router.go(VideoFeedPage.pathForIndex(0));
      // Clear editor state after navigation animation completes (~600ms)
      Future.delayed(
        const Duration(milliseconds: 600),
        ref.read(videoPublishProvider.notifier).clearAll,
      );
    }
  }

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
        child: Row(
          crossAxisAlignment: .end,
          spacing: 10,
          children: [
            Expanded(
              child: _SaveForLaterButton(
                onTap: () => _onSaveForLater(context, ref),
              ),
            ),
            Expanded(child: _PostButton(onTap: () => _onPost(context, ref))),
          ],
        ),
      ),
    );
  }
}

/// Outlined button to save the video to drafts and gallery without publishing.
class _SaveForLaterButton extends ConsumerWidget {
  /// Creates a save for later button.
  const _SaveForLaterButton({required this.onTap});

  /// Called when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deliberately not gated on isProcessing: saving a draft needs no rendered
    // file, and the render can take minutes when its C2PA signing step has no
    // network to reach. Only a save already in flight disables the button.
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          isSavingDraft: s.isSavingDraft,
          hasRenderedClip: s.finalRenderedClip != null,
        ),
      ),
    );
    final isSaving = state.isSavingDraft;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: !isSaving ? 1 : 0.32,
      child: Semantics(
        identifier: 'save_for_later_button',
        label: context.l10n.videoMetadataSaveForLaterSemanticLabel,
        hint: isSaving
            ? context.l10n.videoMetadataSavingVideoHint
            : !state.hasRenderedClip
            // The gallery copy is made from the rendered file, so it is skipped
            // exactly when that file is missing — mid-render, and after a
            // render that failed. isProcessing is the wrong signal for it: a
            // C2PA re-sign sets it over an already-rendered clip, and there the
            // copy does happen.
            ? context.l10n.videoMetadataSaveToDraftsWithoutGalleryHint(
                GallerySaveService.destinationName,
              )
            : context.l10n.videoMetadataSaveToDraftsHint(
                GallerySaveService.destinationName,
              ),
        button: true,
        excludeSemantics: true,
        enabled: !isSaving,
        onTap: isSaving ? null : onTap,
        child: DivineButton(
          onPressed: isSaving ? null : onTap,
          type: .secondary,
          label: context.l10n.videoMetadataSaveForLaterButton,
        ),
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
        hint: isValidToPost
            ? context.l10n.videoMetadataPublishVideoHint
            : context.l10n.videoMetadataFormNotReadyHint,
        button: true,
        enabled: isValidToPost,
        excludeSemantics: true,
        onTap: isValidToPost ? onTap : null,
        child: DivineButton(
          onPressed: isValidToPost ? onTap : null,
          expanded: true,
          label: context.l10n.videoMetadataPostButton,
        ),
      ),
    );
  }
}
