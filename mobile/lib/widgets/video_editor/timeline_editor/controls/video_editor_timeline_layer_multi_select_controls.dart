import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';

/// Action bar shown while the timeline is in draw-layer multi-select mode.
///
/// Surfaces the selection count plus Combine / Delete / Done actions. Combine
/// is gated on the selection so the user can never combine a single drawing.
class TimelineLayerMultiSelectControls extends StatelessWidget {
  const TimelineLayerMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCount = context.select(
      (TimelineOverlayBloc b) => b.state.multiSelectedLayerIds.length,
    );

    final canCombine = selectedCount >= 2;
    final canDelete = selectedCount >= 1;

    return TimelineActionBar(
      countLabel: context.l10n.videoEditorLayerMultiSelectCountLabel(
        selectedCount,
      ),
      actions: [
        TimelineActionButton(
          icon: .stackSimple,
          label: context.l10n.videoEditorCombineLabel,
          semanticLabel: context.l10n.videoEditorCombineDrawLayersSemanticLabel,
          onPressed: canCombine ? () => _combine(context) : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .trash,
          label: context.l10n.videoEditorDeleteLabel,
          semanticLabel:
              context.l10n.videoEditorDeleteSelectedDrawingsSemanticLabel,
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: context.l10n.videoEditorDoneLabel,
          semanticLabel:
              context.l10n.videoEditorLayerMultiSelectDoneSemanticLabel,
          onPressed: () => context.read<TimelineOverlayBloc>().add(
            const TimelineOverlayLayerMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  /// Combines the selected draw layers into one via
  /// [ProImageEditorState.mergeSelectedLayers], then exits multi-select mode
  /// and selects the merged layer.
  void _combine(BuildContext context) {
    final editor = VideoEditorScope.of(context).editor;
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final ids = overlayBloc.state.multiSelectedLayerIds;
    if (editor == null || ids.length < 2) return;

    editor.unselectAllLayers();
    for (final id in ids) {
      editor.selectLayerById(id, enableMultiSelect: true);
    }
    final merged = editor.mergeSelectedLayers();
    editor.clearLayerSelection();

    overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
    if (merged != null) {
      overlayBloc.add(TimelineOverlayItemSelected(merged.id));
    }
  }

  /// Removes the selected draw layers from the canvas as a single undo step,
  /// then exits multi-select mode.
  void _delete(BuildContext context) {
    final editor = VideoEditorScope.of(context).editor;
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final ids = overlayBloc.state.multiSelectedLayerIds;
    if (editor == null || ids.isEmpty) return;

    final remaining = editor.activeLayers
        .where((layer) => !ids.contains(layer.id))
        .toList();
    editor.addHistory(layers: remaining);

    overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
  }
}
