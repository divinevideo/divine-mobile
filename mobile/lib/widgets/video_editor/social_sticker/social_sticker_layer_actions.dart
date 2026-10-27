// ABOUTME: Builds social sticker layers for the canvas and applies the changes
// ABOUTME: made in the social sticker sheet to one already there.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A widget layer that shows [data], [width] canvas units wide.
///
/// The sticker is kept in both meta slots, like every widget layer the editor
/// makes, so it comes back from undo and from a draft.
WidgetLayer socialStickerWidgetLayer(
  SocialStickerData data, {
  required double width,
}) {
  final meta = data.toMeta();
  return WidgetLayer(
    width: width,
    widget: SocialStickerView(data: data),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meta: meta,
    ),
  );
}

/// The hashtags the post carries besides those of the sticker on the layer
/// [exceptLayerId]: the creator's own [postTags] and those of the other
/// hashtag stickers among [layers].
Set<String> socialStickerOtherHashtags({
  required Set<String> postTags,
  required Iterable<Layer> layers,
  String? exceptLayerId,
}) => {
  ...postTags,
  ...SocialStickerCredits.of(
    layers.where((layer) => layer.id != exceptLayerId),
  ).hashtags,
};

/// Opens the social sticker sheet for [layer] and applies what was changed
/// there, keeping the layer where and as large as it is. A sound credit can
/// switch to any of [sounds], the sounds in the video now.
Future<void> editSocialStickerLayer(
  BuildContext context,
  Layer layer, {
  List<AudioEvent> sounds = const [],
}) async {
  final data = SocialStickerData.of(layer);
  if (data == null) return;
  // Captured before the await: the timeline bar that opened the sheet can
  // unmount while the sheet is up, and the edit would be lost with it.
  final scope = VideoEditorScope.of(context);
  final editorState = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(videoEditorProvider);
  final picked = await showSocialStickerSheet(
    context,
    initial: data,
    otherHashtags: socialStickerOtherHashtags(
      postTags: editorState.tags,
      layers: scope.editor?.activeLayers ?? const [],
      exceptLayerId: layer.id,
    ),
    soundChoices: SocialStickerData.soundCreditsFor([
      ?editorState.selectedSound,
      ...sounds,
    ]),
  );
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
      widget: SocialStickerView(data: picked),
      meta: meta,
      exportConfigs: current.exportConfigs.copyWith(meta: meta),
    ),
  );
}
