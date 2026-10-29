// ABOUTME: Tests which sticker texts look the same on every phone: those in the
// ABOUTME: bundled sticker font, and emoji once the sticker emoji font loads.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/sticker_text_glyphs.dart';

void main() {
  group(StickerTextGlyphs, () {
    group('of', () {
      test('reads text in the sticker font as needing only the font', () {
        expect(
          [
            'summer',
            'Café Zürich, 2026!',
            'Tiếng Việt',
            '€5 – “quoted”',
            'title\nartist',
          ].map(StickerTextGlyphs.of),
          everyElement(StickerTextGlyphs.font),
        );
      });

      test('reads emoji, joined, tinted or flagged, as needing emoji', () {
        expect(
          ['party 🎉', '👍🏽', '👨‍👩‍👧', '🇨🇭', '1️⃣', '❤️'].map(
            StickerTextGlyphs.of,
          ),
          everyElement(StickerTextGlyphs.emoji),
        );
      });

      test('reads any other script as drawn by the phone', () {
        expect(
          ['東京', 'Привет', 'مرحبا', 'party 🎉 東京'].map(StickerTextGlyphs.of),
          everyElement(StickerTextGlyphs.platform),
        );
      });
    });

    group('isDrawnAlike', () {
      test('needs the emoji font only for emoji', () {
        expect(
          StickerTextGlyphs.font.isDrawnAlike(emojiFontLoaded: false),
          isTrue,
        );
        expect(
          StickerTextGlyphs.emoji.isDrawnAlike(emojiFontLoaded: false),
          isFalse,
        );
        expect(
          StickerTextGlyphs.emoji.isDrawnAlike(emojiFontLoaded: true),
          isTrue,
        );
        expect(
          StickerTextGlyphs.platform.isDrawnAlike(emojiFontLoaded: true),
          isFalse,
        );
      });
    });
  });
}
