// ABOUTME: The split-screen layout as it will look: the border colour behind
// ABOUTME: every cell, each cell showing its clip framed, pan and pinch to reframe

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

/// The frame the layout splits, with every cell where the export will put it.
///
/// A tap selects a cell for the action bar; panning or pinching a filled cell
/// moves or zooms the footage inside it, so the render shows what is on
/// screen.
class SplitScreenLayoutPreview extends StatelessWidget {
  const SplitScreenLayoutPreview({super.key});

  /// Corner radius of the frame on screen. The video itself is square-cornered;
  /// the rounding only sets the preview off from the screen around it.
  static const double frameRadius = 16;

  @override
  Widget build(BuildContext context) {
    // The inputs of the cell rects rather than the rects themselves: those
    // are a new list each time, which would rebuild every cell on every pan.
    final (:frameAspectRatio, :borderColor, :preset, :gap) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        frameAspectRatio: cubit.state.frameAspectRatio,
        borderColor: cubit.state.borderColor,
        preset: cubit.state.preset,
        gap: cubit.state.gap,
      ),
    );
    final rects = preset.cellRects(aspectRatio: frameAspectRatio, gap: gap);

    return Center(
      child: AspectRatio(
        aspectRatio: frameAspectRatio,
        child: ClipRRect(
          borderRadius: .circular(frameRadius),
          child: ColoredBox(
            color: borderColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  children: [
                    for (final (index, rect) in rects.indexed)
                      _PositionedCell(
                        index: index,
                        rect: rect,
                        frame: size,
                        // A window over the left of a cell, the
                        // bottom-left picture-in-picture one, would hide
                        // the badge there.
                        badgeOnRight: rects
                            .skip(index + 1)
                            .any(
                              (above) =>
                                  above.overlaps(rect) &&
                                  above.center.dx < rect.center.dx,
                            ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A cell placed in a [frame] of the preview, from its [rect] in fractions.
///
/// Where the cell reaches a rounded corner of the frame it is rounded to
/// match, so its selection border follows the corner instead of being cut off
/// by it.
class _PositionedCell extends StatelessWidget {
  const _PositionedCell({
    required this.index,
    required this.rect,
    required this.frame,
    required this.badgeOnRight,
  });

  final int index;
  final Rect rect;
  final Size frame;
  final bool badgeOnRight;

  @override
  Widget build(BuildContext context) {
    final cell = Rect.fromLTWH(
      rect.left * frame.width,
      rect.top * frame.height,
      rect.width * frame.width,
      rect.height * frame.height,
    );

    // A cell inset from a corner by the gap needs that much less rounding to
    // stay inside it — the same rule as concentric rounded rects.
    Radius corner(double fromSide, double fromEnd) {
      final radius =
          SplitScreenLayoutPreview.frameRadius - math.max(fromSide, fromEnd);
      return radius > 0 ? Radius.circular(radius) : Radius.zero;
    }

    return Positioned.fromRect(
      rect: cell,
      child: _LayoutCell(
        index: index,
        badgeOnRight: badgeOnRight,
        borderRadius: BorderRadius.only(
          topLeft: corner(cell.left, cell.top),
          topRight: corner(frame.width - cell.right, cell.top),
          bottomLeft: corner(cell.left, frame.height - cell.bottom),
          bottomRight: corner(
            frame.width - cell.right,
            frame.height - cell.bottom,
          ),
        ),
      ),
    );
  }
}

class _LayoutCell extends StatefulWidget {
  const _LayoutCell({
    required this.index,
    required this.borderRadius,
    required this.badgeOnRight,
  });

  final int index;
  final BorderRadius borderRadius;

  /// Whether the duration badge sits in the bottom-right corner rather than
  /// the bottom-left one, which another cell covers.
  final bool badgeOnRight;

  @override
  State<_LayoutCell> createState() => _LayoutCellState();
}

class _LayoutCellState extends State<_LayoutCell> {
  /// The cell's zoom when the fingers came down. A pinch reports its scale
  /// against the start of the gesture, not against the previous update.
  double _gestureStartZoom = 1;

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final (:cell, :isSelected) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        cell: cubit.state.cells[index],
        isSelected: cubit.state.selectedCellIndex == index,
      ),
    );
    final cubit = context.read<SplitScreenLayoutCubit>();
    final number = '${index + 1}';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Semantics(
          button: true,
          selected: isSelected,
          label: cell == null
              ? context.l10n.videoEditorLayoutCellEmptySemanticLabel(number)
              : context.l10n.videoEditorLayoutCellSemanticLabel(number),
          // The badge says it on screen; a screen reader hears it here.
          value: cell == null
              ? null
              : context.l10n.libraryClipDuration(
                  cell.clip.playbackDuration.toFormattedSeconds(),
                ),
          child: GestureDetector(
            behavior: .opaque,
            onTap: () => cubit.cellSelected(index),
            onScaleStart: cell == null
                ? null
                : (_) {
                    cubit.cellSelected(index);
                    _gestureStartZoom = cell.zoom;
                  },
            onScaleUpdate: cell == null
                ? null
                : (details) => cubit.cellReframed(
                    index,
                    focalPoint:
                        details.localFocalPoint - details.focalPointDelta,
                    delta: details.focalPointDelta,
                    zoom: _gestureStartZoom * details.scale,
                    cellSize: constraints.biggest,
                  ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Stack(
                fit: .expand,
                children: [
                  if (cell == null)
                    const _EmptyCell()
                  else
                    _CellFootage(
                      thumbnailPath: cell.clip.thumbnailPath,
                      sourceAspectRatio: cell.clip.videoAspectRatio,
                      alignment: cell.alignment,
                      zoom: cell.zoom,
                    ),
                  if (cell != null)
                    Positioned(
                      left: widget.badgeOnRight ? null : 6,
                      right: widget.badgeOnRight ? 6 : null,
                      bottom: 6,
                      child: _DurationBadge(
                        duration: cell.clip.playbackDuration,
                      ),
                    ),
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        border: Border.all(
                          width: 2,
                          color: isSelected
                              ? VineTheme.primary
                              : VineTheme.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surfaceContainer.withValues(alpha: 0.85),
      child: Center(
        child: DivineIcon(icon: .plus, color: context.vineColors.onSurface),
      ),
    );
  }
}

/// The clip's poster frame laid out where the render will draw the clip's
/// frame — see [splitScreenFootageRect] — so the cell shows what it will hold.
///
/// The poster stands in for the whole frame: it is laid out at the shape of
/// the clip's video, not its own, because that is what the cell is cut from.
class _CellFootage extends StatelessWidget {
  const _CellFootage({
    required this.thumbnailPath,
    required this.sourceAspectRatio,
    required this.alignment,
    required this.zoom,
  });

  final String? thumbnailPath;
  final double sourceAspectRatio;
  final Alignment alignment;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final thumbnail = thumbnailPath;
    final missing = ColoredBox(color: context.vineColors.surfaceContainerHigh);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final footage = splitScreenFootageRect(
            cellSize: constraints.biggest,
            sourceAspectRatio: sourceAspectRatio,
            alignment: alignment,
            zoom: zoom,
          );
          // A Stack clips to its own bounds, which cuts the overhang away.
          return Stack(
            children: [
              Positioned.fromRect(
                rect: footage,
                child: thumbnail == null
                    ? missing
                    : ClipThumbnailImage(
                        path: thumbnail,
                        fit: .cover,
                        placeholder: missing,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// How long the cell's clip plays.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.scrim65,
            borderRadius: .circular(8),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 6, vertical: 2),
            child: Text(
              context.l10n.libraryClipDuration(duration.toFormattedSeconds()),
              style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
            ),
          ),
        ),
      ),
    );
  }
}
