// ABOUTME: Copy style and Paste style for overlay layers: lifts a layer's
// ABOUTME: style onto the style clipboard and writes it onto one or several
// ABOUTME: layers as a single undo step (#10258).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/style_clipboard/style_clipboard_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/layer_style.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;

/// Puts the style [layer] shows at the playhead on the style clipboard.
void copyLayerStyle(BuildContext context, Layer layer) {
  if (!canCopyLayerStyle(layer)) return;
  final time = VideoEditorScope.of(context).playTimeNotifier.value;
  context.read<StyleClipboardCubit>().copyLayerStyle(
    LayerStyle.of(layer, at: time, boxSize: _boxSizeOf(layer)),
  );
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.videoEditorStyleCopied,
      duration: VideoEditorConstants.styleCopiedSnackBarDuration,
    ),
  );
}

/// Puts the copied layer style on every layer in [layerIds] that takes one,
/// as one undo step. Does nothing while no layer style is copied.
void pasteLayerStyle(BuildContext context, Set<String> layerIds) {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  final style = context.read<StyleClipboardCubit>().state.layerStyle;
  if (editor == null || !editor.mounted || style == null) return;
  // The editor-timeline total, not the player's: see `_animateLayer`.
  final totalDuration = context.read<ClipEditorBloc>().state.totalDuration;

  var changed = false;
  final layers = <Layer>[];
  for (final layer in editor.activeLayers) {
    if (!layerIds.contains(layer.id) || !canCopyLayerStyle(layer)) {
      layers.add(layer);
      continue;
    }
    changed = true;
    layers.add(
      style.applyTo(
        layer,
        canvasSize: scope.canvasRenderSize,
        totalDuration: totalDuration,
        boxSize: _boxSizeOf(layer),
      ),
    );
  }
  if (changed) editor.addHistory(layers: layers);
}

/// The size of the box [layer] is drawn in, which its mask is measured
/// against, or `null` while it is not laid out.
Size? _boxSizeOf(Layer layer) {
  final box = layer.repaintBoundaryKey.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.size;
}
