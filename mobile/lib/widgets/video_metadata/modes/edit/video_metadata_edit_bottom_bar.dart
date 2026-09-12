// ABOUTME: Bottom bar for the full-screen video metadata edit flow.
// ABOUTME: Handles update (re-publish with createdAt+1) and delete flows.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide AspectRatio;
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/video_metadata_update_error_l10n.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/utils/delete_result_localization.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';
import 'package:unified_logger/unified_logger.dart';

/// Bottom action bar for the video metadata edit screen.
///
/// Shows a "Delete" button (secondary) and an "Update" button (primary)
/// side by side, matching the capture bottom bar layout.
class VideoMetadataEditBottomBar extends ConsumerStatefulWidget {
  const VideoMetadataEditBottomBar({
    required this.video,
    required this.initialCollaboratorPubkeys,
    this.pendingThumbnailPath,
    this.onVideoUpdated,
    super.key,
  });

  final VideoEvent video;
  final Set<String> initialCollaboratorPubkeys;
  final String? pendingThumbnailPath;
  final ValueChanged<VideoEvent>? onVideoUpdated;

  @override
  ConsumerState<VideoMetadataEditBottomBar> createState() =>
      _VideoMetadataEditBottomBarState();
}

class _VideoMetadataEditBottomBarState
    extends ConsumerState<VideoMetadataEditBottomBar> {
  bool _isUpdating = false;
  bool _isDeleting = false;
  late final OwnerVideoActionsCubit _ownerVideoActionsCubit;

  @override
  void initState() {
    super.initState();
    _ownerVideoActionsCubit = OwnerVideoActionsCubit(
      contentDeletionService: () =>
          ref.read(contentDeletionServiceProvider.future),
      videoEventService: () => ref.read(videoEventServiceProvider),
      enforcementRepository: () =>
          ref.read(creatorDeleteEnforcementRepositoryProvider),
    );
  }

  @override
  void dispose() {
    _ownerVideoActionsCubit.close();
    super.dispose();
  }

  bool get _isBusy => _isUpdating || _isDeleting;

  Future<void> _editSubtitles() async {
    final updatedVideo = await context.push<VideoEvent>(
      SubtitleEditorScreen.pathFor(widget.video.id),
      extra: widget.video,
    );
    if (!mounted || updatedVideo == null) return;
    widget.onVideoUpdated?.call(updatedVideo);
  }

  Future<void> _updateVideo() async {
    if (_isBusy) return;
    setState(() => _isUpdating = true);

    try {
      final editorState = ref.read(videoEditorProvider);
      final service = ref.read(videoMetadataUpdateServiceProvider);
      final result = await service.updateVideo(
        originalVideo: widget.video,
        editorState: editorState,
        newThumbnailFile: widget.pendingThumbnailPath != null
            ? File(widget.pendingThumbnailPath!)
            : null,
        initialCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
      );

      if (result is VideoUpdateSuccess) {
        if (widget.pendingThumbnailPath != null) {
          File(widget.pendingThumbnailPath!).delete().ignore();
        }
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final snackBar = DivineSnackbarContainer.snackBar(
            result.inviteFailureCount == 0
                ? context.l10n.shareMenuVideoUpdated
                : context.l10n.shareMenuVideoUpdatedWithInviteFailures(
                    result.inviteFailureCount,
                  ),
            error: result.inviteFailureCount > 0,
          );
          context.pop();
          messenger.showSnackBar(snackBar);
        }
      } else if (result is VideoUpdateOriginalUnavailable) {
        _reportOriginalVideoUnavailable();
      } else if (result is VideoUpdateFailure) {
        _reportUpdateFailure(result.reason, result.reason.name);
      }
    } catch (e) {
      _reportUpdateFailure(VideoMetadataUpdateError.generic, e);
    }
  }

  void _reportOriginalVideoUnavailable() {
    if (!mounted) return;
    setState(() => _isUpdating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.shareMenuOriginalVideoUnavailable,
        error: true,
      ),
    );
  }

  void _reportUpdateFailure(VideoMetadataUpdateError reason, Object detail) {
    Log.error(
      'Failed to update video: $detail',
      name: 'VideoMetadataEditBottomBar',
      category: LogCategory.ui,
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.videoMetadataUpdateErrorMessage(reason),
        error: true,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_isBusy) return;
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: DivineStickerName.alert,
      title: context.l10n.shareMenuDeleteVideoQuestion,
      subtitle: context.l10n.shareMenuDeleteConfirmation,
      primaryButtonText: context.l10n.shareMenuDelete,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: context.l10n.shareMenuCancel,
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    // Guard against the edit surface being unmounted while the confirm sheet
    // is open (external navigation): _deleteVideo calls setState. Matches the
    // other owner-delete surfaces, which recheck mounted after their confirm.
    if (confirmed != true || !mounted) return;
    await _deleteVideo();
  }

  Future<void> _deleteVideo() async {
    if (_isBusy) return;
    setState(() => _isDeleting = true);

    try {
      final start = await _ownerVideoActionsCubit.deleteVideo(widget.video);
      if (start == OwnerVideoDeleteStart.busy) return;
      if (!mounted) return;
      final operation = _ownerVideoActionsCubit.state.forVideo(widget.video.id);

      if (operation.deleteStatus == OwnerVideoDeleteStatus.success) {
        showOwnerVideoCleanupCompletion(
          context,
          _ownerVideoActionsCubit,
          widget.video.id,
        );
        Log.info(
          'Video deleted successfully: ${widget.video.id}',
          name: 'VideoMetadataEditBottomBar',
          category: LogCategory.ui,
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final snackBar = DivineSnackbarContainer.snackBar(
            localizedOwnerVideoDeleteSuccessMessage(context, operation),
            error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
          );
          context.pop();
          messenger.showSnackBar(snackBar);
        }
      } else {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              operation.deleteResult == null
                  ? context.l10n.shareMenuDeleteFailedGeneric
                  : localizedDeleteFailureMessage(
                      context,
                      operation.deleteResult!,
                    ),
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to delete video: $e',
        name: 'VideoMetadataEditBottomBar',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareMenuDeleteFailedGeneric,
            error: true,
          ),
        );
      }
    } finally {
      if (mounted && _isDeleting) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            _EditSubtitlesButton(onTap: _editSubtitles, isBusy: _isBusy),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 10,
              children: [
                Expanded(
                  child: _DeleteButton(
                    onTap: _confirmDelete,
                    isBusy: _isBusy,
                    isDeleting: _isDeleting,
                  ),
                ),
                Expanded(
                  child: _UpdateButton(
                    onTap: _updateVideo,
                    isBusy: _isBusy,
                    isUpdating: _isUpdating,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width secondary button to open the subtitle editor.
class _EditSubtitlesButton extends StatelessWidget {
  const _EditSubtitlesButton({required this.onTap, required this.isBusy});

  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'edit_subtitles_button',
      child: DivineButton(
        onPressed: isBusy ? null : onTap,
        type: DivineButtonType.secondary,
        expanded: true,
        leadingIcon: DivineIconName.closedCaptioning,
        label: context.l10n.videoEditEditSubtitles,
      ),
    );
  }
}

/// Outlined button to delete the video.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.onTap,
    required this.isBusy,
    required this.isDeleting,
  });

  final VoidCallback onTap;
  final bool isBusy;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delete_button',
      child: DivineButton(
        onPressed: isBusy ? null : onTap,
        type: .error,
        label: context.l10n.shareMenuDeleteVideo,
        isLoading: isDeleting,
      ),
    );
  }
}

/// Filled button to publish the updated video metadata.
class _UpdateButton extends StatelessWidget {
  const _UpdateButton({
    required this.onTap,
    required this.isBusy,
    required this.isUpdating,
  });

  final VoidCallback onTap;
  final bool isBusy;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'update_button',
      child: DivineButton(
        onPressed: isBusy ? null : onTap,
        expanded: true,
        label: context.l10n.shareMenuUpdate,
        isLoading: isUpdating,
      ),
    );
  }
}
