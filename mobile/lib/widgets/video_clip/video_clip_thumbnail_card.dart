// ABOUTME: Thumbnail card widget for displaying video clips in grid layout
// ABOUTME: Shows thumbnail with duration badge, selection state, and tap handlers

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_gallery_backup.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';
import 'package:openvine/widgets/video_clip/clip_crop_guide.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_clip/video_clip_hero.dart';
import 'package:openvine/widgets/video_clip/video_clip_semantic_label.dart';

/// Thumbnail card for a single clip in the grid.
///
/// Displays a video clip thumbnail with duration badge and optional selection
/// indicator.
class VideoClipThumbnailCard extends StatefulWidget {
  const VideoClipThumbnailCard({
    required this.clip,
    this.onTap,
    this.selectionIndex = -1,
    this.showSelectionIndicator = true,
    this.disabled = false,
    this.showDurationBadge = true,
    this.showArchivedBadge = false,
    super.key,
  });

  /// The clip data to display, including thumbnail path, duration, and
  /// aspect ratio.
  final DivineVideoClip clip;

  /// The 1-based position of this clip in the current selection order.
  ///
  /// Displayed inside the selection circle when the card is selected.
  final int selectionIndex;

  /// Whether to show the selection indicator in the top-right corner.
  ///
  /// Without it a tap opens the clip preview, which is what the card tells
  /// screen readers it does.
  final bool showSelectionIndicator;

  /// Callback invoked when the card is tapped. When `null`, the card
  /// is non-interactive (e.g. in the trash bin view where restore /
  /// delete-now actions live outside the thumbnail) and is not announced as
  /// a button.
  final VoidCallback? onTap;

  /// Whether to show the duration badge at the bottom-left corner.
  final bool showDurationBadge;

  /// Whether to mark the clip as archived.
  ///
  /// Only the category views set this: an archived clip can stay filed under
  /// its category, and there the marker is the one thing separating it from
  /// the active clips beside it. In the archive view every clip carries the
  /// state, so the marker would say nothing.
  final bool showArchivedBadge;

  /// Whether this clip is disabled and cannot be interacted with.
  /// When disabled, the card is shown with reduced opacity and tap handlers
  /// are inactive.
  final bool disabled;

  @override
  State<VideoClipThumbnailCard> createState() => _VideoClipThumbnailCardState();
}

/// State for [VideoClipThumbnailCard].
///
/// Manages thumbnail existence check as a cached [Future] to prevent
/// redundant file system checks on rebuild.
class _VideoClipThumbnailCardState extends State<VideoClipThumbnailCard> {
  bool get _isSelected => widget.selectionIndex > 0;

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio for container
    final aspectRatio = widget.clip.targetAspectRatio.value;
    final showDurationBadge =
        widget.showDurationBadge && !widget.clip.isStopMotion;

    final l10n = context.l10n;
    // Only a backup that is not done yet, or is done without proof, is
    // flagged; a finished one is the normal case and stays quiet.
    final backupStatus = switch (widget.clip.galleryBackup) {
      final backup? when backup.needsAttention => backup.status,
      _ => null,
    };
    final label = widget.clip.semanticLabel(l10n);
    final labelWithBackup = switch (backupStatus) {
      ClipGalleryBackupStatus.pending =>
        l10n.videoClipBackupPendingSemanticLabel(label),
      ClipGalleryBackupStatus.savedUnsigned =>
        l10n.videoClipBackupUnsignedSemanticLabel(label),
      ClipGalleryBackupStatus.saved || null => label,
    };

    final isInteractive = widget.onTap != null;
    // Selection is only announced while its badge is on screen. Entering the
    // library with clips already in the editor pre-selects them while
    // selection mode is off, and there a tap opens the preview instead.
    final announcesSelection = isInteractive && widget.showSelectionIndicator;

    return Semantics(
      container: true,
      label: widget.showArchivedBadge
          ? l10n.videoClipArchivedSemanticLabel(labelWithBackup)
          : labelWithBackup,
      value: announcesSelection
          // The badge shows the pick order, which decides the order clips are
          // stitched into, so announce it rather than letting the badge's bare
          // digits merge into the label.
          ? _isSelected
                ? l10n.videoClipSemanticValueSelectedAtPosition(
                    widget.selectionIndex,
                  )
                : l10n.videoClipSemanticValueNotSelected
          : null,
      button: isInteractive,
      selected: announcesSelection ? _isSelected : null,
      enabled: isInteractive ? !widget.disabled : null,
      onTap: widget.disabled ? null : widget.onTap,
      hint: !isInteractive
          ? null
          : widget.disabled
          ? l10n.videoClipSemanticHintDisabled
          : !widget.showSelectionIndicator
          ? l10n.videoClipSemanticHintPreview
          : _isSelected
          ? l10n.videoClipSemanticHintDeselect
          : l10n.videoClipSemanticHintSelect,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: widget.disabled ? 0.4 : 1.0,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: widget.disabled ? null : widget.onTap,
          child: ClipRRect(
            borderRadius: .circular(4),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                color: context.vineColors.card,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Thumbnail or placeholder
                    _Thumbnail(clip: widget.clip),

                    /// The part of the frame a picker above will keep
                    if (ClipCropGuide.maybeOf(context) case final guide?)
                      ClipCropGuideOverlay(
                        aspectRatio: guide.aspectRatio,
                        contentAspectRatio: widget.clip.videoAspectRatio,
                      ),

                    /// The badges keep their size while a pinch on the clip
                    /// grid scales the thumbnail under them.
                    PinchZoomUnscaled(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          /// Stop-motion marker + still count and the
                          /// archived marker - top left
                          if (widget.clip.isStopMotion ||
                              widget.showArchivedBadge ||
                              backupStatus != null)
                            _TopLeftBadges(
                              frameCount: widget.clip.isStopMotion
                                  ? widget.clip.stopMotionFrames?.length ?? 0
                                  : null,
                              showArchived: widget.showArchivedBadge,
                              backupStatus: backupStatus,
                            ),

                          /// Duration badge - bottom left. Hidden for
                          /// stop-motion recordings: their playback length
                          /// (frame count / 12fps) is a tiny, misleading
                          /// value, so they read as a still image marked only
                          /// by the stop-motion badge.
                          if (showDurationBadge)
                            _DurationBadge(clip: widget.clip),

                          if (widget.clip.libraryTitle case final title?)
                            _TitleBadge(
                              title: title,
                              bottomOffset: showDurationBadge ? 32 : 8,
                            ),

                          /// Selection check circle - top right
                          if (widget.showSelectionIndicator)
                            _SelectionOverlay(
                              selectionIndex: widget.selectionIndex,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the thumbnail image or placeholder.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = clip.thumbnailPath;
    if (thumbnailPath != null) {
      return Hero(
        tag: videoClipPreviewHeroTag(clip.id),
        // Stop-motion clips use a full-resolution still as their thumbnail;
        // bound the decode to the grid cell so it doesn't cost tens of MB.
        child: ClipThumbnailImage(
          path: thumbnailPath,
          fit: BoxFit.cover,
          cacheHeight:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context) /
                      2)
                  .round(),
          placeholder: const VideoClipThumbnailPlaceholder(),
        ),
      );
    }

    return const VideoClipThumbnailPlaceholder();
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.title, required this.bottomOffset});

  final String title;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 8,
      end: 8,
      bottom: bottomOffset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: .circular(4),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 6, vertical: 3),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
          ),
        ),
      ),
    );
  }
}

/// The badge row in the top-left corner: the stop-motion marker, the
/// archived marker and the gallery backup marker, side by side.
class _TopLeftBadges extends StatelessWidget {
  const _TopLeftBadges({
    required this.frameCount,
    required this.showArchived,
    required this.backupStatus,
  });

  /// Number of captured stills, or `null` when the clip is not a
  /// stop-motion recording and carries no stop-motion badge.
  final int? frameCount;

  /// Whether the archived marker is part of the row.
  final bool showArchived;

  /// The gallery backup state to flag, or `null` when there is none to flag.
  final ClipGalleryBackupStatus? backupStatus;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 6,
      top: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (frameCount case final count?) _StopMotionBadge(frameCount: count),
          if (showArchived) const _ArchivedBadge(),
          if (backupStatus case final status?)
            _GalleryBackupBadge(status: status),
        ],
      ),
    );
  }
}

/// Flags a recording whose gallery backup is still waiting, or was saved
/// without its C2PA credential and so cannot come back to the clips.
class _GalleryBackupBadge extends StatelessWidget {
  const _GalleryBackupBadge({required this.status});

  final ClipGalleryBackupStatus status;

  @override
  Widget build(BuildContext context) {
    // Decorative: the card's own label already announces the backup state.
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(4),
        ),
        child: DivineIcon(
          icon: status == ClipGalleryBackupStatus.pending
              ? .clockCountdown
              : .sealWarning,
          color: VineTheme.lightText,
          size: 14,
        ),
      ),
    );
  }
}

/// Marks a clip shown inside a category as archived.
class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge();

  @override
  Widget build(BuildContext context) {
    // Decorative: the card's own label already announces the archived state,
    // and a second node here would sit inside the card's button.
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const DivineIcon(
          icon: .stackSimple,
          color: VineTheme.lightText,
          size: 14,
        ),
      ),
    );
  }
}

/// Marks a clip in the library as a stop-motion recording and shows how many
/// stills it holds.
class _StopMotionBadge extends StatelessWidget {
  const _StopMotionBadge({required this.frameCount});

  /// Number of captured stills in the set.
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    // Fully decorative: the card's own label already announces that this is
    // a stop-motion clip and how many stills it holds. Emitting a node here
    // too would put a second, non-actionable node inside the card's button.
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            const DivineIcon(
              icon: .imagesSquare,
              color: VineTheme.lightText,
              size: 14,
            ),
            Text(
              '$frameCount',
              style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the duration badge shown at the bottom-left corner.
///
/// Displays the clip duration in seconds with 2 decimal places.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 8,
      bottom: 8,
      child: Container(
        padding: const .symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: .circular(4),
        ),
        child: ExcludeSemantics(
          child: Text(
            clip.durationInSeconds.toStringAsFixed(2),
            style: VineTheme.labelSmallFont(color: VineTheme.whiteText)
                .copyWith(fontFeatures: [const .tabularFigures()]),
          ),
        ),
      ),
    );
  }
}

/// Builds the selection overlay with a numbered circle indicator.
///
/// Shows a circular badge in the top-right corner. When selected, displays
/// the selection index number; when unselected, shows an empty circle.
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.selectionIndex});

  final int selectionIndex;

  bool get _isSelected => selectionIndex > 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          end: 8,
          top: 6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            padding: const .all(5),
            decoration: BoxDecoration(
              color: _isSelected
                  ? VineTheme.surfaceBackground
                  : VineTheme.onSurfaceDisabled,
              border: Border.all(
                color: _isSelected ? VineTheme.primary : VineTheme.onSurface,
                width: 3,
              ),
              borderRadius: .circular(999),
            ),
            child: _isSelected
                ? Center(
                    child: MediaQuery.withNoTextScaling(
                      child: ExcludeSemantics(
                        child: Text(
                          selectionIndex.toString(),
                          maxLines: 1,
                          style:
                              VineTheme.labelLargeFont(
                                color: VineTheme.primaryText,
                              ).copyWith(
                                fontFeatures: [const .tabularFigures()],
                                height: 1,
                              ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
