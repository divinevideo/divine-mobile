part of 'video_editor_timeline_clip_strip.dart';

/// Scale factor that maps source-time pixel widths to playback-time pixel
/// widths. `1 / playbackSpeed`, clamped for non-positive speeds.
///
/// `_ClipTile.fullWidth` / `trimStartOffset` must be scaled by this so the
/// underlying source-time strip lines up with the visible slot width (which
/// is in playback time — see `_clipWidth` in the strip widget). Without
/// scaling, slow clips (speed < 1) produce a visible slot wider than the
/// underlying strip, leaving the trailing region empty/black.
extension _DivineVideoClipTimelineScale on DivineVideoClip {
  double get _playbackScale {
    final speed = playbackSpeed ?? 1.0;
    return speed > 0 ? 1.0 / speed : 1.0;
  }
}

/// Raster anchor offset for [clip]'s thumbnail slot grid.
///
/// Reversed clips return zero: reversing keeps [DivineVideoClip
/// .sourceStartOffset] (it survives `copyWith`), but the reversed file is
/// physically mirrored — there is no recording continuity to preserve, so
/// the raster stays file-anchored instead of phase-shifting by the stale
/// offset.
Duration _rasterAnchorOffset(DivineVideoClip clip) =>
    clip.reversed ? Duration.zero : clip.sourceStartOffset;

/// How far (in px) the clip's thumbnail slot grid is shifted left so its
/// grid lines stay glued to the *original recording's* timeline.
///
/// A split's rendered end half starts [DivineVideoClip.sourceStartOffset]
/// into the recording; without this phase the grid would re-anchor at the
/// new file's zero and every frame in the tile would visibly jump by up to
/// one slot when the render lands. The same phase shifts the slot windows
/// (in [_ClipContainer]) and the tile's content translation (in
/// [_ClipTile]), which together keep each frame's on-screen position
/// exactly invariant across the preview → rendered swap.
double _rasterPhasePx(DivineVideoClip clip, double contentWidth) {
  final durationMs = clip.duration.inMilliseconds;
  if (durationMs <= 0 || contentWidth <= 0) return 0;
  final offsetPx =
      _rasterAnchorOffset(clip).inMilliseconds * contentWidth / durationMs;
  return offsetPx % TimelineConstants.thumbnailWidth;
}

class _TrimmableClipTile extends StatefulWidget {
  const _TrimmableClipTile({
    required this.clip,
    required this.clipWidth,
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
    required this.waveformNotifier,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onTap,
    this.trimExpand = 0,
  });

  final DivineVideoClip clip;
  final double clipWidth;
  final double pixelsPerSecond;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  /// Null while the strip is in a reorder drag — see [_ClipTile].
  final ValueNotifier<ClipWaveform?>? waveformNotifier;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final VoidCallback? onTap;

  /// Extra horizontal padding on each side to keep the content at
  /// the original [clipWidth] while the parent [AnimatedPositioned]
  /// is wider for hit-testing.
  final double trimExpand;

  @override
  State<_TrimmableClipTile> createState() => _TrimmableClipTileState();
}

class _TrimmableClipTileState extends State<_TrimmableClipTile> {
  bool _leftAtLimit = false;
  bool _rightAtLimit = false;

  // Trim values accumulated during the active drag. Handles report incremental
  // pixel deltas; the result round-trips through ClipEditorBloc and only lands
  // back on widget.clip a frame later. Reading widget.clip mid-drag would use a
  // stale base and drop deltas whenever pointer updates outpace rebuilds (e.g.
  // 120Hz touch sampling emitting 2+ moves per frame), making the handle lag
  // further behind the finger the longer you drag. Accumulating locally keeps
  // every delta.
  Duration? _dragTrimStart;
  Duration? _dragTrimEnd;

  Duration _dxToDuration(double dx) {
    final seconds = dx / widget.pixelsPerSecond;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  void _onDragStart() {
    // Re-arm the at-limit haptic: a previous drag may have ended at a limit.
    _leftAtLimit = false;
    _rightAtLimit = false;
    _dragTrimStart = widget.clip.trimStart;
    _dragTrimEnd = widget.clip.trimEnd;
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _dragTrimStart = null;
    _dragTrimEnd = null;
    widget.onTrimDragChanged?.call(false);
  }

  void _onLeftDragUpdate(double dx) {
    final clip = widget.clip;
    final trimEnd = _dragTrimEnd ?? clip.trimEnd;
    var newTrimStart = (_dragTrimStart ?? clip.trimStart) + _dxToDuration(dx);

    // A trim-based split's end half floors its start handle at the split point
    // so it can't be dragged back into the start half's frames.
    final minTrimStart = clip.minTrimStart;
    final maxTrimStart =
        clip.duration - trimEnd - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimStart <= minTrimStart) {
      newTrimStart = minTrimStart;
      atLimit = true;
    } else if (newTrimStart >= maxTrimStart) {
      newTrimStart = maxTrimStart;
      atLimit = true;
    }

    if (atLimit && !_leftAtLimit) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _leftAtLimit = atLimit;
    _dragTrimStart = newTrimStart;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      isStart: true,
      trimStart: newTrimStart,
      trimEnd: trimEnd,
    );
  }

  void _onRightDragUpdate(double dx) {
    final clip = widget.clip;
    final trimStart = _dragTrimStart ?? clip.trimStart;
    // Dragging right handle left (negative dx) increases trimEnd.
    var newTrimEnd = (_dragTrimEnd ?? clip.trimEnd) + _dxToDuration(-dx);

    final maxTrimEnd =
        clip.duration - trimStart - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimEnd <= Duration.zero) {
      newTrimEnd = Duration.zero;
      atLimit = true;
    } else if (newTrimEnd >= maxTrimEnd) {
      newTrimEnd = maxTrimEnd;
      atLimit = true;
    }

    if (atLimit && !_rightAtLimit) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _rightAtLimit = atLimit;
    _dragTrimEnd = newTrimEnd;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      isStart: false,
      trimStart: trimStart,
      trimEnd: newTrimEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.trimExpand),
      child: TimelineTrimHandles(
        height: TimelineConstants.thumbnailStripHeight,
        width: widget.clipWidth,
        onLeftDragUpdate: _onLeftDragUpdate,
        onRightDragUpdate: _onRightDragUpdate,
        onDragStart: _onDragStart,
        onDragEnd: _onDragEnd,
        child: Semantics(
          label: context.l10n.videoEditorTimelineTrimClipSemanticLabel,
          hint: context.l10n.videoEditorTimelineTrimClipHint,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: _ClipTile(
              clip: widget.clip,
              fullWidth:
                  widget.clip.durationInSeconds *
                  widget.pixelsPerSecond *
                  widget.clip._playbackScale,
              trimStartOffset:
                  widget.clip.trimStart.inMilliseconds /
                  1000.0 *
                  widget.pixelsPerSecond *
                  widget.clip._playbackScale,
              thumbnailNotifier: widget.thumbnailNotifier,
              waveformNotifier: widget.waveformNotifier,
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggedClipTile extends StatelessWidget {
  const _DraggedClipTile({
    required this.clip,
    required this.index,
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
  });

  final DivineVideoClip clip;
  final int index;
  final double pixelsPerSecond;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: .circular(TimelineConstants.thumbnailRadius),
        border: .all(color: VineTheme.primary, width: 2),
      ),
      child: Semantics(
        label: context.l10n.videoEditorTimelineDraggingClipSemanticLabel(
          index + 1,
        ),
        child: _ClipTile(
          clip: clip,
          fullWidth:
              clip.durationInSeconds * pixelsPerSecond * clip._playbackScale,
          trimStartOffset:
              clip.trimStart.inMilliseconds /
              1000.0 *
              pixelsPerSecond *
              clip._playbackScale,
          thumbnailNotifier: thumbnailNotifier,
        ),
      ),
    );
  }
}

class _AccessibleClipTile extends StatelessWidget {
  const _AccessibleClipTile({
    required this.clip,
    required this.index,
    required this.total,
    required this.clipWidth,
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
    required this.waveformNotifier,
    required this.onReorder,
    this.wrapHeadOffset = 0,
    this.onTap,
    this.isMultiSelectMode = false,
    this.isSelected = false,
  });

  final DivineVideoClip clip;
  final int index;
  final int total;
  final double clipWidth;
  final double pixelsPerSecond;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  /// Null while the strip is in a reorder drag — see [_ClipTile].
  final ValueNotifier<ClipWaveform?>? waveformNotifier;
  final void Function(int from, int to) onReorder;

  /// Extra pixels to shift thumbnails left (on top of trim-start) so a loop
  /// wrap's consumed head is skipped on the first clip. Zero otherwise.
  final double wrapHeadOffset;
  final ValueChanged<int>? onTap;
  final bool isMultiSelectMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final durationSec = clip.duration.inMilliseconds / 1000.0;
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(index) : null,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: isMultiSelectMode
            ? (isSelected
                  ? context.l10n.videoEditorTimelineClipSelectedSemanticLabel(
                      index + 1,
                      total,
                    )
                  : context.l10n.videoEditorTimelineClipUnselectedSemanticLabel(
                      index + 1,
                      total,
                    ))
            : context.l10n.videoEditorTimelineClipSemanticLabel(
                index + 1,
                total,
                durationSec.toStringAsFixed(1),
              ),
        selected: isMultiSelectMode ? isSelected : null,
        hint: !isMultiSelectMode && total > 1
            ? context.l10n.videoEditorTimelineClipReorderHint
            : null,
        customSemanticsActions: isMultiSelectMode
            ? null
            : {
                if (index > 0)
                  CustomSemanticsAction(
                    label: context.l10n.videoEditorTimelineClipMoveLeft,
                  ): () =>
                      onReorder(index, index - 1),
                if (index < total - 1)
                  CustomSemanticsAction(
                    label: context.l10n.videoEditorTimelineClipMoveRight,
                  ): () =>
                      onReorder(index, index + 1),
              },
        child: _ClipTile(
          clip: clip,
          fullWidth:
              clip.durationInSeconds * pixelsPerSecond * clip._playbackScale,
          trimStartOffset:
              clip.trimStart.inMilliseconds /
                  1000.0 *
                  pixelsPerSecond *
                  clip._playbackScale +
              wrapHeadOffset,
          thumbnailNotifier: thumbnailNotifier,
          waveformNotifier: waveformNotifier,
          selectionState: isMultiSelectMode
              ? (isSelected
                    ? _ClipSelectionState.selected
                    : _ClipSelectionState.unselected)
              : _ClipSelectionState.none,
        ),
      ),
    );
  }
}

/// Multi-select visual state for a clip tile.
enum _ClipSelectionState { none, unselected, selected }

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.fullWidth,
    required this.thumbnailNotifier,
    this.waveformNotifier,
    this.trimStartOffset = 0,
    this.selectionState = _ClipSelectionState.none,
  });

  final DivineVideoClip clip;
  final double fullWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  /// The clip's audio waveform, drawn over the thumbnails. Null during a
  /// reorder drag, where every tile shrinks to a badge with no room for it.
  final ValueNotifier<ClipWaveform?>? waveformNotifier;

  /// Pixel offset from the left to shift thumbnails for trim-start.
  final double trimStartOffset;

  /// Multi-select visual state — drives the selection border / dim scrim.
  final _ClipSelectionState selectionState;

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: .circular(TimelineConstants.thumbnailRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // displayWidth: how wide the visible tile is (e.g. _reorderSize
          // during drag). contentWidth: the natural clip width that drives
          // thumbnail count — never changes during the reorder animation so
          // thumbnails don't swap content while the tile shrinks/grows.
          final displayWidth = math.max(fullWidth, constraints.maxWidth);
          // Shift content by the raster phase in lockstep with the slot
          // windows so frames keep their recording-anchored positions.
          final phasePx = _rasterPhasePx(clip, fullWidth);
          return SizedBox(
            width: displayWidth,
            height: TimelineConstants.thumbnailStripHeight,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(-trimStartOffset - phasePx, 0),
                  child: Stack(
                    // The enclosing ClipRect already trims the tile to its
                    // visible box — a second clip layer here buys nothing.
                    clipBehavior: .none,
                    children: [
                      ValueListenableBuilder<List<StripThumbnail>>(
                        valueListenable: thumbnailNotifier,
                        builder: (context, stripThumbnails, _) {
                          return _ClipContainer(
                            clip: clip,
                            displayWidth: displayWidth,
                            contentWidth: fullWidth,
                            stripThumbnails: stripThumbnails,
                          );
                        },
                      ),
                      if (waveformNotifier != null)
                        // The thumbnail row starts one raster phase before the
                        // clip's zero (see [_rasterPhasePx]); the waveform maps
                        // straight from clip time, so it starts at the phase.
                        // Both then ride the same translate, which keeps the
                        // bars glued to the frames through trim and zoom.
                        //
                        // Width is the clip's natural width, not displayWidth:
                        // the band's px-per-second must stay the frames' one,
                        // and displayWidth inflates to the slot while a reorder
                        // animates a sub-slot-width clip back to size.
                        Positioned(
                          left: phasePx,
                          top: 0,
                          width: fullWidth,
                          height: TimelineConstants.thumbnailStripHeight,
                          child: _ClipWaveformLayer(
                            clip: clip,
                            waveformNotifier: waveformNotifier!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (selectionState == _ClipSelectionState.none) return tile;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        tile,
        Positioned.fill(
          child: _ClipSelectionOverlay(
            isSelected: selectionState == _ClipSelectionState.selected,
          ),
        ),
      ],
    );
  }
}

/// Repaints the clip's waveform band on its own, so an arriving waveform never
/// rebuilds the thumbnail row next to it.
class _ClipWaveformLayer extends StatelessWidget {
  const _ClipWaveformLayer({
    required this.clip,
    required this.waveformNotifier,
  });

  final DivineVideoClip clip;
  final ValueNotifier<ClipWaveform?> waveformNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClipWaveform?>(
      valueListenable: waveformNotifier,
      builder: (context, waveform, _) {
        if (waveform == null) return const SizedBox.shrink();
        return ClipWaveformOverlay(
          waveform: waveform,
          clipDuration: clip.duration,
          volume: clip.volume,
        );
      },
    );
  }
}

/// Foreground overlay drawn on a clip tile while multi-selecting: a primary
/// border + check badge for selected clips, a translucent dim scrim for
/// unselected ones.
class _ClipSelectionOverlay extends StatelessWidget {
  const _ClipSelectionOverlay({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    if (!isSelected) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(
            TimelineConstants.thumbnailRadius,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: VineTheme.primary, width: 2),
            borderRadius: BorderRadius.circular(
              TimelineConstants.thumbnailRadius,
            ),
          ),
        ),
        const Positioned(
          top: 4,
          right: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: DivineIcon(
                icon: .check,
                size: 12,
                color: VineTheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single clip — thumbnail images filling the width.
class _ClipContainer extends StatelessWidget {
  const _ClipContainer({
    required this.clip,
    required this.displayWidth,
    required this.contentWidth,
    required this.stripThumbnails,
  });

  final DivineVideoClip clip;

  /// Visible tile width — used to size each slot so thumbnails fill the tile.
  final double displayWidth;

  /// Natural clip width at the current zoom — used for count and timestamp
  /// mapping so thumbnail content stays stable during the reorder animation.
  final double contentWidth;

  final List<StripThumbnail> stripThumbnails;

  int get _thumbnailCount {
    // The raster phase shifts every slot left, so one extra slot may be
    // needed to keep the tile's right edge covered.
    final natural =
        ((contentWidth + _rasterPhasePx(clip, contentWidth)) /
                TimelineConstants.thumbnailWidth)
            .ceil();
    // Keep visual slot count independent from loading progress so the strip
    // does not collapse to a single slot while thumbnails are still streaming in.
    return natural.clamp(1, 1000);
  }

  /// Time (in ms) one [TimelineConstants.thumbnailWidth]-wide slot covers.
  ///
  /// The window pitch matches the slot box pitch exactly, so a frame's
  /// on-screen position is linear in its timestamp — the `duration/count`
  /// pitch used previously was slightly narrower than a box (ceil rounding),
  /// drifting frames rightward toward the tile's end.
  double get _slotSpanMs =>
      TimelineConstants.thumbnailWidth *
      clip.duration.inMilliseconds /
      contentWidth;

  /// Maps a visual slot index to a [StripThumbnail] path that falls
  /// within the slot's time range.
  ///
  /// Each slot owns a fixed time window `[slotStart, slotEnd)`. Only a
  /// thumbnail whose timestamp falls inside that window is returned.
  /// This guarantees a slot never changes its image once a matching
  /// thumbnail has been loaded — new thumbnails for *other* slots
  /// don't cause a reassignment.
  ///
  /// Windows are anchored to the original recording's timeline (shifted by
  /// the raster phase, see [_rasterPhasePx]), so a split render landing —
  /// which rebases the clip's file timeline — never re-buckets frames.
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (stripThumbnails.isEmpty) return null;

    final durationMs = clip.duration.inMilliseconds;
    if (durationMs <= 0) return stripThumbnails.first.path;

    final spanMs = _slotSpanMs;
    final phaseMs =
        _rasterPhasePx(clip, contentWidth) * durationMs / contentWidth;

    // Fixed, recording-anchored time window for this slot.
    final slotStartMs = slotIndex * spanMs - phaseMs;
    final slotEndMs = (slotIndex + 1) * spanMs - phaseMs;
    final slotCenterMs = (slotStartMs + slotEndMs) / 2;

    // Binary search for the first thumbnail at or after slotStartMs.
    var lo = 0;
    var hi = stripThumbnails.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (stripThumbnails[mid].timestamp.inMilliseconds < slotStartMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // Scan candidates within [slotStartMs, slotEndMs) and pick the
    // one closest to the slot center.
    String? bestPath;
    var bestDist = double.infinity;
    for (var i = lo; i < stripThumbnails.length; i++) {
      final tsMs = stripThumbnails[i].timestamp.inMilliseconds;
      if (tsMs >= slotEndMs) break;
      final dist = (tsMs - slotCenterMs).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestPath = stripThumbnails[i].path;
      }
    }

    return bestPath;
  }

  @override
  Widget build(BuildContext context) {
    final count = _thumbnailCount;
    // Scale slots up only for tiny clips shown inside a larger container
    // (e.g. the reorder tile where displayWidth > contentWidth). For normal
    // and long clips keep thumbnailWidth fixed so each image represents the
    // correct time span instead of stretching to fill the whole tile.
    final slotWidth = contentWidth < displayWidth
        ? math.max(TimelineConstants.thumbnailWidth, displayWidth / count)
        : TimelineConstants.thumbnailWidth;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheH = (TimelineConstants.thumbnailStripHeight * dpr).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          SizedBox(
            width: slotWidth,
            height: TimelineConstants.thumbnailStripHeight,
            child: _ThumbnailImage(
              cacheHeight: cacheH,
              thumbnailPath: clip.thumbnailPath,
              stripThumbnailPath: _thumbnailForSlot(i, count),
            ),
          ),
      ],
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.cacheHeight,
    required this.thumbnailPath,
    this.stripThumbnailPath,
  });

  final int cacheHeight;
  final String? thumbnailPath;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    // No cacheHeight: reuse the plain FileImage key the poster/grid already
    // warmed so this is a cache hit, not a cold resized decode that flashes
    // black. Strip thumbnails below keep it — they have no warm entry to share.
    final fallback = thumbnailPath != null
        ? Image.file(
            File(thumbnailPath!),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: context.vineColors.surfaceContainerHigh),
          )
        : ColoredBox(color: context.vineColors.surfaceContainerHigh);

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
