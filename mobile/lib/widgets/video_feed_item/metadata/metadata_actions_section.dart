// ABOUTME: Action row in the video info sheet: edit, delete, save, add to
// ABOUTME: clips, add to list and debug copies, shared with the share sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/owner_video_actions_sheet.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_rules.dart';

void _runDetached(Future<void> operation, String description) {
  runDetached(
    operation,
    description,
    logName: 'MetadataActionsSection',
    category: LogCategory.ui,
  );
}

/// Content actions for [video] in the info sheet.
///
/// Reads the [VideoContentActionsBloc] the sheet provides, and treats the
/// video as the viewer's own exactly when an [OwnerVideoActionsCubit] is
/// provided too. Renders nothing without the bloc, so the sheet can still be
/// built on its own.
class MetadataActionsSection extends ConsumerWidget {
  const MetadataActionsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentActions = context.read<VideoContentActionsBloc?>();
    if (contentActions == null) return const SizedBox.shrink();

    final ownerCubit = context.read<OwnerVideoActionsCubit?>();
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
    final l10n = context.l10n;

    final actions = <VideoActionRowItem>[
      if (ownerCubit != null) ...[
        VideoActionRowItem(
          icon: DivineIconName.pencilSimpleLine,
          label: l10n.shareMenuEditVideo,
          onTap: () => _editVideo(context, ownerCubit),
          isDisabled: isDeletePending,
        ),
        VideoActionRowItem(
          icon: DivineIconName.trash,
          label: l10n.shareMenuDeleteVideo,
          onTap: () => _runDetached(
            confirmAndDeleteOwnerVideo(
              context: context,
              video: video,
              cubit: ownerCubit,
              onDeleted: () async => dismissSheet(context),
            ),
            'delete own video',
          ),
          isPending: isDeletePending,
        ),
      ],
      // `unknown` deliberately renders as "Save": an unresolved read must not
      // claim the video is unsaved.
      VideoActionRowItem(
        icon: DivineIconName.bookmarkSimple,
        label: isSaved ? l10n.shareSheetRemoveFromSaved : l10n.shareSheetSave,
        onTap: () => contentActions.add(const VideoContentSaveRequested()),
        isPending: isSavePending,
      ),
      if (canAddVideoToClips(video: video, isOwnContent: ownerCubit != null))
        VideoActionRowItem(
          icon: DivineIconName.filmSlate,
          label: l10n.shareSheetAddToClips,
          onTap: () =>
              _runDetached(requestAddToClips(context), 'request add to clips'),
        ),
      VideoActionRowItem(
        icon: DivineIconName.listPlus,
        label: l10n.shareSheetAddToList,
        onTap: () => _runDetached(
          presentAfterSheetDismiss<void>(
            context,
            (hostContext) => showSelectListSheet(hostContext, video: video),
          ),
          'present list picker sheet',
        ),
      ),
      if (showDebugTools) ...[
        VideoActionRowItem(
          icon: DivineIconName.bracketsAngle,
          label: l10n.shareSheetEventJson,
          onTap: () =>
              contentActions.add(const VideoContentCopyEventJsonRequested()),
        ),
        VideoActionRowItem(
          icon: DivineIconName.copySimple,
          label: l10n.shareSheetEventId,
          onTap: () =>
              contentActions.add(const VideoContentCopyEventIdRequested()),
        ),
      ],
    ];

    return VideoActionRow(actions: actions);
  }

  void _editVideo(BuildContext context, OwnerVideoActionsCubit ownerCubit) {
    if (ownerCubit.isDeleteInProgress(video.id)) return;
    _runDetached(
      presentAfterSheetDismiss<void>(context, (hostContext) {
        return VideoMetadataEditRouteData(
          videoId: video.id,
          $extra: video,
        ).push<void>(hostContext);
      }),
      'open video metadata editor',
    );
  }
}
