part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// "More actions" horizontal row
// ---------------------------------------------------------------------------

class _MoreActionsSection extends ConsumerWidget {
  const _MoreActionsSection({
    required this.video,
    required this.isOwnContent,
    required this.canAddToClips,
    required this.onSaveWithWatermark,
    required this.onAddToList,
    required this.onCopyLink,
    required this.onShareVia,
    required this.onCrosspostShown,
    this.isDeletePending = false,
    this.onEditVideo,
    this.onDeleteVideo,
    this.onSaveOriginal,
    this.onCrosspost,
  });

  final VideoEvent video;
  final bool isOwnContent;

  /// Whether Add to clips is offered for this video.
  final bool canAddToClips;
  final bool isDeletePending;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final VoidCallback onAddToList;
  final VoidCallback onCopyLink;
  final VoidCallback onShareVia;
  final VoidCallback? onEditVideo;
  final Future<void> Function()? onDeleteVideo;
  final Future<void> Function()? onCrosspost;
  final VoidCallback onCrosspostShown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    final contentActions = context.read<VideoContentActionsBloc>();
    // Whether the bookmark toggle is mid-flight (#7073).
    final isSavePending = context.select(
      (VideoContentActionsBloc bloc) => bloc.state.isSaving,
    );
    final isSaved = context.select(
      (VideoContentActionsBloc bloc) =>
          bloc.state.bookmarkStatus == VideoBookmarkStatus.saved,
    );

    final actions = <VideoActionRowItem>[
      if (onEditVideo != null)
        VideoActionRowItem(
          icon: DivineIconName.pencilSimpleLine,
          label: context.l10n.shareMenuEditVideo,
          onTap: onEditVideo!,
          isDisabled: isDeletePending,
        ),
      if (onDeleteVideo != null)
        VideoActionRowItem(
          icon: DivineIconName.trash,
          label: context.l10n.shareMenuDeleteVideo,
          onTap: onDeleteVideo!,
          isPending: isDeletePending,
        ),
      // `unknown` deliberately renders as "Save": an unresolved read must not
      // claim the video is unsaved, and "Save" is the pre-existing wording.
      VideoActionRowItem(
        icon: DivineIconName.bookmarkSimple,
        label: isSaved
            ? context.l10n.shareSheetRemoveFromSaved
            : context.l10n.shareSheetSave,
        onTap: () => contentActions.add(const VideoContentSaveRequested()),
        isPending: isSavePending,
      ),
      if (onSaveOriginal != null)
        VideoActionRowItem(
          icon: DivineIconName.downloadSimple,
          label: context.l10n.shareSheetSaveToGallery,
          onTap: () => onSaveOriginal!.call(),
        ),
      VideoActionRowItem(
        icon: DivineIconName.downloadSimple,
        label: isOwnContent
            ? context.l10n.shareSheetSaveWithWatermark
            : context.l10n.shareSheetSaveVideo,
        onTap: onSaveWithWatermark,
      ),
      if (canAddToClips)
        VideoActionRowItem(
          icon: DivineIconName.filmSlate,
          label: context.l10n.shareSheetAddToClips,
          onTap: () => _runShareDetached(
            requestAddToClips(context),
            'request add to clips',
          ),
        ),
      if (onCrosspost != null)
        VideoActionRowItem(
          icon: DivineIconName.arrowsClockwise,
          label: context.l10n.shareSheetCrosspost,
          onTap: () => unawaited(onCrosspost!.call()),
          onShown: onCrosspostShown,
        ),
      VideoActionRowItem(
        icon: DivineIconName.listPlus,
        label: context.l10n.shareSheetAddToList,
        onTap: onAddToList,
      ),
      VideoActionRowItem(
        icon: DivineIconName.linkSimple,
        label: context.l10n.shareSheetCopy,
        onTap: onCopyLink,
      ),
      VideoActionRowItem(
        icon: DivineIconName.shareFat,
        label: context.l10n.shareSheetShareVia,
        onTap: onShareVia,
      ),
      if (showDebugTools) ...[
        VideoActionRowItem(
          icon: DivineIconName.bracketsAngle,
          label: context.l10n.shareSheetEventJson,
          onTap: () =>
              contentActions.add(const VideoContentCopyEventJsonRequested()),
        ),
        VideoActionRowItem(
          icon: DivineIconName.copySimple,
          label: context.l10n.shareSheetEventId,
          onTap: () =>
              contentActions.add(const VideoContentCopyEventIdRequested()),
        ),
      ],
    ];

    return VideoActionRow(
      title: context.l10n.shareSheetMoreActions,
      actions: actions,
    );
  }
}
