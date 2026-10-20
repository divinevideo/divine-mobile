// ABOUTME: Drives the split-screen layout screen: the layout, its gap and
// ABOUTME: border colour, the clip in each cell, and the render that places it

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart' show Alignment, BoxFit;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/split_screen_layout_render_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:unified_logger/unified_logger.dart';

part 'split_screen_layout_state.dart';

/// Renders the layout into one clip — see
/// [SplitScreenLayoutRenderService.render].
typedef SplitScreenRenderLayoutFn = Future<DivineVideoClip?> Function({
  required List<SplitScreenRenderCell> cells,
  required model.AspectRatio aspectRatio,
  required Color backgroundColor,
  required String taskId,
});

/// Assembles a stop-motion set into a playable clip — see
/// [StopMotionRenderService.materialize].
typedef SplitScreenMaterializeFn = Future<DivineVideoClip?> Function(
  DivineVideoClip clip, {
  String? taskId,
});

/// Bakes the key a take was recorded with into its file — the clip manager's
/// bake, which a take shot for a cell can still be waiting on.
typedef SplitScreenBakeChromaKeyFn = Future<DivineVideoClip> Function(
  DivineVideoClip clip,
);

/// Hands files nothing will reference to the editor's deferred cleanup.
typedef SplitScreenDeferFileCleanupFn = void Function(Iterable<String?> paths);

void _noopDeferFileCleanup(Iterable<String?> paths) {}

/// Owns a split-screen layout while the user builds it.
///
/// Everything stays in memory until [apply]: picking, panning and pinching
/// only change this state, and the render runs once, when the user confirms.
/// That keeps a half-built layout free — no file is written for a clip the
/// user replaces a moment later — and lets a failed render leave every choice
/// in place for a second try.
class SplitScreenLayoutCubit extends Cubit<SplitScreenLayoutState>
    with CloseGuardedEmit<SplitScreenLayoutState> {
  SplitScreenLayoutCubit({
    required model.AspectRatio aspectRatio,
    required Color borderColor,
    SplitScreenRenderLayoutFn? renderLayout,
    SplitScreenMaterializeFn? materializeStopMotionClip,
    SplitScreenBakeChromaKeyFn? bakeCapturedChromaKey,
    SplitScreenDeferFileCleanupFn? deferFileCleanup,
  }) : _aspectRatio = aspectRatio,
       _renderLayout = renderLayout ?? SplitScreenLayoutRenderService.render,
       _materializeStopMotionClip =
           materializeStopMotionClip ?? StopMotionRenderService.materialize,
       _bakeCapturedChromaKey = bakeCapturedChromaKey,
       _deferFileCleanup = deferFileCleanup ?? _noopDeferFileCleanup,
       super(
         SplitScreenLayoutState(
           frameAspectRatio: aspectRatio.value,
           borderColor: borderColor.withValues(alpha: 1),
         ),
       );

  final model.AspectRatio _aspectRatio;
  final SplitScreenRenderLayoutFn _renderLayout;
  final SplitScreenMaterializeFn _materializeStopMotionClip;

  /// `null` when nothing is wired to bake recorded chroma keys, which leaves a
  /// pending take raw — the same default as the clip editor's.
  final SplitScreenBakeChromaKeyFn? _bakeCapturedChromaKey;
  final SplitScreenDeferFileCleanupFn _deferFileCleanup;

  void presetSelected(SplitScreenLayoutPreset preset) {
    if (state.isApplying) return;
    emit(
      state.copyWith(
        preset: preset,
        selectedCellIndex: state.selectedCellIndex.clamp(
          0,
          preset.cellCount - 1,
        ),
      ),
    );
  }

  void gapChanged(double gap) {
    if (state.isApplying) return;
    emit(state.copyWith(gap: gap.clamp(0, SplitScreenLayoutGeometry.maxGap)));
  }

  /// The video has no alpha channel, so the colour is stored opaque — the
  /// preview then shows the shade the render will.
  void borderColorChanged(Color color) {
    if (state.isApplying) return;
    emit(state.copyWith(borderColor: color.withValues(alpha: 1)));
  }

  void cellSelected(int index) {
    if (state.isApplying || index < 0 || index >= state.preset.cellCount) {
      return;
    }
    emit(state.copyWith(selectedCellIndex: index));
  }

  /// Puts [clips] into the layout, the first into the selected cell and the
  /// rest into the empty cells after it, wrapping round to the first.
  ///
  /// Picking several clips at once is how a whole grid gets filled in one go.
  /// What the layout has no cell for waits in the cells of the bigger layouts,
  /// so switching to one shows those clips straight away. The selection then
  /// moves to the next empty cell, if there is one, so the next pick lands
  /// where the user is most likely to want it.
  ///
  /// Returns how many clips found no cell even in the biggest layout, so the
  /// screen can say so. A set whose stills are all gone is dropped without
  /// counting: there was nothing to place.
  int clipsPicked(List<DivineVideoClip> clips) {
    if (state.isApplying) return 0;
    final usable = [
      for (final clip in clips) ?StopMotionFrameOps.sanitizedClip(clip),
    ];
    if (usable.isEmpty) return 0;

    final shown = state.preset.cellCount;
    final start = state.selectedCellIndex;
    final targets = [
      start,
      for (var step = 1; step < shown; step++)
        if (state.cells[(start + step) % shown] == null) (start + step) % shown,
      for (var index = shown; index < state.cells.length; index++)
        if (state.cells[index] == null) index,
    ];

    final cells = List<SplitScreenLayoutCell?>.of(state.cells);
    final placed = usable.length < targets.length
        ? usable.length
        : targets.length;
    for (var i = 0; i < placed; i++) {
      cells[targets[i]] = SplitScreenLayoutCell(clip: usable[i]);
    }

    final nextEmpty = [
      for (var step = 1; step <= shown; step++) (start + step) % shown,
    ].where((index) => cells[index] == null).firstOrNull;

    emit(
      state.copyWith(
        cells: List.unmodifiable(cells),
        selectedCellIndex: nextEmpty ?? start,
      ),
    );
    return usable.length - placed;
  }

  /// Empties the selected cell. Its clip stays in the library, and the cell
  /// shows the border colour until something else is picked for it.
  void selectedCellCleared() {
    if (state.isApplying || state.selectedCell == null) return;
    final cells = List<SplitScreenLayoutCell?>.of(state.cells)
      ..[state.selectedCellIndex] = null;
    emit(state.copyWith(cells: List.unmodifiable(cells)));
  }

  /// Reframes the footage in cell [index], laid out at [cellSize], for one
  /// step of a pan or pinch: the fingers were at [focalPoint], moved by
  /// [delta], and the pinch asks for [zoom] — see [splitScreenReframed].
  void cellReframed(
    int index, {
    required Offset focalPoint,
    required Offset delta,
    required double zoom,
    required Size cellSize,
  }) {
    if (state.isApplying || index < 0 || index >= state.preset.cellCount) {
      return;
    }
    final cell = state.cells[index];
    if (cell == null) return;
    final framing = splitScreenReframed(
      alignment: cell.alignment,
      zoom: cell.zoom,
      targetZoom: zoom,
      focalPoint: focalPoint,
      delta: delta,
      cellSize: cellSize,
      sourceAspectRatio: cell.clip.videoAspectRatio,
    );
    if (framing.alignment == cell.alignment && framing.zoom == cell.zoom) {
      return;
    }
    final cells = List<SplitScreenLayoutCell?>.of(state.cells)
      ..[index] = cell.copyWith(
        alignment: framing.alignment,
        zoom: framing.zoom,
      );
    emit(state.copyWith(cells: List.unmodifiable(cells)));
  }

  /// Renders the layout into one clip.
  ///
  /// A stop-motion set is assembled into a video first, one render each, so
  /// the progress overlay counts those as steps before the layout's own. On
  /// success the state carries the clip in [SplitScreenLayoutState.result];
  /// on failure every file written so far is handed to cleanup and the layout
  /// is left exactly as it was.
  Future<void> apply() async {
    if (!state.canApply) return;

    final rects = state.cellRects;
    final picked = [
      for (var i = 0; i < rects.length; i++)
        if (state.cells[i] case final cell?) (cell: cell, rect: rects[i]),
    ];
    final stepCount =
        picked.where((entry) => entry.cell.clip.isStopMotion).length + 1;
    final base = 'split_layout_${DateTime.now().microsecondsSinceEpoch}';
    final written = <String?>[];
    var step = 0;

    String startStep() {
      step++;
      final renderId = '$base-$step';
      emitIfOpen(
        state.copyWith(
          status: SplitScreenLayoutStatus.applying,
          applyRenderId: renderId,
          applyStep: step,
          applyStepCount: stepCount,
        ),
      );
      return renderId;
    }

    void cleanUp(Iterable<String?> paths) {
      _deferFileCleanup(List.of(paths));
      written.clear();
    }

    try {
      final ready = <SplitScreenRenderCell>[];
      for (final (:cell, :rect) in picked) {
        final clip = await _clipForCell(
          cell.clip,
          startStep: startStep,
          written: written,
        );
        if (isClosed) {
          cleanUp(written);
          return;
        }
        ready.add((
          clip: clip,
          rect: rect,
          alignment: cell.alignment,
          zoom: cell.zoom,
        ));
      }

      final rendered = await _renderLayout(
        cells: ready,
        aspectRatio: _aspectRatio,
        backgroundColor: state.borderColor,
        taskId: startStep(),
      );
      // An assembled set is baked into the layout now; nothing points at it.
      cleanUp(written);
      if (rendered == null) throw const _SplitScreenRenderFailed('layout');
      if (isClosed) {
        cleanUp(rendered.ownedFilePaths);
        return;
      }

      Log.info(
        '🔲 Rendered ${ready.length} clip(s) in a ${state.preset.name} '
        'layout into ${rendered.duration.inMilliseconds}ms',
        name: 'SplitScreenLayoutCubit',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: SplitScreenLayoutStatus.applied,
          clearApplyRenderId: true,
          result: rendered,
        ),
      );
    } on RenderCanceledException {
      // Teardown cancels the native task under it; nothing to report.
      cleanUp(written);
      emitIfOpen(
        state.copyWith(
          status: SplitScreenLayoutStatus.editing,
          clearApplyRenderId: true,
        ),
      );
    } catch (e, stackTrace) {
      cleanUp(written);
      if (isClosed) return;
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: 'SplitScreenLayoutCubit.apply'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to render the split-screen layout: $e',
        name: 'SplitScreenLayoutCubit',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: SplitScreenLayoutStatus.failure,
          clearApplyRenderId: true,
        ),
      );
    }
  }

  /// [clip] made ready to play in a cell: a set assembled into a video, which
  /// is a step of its own, and a recorded key baked in.
  ///
  /// A file written on the way goes into [written], so a later failure can
  /// clean it up.
  Future<DivineVideoClip> _clipForCell(
    DivineVideoClip clip, {
    required String Function() startStep,
    required List<String?> written,
  }) async {
    var ready = clip;
    if (ready.isStopMotion) {
      final materialized = await _materializeStopMotionClip(
        ready,
        taskId: startStep(),
      );
      if (materialized == null) {
        throw const _SplitScreenRenderFailed('stop-motion set');
      }
      written.add(materialized.video?.file?.path);
      ready = materialized;
    }

    final bake = _bakeCapturedChromaKey;
    if (bake != null && ready.hasPendingCaptureChromaKey) {
      ready = ready.withCapturedChromaKeyBake(await bake(ready));
    }
    if (ready.video == null) throw const _SplitScreenRenderFailed('clip file');
    return ready;
  }
}

/// A render that produced nothing, as opposed to one that threw.
class _SplitScreenRenderFailed implements Exception {
  const _SplitScreenRenderFailed(this.what);

  final String what;

  @override
  String toString() => 'SplitScreenRenderFailed: $what';
}
