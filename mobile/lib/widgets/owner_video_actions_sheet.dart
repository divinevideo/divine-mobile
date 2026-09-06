// ABOUTME: Shared edit/delete action sheet for a video the viewer owns.
// ABOUTME: Used by the profile grid and the composable (mixed-owner) grid.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/delete_result_localization.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';

/// Shows the edit/delete actions for a video the signed-in viewer owns.
///
/// Callers are responsible for deciding ownership: this sheet is the
/// presentation of an action set, not a permission check. Both grids gate the
/// long-press affordance per tile so a non-owner never reaches here.
///
/// [onEditRequested] runs after the sheet is dismissed. [onDeleted] runs after
/// a successful delete and before the confirmation snackbar, and exists because
/// the two surfaces differ: the profile grid refreshes its feed so the tile
/// disappears without waiting for relay propagation, while the mixed-owner
/// grids have no feed cubit to refresh.
Future<void> showOwnerVideoActionsSheet({
  required BuildContext context,
  required VideoEvent video,
  required OwnerVideoActionsCubit cubit,
  required VoidCallback onEditRequested,
  Future<void> Function()? onDeleted,
}) {
  return VineBottomSheet.show<void>(
    context: context,
    scrollable: false,
    expanded: false,
    title: Text(
      context.l10n.videoGridOptionsTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    body: Builder(
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<OwnerVideoActionsCubit, OwnerVideoActionsState>(
          builder: (_, state) {
            final operation = state.forVideo(video.id);
            return _OwnVideoActionsSheetBody(
              onEditVideo: () {
                if (cubit.isDeleteInProgress(video.id)) return;
                if (!sheetContext.popModalIfMounted()) return;
                onEditRequested();
              },
              onDeleteVideo: () => _confirmAndDelete(
                hostContext: context,
                sheetContext: sheetContext,
                video: video,
                cubit: cubit,
                onDeleted: onDeleted,
              ),
              isDeleting:
                  operation.deleteStatus == OwnerVideoDeleteStatus.deleting ||
                  operation.cleanupStatus == OwnerVideoCleanupStatus.inProgress,
            );
          },
        ),
      ),
    ),
  );
}

/// Confirms, publishes the deletion, and reports the outcome.
///
/// Every surface reports through [DivineSnackbarContainer] with the same
/// localized copy, so a delete reads identically wherever it was started.
Future<void> _confirmAndDelete({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required VideoEvent video,
  required OwnerVideoActionsCubit cubit,
  required Future<void> Function()? onDeleted,
}) async {
  final confirmed = await showOwnerVideoDeleteConfirmationDialog(hostContext);
  if (!confirmed || !hostContext.mounted) return;

  final start = await cubit.deleteVideo(video);
  if (start == OwnerVideoDeleteStart.busy) return;
  if (!hostContext.mounted) return;

  final operation = cubit.state.forVideo(video.id);
  final messenger = ScaffoldMessenger.of(hostContext);

  if (operation.deleteStatus != OwnerVideoDeleteStatus.success) {
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        operation.deleteResult == null
            ? hostContext.l10n.shareMenuDeleteFailedGeneric
            : localizedDeleteFailureMessage(
                hostContext,
                operation.deleteResult!,
              ),
        error: true,
      ),
    );
    return;
  }

  showOwnerVideoCleanupCompletion(hostContext, cubit, video.id);
  await onDeleted?.call();
  if (sheetContext.mounted) {
    sheetContext.popModalIfMounted();
  }
  if (!hostContext.mounted) return;
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      localizedOwnerVideoDeleteSuccessMessage(hostContext, operation),
      error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
    ),
  );
}

/// Edit/Delete actions shown when long-pressing an own video tile.
class _OwnVideoActionsSheetBody extends StatelessWidget {
  const _OwnVideoActionsSheetBody({
    required this.onEditVideo,
    required this.onDeleteVideo,
    required this.isDeleting,
  });

  final VoidCallback onEditVideo;
  final VoidCallback onDeleteVideo;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OwnVideoActionTile(
          icon: DivineIconName.pencilSimple,
          iconColor: context.vineColors.accentPositive,
          title: context.l10n.videoGridEditVideo,
          subtitle: context.l10n.videoGridEditVideoSubtitle,
          onTap: onEditVideo,
          isDisabled: isDeleting,
        ),
        _OwnVideoActionTile(
          icon: DivineIconName.trash,
          iconColor: VineTheme.error,
          title: context.l10n.videoGridDeleteVideo,
          subtitle: context.l10n.videoGridDeleteVideoSubtitle,
          onTap: onDeleteVideo,
          isBusy: isDeleting,
        ),
        SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 16),
      ],
    );
  }
}

class _OwnVideoActionTile extends StatelessWidget {
  const _OwnVideoActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isBusy = false,
    this.isDisabled = false,
  });

  final DivineIconName icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isBusy;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final actionColor = isDisabled
        ? context.vineColors.secondaryText
        : iconColor;
    // The sheet paints its own background; a transparent Material keeps
    // ListTile's ink effects visible without double-painting a surface.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        enabled: !isBusy && !isDisabled,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.vineColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isBusy
              ? const DivineCircularProgressIndicator(strokeWidth: 2)
              : DivineIcon(icon: icon, color: actionColor, size: 20),
        ),
        title: Text(
          title,
          style: VineTheme.titleMediumFont(
            color: isDisabled
                ? context.vineColors.secondaryText
                : context.vineColors.primaryText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        onTap: isBusy || isDisabled ? null : onTap,
      ),
    );
  }
}
