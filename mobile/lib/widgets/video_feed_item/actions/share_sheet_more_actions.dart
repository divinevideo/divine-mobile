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
  final Future<void> Function() onAddToList;
  final VoidCallback onCopyLink;
  final VoidCallback onShareVia;
  final Future<void> Function()? onEditVideo;
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
      if (onEditVideo case final onEdit?)
        editOwnerVideoActionItem(
          context,
          onEdit: onEdit,
          isDeletePending: isDeletePending,
        ),
      if (onDeleteVideo case final onDelete?)
        deleteOwnerVideoActionItem(
          context,
          onDelete: onDelete,
          isDeletePending: isDeletePending,
        ),
      saveVideoActionItem(
        context,
        bloc: contentActions,
        isSaved: isSaved,
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
      if (canAddToClips) addToClipsActionItem(context),
      if (onCrosspost != null)
        VideoActionRowItem(
          icon: DivineIconName.arrowsClockwise,
          label: context.l10n.shareSheetCrosspost,
          onTap: () => unawaited(onCrosspost!.call()),
          onShown: onCrosspostShown,
        ),
      addToListActionItem(context, onAddToList: onAddToList),
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
        copyEventJsonActionItem(context, bloc: contentActions),
        copyEventIdActionItem(context, bloc: contentActions),
      ],
    ];

    return VideoActionRow(
      title: context.l10n.shareSheetMoreActions,
      actions: actions,
    );
  }
}
