// ABOUTME: Overlay controls for the video editor tune adjustments.
// ABOUTME: Contains the top close/done toolbar over the video preview.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Overlay controls for the tune editor.
///
/// Shows the shared close/done toolbar over the video preview and forwards a
/// tap on the preview area to a play/pause toggle (the tune sub-editor doesn't
/// forward `onTap`).
class VideoEditorTuneOverlayControls extends StatelessWidget {
  const VideoEditorTuneOverlayControls({super.key});

  /// Builds the new `activeTuneAdjustments` list for committing an Adjust
  /// session as a timeline *set*.
  ///
  /// [editorMatrix] is the tune editor's working matrix (all preset kinds; only
  /// the non-neutral ones become members). A new session ([editingSetId] `null`)
  /// appends a fresh set keyed by [newSetId]; an edit session replaces the
  /// members of [editingSetId] in [active] while preserving that set's time
  /// window. Returns `null` when a new session changed nothing (no bar to add).
  ///
  /// Each member gets a unique per-instance id and records its set id / preset
  /// kind in `meta` so the timeline can group and re-label it.
  @visibleForTesting
  static List<TuneAdjustmentMatrix>? computeTuneSetCommit({
    required List<TuneAdjustmentMatrix> editorMatrix,
    required List<TuneAdjustmentMatrix> active,
    required String? editingSetId,
    required String newSetId,
  }) {
    final setId = editingSetId ?? newSetId;

    // Preserve the window when editing an existing set.
    TuneAdjustmentMatrix? windowSource;
    if (editingSetId != null) {
      for (final m in active) {
        if (m.tuneSetId == editingSetId) {
          windowSource = m;
          break;
        }
      }
    }

    // Only the time window is carried over from the edited set; fade fields
    // (enter/exitDuration, enter/exitCurve) are intentionally dropped because
    // nothing sets tune fades today. If tune fades are ever added, forward them
    // from [windowSource] here so editing a set preserves them (as
    // duplicate/split already do via copyWith).
    final members = [
      for (final m in editorMatrix)
        if (m.value != 0)
          m.copyWith(
            id: TuneSet.memberId(kind: m.id, setId: setId),
            startTime: windowSource?.startTime,
            endTime: windowSource?.endTime,
            meta: TuneSet.metaFor(setId: setId, kind: m.id),
          ),
    ];

    // A new session appends a fresh set at the end; if nothing changed there is
    // no bar to add.
    if (editingSetId == null) {
      if (members.isEmpty) return null;
      return [...active.map((m) => m.copy()), ...members];
    }

    // An edit replaces the set's members in place, preserving its position in
    // the list (and therefore its render order relative to other sets).
    // Neutralising every adjustment leaves no members, removing the set.
    final result = <TuneAdjustmentMatrix>[];
    var replaced = false;
    for (final m in active) {
      if (m.tuneSetId != setId) {
        result.add(m.copy());
        continue;
      }
      if (!replaced) {
        result.addAll(members);
        replaced = true;
      }
    }
    if (!replaced) result.addAll(members);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        Semantics(
          button: true,
          label: context.l10n.videoEditorPlayPauseSemanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<VideoEditorMainBloc>().add(
              const VideoEditorPlaybackToggleRequested(),
            ),
          ),
        ),
        const _TopBarContent(),
      ],
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VideoEditorTuneBloc>();
    final scope = VideoEditorScope.of(context);

    return Align(
      alignment: .topCenter,
      child: VideoEditorToolbar(
        closeSemanticLabel: context.l10n
            .videoEditorDiscardToolChangesSemanticLabel(
              context.l10n.videoEditorTuneLabel,
            ),
        doneSemanticLabel: context.l10n
            .videoEditorApplyToolChangesSemanticLabel(
              context.l10n.videoEditorTuneLabel,
            ),
        onClose: () {
          bloc.add(const VideoEditorTuneCancelled());
          scope.tuneEditor?.close();
        },
        onDone: () => _commit(bloc, scope),
      ),
    );
  }

  /// Commits this session's non-neutral adjustments as a timeline *set*.
  ///
  /// Each set is grouped by [VideoEditorConstants.tuneSetIdMetaKey] and rendered
  /// as a single timeline bar sharing one time window; members get a unique
  /// per-instance id (so multiple sets, or multiple segments of the same kind,
  /// coexist) with the preset kind recorded in
  /// [VideoEditorConstants.tuneKindMetaKey]. A new session appends a fresh set;
  /// an edit session ([VideoEditorTuneState.editingSetId]) replaces the set's
  /// adjustments in place, preserving its time window.
  ///
  /// The editor's own `done()` (via `openTuneEditor`) instead appends its full
  /// returned matrix to `activeTuneAdjustments`, which both doubles adjustments
  /// on re-open and can't express sets. We discard that with `close()` and
  /// write our own history entry via the main editor's `addHistory` (the same
  /// public API the timeline/filter paths already use).
  void _commit(VideoEditorTuneBloc bloc, VideoEditorScope scope) {
    final editorMatrix = scope.tuneEditor?.tuneAdjustmentMatrix;
    final editingSetId = bloc.state.editingSetId;
    bloc.add(const VideoEditorTuneConfirmed());
    scope.tuneEditor?.close();
    if (editorMatrix == null) return;

    final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
      editorMatrix: editorMatrix,
      active:
          scope.editor?.stateManager.activeTuneAdjustments ??
          const <TuneAdjustmentMatrix>[],
      editingSetId: editingSetId,
      newSetId: TuneSet.newId(),
    );
    if (result != null) {
      scope.editor?.addHistory(tuneAdjustments: result);
    }
  }
}
