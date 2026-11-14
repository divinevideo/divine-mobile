part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// "More actions" horizontal row
// ---------------------------------------------------------------------------

class _MoreActionsSection extends ConsumerWidget {
  const _MoreActionsSection({
    required this.video,
    required this.isOwnContent,
    required this.bookmarkStatus,
    required this.onSave,
    required this.onSaveWithWatermark,
    required this.onAddToList,
    required this.onCopyLink,
    required this.onShareVia,
    required this.onCopyEventJson,
    required this.onCopyEventId,
    required this.onCrosspostShown,
    this.isSavePending = false,
    this.isDeletePending = false,
    this.onEditVideo,
    this.onDeleteVideo,
    this.onAddVideoToClips,
    this.onSaveOriginal,
    this.onCrosspost,
  });

  final VideoEvent video;
  final bool isOwnContent;

  /// Whether the bookmark toggle is mid-flight (#7073).
  final bool isSavePending;
  final bool isDeletePending;
  final ShareSheetBookmarkStatus bookmarkStatus;
  final VoidCallback onSave;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final VoidCallback onAddToList;
  final VoidCallback onCopyLink;
  final VoidCallback onShareVia;
  final VoidCallback onCopyEventJson;
  final VoidCallback onCopyEventId;
  final VoidCallback? onEditVideo;
  final Future<void> Function()? onDeleteVideo;
  final VoidCallback? onAddVideoToClips;
  final Future<void> Function()? onCrosspost;
  final VoidCallback onCrosspostShown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    final isSaved = bookmarkStatus == ShareSheetBookmarkStatus.saved;

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
        onTap: onSave,
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
      if (onAddVideoToClips != null)
        VideoActionRowItem(
          icon: DivineIconName.filmSlate,
          label: context.l10n.shareSheetAddToClips,
          onTap: onAddVideoToClips!,
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
          onTap: onCopyEventJson,
        ),
        VideoActionRowItem(
          icon: DivineIconName.copySimple,
          label: context.l10n.shareSheetEventId,
          onTap: onCopyEventId,
        ),
      ],
    ];

    return VideoActionRow(
      title: context.l10n.shareSheetMoreActions,
      actions: actions,
    );
  }
}
