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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    final isSaved = bookmarkStatus == ShareSheetBookmarkStatus.saved;

    // The crosspost action only appears once the connections fetch
    // reports at least one connected platform.
    var connectedCrosspostPlatforms = const <String>[];
    if (onCrosspost != null) {
      connectedCrosspostPlatforms = context.select(
        (VideoCrosspostCubit cubit) => cubit.state.connectedPlatforms,
      );
    }

    final actions = <_ActionData>[
      if (onEditVideo != null)
        _ActionData(
          icon: DivineIconName.pencilSimpleLine,
          label: context.l10n.shareMenuEditVideo,
          onTap: onEditVideo!,
          isDisabled: isDeletePending,
        ),
      if (onDeleteVideo != null)
        _ActionData(
          icon: DivineIconName.trash,
          label: context.l10n.shareMenuDeleteVideo,
          onTap: onDeleteVideo!,
          isPending: isDeletePending,
        ),
      // `unknown` deliberately renders as "Save": an unresolved read must not
      // claim the video is unsaved, and "Save" is the pre-existing wording.
      _ActionData(
        icon: DivineIconName.bookmarkSimple,
        label: isSaved
            ? context.l10n.shareSheetRemoveFromSaved
            : context.l10n.shareSheetSave,
        onTap: onSave,
        isPending: isSavePending,
      ),
      if (onSaveOriginal != null)
        _ActionData(
          icon: DivineIconName.downloadSimple,
          label: context.l10n.shareSheetSaveToGallery,
          onTap: () => onSaveOriginal!.call(),
        ),
      _ActionData(
        icon: DivineIconName.downloadSimple,
        label: isOwnContent
            ? context.l10n.shareSheetSaveWithWatermark
            : context.l10n.shareSheetSaveVideo,
        onTap: onSaveWithWatermark,
      ),
      if (onAddVideoToClips != null)
        _ActionData(
          icon: DivineIconName.filmSlate,
          label: context.l10n.shareSheetAddToClips,
          onTap: onAddVideoToClips!,
        ),
      if (onCrosspost != null && connectedCrosspostPlatforms.isNotEmpty)
        _ActionData(
          icon: DivineIconName.arrowsClockwise,
          label: context.l10n.shareSheetCrosspost,
          onTap: () => onCrosspost!.call(),
        ),
      _ActionData(
        icon: DivineIconName.listPlus,
        label: context.l10n.shareSheetAddToList,
        onTap: onAddToList,
      ),
      _ActionData(
        icon: DivineIconName.linkSimple,
        label: context.l10n.shareSheetCopy,
        onTap: onCopyLink,
      ),
      _ActionData(
        icon: DivineIconName.shareFat,
        label: context.l10n.shareSheetShareVia,
        onTap: onShareVia,
      ),
      if (showDebugTools) ...[
        _ActionData(
          icon: DivineIconName.bracketsAngle,
          label: context.l10n.shareSheetEventJson,
          onTap: onCopyEventJson,
        ),
        _ActionData(
          icon: DivineIconName.copySimple,
          label: context.l10n.shareSheetEventId,
          onTap: onCopyEventId,
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.shareSheetMoreActions,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _ActionCircle(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                  isPending: action.isPending,
                  isDisabled: action.isDisabled,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPending = false,
    this.isDisabled = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;

  /// Whether the action is mid-flight, so the circle shows a spinner and stops
  /// responding to taps.
  final bool isPending;

  /// Whether another operation temporarily prevents this action.
  final bool isDisabled;
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPending = false,
    this.isDisabled = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isPending;

  /// Disables the action without presenting it as the pending operation.
  final bool isDisabled;

  static const double _circleSize = 48;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDisabled
        ? context.vineColors.surfaceContainer
        : VineTheme.vineGreen.withValues(alpha: 0.15);
    final iconColor = isDisabled
        ? context.vineColors.secondaryText
        : context.vineColors.accentPositive;

    return Semantics(
      button: true,
      label: label,
      enabled: !isPending && !isDisabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isPending || isDisabled ? null : onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: _circleSize,
                height: _circleSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPending
                      // Same footprint as the icon it replaces, so the row does
                      // not reflow while the save is in flight. Mirrors the
                      // send button in share_sheet_message_input.dart.
                      ? SizedBox.square(
                          dimension: _iconSize,
                          child: DivineCircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              iconColor,
                            ),
                          ),
                        )
                      : DivineIcon(
                          icon: icon,
                          size: _iconSize,
                          color: iconColor,
                        ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: context.vineColors.secondaryText,
                  fontSize: 11,
                ),
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
