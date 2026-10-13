// ABOUTME: Combines several sticker layers into one, keeping every sticker
// ABOUTME: exactly where, how large and how rotated it was on the canvas.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/sticker_group.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_group.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Combines the sticker layers in [layers] whose ids are in [ids] into one
/// `WidgetLayer` holding a [StickerGroupData].
///
/// The sticker counterpart of `ProImageEditorState.mergeSelectedLayers`:
/// sources that are not mergeable stickers ([isMergeableStickerLayer]) are
/// ignored, the combined layer takes the z-position of the top-most source,
/// and the other layers keep their order. A source that is itself a combined
/// sticker becomes a nested group, so combining again never loses a placement.
///
/// [sizeOf] returns a layer's rendered size before rotation, with its scale
/// applied; it defaults to [Layer.renderSize], which is only known while the
/// layer is laid out on the canvas.
///
/// Returns the new layer list and the combined layer, or `null` when fewer
/// than two mergeable stickers are selected or one of them has no size.
({List<Layer> layers, WidgetLayer combined})? combineStickerLayers({
  required List<Layer> layers,
  required Set<String> ids,
  Size? Function(Layer layer)? sizeOf,
}) {
  final sources = layers
      .where(
        (layer) => ids.contains(layer.id) && isMergeableStickerLayer(layer),
      )
      .cast<WidgetLayer>()
      .toList();
  if (sources.length < 2) return null;

  final placed = <({WidgetLayer layer, Size size, Object content})>[];
  for (final layer in sources) {
    final content = _contentOf(layer);
    final size = (sizeOf ?? _renderSize)(layer);
    if (content == null || size == null || size.isEmpty) return null;
    placed.add((layer: layer, size: size, content: content));
  }

  var bounds = _boundsOf(placed.first.layer, placed.first.size);
  for (final source in placed.skip(1)) {
    bounds = bounds.expandToInclude(_boundsOf(source.layer, source.size));
  }

  final group = StickerGroupData(
    size: bounds.size,
    children: [
      for (final (:layer, :size, :content) in placed)
        StickerGroupChild(
          sticker: content is StickerData ? content : null,
          group: content is StickerGroupData ? content : null,
          center: layer.offset - bounds.topLeft,
          size: size,
          rotation: layer.rotation,
          flipX: layer.flipX,
          flipY: layer.flipY,
          opacity: layer.opacity,
        ),
    ],
  );
  final meta = group.toMeta();
  final combined = WidgetLayer(
    offset: bounds.center,
    width: bounds.width,
    widget: VideoEditorStickerGroup(group: group),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meta: meta,
    ),
  );

  final sourceIds = {for (final source in sources) source.id};
  final topMostId = sources.last.id;
  return (
    layers: [
      for (final layer in layers)
        if (layer.id == topMostId)
          combined
        else if (!sourceIds.contains(layer.id))
          layer,
    ],
    combined: combined,
  );
}

Size? _renderSize(Layer layer) => layer.renderSize;

/// The [StickerData] or [StickerGroupData] a sticker layer shows.
Object? _contentOf(WidgetLayer layer) {
  final meta = layer.exportConfigs.meta ?? layer.meta;
  final group = StickerGroupData.fromMeta(meta);
  if (group != null) return group;
  try {
    return StickerData.fromJson(meta!);
  } on Object {
    return null;
  }
}

/// The axis-aligned box [layer] covers on the canvas when it is [size] large
/// before rotation. Mirroring a box around its centre leaves it in place.
Rect _boundsOf(Layer layer, Size size) {
  final cos = math.cos(layer.rotation).abs();
  final sin = math.sin(layer.rotation).abs();
  return Rect.fromCenter(
    center: layer.offset,
    width: size.width * cos + size.height * sin,
    height: size.width * sin + size.height * cos,
  );
}
