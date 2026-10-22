import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/style_clipboard/style_clipboard_cubit.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/sticker_group.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/combine_sticker_layers.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/layer_style_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, PaintLayer, WidgetLayer;

/// What the selected layers are, for naming them in the bar.
enum _SelectionKind {
  /// Every selected layer is a drawing.
  drawings,

  /// Every selected layer is a sticker.
  stickers,

  /// The selection holds texts or visualizers, mixes kinds, or is empty.
  layers,
}

/// Action bar shown while the timeline is in layer multi-select mode.
///
/// Surfaces the selection count plus Combine / Paste style / Delete / Done
/// actions. Any layer that takes a style can be selected; Combine is offered
/// only for two or more drawings, or two or more stickers, that can be
/// combined, and Paste style once a layer style is copied.
class TimelineLayerMultiSelectControls extends StatelessWidget {
  const TimelineLayerMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final (selectedCount, mergeKind, kind) = context.select((
      TimelineOverlayBloc b,
    ) {
      final layers = b.state.multiSelectedLayers;
      return (
        b.state.multiSelectedLayerIds.length,
        sharedLayerMergeKind(layers),
        _selectionKindOf(layers),
      );
    });
    final hasCopiedStyle = context.select(
      (StyleClipboardCubit cubit) => cubit.state.layerStyle != null,
    );
    final l10n = context.l10n;

    final canCombine = selectedCount >= 2 && mergeKind != null;
    final canPasteStyle = hasCopiedStyle && selectedCount >= 1;
    final canDelete = selectedCount >= 1;

    return TimelineActionBar(
      countLabel: switch (kind) {
        .drawings => l10n.videoEditorLayerMultiSelectCountLabel(selectedCount),
        .stickers => l10n.videoEditorStickerMultiSelectCountLabel(
          selectedCount,
        ),
        .layers => l10n.videoEditorLayersMultiSelectCountLabel(selectedCount),
      },
      actions: [
        TimelineActionButton(
          icon: .stackSimple,
          label: l10n.videoEditorCombineLabel,
          semanticLabel: mergeKind == .sticker
              ? l10n.videoEditorCombineStickerLayersSemanticLabel
              : l10n.videoEditorCombineDrawLayersSemanticLabel,
          onPressed: canCombine ? () => _combine(context, mergeKind) : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .paintBucket,
          label: l10n.videoEditorPasteStyleLabel,
          semanticLabel: l10n.videoEditorPasteStyleSelectedLayersSemanticLabel,
          onPressed: canPasteStyle ? () => _pasteStyle(context) : null,
        ),
        TimelineActionButton(
          icon: .trash,
          label: l10n.videoEditorDeleteLabel,
          semanticLabel: switch (kind) {
            .drawings => l10n.videoEditorDeleteSelectedDrawingsSemanticLabel,
            .stickers => l10n.videoEditorDeleteSelectedStickersSemanticLabel,
            .layers => l10n.videoEditorDeleteSelectedLayersSemanticLabel,
          },
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: l10n.videoEditorDoneLabel,
          semanticLabel: switch (kind) {
            .drawings => l10n.videoEditorLayerMultiSelectDoneSemanticLabel,
            .stickers => l10n.videoEditorStickerMultiSelectDoneSemanticLabel,
            .layers => l10n.videoEditorLayersMultiSelectDoneSemanticLabel,
          },
          onPressed: () => context.read<TimelineOverlayBloc>().add(
            const TimelineOverlayLayerMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  static _SelectionKind _selectionKindOf(List<Layer> layers) {
    if (layers.isEmpty) return .layers;
    if (layers.every((l) => l is PaintLayer && !l.isCensor)) return .drawings;
    if (layers.every(
      (l) =>
          l is WidgetLayer &&
          isStickerLayerMeta(l.exportConfigs.meta ?? l.meta),
    )) {
      return .stickers;
    }
    return .layers;
  }

  /// Puts the copied layer style on every selected layer as one undo step,
  /// then exits multi-select mode.
  void _pasteStyle(BuildContext context) {
    final overlayBloc = context.read<TimelineOverlayBloc>();
    pasteLayerStyle(context, overlayBloc.state.multiSelectedLayerIds);
    overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
  }

  /// Combines the selected layers into one, then exits multi-select mode and
  /// selects the combined layer.
  ///
  /// Drawings go through [ProImageEditorState.mergeSelectedLayers]; stickers
  /// through [combineStickerLayers], committed as a single undo step.
  void _combine(BuildContext context, LayerMergeKind? kind) {
    final editor = VideoEditorScope.of(context).editor;
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final ids = overlayBloc.state.multiSelectedLayerIds;
    if (editor == null || ids.length < 2) return;

    final String? combinedId;
    if (kind == LayerMergeKind.sticker) {
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
