// ABOUTME: Tests how the mask editor writes a mask onto a layer.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/mask_editor/video_editor_mask_editor.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape, WidgetLayer;

void main() {
  group('layerWithMask', () {
    const heart = LayerMask(shape: LayerMaskShape.heart);

    test('keeps the widget keys, so a detached clip keeps its player', () {
      final layer = WidgetLayer(widget: const SizedBox(), opacity: 0.5);

      final masked = layerWithMask(layer, heart);

      expect(masked, isNot(same(layer)));
      expect(masked.mask, heart);
      expect(masked.opacity, 0.5);
      expect(masked.key, same(layer.key));
      expect(masked.keyInternalSize, same(layer.keyInternalSize));
      expect(masked.repaintBoundaryKey, same(layer.repaintBoundaryKey));
      expect(layer.mask, isNull);
    });

    test('removes the mask for null', () {
      final layer = WidgetLayer(widget: const SizedBox(), mask: heart);

      expect(layerWithMask(layer, null).mask, isNull);
    });
  });
}
