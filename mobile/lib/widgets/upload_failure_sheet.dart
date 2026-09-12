// ABOUTME: Bottom sheet shown when a background video upload fails.
// ABOUTME: Displays error reason with recovery and save-to-drafts actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/publish_error_kind_l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

/// Shows a bottom sheet when a background upload fails.
///
/// Offers retry for transient failures, or Account status for a confirmed
/// restriction. Saving to drafts is always available:
/// - **Try Again** retries via [BackgroundPublishRetryRequested].
/// - **Account status** removes the terminal upload and explains the restriction.
/// - **Save to Drafts** removes the upload from the active queue while the
///   draft remains in the library for later publishing.
///
/// Dismissing the sheet without choosing an action has the same effect as
/// saving to drafts.
Future<void> showUploadFailureSheet(
  BuildContext context,
  BackgroundUpload upload,
) async {
  final result = await VineBottomSheet.show<String>(
    context: context,
    scrollable: false,
    isDismissible: false,
    enableDrag: false,
    children: [
      _UploadFailureSheetContent(
        upload: upload,
        onRetry: () => Navigator.of(context).pop('retry'),
        onAccountStatus: () => Navigator.of(context).pop('account_status'),
        onSaveToDrafts: () => Navigator.of(context).pop('save_drafts'),
      ),
    ],
  );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);

  switch (result) {
    case 'retry':
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishRetryRequested(draftId: upload.draft.id),
      );
      messenger?.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.uploadFailureSheetRetryingSnackbar,
        ),
      );
    case 'save_drafts':
      // Explicit save: remove from queue, draft stays in library
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishVanished(draftId: upload.draft.id),
      );
      messenger?.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.uploadFailureSheetSavedToDraftsSnackbar,
          actionLabel: context.l10n.contentWarningView,
          onActionPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.push(LibraryScreen.draftsPath);
          },
        ),
      );
    case 'account_status':
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishVanished(draftId: upload.draft.id),
      );
      messenger?.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.uploadFailureSheetSavedToDraftsSnackbar,
          actionLabel: context.l10n.contentWarningView,
          onActionPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.push(LibraryScreen.draftsPath);
          },
        ),
      );
      context.push(RoutePaths.accountStatus, extra: true);
    case _:
      // Sheet was popped externally (e.g. during route transition).
      // Save to drafts silently so the user's content is preserved.
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishVanished(draftId: upload.draft.id),
      );
  }
}

class _UploadFailureSheetContent extends StatelessWidget {
  const _UploadFailureSheetContent({
    required this.upload,
    required this.onRetry,
    required this.onAccountStatus,
    required this.onSaveToDrafts,
  });

  final BackgroundUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onAccountStatus;
  final VoidCallback onSaveToDrafts;

  @override
  Widget build(BuildContext context) {
    final errorMessage = switch (upload.result) {
      PublishError(:final kind, :final serverName, :final rawFallback) =>
        rawFallback ??
            context.l10n.publishErrorMessage(kind, serverName: serverName),
      _ => null,
    };

    final draft = upload.draft;
    final isAccountRestricted = switch (upload.result) {
      PublishError(kind: PublishErrorKind.accountRestricted) => true,
      _ => false,
    };
    final clip = draft.clips.isNotEmpty ? draft.clips.first : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _DraftPreview(clip: clip),

            const SizedBox(height: 16),
            Text(
              context.l10n.uploadFailureSheetTitle,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
                textAlign: .center,
              ),
            ],

            const SizedBox(height: 32),
            DivineButton(
              expanded: true,
              label: isAccountRestricted
                  ? context.l10n.uploadFailureSheetAccountStatusButton
                  : context.l10n.uploadFailureSheetTryAgainButton,
              onPressed: isAccountRestricted ? onAccountStatus : onRetry,
            ),

            const SizedBox(height: 12),
            DivineButton(
              expanded: true,
              type: .secondary,
              label: context.l10n.uploadFailureSheetSaveToDraftsButton,
              onPressed: onSaveToDrafts,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({this.clip});

  final DivineVideoClip? clip;

  void _openPreview(BuildContext context) {
    final currentClip = clip;
    if (currentClip == null) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            VideoMetadataPreviewScreen(clip: currentClip, previewOnly: true),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const previewHeight = 160.0;
    final path = clip?.thumbnailPath;
    final aspectRatio = clip?.targetAspectRatio.value ?? 9 / 16;
    final previewWidth = previewHeight * aspectRatio;
    final placeholder = SvgPicture.asset(
      'assets/stickers/alert.svg',
      height: 132,
      width: 132,
    );

    return GestureDetector(
      onTap: path != null ? () => _openPreview(context) : null,
      child: ClipRRect(
        borderRadius: .circular(12),
        child: SizedBox(
          height: previewHeight,
          width: previewWidth,
          child: path != null
              ? ClipThumbnailImage(
                  path: path,
                  fit: BoxFit.cover,
                  placeholder: placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}
