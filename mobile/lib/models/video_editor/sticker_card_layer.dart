// ABOUTME: Which layers are sticker cards: the Info, Social and Interactive
// ABOUTME: stickers, whole cards rather than artwork to cut, fade or blend.

import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] is a sticker card from the Info, Social or Interactive
/// rows of the sticker sheet: a date, place or weather card, a mention, link
/// or hashtag, a countdown, a poll and the like.
///
/// A card shows as it is: it is not split, masked, made see-through or
/// blended, and it neither gives its style to other layers nor takes theirs.
/// Its bar can be trimmed, except an interactive card's, which shows for the
/// whole video.
bool isStickerCardLayer(Layer? layer) =>
    layer != null &&
    (InfoStickerData.isInfoStickerLayer(layer) ||
        SocialStickerData.isSocialStickerLayer(layer));
