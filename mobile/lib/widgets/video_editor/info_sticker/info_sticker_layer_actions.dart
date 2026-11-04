// ABOUTME: Builds info sticker layers for the canvas and applies the changes
// ABOUTME: made in the info sticker sheet to one already there.

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A widget layer that shows [data], [width] canvas units wide.
///
/// The sticker is kept in both meta slots, like every widget layer the editor
/// makes, so it comes back from undo and from a draft.
WidgetLayer infoStickerWidgetLayer(
  InfoStickerData data, {
  required double width,
}) {
  final meta = data.toMeta();
  return WidgetLayer(
    width: width,
    widget: InfoStickerView(data: data),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meta: meta,
    ),
  );
}

/// Opens the info sticker sheet for [layer] and applies what was changed
/// there, keeping the layer where and as large as it is.
Future<void> editInfoStickerLayer(BuildContext context, Layer layer) async {
  final data = InfoStickerData.of(layer);
  if (data == null) return;
  // Captured before the await: the timeline bar that opened the sheet can
  // unmount while the sheet is up, and the edit would be lost with it.
  final scope = VideoEditorScope.of(context);
  final picked = await showInfoStickerSheet(context, initial: data);
  if (picked == null || picked == data) return;

  final editor = scope.editor;
  if (editor == null) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;
  final current = editor.activeLayers[index];
  if (current is! WidgetLayer) return;

  final meta = picked.toMeta();
  editor.replaceLayer(
    index: index,
    layer: current.copyWith(
      widget: InfoStickerView(data: picked),
      meta: meta,
      exportConfigs: current.exportConfigs.copyWith(meta: meta),
    ),
  );
}
