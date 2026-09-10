// ABOUTME: List of soft-deleted clips with restore and delete-now actions.
// ABOUTME: Backs the clip library's Deleted filter.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/constants/clip_library_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Clips that have been soft-deleted and are awaiting the 30-day auto-purge.
///
/// The user can restore a clip back to the library or delete it now to skip
/// the retention window. Reads [ClipsLibraryState.trashedClips]; the Deleted
/// filter loads them.
class TrashedClipsList extends StatelessWidget {
  const TrashedClipsList({this.scrollController, super.key});

  /// Optional scroll controller, e.g. from a parent bottom sheet.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      buildWhen: (prev, curr) =>
          prev.trashedClips != curr.trashedClips || prev.status != curr.status,
      builder: (context, state) {
        if (state.status == ClipsLibraryStatus.trashLoading &&
            state.trashedClips.isEmpty) {
          return const Center(child: BrandedLoadingIndicator(size: 60));
        }
        if (state.trashedClips.isEmpty) {
          return EmptyLibraryState(
            icon: DivineIconName.trash,
            title: context.l10n.libraryTrashEmptyTitle,
            subtitle: context.l10n.libraryTrashEmptySubtitle,
            showRecordButton: false,
            scrollController: scrollController,
          );
        }
        return ListView.separated(
          controller: scrollController,
          padding: .fromLTRB(
            8,
            8,
            8,
            MediaQuery.viewPaddingOf(context).bottom + 8,
          ),
          itemCount: state.trashedClips.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _TrashedClipTile(clip: state.trashedClips[index]),
        );
      },
    );
  }
}

class _TrashedClipTile extends StatelessWidget {
  const _TrashedClipTile({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        horizontalTitleGap: 12,
        minLeadingWidth: 56,
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: VideoClipThumbnailCard(
              clip: clip,
              showSelectionIndicator: false,
              showDurationBadge: false,
            ),
          ),
        ),
        title: Text(
          context.l10n.libraryClipDuration(clip.duration.toFormattedSeconds()),
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        subtitle: Text(
          context.l10n.libraryTrashAutoDeletes(_daysUntilPurge(clip)),
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            DivineIconButton(
              icon: .arrowCounterClockwise,
              size: DivineIconButtonSize.small,
              type: DivineIconButtonType.secondary,
              tooltip: context.l10n.libraryTrashRestoreLabel,
              semanticLabel: context.l10n.libraryTrashRestoreLabel,
              onPressed: () => context.read<ClipsLibraryBloc>().add(
                ClipsLibraryRestoreClips({clip.id}),
              ),
            ),
            DivineIconButton(
              icon: .trash,
              size: DivineIconButtonSize.small,
              type: DivineIconButtonType.error,
              tooltip: context.l10n.libraryTrashDeleteNowLabel,
              semanticLabel: context.l10n.libraryTrashDeleteNowLabel,
              onPressed: () => _confirmHardDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Whole days remaining until the 30-day purge sweep hard-deletes
  /// [clip]. Returns 0 for clips already past the cutoff (the next purge
  /// run will catch them). Trashed rows are expected to carry `deletedAt`;
  /// debug builds assert that invariant and release builds degrade to 0.
  int _daysUntilPurge(DivineVideoClip clip) {
    final deletedAt = clip.deletedAt;
    assert(deletedAt != null, 'Trashed clip must have deletedAt');
    if (deletedAt == null) return 0;
    final cutoff = deletedAt.add(ClipLibraryConstants.trashRetention);
    final remaining = cutoff.difference(DateTime.now());
    if (remaining <= Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  Future<void> _confirmHardDelete(BuildContext context) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryTrashDeleteConfirmTitle,
      subtitle: context.l10n.libraryTrashDeleteConfirmMessage,
      additionalText: context.l10n.libraryDeleteClipsWarning,
      primaryButtonText: context.l10n.libraryDeleteConfirm,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<ClipsLibraryBloc>().add(ClipsLibraryHardDeleteClip(clip));
  }
}
