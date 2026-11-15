// ABOUTME: Full-width "Remix this video" button in the video info sheet.
// ABOUTME: Asks for a remix of the video; on the web, points to the app.

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
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lets the viewer make a new video from [video]: the tap asks the sheet's
/// [VideoContentActionsBloc] for a remix, which the sheet's action row then
/// opens in the editor.
///
/// Shown only when [canRemixVideo] allows it. Renders nothing without the
/// bloc. Held, like the action row, while another content action or a delete
/// of the viewer's own video runs.
///
/// Remixing needs the mobile editor, so on the web ([isWeb]) the tap closes
/// the sheet and points to the app instead.
class MetadataRemixButton extends StatelessWidget {
  const MetadataRemixButton({
    required this.video,
    this.isOwnVideo = false,
    this.isWeb = kIsWeb,
    super.key,
  });

  final VideoEvent video;

  /// Whether the signed-in viewer owns [video], decided once by the sheet.
  /// The sheet then also provides an [OwnerVideoActionsCubit].
  final bool isOwnVideo;

  /// Whether the app runs on the web, where the editor is unavailable.
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final contentActions = context.read<VideoContentActionsBloc?>();
    if (contentActions == null) return const SizedBox.shrink();
    if (!canRemixVideo(video: video, isOwnContent: isOwnVideo)) {
      return const SizedBox.shrink();
    }

    final isPreparing = context.select(
      (VideoContentActionsBloc bloc) => bloc.state.isPreparingRemix,
    );
    final isOtherActionRunning = context.select(
      (VideoContentActionsBloc bloc) =>
          bloc.state.isActionInFlight && !bloc.state.isPreparingRemix,
    );
    final isDeletePending =
        isOwnVideo &&
        context.select<OwnerVideoActionsCubit, bool>(
          (cubit) => cubit.isDeleteInProgress(video.id),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DivineButton(
        label: context.l10n.remixThisVideo,
        expanded: true,
        isLoading: isPreparing,
        onPressed: isOtherActionRunning || isDeletePending
            ? null
            : isWeb
            ? () => _showAppNudge(context)
            : () => contentActions.add(const VideoContentRemixRequested()),
      ),
    );
  }

  void _showAppNudge(BuildContext sheetContext) {
    final l10n = sheetContext.l10n;
    final messenger = ScaffoldMessenger.of(sheetContext);
    // A snackbar raised while the sheet is open lands underneath it.
    dismissSheet(sheetContext);
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.remixWebAppNudge,
        actionLabel: l10n.remixWebGetTheApp,
        onActionPressed: () => runDetached(
          launchUrl(
            Uri.parse(AppConstants.downloadUrl),
            mode: LaunchMode.externalApplication,
          ),
          'open the app download page',
          logName: 'MetadataRemixButton',
          category: LogCategory.ui,
        ),
      ),
    );
  }
}
