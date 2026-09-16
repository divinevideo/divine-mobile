// ABOUTME: Shared edit/pin/delete action sheet for a video the viewer owns.
// ABOUTME: Used by the profile grid and the composable (mixed-owner) grid.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/delete_result_localization.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';

/// The Pin/Unpin entry the owner's profile grid adds to the sheet.
///
/// Only the profile grid offers it: pins live on the profile, so a video
/// reached through a list or search has nowhere to be pinned to. The values
/// are a snapshot of the feed state at the moment the sheet opens; the sheet
/// closes on tap and the outcome arrives as a snackbar, so it never needs to
/// track them live.
class OwnerVideoPinAction {
  const OwnerVideoPinAction({
    required this.isPinned,
    required this.isBusy,
    required this.onTap,
  });

  /// The video is on the owner's pin list, so the entry reads Unpin.
  final bool isPinned;

  /// A pin mutation is already in flight; the entry is disabled.
  final bool isBusy;

  /// Runs after the sheet is dismissed.
  final VoidCallback onTap;
}

enum _OwnerVideoAction { edit, pin, delete }

/// Shows the edit/pin/delete actions for a video the signed-in viewer owns.
///
/// Callers are responsible for deciding ownership: this sheet is the
/// presentation of an action set, not a permission check. Both grids gate the
/// long-press affordance per tile so a non-owner never reaches here.
///
/// The sheet closes on any tap and the chosen action runs afterwards, so a
/// delete's confirmation dialog and outcome snackbar appear over the grid, not
/// over the sheet. While a delete is still in flight for this video every
/// entry is disabled; a later tap on Delete is refused by the cubit anyway.
///
/// [onEditRequested] runs after the sheet is dismissed. [onDeleted] runs after
/// a successful delete and before the confirmation snackbar, and exists because
/// the two surfaces differ: the profile grid refreshes its feed so the tile
/// disappears without waiting for relay propagation, while the mixed-owner
/// grids have no feed cubit to refresh. [pinAction] adds a Pin/Unpin entry
/// between the two.
Future<void> showOwnerVideoActionsSheet({
  required BuildContext context,
  required VideoEvent video,
  required OwnerVideoActionsCubit cubit,
  required VoidCallback onEditRequested,
  Future<void> Function()? onDeleted,
  OwnerVideoPinAction? pinAction,
}) async {
  final l10n = context.l10n;
  final isDeleting = cubit.isDeleteInProgress(video.id);
  _OwnerVideoAction? choice;

  await VineBottomSheetActionMenu.show(
    context: context,
    title: Text(
      l10n.videoGridOptionsTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    options: [
      VineBottomSheetActionData(
        iconPath: DivineIconName.pencilSimple.assetPath,
        label: l10n.videoGridEditVideo,
        onTap: isDeleting ? null : () => choice = _OwnerVideoAction.edit,
      ),
      if (pinAction != null)
        VineBottomSheetActionData(
          iconPath: DivineIconName.pushPin.assetPath,
          label: pinAction.isPinned
              ? l10n.videoGridUnpinVideo
              : l10n.videoGridPinVideo,
          onTap: isDeleting || pinAction.isBusy
              ? null
              : () => choice = _OwnerVideoAction.pin,
        ),
      VineBottomSheetActionData(
        iconPath: DivineIconName.trash.assetPath,
        label: l10n.videoGridDeleteVideo,
        isDestructive: true,
        onTap: isDeleting ? null : () => choice = _OwnerVideoAction.delete,
      ),
    ],
  );
  if (!context.mounted) return;

  switch (choice) {
    case _OwnerVideoAction.edit:
      onEditRequested();
    case _OwnerVideoAction.pin:
      pinAction!.onTap();
    case _OwnerVideoAction.delete:
      await _confirmAndDelete(
        context: context,
        video: video,
        cubit: cubit,
        onDeleted: onDeleted,
      );
    case null:
      return;
  }
}

/// Confirms, publishes the deletion, and reports the outcome.
///
/// Every surface reports through [DivineSnackbarContainer] with the same
/// localized copy, so a delete reads identically wherever it was started.
Future<void> _confirmAndDelete({
  required BuildContext context,
  required VideoEvent video,
  required OwnerVideoActionsCubit cubit,
  required Future<void> Function()? onDeleted,
}) async {
  final confirmed = await showOwnerVideoDeleteConfirmationDialog(context);
  if (!confirmed || !context.mounted) return;

  final start = await cubit.deleteVideo(video);
  if (start == OwnerVideoDeleteStart.busy) return;
  if (!context.mounted) return;

  final operation = cubit.state.forVideo(video.id);
  final messenger = ScaffoldMessenger.of(context);

  if (operation.deleteStatus != OwnerVideoDeleteStatus.success) {
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        operation.deleteResult == null
            ? context.l10n.shareMenuDeleteFailedGeneric
            : localizedDeleteFailureMessage(context, operation.deleteResult!),
        error: true,
      ),
    );
    return;
  }

  showOwnerVideoCleanupCompletion(context, cubit, video.id);
  await onDeleted?.call();
  if (!context.mounted) return;
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      localizedOwnerVideoDeleteSuccessMessage(context, operation),
      error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
    ),
  );
}
