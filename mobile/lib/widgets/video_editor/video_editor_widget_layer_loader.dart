// ABOUTME: Rebuilds every kind of WidgetLayer the video editor creates from
// ABOUTME: the meta it was exported with (stickers, detached clips, audio
// ABOUTME: visualizers, info and social stickers)

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_layer_view.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
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
  if (AudioVisualizerLayerData.fromMeta(meta) case final visualizer?) {
    return AudioVisualizerLayerView(data: visualizer);
  }
  if (InfoStickerData.isInfoStickerMeta(meta)) {
    final info = InfoStickerData.fromMeta(meta);
    // A kind this version does not know shows nothing rather than being read
    // as an image sticker.
    return info == null ? const SizedBox.shrink() : InfoStickerView(data: info);
  }
  if (SocialStickerData.isSocialStickerMeta(meta)) {
    final social = SocialStickerData.fromMeta(meta);
    return social == null
        ? const SizedBox.shrink()
        : SocialStickerView(data: social);
  }
  return videoEditorStickerWidgetLoader(id, meta: meta);
}
