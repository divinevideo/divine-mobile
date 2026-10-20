part of 'split_screen_layout_cubit.dart';

/// Where the layout screen is in its life.
enum SplitScreenLayoutStatus {
  /// The user is picking a layout and filling its cells.
  editing,

  /// The layout is being rendered into a clip.
  applying,

  /// The layout is rendered; [SplitScreenLayoutState.result] holds the clip.
  applied,

  /// A render failed. The layout is as the user left it, ready to try again.
  failure,
}

/// One filled cell: the clip it shows and which part of it.
@immutable
class SplitScreenLayoutCell extends Equatable {
  const SplitScreenLayoutCell({
    required this.clip,
    this.alignment = Alignment.center,
    this.zoom = 1,
  });

  /// The clip as it was picked.
  final DivineVideoClip clip;

  /// Which part of the clip's frame the cell shows, the way [BoxFit.cover]
  /// places an image: the centre to begin with, moved by panning the cell.
  final Alignment alignment;

  /// How far the cell is zoomed into the clip, from 1 — the frame just
  /// covering the cell — up to [SplitScreenLayoutGeometry.maxZoom].
  final double zoom;

  /// How long the cell plays in the layout. A stop-motion set shorter than
  /// the shortest assembly is looped up to it when it is assembled — see
  /// [StopMotionRenderService.framesForMinOutputDuration].
  Duration get playbackDuration {
    final frames = clip.isStopMotion ? clip.stopMotionFrames : null;
    if (frames == null) return clip.playbackDuration;
    final assembled = StopMotionRenderService.framesForMinOutputDuration(
      frames,
    ).fold(Duration.zero, (total, frame) => total + frame.duration);
    return clip.copyWith(duration: assembled).playbackDuration;
  }

  SplitScreenLayoutCell copyWith({Alignment? alignment, double? zoom}) =>
      SplitScreenLayoutCell(
        clip: clip,
        alignment: alignment ?? this.alignment,
        zoom: zoom ?? this.zoom,
      );

  @override
  List<Object?> get props => [clip, alignment, zoom];
}

class SplitScreenLayoutState extends Equatable {
  const SplitScreenLayoutState({
    required this.frameAspectRatio,
    required this.borderColor,
    this.preset = SplitScreenLayoutPreset.sideBySide,
    this.gap = 0,
    this.cells = const [null, null, null, null],
    this.selectedCellIndex = 0,
    this.status = SplitScreenLayoutStatus.editing,
    this.applyRenderId,
    this.applyStep = 0,
    this.applyStepCount = 0,
    this.result,
  });

  /// Width / height of the video the layout splits.
  final double frameAspectRatio;

  final SplitScreenLayoutPreset preset;

  /// Space around and between the cells, as a fraction of the frame's shorter
  /// side.
  final double gap;

  /// The colour that shows in the gaps and wherever a cell is empty.
  final Color borderColor;

  /// One slot per cell of the largest layout. A layout with fewer cells only
  /// uses the first few, and keeps the rest — switching back to a bigger
  /// layout brings the clips that were there back.
  final List<SplitScreenLayoutCell?> cells;

  /// The cell the action bar acts on, always one of [preset]'s.
  final int selectedCellIndex;

  final SplitScreenLayoutStatus status;

  /// Progress-stream key of the render in flight while [status] is
  /// [SplitScreenLayoutStatus.applying].
  final String? applyRenderId;

  /// Which of [applyStepCount] renders is running, from 1.
  final int applyStep;

  final int applyStepCount;

  /// The clip the layout was rendered into, once [status] is
  /// [SplitScreenLayoutStatus.applied].
  final DivineVideoClip? result;

  /// The cells [preset] shows, filled or not.
  List<SplitScreenLayoutCell?> get activeCells =>
      cells.take(preset.cellCount).toList();

  /// Where each of [activeCells] sits, as fractions of the frame.
  List<Rect> get cellRects =>
      preset.cellRects(aspectRatio: frameAspectRatio, gap: gap);

  /// The cell [selectedCellIndex] points at, or `null` when it is empty.
  SplitScreenLayoutCell? get selectedCell => cells[selectedCellIndex];

  /// How many clips one pick can place: one for the selected cell, whether
  /// it is filled or not, and one for each other empty cell — those of the
  /// bigger layouts included, where clips wait until the user switches.
  int get pickableClipCount =>
      1 +
      [
        for (final (index, cell) in cells.indexed)
          if (index != selectedCellIndex && cell == null) index,
      ].length;

  /// Whether any cell holds a clip, which is what a layout needs to be placed.
  bool get canApply =>
      status != SplitScreenLayoutStatus.applying &&
      activeCells.any((cell) => cell != null);

  bool get isApplying => status == SplitScreenLayoutStatus.applying;

  SplitScreenLayoutState copyWith({
    SplitScreenLayoutPreset? preset,
    double? gap,
    Color? borderColor,
    List<SplitScreenLayoutCell?>? cells,
    int? selectedCellIndex,
    SplitScreenLayoutStatus? status,
    String? applyRenderId,
    bool clearApplyRenderId = false,
    int? applyStep,
    int? applyStepCount,
    DivineVideoClip? result,
  }) {
    return SplitScreenLayoutState(
      frameAspectRatio: frameAspectRatio,
      preset: preset ?? this.preset,
      gap: gap ?? this.gap,
      borderColor: borderColor ?? this.borderColor,
      cells: cells ?? this.cells,
      selectedCellIndex: selectedCellIndex ?? this.selectedCellIndex,
      status: status ?? this.status,
      applyRenderId: clearApplyRenderId
          ? null
          : applyRenderId ?? this.applyRenderId,
      applyStep: applyStep ?? this.applyStep,
      applyStepCount: applyStepCount ?? this.applyStepCount,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [
    frameAspectRatio,
    preset,
    gap,
    borderColor,
    cells,
    selectedCellIndex,
    status,
    applyRenderId,
    applyStep,
    applyStepCount,
    result,
  ];
}
