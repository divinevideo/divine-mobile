// ABOUTME: Tests the pill looks' colors, and the parts of them drawn again over
// ABOUTME: a sticker already in a video's frames.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';

void main() {
  group(StickerPillPalette, () {
    group('covering', () {
      test('keeps nothing see-through, no glow and no shadow', () {
        for (final style in InfoStickerStyle.pills) {
          final covering = StickerPillPalette.of(style).covering;

          expect(covering.background?.a ?? 1, equals(1), reason: style.name);
          expect(covering.border?.a ?? 1, equals(1), reason: style.name);
          expect(covering.shadows, isEmpty, reason: style.name);
        }
      });

      test('keeps the ink, and a solid pill as it is', () {
        final dark = StickerPillPalette.of(InfoStickerStyle.dark);
        final light = StickerPillPalette.of(InfoStickerStyle.light);
        final outline = StickerPillPalette.of(InfoStickerStyle.outline);

        expect(dark.covering.ink, equals(dark.ink));
        expect(dark.covering.background, isNull);
        expect(light.covering.background, equals(light.background));
        expect(outline.covering.border, equals(outline.border));
      });

      test('keeps a fill exactly in the looks with a solid pill', () {
        // The publish gives a copy in any script to a look with a solid
        // pill, which only a covering fill hides the frames beneath.
        for (final style in InfoStickerStyle.pills) {
          expect(
            StickerPillPalette.of(style).covering.background != null,
            equals(style.hasSolidPill),
            reason: style.name,
          );
        }
      });
    });
  });
}
