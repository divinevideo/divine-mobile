// ABOUTME: Row items and handlers for the content actions both video sheets
// ABOUTME: offer; each sheet picks their order and adds its own actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_action_rules.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/owner_video_actions_sheet.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

void _runActionDetached(Future<void> operation, String description) {
  runDetached(
    operation,
    description,
    logName: 'VideoContentActionItems',
    category: LogCategory.ui,
  );
}

/// Closes the sheet owning [sheetContext], then opens the metadata editor for
/// the viewer's own [video].
///
/// Does nothing while [video] is being deleted.
Future<void> openOwnerVideoEditor(
  BuildContext sheetContext,
  VideoEvent video,
  OwnerVideoActionsCubit cubit,
) async {
  if (cubit.isDeleteInProgress(video.id)) return;
  await presentAfterSheetDismiss<void>(sheetContext, (hostContext) {
    return VideoMetadataEditRouteData(
      videoId: video.id,
      $extra: video,
    ).push<void>(hostContext);
  });
}

/// Closes the sheet owning [sheetContext], then opens the list picker for
/// [video].
Future<void> openAddToList(BuildContext sheetContext, VideoEvent video) {
  return presentAfterSheetDismiss<void>(
    sheetContext,
    (hostContext) => showSelectListSheet(hostContext, video: video),
  );
}

/// Confirms and deletes the viewer's own [video], closing the sheet owning
/// [sheetContext] before the outcome is reported, whether it succeeded or
/// failed: a snackbar raised while the sheet is open lands underneath it.
/// A route the user opened over the sheet meanwhile is left open, and the
/// outcome is then reported beneath it.
///
/// [sheetContext] must stay mounted for as long as the sheet is open: the
/// outcome is reported through it after the network round trip.
Future<void> deleteOwnerVideoFromSheet(
  BuildContext sheetContext,
  VideoEvent video,
  OwnerVideoActionsCubit cubit,
) {
  // Only while the sheet is on top: dismissing pops the top route, which by
  // then may be one the user opened over the sheet, such as an info sheet.
  Future<void> dismissIfCurrent() async {
    if (ModalRoute.of(sheetContext)?.isCurrent ?? true) {
      dismissSheet(sheetContext);
    }
  }

  return confirmAndDeleteOwnerVideo(
    context: sheetContext,
    video: video,
    cubit: cubit,
    onDeleted: dismissIfCurrent,
    onFailed: dismissIfCurrent,
  );
}

/// Opens the editor for the viewer's own video through [onEdit].
VideoActionRowItem editOwnerVideoActionItem(
  BuildContext context, {
  required Future<void> Function() onEdit,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.pencilSimpleLine,
    label: context.l10n.shareMenuEditVideo,
    onTap: () => _runActionDetached(onEdit(), 'open video metadata editor'),
  );
}

/// Deletes the viewer's own video through [onDelete].
///
/// Lock the row while [isDeletePending], as `VideoActionRow.isLocked`
/// describes, so no other row action closes the sheet before it reports.
VideoActionRowItem deleteOwnerVideoActionItem(
  BuildContext context, {
  required Future<void> Function() onDelete,
  required bool isDeletePending,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.trash,
    label: context.l10n.shareMenuDeleteVideo,
    onTap: () => _runActionDetached(onDelete(), 'delete own video'),
    isPending: isDeletePending,
  );
}

/// Toggles the video in the viewer's saved videos through [bloc].
///
/// An unknown bookmark status renders as "Save" (pass [isSaved] false): an
/// unresolved read must not claim the video is unsaved, and "Save" is the
/// pre-existing wording.
VideoActionRowItem saveVideoActionItem(
  BuildContext context, {
  required VideoContentActionsBloc bloc,
  required bool isSaved,
  required bool isPending,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.bookmarkSimple,
    label: isSaved
        ? context.l10n.shareSheetRemoveFromSaved
        : context.l10n.shareSheetSave,
    onTap: () => bloc.add(const VideoContentSaveRequested()),
    isPending: isPending,
  );
}

/// Closes the sheet owning [context], then opens the report flow for
/// [video], a remix of one of the viewer's videos, so they can ask Trust &
/// Safety to take it down.
VideoActionRowItem reportRemixActionItem(
  BuildContext context, {
  required VideoEvent video,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.flag,
    label: context.l10n.metadataReportRemix,
    onTap: () => _runActionDetached(
      presentAfterSheetDismiss<void>(
        context,
        (hostContext) => ReportContentDialog.show(hostContext, video: video),
      ),
      'report a remix',
    ),
  );
}

/// Asks for a clip title, then adds [video] to the viewer's clips, or null
/// when [canRemixVideo] does not allow it for this viewer, or on the web
/// ([isWeb]), where clip import is unavailable.
///
/// Shows as pending while the import runs. [context] must be the building
/// context of a widget below the sheet's [VideoContentActionsBloc]: the item
/// subscribes it to the import progress.
VideoActionRowItem? addToClipsActionItem(
  BuildContext context, {
  required VideoEvent video,
  required bool isOwnContent,
  bool isWeb = kIsWeb,
}) {
  if (isWeb || !canRemixVideo(video: video, isOwnContent: isOwnContent)) {
    return null;
  }
  final isImporting = context.select(
    (VideoContentActionsBloc bloc) => bloc.state.isImportingClip,
  );
  return VideoActionRowItem(
    icon: DivineIconName.filmSlate,
    label: context.l10n.shareSheetAddToClips,
    onTap: () =>
        _runActionDetached(requestAddToClips(context), 'request add to clips'),
    isPending: isImporting,
  );
}

/// Asks [bloc] for a remix of [video], which the sheet then opens in the
/// editor, or null when [canRemixVideo] does not allow it for this viewer.
///
/// Remixing needs the mobile editor, so on the web ([isWeb]) the tap closes
/// the sheet owning [context] and points to the app instead.
///
/// Shows as pending while the remix is prepared. [context] must be the
/// building context of a widget below the sheet's [VideoContentActionsBloc]:
/// the item subscribes it to the remix progress.
VideoActionRowItem? remixVideoActionItem(
  BuildContext context, {
  required VideoContentActionsBloc bloc,
  required VideoEvent video,
  required bool isOwnContent,
  bool isWeb = kIsWeb,
}) {
  if (!canRemixVideo(video: video, isOwnContent: isOwnContent)) return null;
  final isPreparing = context.select(
    (VideoContentActionsBloc actions) => actions.state.isPreparingRemix,
  );
  return VideoActionRowItem(
    icon: DivineIconName.filmSlate,
    label: context.l10n.metadataRemixAction,
    onTap: isWeb
        ? () => _showRemixAppNudge(context)
        : () => bloc.add(const VideoContentRemixRequested()),
    isPending: isPreparing,
  );
}

/// Closes the sheet owning [sheetContext] and says remixing happens in the
/// app, with an action opening the app download page.
void _showRemixAppNudge(BuildContext sheetContext) {
  final l10n = sheetContext.l10n;
  final messenger = ScaffoldMessenger.of(sheetContext);
  // A snackbar raised while the sheet is open lands underneath it.
  dismissSheet(sheetContext);
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      l10n.remixWebAppNudge,
      actionLabel: l10n.remixWebGetTheApp,
      onActionPressed: () => _runActionDetached(
        launchUrl(
          Uri.parse(AppConstants.downloadUrl),
          mode: LaunchMode.externalApplication,
        ),
        'open the app download page',
      ),
    ),
  );
}

/// Opens the list picker through [onAddToList].
VideoActionRowItem addToListActionItem(
  BuildContext context, {
  required Future<void> Function() onAddToList,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.listPlus,
    label: context.l10n.shareSheetAddToList,
    onTap: () => _runActionDetached(onAddToList(), 'present list picker sheet'),
  );
}

/// Debug action copying the video's event JSON through [bloc].
VideoActionRowItem copyEventJsonActionItem(
  BuildContext context, {
  required VideoContentActionsBloc bloc,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.bracketsAngle,
    label: context.l10n.shareSheetEventJson,
    onTap: () => bloc.add(const VideoContentCopyEventJsonRequested()),
  );
}

/// Debug action copying the video's event ID through [bloc].
VideoActionRowItem copyEventIdActionItem(
  BuildContext context, {
  required VideoContentActionsBloc bloc,
}) {
  return VideoActionRowItem(
    icon: DivineIconName.copySimple,
    label: context.l10n.shareSheetEventId,
    onTap: () => bloc.add(const VideoContentCopyEventIdRequested()),
  );
}
