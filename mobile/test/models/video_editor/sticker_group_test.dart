// ABOUTME: Tests for StickerGroupData: the meta a combined sticker layer is
// ABOUTME: saved with must come back unchanged after a draft round-trip.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/models/video_editor/sticker_group.dart';

// The plain constructor, which is also what a draft round-trip rebuilds:
// `StickerData.asset` makes a subclass that never equals the restored one.
StickerData _sticker(String name) => StickerData(
  assetPath: 'assets/stickers/$name.svg',
  description: LocalizedText.single(name),
  tags: [name],
  packData: StickerPackData.fallback,
);

final _nested = StickerGroupData(
  size: const Size(80, 40),
  children: [
    StickerGroupChild(
      sticker: _sticker('star'),
      center: const Offset(20, 20),
      size: const Size(40, 40),
    ),
    StickerGroupChild(
      sticker: _sticker('moon'),
      center: const Offset(60, 20),
      size: const Size(40, 40),
    ),
  ],
);

final _group = StickerGroupData(
  size: const Size(200, 120),
  children: [
    StickerGroupChild(
      sticker: _sticker('heart'),
      center: const Offset(50, 60),
      size: const Size(100, 80),
      rotation: 0.5,
      flipX: true,
      opacity: 0.4,
    ),
    StickerGroupChild(
      group: _nested,
      center: const Offset(150, 60),
      size: const Size(100, 50),
      flipY: true,
    ),
  ],
);

void main() {
  group(StickerGroupData, () {
    group('fromMeta', () {
      test('restores the group after a JSON round-trip', () {
        // A draft stores the meta as JSON, so every double that happens to be
        // whole comes back as an int and every map as Map<String, dynamic>.
        final meta =
            jsonDecode(jsonEncode(_group.toMeta())) as Map<String, dynamic>;

        expect(StickerGroupData.fromMeta(meta), equals(_group));
      });

      test('returns null for a group without children', () {
        expect(
          StickerGroupData.fromMeta({
            stickerGroupMetaKey: {'width': 10, 'height': 10, 'children': []},
          }),
          isNull,
        );
      });

      test('returns null for a damaged child', () {
        expect(
          StickerGroupData.fromMeta({
            stickerGroupMetaKey: {
              'width': 10,
              'height': 10,
              'children': [
                {'x': 'left', 'y': 0, 'width': 1, 'height': 1},
              ],
            },
          }),
          isNull,
        );
      });

      test('returns null for a single sticker', () {
        expect(StickerGroupData.fromMeta(_sticker('heart').toJson()), isNull);
      });
    });

    group('stickers', () {
      test('lists every sticker in paint order, nested ones in place', () {
        final group = StickerGroupData(
          size: const Size(10, 10),
          children: [
            StickerGroupChild(
              sticker: _sticker('sun'),
              center: Offset.zero,
              size: const Size(1, 1),
            ),
            StickerGroupChild(
              group: _nested,
              center: Offset.zero,
              size: const Size(1, 1),
            ),
            StickerGroupChild(
              sticker: _sticker('cloud'),
              center: Offset.zero,
              size: const Size(1, 1),
            ),
          ],
        );

        expect(
          group.stickers.map((s) => s.assetPath),
          [
            'assets/stickers/sun.svg',
            'assets/stickers/star.svg',
            'assets/stickers/moon.svg',
            'assets/stickers/cloud.svg',
          ],
        );
        expect(group.stickerCount, 4);
      });
    });
  });

  group('isStickerLayerMeta', () {
    test('accepts a single sticker and a combined one', () {
      expect(isStickerLayerMeta(_sticker('heart').toJson()), isTrue);
      expect(isStickerLayerMeta(_group.toMeta()), isTrue);
    });

    test('rejects other widget layer meta', () {
      expect(isStickerLayerMeta(null), isFalse);
      expect(isStickerLayerMeta({'kind': 'detachedClip'}), isFalse);
    });
  });
}
