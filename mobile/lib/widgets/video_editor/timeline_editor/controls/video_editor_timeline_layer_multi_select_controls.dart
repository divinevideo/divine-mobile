import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/combine_sticker_layers.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';

/// Action bar shown while the timeline is in layer multi-select mode.
///
/// Surfaces the selection count plus Combine / Delete / Done actions for the
/// kind being selected — drawings or stickers. Combine is gated on the
/// selection so the user can never combine a single layer.
class TimelineLayerMultiSelectControls extends StatelessWidget {
  const TimelineLayerMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final (selectedCount, kind) = context.select(
      (TimelineOverlayBloc b) =>
          (b.state.multiSelectedLayerIds.length, b.state.layerMultiSelectKind),
    );
    final isSticker = kind == .sticker;
    final l10n = context.l10n;

    final canCombine = selectedCount >= 2;
    final canDelete = selectedCount >= 1;

    return TimelineActionBar(
      countLabel: isSticker
          ? l10n.videoEditorStickerMultiSelectCountLabel(selectedCount)
          : l10n.videoEditorLayerMultiSelectCountLabel(selectedCount),
      actions: [
        TimelineActionButton(
          icon: .stackSimple,
          label: l10n.videoEditorCombineLabel,
          semanticLabel: isSticker
              ? l10n.videoEditorCombineStickerLayersSemanticLabel
              : l10n.videoEditorCombineDrawLayersSemanticLabel,
          onPressed: canCombine ? () => _combine(context) : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .trash,
          label: l10n.videoEditorDeleteLabel,
          semanticLabel: isSticker
              ? l10n.videoEditorDeleteSelectedStickersSemanticLabel
              : l10n.videoEditorDeleteSelectedDrawingsSemanticLabel,
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: l10n.videoEditorDoneLabel,
          semanticLabel: isSticker
              ? l10n.videoEditorStickerMultiSelectDoneSemanticLabel
              : l10n.videoEditorLayerMultiSelectDoneSemanticLabel,
          onPressed: () => context.read<TimelineOverlayBloc>().add(
            const TimelineOverlayLayerMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  /// Combines the selected layers into one, then exits multi-select mode and
  /// selects the combined layer.
  ///
  /// Drawings go through [ProImageEditorState.mergeSelectedLayers]; stickers
  /// through [combineStickerLayers], committed as a single undo step.
  void _combine(BuildContext context) {
    final editor = VideoEditorScope.of(context).editor;
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final ids = overlayBloc.state.multiSelectedLayerIds;
    if (editor == null || ids.length < 2) return;

    final String? combinedId;
    if (overlayBloc.state.layerMultiSelectKind == LayerMergeKind.sticker) {
      final result = combineStickerLayers(
        layers: editor.activeLayers,
        ids: ids,
      );
      if (result != null) editor.addHistory(layers: result.layers);
      combinedId = result?.combined.id;
    } else {
      editor.unselectAllLayers();
      for (final id in ids) {
        editor.selectLayerById(id, enableMultiSelect: true);
      }
      final merged = editor.mergeSelectedLayers();
      editor.clearLayerSelection();
      combinedId = merged?.id;
    }

    overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
    if (combinedId != null) {
      overlayBloc.add(TimelineOverlayItemSelected(combinedId));
    }
  }

  /// Removes the selected layers from the canvas as a single undo step, then
  /// exits multi-select mode.
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
