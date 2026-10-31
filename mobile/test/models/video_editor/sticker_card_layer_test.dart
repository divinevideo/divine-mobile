// ABOUTME: Tests which layers count as sticker cards: the info, social and
// ABOUTME: interactive stickers, and nothing else.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/layer_style.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/sticker_card_layer.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

WidgetLayer _layer(Map<String, dynamic> meta) => WidgetLayer(
  id: 'layer',
  widget: const SizedBox.shrink(),
  meta: meta,
  exportConfigs: WidgetLayerExportConfigs(id: 'layer', meta: meta),
);

void main() {
  group('isStickerCardLayer', () {
    final info = _layer(
      const InfoStickerData(
        kind: InfoStickerKind.weather,
        localeName: 'en',
      ).toMeta(),
    );
    final social = _layer(
      const SocialStickerData(
        kind: SocialStickerKind.mention,
        name: 'alice',
      ).toMeta(),
    );
    final plain = _layer(const {'kind': 'emoji'});

    test('is true for info and social stickers only', () {
      expect(isStickerCardLayer(info), isTrue);
      expect(isStickerCardLayer(social), isTrue);
      expect(isStickerCardLayer(plain), isFalse);
      expect(isStickerCardLayer(null), isFalse);
    });

    test('keeps a sticker card out of masks and copied styles', () {
      expect(canMaskLayer(info), isFalse);
      expect(canCopyLayerStyle(social), isFalse);
      expect(canMaskLayer(plain), isTrue);
      expect(canCopyLayerStyle(plain), isTrue);
    });
  });
}
