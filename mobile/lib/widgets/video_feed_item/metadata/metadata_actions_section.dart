// ABOUTME: Action row in the video info sheet: edit, delete, save, add to
// ABOUTME: clips, add to list and debug copies, shared with the share sheet.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_items.dart';

/// Content actions for [video] in the info sheet.
///
/// Reads the [VideoContentActionsBloc] the sheet provides, and the
/// [OwnerVideoActionsCubit] it provides alongside when [isOwnVideo] is true.
/// Renders nothing without the bloc, so the sheet can still be built on its
/// own.
///
/// Kept alive in the sheet's lazy list: its context drives flows that outlive
/// a tap (delete, add to clips), and those must still close the sheet and
/// report their outcome after the row has scrolled out of view.
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
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );
    final isSavePending = context.select(
      (VideoContentActionsBloc bloc) => bloc.state.isSaving,
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
      ?addToClipsActionItem(
        context,
        video: video,
        isOwnContent: ownerCubit != null,
      ),
      addToListActionItem(
        context,
        onAddToList: () => openAddToList(context, video),
      ),
      if (showDebugTools) ...[
        copyEventJsonActionItem(context, bloc: contentActions),
        copyEventIdActionItem(context, bloc: contentActions),
      ],
    ];

    return VideoActionRow(actions: actions, isLocked: isDeletePending);
  }
}
