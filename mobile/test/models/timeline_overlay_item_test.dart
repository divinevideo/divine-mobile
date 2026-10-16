// ABOUTME: Tests for which layers the timeline's multi-select can combine.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group('layerMergeKindOf', () {
    WidgetLayer sticker() => WidgetLayer(
      widget: const SizedBox(),
      meta: StickerData(
        assetPath: 'assets/stickers/heart.svg',
        description: LocalizedText.single('heart'),
        tags: const ['heart'],
        packData: StickerPackData.fallback,
      ).toJson(),
    );

    PaintLayer drawing() => PaintLayer(
      item: PaintedModel(
        mode: PaintMode.freeStyle,
        offsets: const [Offset.zero, Offset(10, 10)],
        erasedOffsets: const [],
        color: const Color(0xFFFFFFFF),
        strokeWidth: 2,
        opacity: 1,
      ),
      rawSize: const Size(10, 10),
      opacity: 1,
    );

    test('leaves out a masked sticker or drawing, whose mask a combined '
        'layer could not keep', () {
      const mask = LayerMask(shape: LayerMaskShape.heart);

      expect(layerMergeKindOf(sticker()), LayerMergeKind.sticker);
      expect(layerMergeKindOf(drawing()), LayerMergeKind.drawing);
      expect(layerMergeKindOf(sticker()..mask = mask), isNull);
      expect(layerMergeKindOf(drawing()..mask = mask), isNull);
    });
  });
}
