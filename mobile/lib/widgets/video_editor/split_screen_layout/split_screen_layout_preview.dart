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
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_cell_shape_widgets.dart';

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
    final cells = preset.cells(aspectRatio: frameAspectRatio, gap: gap);

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
                    for (final (index, cell) in cells.indexed)
                      _PositionedCell(
                        index: index,
                        cell: cell,
                        frame: size,
                        // A window over a cell, such as a
                        // picture-in-picture one, would hide its badge.
                        coveredBy: cells.skip(index + 1).toList(),
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

/// A cell placed in a [frame] of the preview, from its rect in fractions.
///
/// Where the cell reaches a rounded corner of the frame it is rounded to
/// match, so its selection border follows the corner instead of being cut off
/// by it.
class _PositionedCell extends StatelessWidget {
  const _PositionedCell({
    required this.index,
    required this.cell,
    required this.frame,
    required this.coveredBy,
  });

  final int index;
  final SplitScreenCellGeometry cell;
  final Size frame;

  /// The cells stacked on top of this one.
  final List<SplitScreenCellGeometry> coveredBy;

  @override
  Widget build(BuildContext context) {
    Rect inFrame(Rect rect) => Rect.fromLTWH(
      rect.left * frame.width,
      rect.top * frame.height,
      rect.width * frame.width,
      rect.height * frame.height,
    );
    final cell = inFrame(this.cell.rect);
    final covered = [
      for (final above in coveredBy)
        if (inFrame(above.rect) case final rect when rect.overlaps(cell))
          above.shape.pathIn(rect.shift(-cell.topLeft)),
    ];

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
        shape: this.cell.shape,
        covered: covered,
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
    required this.shape,
    required this.borderRadius,
    required this.covered,
  });

  final int index;
  final SplitScreenCellShape shape;
  final BorderRadius borderRadius;

  /// The outlines of the cells on top of this one, in its own coordinates:
  /// the duration badge keeps clear of them.
  final List<Path> covered;

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
    // An empty cell and a missing poster are app surfaces, so the ring
    // follows the appearance there; over footage the brand green reads in
    // both.
    final ring = cell == null || cell.clip.thumbnailPath == null
        ? context.vineColors.accentBrand
        : VineTheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final badge = _badgePlacement(constraints.biggest);
        // Cut outside the gesture detector, which would otherwise take every
        // touch in the cell's rect: a tap off a round or slanted cell's shape
        // belongs to the cell underneath.
        return SplitScreenCellClip(
          shape: widget.shape,
          borderRadius: widget.borderRadius,
          child: Semantics(
            button: true,
            selected: isSelected,
            label: cell == null
                ? context.l10n.videoEditorLayoutCellEmptySemanticLabel(number)
                : context.l10n.videoEditorLayoutCellSemanticLabel(number),
            // The badge says it on screen; a screen reader hears it here.
            value: cell == null
                ? null
                : context.l10n.libraryClipDuration(
                    cell.playbackDuration.toFormattedSeconds(),
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
                      left: badge.left,
                      right: badge.right,
                      top: badge.top,
                      bottom: badge.bottom,
                      child: _DurationBadge(duration: cell.playbackDuration),
                    ),
                  if (!widget.shape.isRectangle)
                    SplitScreenCellOutline(
                      shape: widget.shape,
                      borderRadius: widget.borderRadius,
                      width: 2,
                      color: isSelected ? ring : VineTheme.transparent,
                    )
                  else
                    IgnorePointer(
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: widget.borderRadius,
                          border: Border.all(
                            width: 2,
                            color: isSelected ? ring : VineTheme.transparent,
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

  /// Where the duration badge goes in a cell of [size]: its bottom-left
  /// corner, or the bottom-right one when that needs less moving — another
  /// cell covers the left, or the cell's shape cuts it away.
  ({double? left, double? right, double? top, double? bottom}) _badgePlacement(
    Size size,
  ) {
    ({Offset offset, double moved}) at(Alignment corner) =>
        splitScreenBadgeOffset(
          shape: widget.shape,
          cell: size,
          badge: _DurationBadge.typicalSize,
          corner: corner,
          covered: widget.covered,
        );
    final left = at(Alignment.bottomLeft);
    if (left.moved == 0) return (left: 6, right: null, top: null, bottom: 6);
    final right = at(Alignment.bottomRight);
    if (right.moved == 0) return (left: null, right: 6, top: null, bottom: 6);
    final best = right.moved < left.moved ? right : left;
    return (
      left: best.offset.dx,
      right: null,
      top: best.offset.dy,
      bottom: null,
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

  /// About how much room the badge takes, for finding a place it fits.
  static const typicalSize = Size(44, 20);

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
