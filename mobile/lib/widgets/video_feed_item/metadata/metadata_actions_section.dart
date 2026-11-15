// ABOUTME: Action row in the video info sheet: edit and delete on the viewer's
// ABOUTME: own video, and save; opens a remix the sheet's button asked for.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/remix_launcher.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_items.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_remix_button.dart';
import 'package:unified_logger/unified_logger.dart';

/// Content actions for [video] in the info sheet: Edit and Delete on the
/// viewer's own video, then Save.
///
/// The sheet's [MetadataRemixButton] stands in for Add to clips. Add to list
/// and the debug copies stay in the share sheet. When the remix the button
/// asked for is ready, this section opens it in the editor.
///
/// Reads the [VideoContentActionsBloc] the sheet provides, and the
/// [OwnerVideoActionsCubit] it provides alongside when [isOwnVideo] is true.
/// Renders nothing without the bloc, so the sheet can still be built on its
/// own.
///
/// Kept alive in the sheet's lazy list: its context drives flows that outlive
/// a tap (delete, remix), and those must still close the sheet and report or
/// open their outcome after the row has scrolled out of view.
class MetadataActionsSection extends ConsumerStatefulWidget {
  const MetadataActionsSection({
    required this.video,
    this.isOwnVideo = false,
    super.key,
  });

  final VideoEvent video;

  /// Whether the signed-in viewer owns [video], decided once by the sheet.
  /// Only then are Edit and Delete offered; an owner cubit provided further
  /// up the tree for some other video does not count.
  final bool isOwnVideo;

  @override
  ConsumerState<MetadataActionsSection> createState() =>
      _MetadataActionsSectionState();
}

class _MetadataActionsSectionState extends ConsumerState<MetadataActionsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final video = widget.video;
    final contentActions = context.read<VideoContentActionsBloc?>();
    if (contentActions == null) return const SizedBox.shrink();

    final ownerCubit = widget.isOwnVideo
        ? context.read<OwnerVideoActionsCubit>()
        : null;
    final isSavePending = context.select(
      (VideoContentActionsBloc bloc) => bloc.state.isSaving,
    );
    final isActionInFlight = context.select(
      (VideoContentActionsBloc bloc) => bloc.state.isActionInFlight,
    );
    final isSaved = context.select(
      (VideoContentActionsBloc bloc) =>
          bloc.state.bookmarkStatus == VideoBookmarkStatus.saved,
    );
    final isDeletePending =
        ownerCubit != null &&
        context.select<OwnerVideoActionsCubit, bool>(
          (cubit) => cubit.isDeleteInProgress(video.id),
        );
    final actions = <VideoActionRowItem>[
      if (ownerCubit != null) ...[
        editOwnerVideoActionItem(
          context,
          onEdit: () => openOwnerVideoEditor(context, video, ownerCubit),
        ),
        deleteOwnerVideoActionItem(
          context,
          onDelete: () => deleteOwnerVideoFromSheet(context, video, ownerCubit),
          isDeletePending: isDeletePending,
        ),
      ],
      saveVideoActionItem(
        context,
        bloc: contentActions,
        isSaved: isSaved,
        isPending: isSavePending,
      ),
    ];

    return BlocListener<VideoContentActionsBloc, VideoContentActionsState>(
      listenWhen: (previous, current) =>
          current.actionResult is VideoContentRemixReady &&
          previous.actionResult != current.actionResult,
      listener: _openReadyRemix,
      child: VideoActionRow(
        actions: actions,
        isLocked: isDeletePending || isActionInFlight,
      ),
    );
  }

  /// Opens the remix in the editor, unless a route the user opened over the
  /// sheet meanwhile covers it: closing the sheet would then close that
  /// route instead. The clip stays in the library either way.
  void _openReadyRemix(BuildContext context, VideoContentActionsState state) {
    final result = state.actionResult;
    if (result is! VideoContentRemixReady) return;
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
      Log.info(
        'Dropped a ready remix: a route covers the sheet',
        name: 'MetadataActionsSection',
        category: LogCategory.ui,
      );
      return;
    }
    runDetached(
      openRemixInEditor(context, ref, result.clip),
      'open remix in the editor',
      logName: 'MetadataActionsSection',
      category: LogCategory.video,
    );
  }
}
