import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/style_clipboard/style_clipboard_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';

/// Action bar shown while the timeline is in multi-select mode.
///
/// Surfaces the selection count plus Merge / Boomerang / Paste style /
/// Delete / Done actions. Merge and Delete are gated on the selection so the
/// user can never merge a single clip or delete every clip, Boomerang on
/// neighbouring clips, since the way back retraces exactly the way there, and
/// Paste style waits for a copied clip style.
class TimelineMultiSelectControls extends StatelessWidget {
  const TimelineMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final (selectedCount, clipCount, isBusy, canBoomerangSelection) = context
        .select(
          (ClipEditorBloc b) => (
            b.state.selectedClipIds.length,
            b.state.clips.length,
            b.state.isMerging || b.state.isBoomeranging,
            b.state.canBoomerangSelection,
          ),
        );

    final hasCopiedStyle = context.select(
      (StyleClipboardCubit cubit) => cubit.state.clipStyle != null,
    );

    final canMerge = selectedCount >= 2 && !isBusy;
    final canBoomerang = canBoomerangSelection && !isBusy;
    final canPasteStyle = hasCopiedStyle && selectedCount >= 1 && !isBusy;
    final canDelete =
        selectedCount >= 1 && selectedCount < clipCount && !isBusy;

    return TimelineActionBar(
      countLabel: context.l10n.videoEditorMultiSelectCountLabel(selectedCount),
      actions: [
        TimelineActionButton(
          icon: .stackSimple,
          label: context.l10n.videoEditorMergeLabel,
          semanticLabel:
              context.l10n.videoEditorMergeSelectedClipsSemanticLabel,
          onPressed: canMerge ? () => _merge(context) : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .arrowUUpRight,
          label: context.l10n.videoEditorBoomerangLabel,
          semanticLabel:
              context.l10n.videoEditorBoomerangSelectedClipsSemanticLabel,
          onPressed: canBoomerang ? () => _boomerang(context) : null,
        ),
        TimelineActionButton(
          icon: .paintBucket,
          label: context.l10n.videoEditorPasteStyleLabel,
          semanticLabel:
              context.l10n.videoEditorPasteStyleSelectedClipsSemanticLabel,
          onPressed: canPasteStyle ? () => _pasteStyle(context) : null,
        ),
        TimelineActionButton(
          icon: .trash,
          label: context.l10n.videoEditorDeleteLabel,
          semanticLabel:
              context.l10n.videoEditorDeleteSelectedClipsSemanticLabel,
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: context.l10n.videoEditorDoneLabel,
          semanticLabel: context.l10n.videoEditorMultiSelectDoneSemanticLabel,
          onPressed: () => context.read<ClipEditorBloc>().add(
            const ClipEditorMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  void _merge(BuildContext context) {
    context.read<ClipEditorBloc>().add(
      const ClipEditorSelectedClipsMergeRequested(),
    );
  }

  void _boomerang(BuildContext context) {
    context.read<ClipEditorBloc>().add(
      const ClipEditorSelectedClipsBoomerangRequested(),
    );
  }

  /// Puts the copied clip style on every selected clip, as one undo step, and
  /// leaves multi-select.
  void _pasteStyle(BuildContext context) {
    final style = context.read<StyleClipboardCubit>().state.clipStyle;
    final bloc = context.read<ClipEditorBloc>();
    if (style == null) return;
    bloc
      ..add(
        ClipEditorStylePasteRequested(
          clipIds: bloc.state.selectedClipIds.toList(),
          style: style,
        ),
      )
      ..add(const ClipEditorMultiSelectCancelled());
  }

  void _delete(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    // Land the playhead on the first cut the deletion leaves. Dispatched
    // before the removal: the player reloads at the playhead the removal
    // finds.
    final cutPosition = clipDeletionCutPosition(
      bloc.state.clips,
      removedClipIds: bloc.state.selectedClipIds,
    );
    if (cutPosition != null) {
      context.read<VideoEditorMainBloc>().add(
        VideoEditorPositionChanged(cutPosition),
      );
    }
    // The bloc owns the clip-list mutation; the scaffold's removed-result
    // listener rebases markers and commits the new list to editor history.
    bloc.add(const ClipEditorSelectedClipsRemoved());
  }
}

/// Action bar shown while a stop-motion composition is in frame multi-select
/// mode: selection count plus hold / Reverse / Duplicate / Delete / Done
/// actions on the selected stills. Delete is gated so at least one still
/// always remains.
class TimelineFrameMultiSelectControls extends StatelessWidget {
  const TimelineFrameMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final ({String clipId, int frameCount, Set<int> selected})? data = context
        .select((ClipEditorBloc b) {
          final state = b.state;
          if (!isStopMotionComposition(state.clips)) return null;
          final clip = state.clips.first;
          return (
            clipId: clip.id,
            frameCount: clip.stopMotionFrames?.length ?? 0,
            selected: state.selectedFrameIndexes,
          );
        });

    if (data == null) return const SizedBox.shrink();

    final selectedCount = data.selected.length;
    final hasSelection = selectedCount >= 1;
    final canDelete = hasSelection && selectedCount < data.frameCount;
    final canReverse = selectedCount >= 2;

    return TimelineActionBar(
      countLabel: context.l10n.videoEditorMultiSelectCountLabel(selectedCount),
      actions: [
        TimelineActionButton(
          icon: .imagesSquare,
          label: context.l10n.videoEditorStopMotionFramesPerImageButtonLabel,
          semanticLabel: context.l10n.videoEditorStopMotionFramesPerImageLabel,
          onPressed: hasSelection
              ? () => editStopMotionFramesHold(
                  context,
                  clipId: data.clipId,
                  frameIndexes: data.selected,
                )
              : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .arrowCounterClockwise,
          label: context.l10n.videoEditorReverseLabel,
          semanticLabel:
              context.l10n.videoEditorReverseSelectedFramesSemanticLabel,
          onPressed: canReverse ? () => _reverse(context) : null,
        ),
        TimelineActionButton(
          icon: .copy,
          label: context.l10n.videoEditorDuplicateLabel,
          semanticLabel:
              context.l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
          onPressed: hasSelection ? () => _duplicate(context) : null,
        ),
        TimelineActionButton(
          icon: .trash,
          label: context.l10n.videoEditorDeleteLabel,
          semanticLabel:
              context.l10n.videoEditorDeleteSelectedFramesSemanticLabel,
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: context.l10n.videoEditorDoneLabel,
          semanticLabel: context.l10n.videoEditorMultiSelectDoneSemanticLabel,
          onPressed: () => context.read<ClipEditorBloc>().add(
            const ClipEditorMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  /// Reverses the selected stills among their own slots. The selection keeps
  /// pointing at the same positions (now holding the reversed stills), so the
  /// mode stays active for follow-up actions like a block move.
  void _reverse(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (!isStopMotionComposition(state.clips)) return;
    final clip = state.clips.first;
    final frames = clip.stopMotionFrames ?? const [];

    commitStopMotionFrames(
      context,
      clipId: clip.id,
      frames: StopMotionFrameOps.reverseFrames(
        frames,
        state.selectedFrameIndexes,
      ),
    );
  }

  /// Repeats the selected stills right after the last of them, then moves the
  /// selection onto the copies — so the highlight shows what was just created
  /// and a follow-up drag or hold change acts on the new stills, not the
  /// originals.
  void _duplicate(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (!isStopMotionComposition(state.clips)) return;
    final clip = state.clips.first;
    final frames = clip.stopMotionFrames ?? const [];
    final selection = state.selectedFrameIndexes;

    final duplicated = StopMotionFrameOps.duplicateFrames(frames, selection);
    if (identical(duplicated, frames)) return;

    final committed = commitStopMotionFrames(
      context,
      clipId: clip.id,
      frames: duplicated,
    );
    if (!committed) return;

    final firstCopy = StopMotionFrameOps.duplicateInsertIndex(selection);
    bloc.add(
      ClipEditorFrameMultiSelectionSet({
        for (var i = 0; i < selection.length; i++) firstCopy + i,
      }),
    );
  }

  void _delete(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (!isStopMotionComposition(state.clips)) return;
    final clip = state.clips.first;
    final frames = clip.stopMotionFrames ?? const [];

    commitStopMotionFrames(
      context,
      clipId: clip.id,
      frames: StopMotionFrameOps.removeFrames(
        frames,
        state.selectedFrameIndexes,
      ),
    );
    bloc.add(const ClipEditorMultiSelectCancelled());
  }
}
