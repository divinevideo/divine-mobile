// ABOUTME: Whether a sticker's text looks the same on every phone: drawn in the
// ABOUTME: bundled sticker font, and its emoji in the bundled emoji font.

/// What a sticker's text needs to look the same on every phone.
enum StickerTextGlyphs {
  /// Only characters the sticker font draws, which the app ships.
  font,

  /// Emoji too, which look the same only in the sticker emoji font.
  emoji,

  /// A character neither font has, which each phone draws its own way.
  platform;

  /// Whether text needing these glyphs looks the same on every phone, given
  /// whether the sticker emoji font [emojiFontLoaded].
  bool isDrawnAlike({required bool emojiFontLoaded}) => switch (this) {
    font => true,
    emoji => emojiFontLoaded,
    platform => false,
  };

  /// The glyphs [text] needs. Line breaks and other control characters draw
  /// nothing and count for nothing.
  static StickerTextGlyphs of(String text) {
    var glyphs = font;
    for (final rune in text.runes) {
      if (rune < 0x20 || _inStickerFont(rune)) continue;
      if (!_emoji.hasMatch(String.fromCharCode(rune))) return platform;
      glyphs = emoji;
    }
    return glyphs;
  }

  /// The characters of an emoji: the pictographs and what joins, colours and
  /// flags them.
  static final _emoji = RegExp(_emojiPattern, unicode: true);

  // Not written into the constructor: the `valid_regexps` lint reads these
  // property escapes as invalid on Linux, where the tests run them.
  static const _emojiPattern =
      r'[\p{Extended_Pictographic}\p{Emoji_Component}]';

  static bool _inStickerFont(int rune) {
    for (final (first, last) in _stickerFontRanges) {
      if (rune < first) return false;
      if (rune <= last) return true;
    }
    return false;
  }
}

/// The characters the sticker font, Bricolage Grotesque ExtraBold, draws, in
/// order: the cmap of `assets/fonts/BricolageGrotesque-ExtraBold.ttf`. Update
/// it with that file.
const List<(int, int)> _stickerFontRanges = [
  (0x0020, 0x007E),
  (0x00A0, 0x00A3),
  (0x00A5, 0x00AC),
  (0x00AE, 0x0107),
  (0x010A, 0x0113),
  (0x0116, 0x011B),
  (0x011E, 0x0123),
  (0x0126, 0x012B),
  (0x012E, 0x0133),
  (0x0136, 0x0137),
  (0x0139, 0x013E),
  (0x0141, 0x0148),
  (0x014A, 0x014D),
  (0x0150, 0x015B),
  (0x015E, 0x0161),
  (0x0164, 0x0165),
  (0x0168, 0x017E),
  (0x01A0, 0x01A1),
  (0x01AF, 0x01B0),
  (0x01CD, 0x01CE),
  (0x0218, 0x021B),
  (0x0237, 0x0237),
  (0x02C6, 0x02C7),
  (0x02D8, 0x02DD),
  (0x0300, 0x0304),
  (0x0306, 0x030C),
  (0x0312, 0x0312),
  (0x031B, 0x031B),
  (0x0323, 0x0323),
  (0x0326, 0x0328),
  (0x03C0, 0x03C0),
  (0x0E3F, 0x0E3F),
  (0x1E80, 0x1E85),
  (0x1E9E, 0x1E9E),
  (0x1EA0, 0x1EF9),
  (0x2000, 0x200B),
  (0x2013, 0x2014),
  (0x2016, 0x2016),
  (0x2018, 0x201A),
  (0x201C, 0x201E),
  (0x2020, 0x2022),
  (0x2026, 0x2026),
  (0x202F, 0x2030),
  (0x2032, 0x2033),
  (0x2039, 0x203A),
  (0x2044, 0x2044),
  (0x2070, 0x2070),
  (0x2074, 0x2079),
  (0x2080, 0x2089),
  (0x20A1, 0x20A1),
  (0x20A4, 0x20A4),
  (0x20A6, 0x20A6),
  (0x20A8, 0x20A9),
  (0x20AB, 0x20AE),
  (0x20B1, 0x20B2),
  (0x20B4, 0x20B5),
  (0x20B8, 0x20BA),
  (0x20BC, 0x20BF),
  (0x2113, 0x2113),
  (0x2116, 0x2116),
  (0x2122, 0x2122),
  (0x2126, 0x2126),
  (0x212E, 0x212E),
  (0x2153, 0x2154),
  (0x215B, 0x215E),
  (0x2190, 0x2193),
  (0x2202, 0x2202),
  (0x2205, 0x2206),
  (0x220F, 0x220F),
  (0x2211, 0x2212),
  (0x221A, 0x221A),
  (0x221E, 0x221E),
  (0x222B, 0x222B),
  (0x2248, 0x2248),
  (0x2260, 0x2260),
  (0x2264, 0x2265),
  (0x27E8, 0x27E9),
];
