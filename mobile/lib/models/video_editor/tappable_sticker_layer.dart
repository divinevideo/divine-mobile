// ABOUTME: Which sticker layers a viewer can tap on the published video: the
// ABOUTME: social stickers and the location sticker, which all hold still.

import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] is a sticker a viewer can tap on the published video: a
/// social sticker, or a location sticker, which opens its place in a map.
///
/// Such a sticker holds still, so its tap area stays where it shows: it
/// takes no keyframes, no tracking and no animations.
bool isTappableStickerLayer(Layer? layer) =>
    layer != null &&
    (SocialStickerData.of(layer) != null ||
        InfoStickerData.of(layer)?.kind == InfoStickerKind.location);
