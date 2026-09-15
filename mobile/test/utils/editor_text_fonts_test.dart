// ABOUTME: Tests the editor font lookup that draft restore relies on: name
// ABOUTME: resolution, family-identifier matching and history scanning.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/utils/editor_text_fonts.dart';

void main() {
  group('googleFontFamilyName', () {
    test('resolves a Google Font tear-off to its published name', () {
      expect(googleFontFamilyName(GoogleFonts.bebasNeue), 'Bebas Neue');
      expect(
        googleFontFamilyName(GoogleFonts.shadowsIntoLight),
        'Shadows Into Light',
      );
      expect(googleFontFamilyName(GoogleFonts.ibmPlexMono), 'IBM Plex Mono');
    });

    test('returns null for a font that is not a Google Font', () {
      expect(googleFontFamilyName(_customFont), isNull);
    });

    test('resolves every editor font', () {
      for (final font in VideoEditorConstants.textFonts) {
        expect(googleFontFamilyName(font), isNotNull);
      }
    });
  });

  group('VideoEditorConstants.textFonts', () {
    test('holds no font twice', () {
      const fonts = VideoEditorConstants.textFonts;
      expect(fonts.toSet(), hasLength(fonts.length));
    });
  });

  group('editorTextFontsFor', () {
    test('matches the identifier a serialized text layer carries', () {
      // Inter is bundled, so this registers nothing new: the test config
      // already loads it for VineTheme.
      final identifier = GoogleFonts.inter().fontFamily!;
      expect(identifier, 'Inter_regular');

      expect(editorTextFontsFor([identifier]), [GoogleFonts.inter]);
    });

    test('keeps the list order and drops unknown identifiers', () {
      final fonts = editorTextFontsFor([
        'BebasNeue_regular',
        'Nope_regular',
        'Inter_regular',
        'ShadowsIntoLight_regular',
      ]);

      expect(fonts, [
        GoogleFonts.inter,
        GoogleFonts.bebasNeue,
        GoogleFonts.shadowsIntoLight,
      ]);
    });

    test('returns nothing for no identifiers', () {
      expect(editorTextFontsFor(const []), isEmpty);
    });
  });

  group('editorTextFontIndexFor', () {
    test('maps a serialized identifier back to its catalogue index', () {
      expect(
        editorTextFontIndexFor('BebasNeue_regular'),
        VideoEditorConstants.textFonts.indexOf(GoogleFonts.bebasNeue),
      );
      expect(
        editorTextFontIndexFor('ShadowsIntoLight_regular'),
        VideoEditorConstants.textFonts.indexOf(GoogleFonts.shadowsIntoLight),
      );
      expect(
        editorTextFontIndexFor('PressStart2P_regular'),
        VideoEditorConstants.textFonts.indexOf(GoogleFonts.pressStart2p),
      );
    });

    test('does not fall back to the first font for a known layer font', () {
      // A restored layer used to be looked up by style equality, which no
      // restored style matches, so every layer opened on Inter. The index for
      // a serialized identifier has to be the font that identifier names.
      expect(editorTextFontIndexFor('BebasNeue_regular'), isNot(0));
    });

    test('returns -1 for an unknown identifier', () {
      expect(editorTextFontIndexFor('Nope_regular'), -1);
    });

    test('returns -1 for a missing identifier', () {
      expect(editorTextFontIndexFor(null), -1);
    });
  });

  group('textFontFamiliesInHistory', () {
    test('collects families from references and history deltas', () {
      final families = textFontFamiliesInHistory({
        'version': '6.0.0',
        'references': {
          'a': {'type': 'text', 'fontFamily': 'BebasNeue_regular'},
          'b': {'type': 'emoji', 'emoji': '🎉'},
        },
        'history': [
          {
            'layers': [
              {'id': 'a', 'fontFamily': 'Inter_regular'},
              {'id': 'b'},
            ],
          },
        ],
      });

      expect(families, {'BebasNeue_regular', 'Inter_regular'});
    });

    test('ignores a fontFamily that is not a string', () {
      final families = textFontFamiliesInHistory({
        'references': {
          'a': {'fontFamily': null},
          'b': {'fontFamily': 3},
        },
      });

      expect(families, isEmpty);
    });

    test('returns nothing for an empty history', () {
      expect(textFontFamiliesInHistory(const {}), isEmpty);
    });
  });
}

TextStyle _customFont({double? fontSize, Color? color}) => TextStyle(
  fontFamily: 'Custom_Face_regular',
  fontSize: fontSize,
  color: color,
);
