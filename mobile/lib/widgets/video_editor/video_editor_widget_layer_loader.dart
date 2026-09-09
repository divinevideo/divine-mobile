// ABOUTME: Rebuilds every kind of WidgetLayer the video editor creates from
// ABOUTME: the meta it was exported with (stickers, detached clips)

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

/// The editor's `widgetLoader`: rebuilds a `WidgetLayer` from the meta map that
/// survived an export / draft round-trip.
///
/// `WidgetLayer` carries no type of its own across that round-trip — the widget
/// is gone and only `exportConfigs.meta` comes back — so the kind is read out
/// of the map. Anything unrecognised falls through to the sticker loader, which
/// is what every widget layer was before detached clips existed and what an
/// older draft's layers therefore still are.
Widget videoEditorWidgetLayerLoader(String id, {Map<String, dynamic>? meta}) {
  if (DetachedClipLayerData.isDetachedClipMeta(meta)) {
    return DetachedClipLayerView(meta: meta!);
  }
  return videoEditorStickerWidgetLoader(id, meta: meta);
}
