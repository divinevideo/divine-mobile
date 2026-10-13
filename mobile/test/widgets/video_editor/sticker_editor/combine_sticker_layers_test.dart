// ABOUTME: Tests for combineStickerLayers: the combined layer must keep every
// ABOUTME: sticker where it was, and leave every other layer untouched.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/models/video_editor/sticker_group.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/combine_sticker_layers.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_group.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

// The plain constructor, which is also what a draft round-trip rebuilds:
// `StickerData.asset` makes a subclass that never equals the restored one.
StickerData _sticker(String name) => StickerData(
  assetPath: 'assets/stickers/$name.svg',
  description: LocalizedText.single(name),
  tags: const [],
  packData: StickerPackData.fallback,
);

WidgetLayer _stickerLayer(
  String id, {
  required Offset offset,
  double rotation = 0,
  bool flipX = false,
  Map<String, dynamic>? meta,
  Duration? startTime,
}) {
  final layerMeta = meta ?? _sticker(id).toJson();
  return WidgetLayer(
    id: id,
    widget: const SizedBox(),
    width: 100,
    offset: offset,
    rotation: rotation,
    flipX: flipX,
    startTime: startTime,
    meta: layerMeta,
    exportConfigs: WidgetLayerExportConfigs(id: id, meta: layerMeta),
  );
}

PaintLayer _paintLayer(String id) => PaintLayer(
  id: id,
  rawSize: const Size(10, 10),
  opacity: 1,
  item: PaintedModel(
    mode: PaintMode.freeStyle,
    offsets: const [Offset.zero, Offset(10, 10)],
    erasedOffsets: const [],
    color: const Color(0xFFFF0000),
    strokeWidth: 6,
    opacity: 1,
  ),
);

/// Every sticker is laid out 100 wide and 50 tall, as `Layer.renderSize`
/// would report it.
Size _size(Layer _) => const Size(100, 50);

StickerGroupData _groupOf(WidgetLayer layer) =>
    StickerGroupData.fromMeta(layer.exportConfigs.meta)!;

void main() {
  group('combineStickerLayers', () {
    test('replaces the stickers with one layer covering them all', () {
      final result = combineStickerLayers(
        layers: [
          _stickerLayer('a', offset: const Offset(-100, 0)),
          _stickerLayer('b', offset: const Offset(100, 50)),
        ],
        ids: {'a', 'b'},
        sizeOf: _size,
      )!;

      final combined = result.combined;
      expect(result.layers, [combined]);
      // a covers x -150..-50, y -25..25; b covers x 50..150, y 25..75.
      expect(combined.offset, const Offset(0, 25));
      expect(combined.width, 300);
      expect(combined.widget, isA<VideoEditorStickerGroup>());

      final group = _groupOf(combined);
      expect(group.size, const Size(300, 100));
      expect(group.children.map((c) => c.center), const [
        Offset(50, 25),
        Offset(250, 75),
      ]);
      expect(group.children.map((c) => c.sticker), [
        _sticker('a'),
        _sticker('b'),
      ]);
      expect(combined.meta, equals(combined.exportConfigs.meta));
    });

    test('keeps rotation and mirroring, and sizes around the rotated box', () {
      final result = combineStickerLayers(
        layers: [
          _stickerLayer(
            'a',
            offset: Offset.zero,
            rotation: math.pi / 2,
            flipX: true,
          ),
          _stickerLayer('b', offset: const Offset(200, 0)),
        ],
        ids: {'a', 'b'},
        sizeOf: _size,
      )!;

      final group = _groupOf(result.combined);
      // Turned a quarter, a stands 50 wide and 100 tall around the origin.
      expect(group.size.width, closeTo(275, 1e-9));
      expect(group.size.height, closeTo(100, 1e-9));
      final rotated = group.children.first;
      expect(rotated.rotation, math.pi / 2);
      expect(rotated.flipX, isTrue);
      expect(rotated.size, const Size(100, 50));
    });

    test('takes the z-position of the top-most sticker', () {
      final result = combineStickerLayers(
        layers: [
          _stickerLayer('a', offset: Offset.zero),
          _paintLayer('drawing'),
          _stickerLayer('b', offset: Offset.zero),
          _paintLayer('top'),
        ],
        ids: {'a', 'b'},
        sizeOf: _size,
      )!;

      expect(result.layers.map((l) => l.id), [
        'drawing',
        result.combined.id,
        'top',
      ]);
    });

    test('nests a sticker that was combined before', () {
      final first = combineStickerLayers(
        layers: [
          _stickerLayer('a', offset: Offset.zero),
          _stickerLayer('b', offset: const Offset(100, 0)),
        ],
        ids: {'a', 'b'},
        sizeOf: _size,
      )!.combined;

      final result = combineStickerLayers(
        layers: [
          first,
          _stickerLayer('c', offset: const Offset(0, 300)),
        ],
        ids: {first.id, 'c'},
        sizeOf: _size,
      )!;

      final group = _groupOf(result.combined);
      expect(group.children.first.group, equals(_groupOf(first)));
      expect(group.children.last.sticker, _sticker('c'));
      expect(group.stickerCount, 3);
    });

    test('ignores selected layers that are not combinable stickers', () {
      final layers = [
        _stickerLayer('a', offset: Offset.zero),
        _stickerLayer(
          'timed',
          offset: Offset.zero,
          startTime: const Duration(seconds: 1),
        ),
        _paintLayer('drawing'),
      ];

      expect(
        combineStickerLayers(
          layers: layers,
          ids: {'a', 'timed', 'drawing'},
          sizeOf: _size,
        ),
        isNull,
      );
    });

    test('gives up when a sticker has not been laid out', () {
      expect(
        combineStickerLayers(
          layers: [
            _stickerLayer('a', offset: Offset.zero),
            _stickerLayer('b', offset: Offset.zero),
          ],
          ids: {'a', 'b'},
          sizeOf: (layer) => layer.id == 'a' ? const Size(10, 10) : null,
        ),
        isNull,
      );
    });

    testWidgets('measures each sticker as the canvas laid it out', (
      tester,
    ) async {
      final a = _stickerLayer('a', offset: Offset.zero);
      final b = _stickerLayer('b', offset: const Offset(0, 100));
      // The layer item puts `keyInternalSize` on the box that holds the
      // sticker at its scaled size, which is what `Layer.renderSize` reads.
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Column(
            mainAxisSize: .min,
            children: [
              SizedBox(key: a.keyInternalSize, width: 120, height: 60),
              SizedBox(key: b.keyInternalSize, width: 40, height: 80),
            ],
          ),
        ),
      );

      final result = combineStickerLayers(layers: [a, b], ids: {'a', 'b'});

      expect(_groupOf(result!.combined).children.map((c) => c.size), const [
        Size(120, 60),
        Size(40, 80),
      ]);
    });
  });
}
