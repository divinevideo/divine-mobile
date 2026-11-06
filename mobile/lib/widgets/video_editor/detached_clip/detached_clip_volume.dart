// ABOUTME: Writes a detached clip's volume onto its layer, as the timeline's
// ABOUTME: volume panel does when one of its arcs is let go or tapped.

import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ProImageEditorState, WidgetLayer;

/// Writes [volume] onto the clip detached onto the canvas as the layer
/// [layerId], as one editor-history entry.
///
/// The volume lives in the clip the layer carries, which is what the canvas
/// player and the export both play it at. Writes nothing when the clip
/// already plays at [volume]: an undo step that undoes nothing reads as a
/// broken undo.
void setDetachedClipVolume(
  ProImageEditorState editor,
  String layerId,
  double volume,
) {
  final index = editor.activeLayers.indexWhere((l) => l.id == layerId);
  if (index < 0) return;
  final layer = editor.activeLayers[index];
  if (layer is! WidgetLayer) return;

  final meta = DetachedClipLayerData.metaOf(layer);
  if (DetachedClipLayerData.volumeOf(meta) == volume) return;
  final updated = DetachedClipLayerData.withVolume(meta, volume);
  if (updated == null) return;

  editor.replaceLayer(
    index: index,
    layer: detachedClipLayerWithMeta(layer, updated),
  );
}
