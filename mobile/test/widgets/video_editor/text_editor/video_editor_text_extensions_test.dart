// ABOUTME: Unit tests for text editor extensions.
// ABOUTME: Verifies icon mapping for text alignment and background modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group('TextEditorFont', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names a Google Font by its published family name', () {
      expect(GoogleFonts.bebasNeue.displayName, 'Bebas Neue');
      expect(GoogleFonts.ibmPlexMono.displayName, 'IBM Plex Mono');
      expect(
        GoogleFonts.pressStart2p.localizedDisplayName(l10n),
        'Press Start 2P',
      );
    });

    test('cleans the family identifier of any other font', () {
      expect(_customFont.displayName, 'Custom Face');
      expect(_customFont.localizedDisplayName(l10n), 'Custom Face');
    });

    test('falls back when the font has no family', () {
      expect(_familyless.displayName, 'Unknown');
      expect(
        _familyless.localizedDisplayName(l10n),
        l10n.videoEditorFontUnknown,
      );
    });
  });

  group('TextEditorTextAlign', () {
    test('maps text alignment to expected icon', () {
      expect(TextAlign.left.icon, equals(DivineIconName.textAlignLeft));
      expect(TextAlign.start.icon, equals(DivineIconName.textAlignLeft));
      expect(TextAlign.right.icon, equals(DivineIconName.textAlignRight));
      expect(TextAlign.end.icon, equals(DivineIconName.textAlignRight));
      expect(TextAlign.center.icon, equals(DivineIconName.textAlignCenter));
      expect(TextAlign.justify.icon, equals(DivineIconName.textAlignCenter));
    });
  });

  group('TextEditorBackgroundMode', () {
    test('maps background mode to expected icon', () {
      expect(
        LayerBackgroundMode.onlyColor.icon,
        equals(DivineIconName.textBgNone),
      );
      expect(
        LayerBackgroundMode.backgroundAndColor.icon,
        equals(DivineIconName.textBgFill),
      );
      expect(
        LayerBackgroundMode.background.icon,
        equals(DivineIconName.textBgFill),
      );
      expect(
        LayerBackgroundMode.backgroundAndColorWithOpacity.icon,
        equals(DivineIconName.textBgTransparent),
      );
    });
  });
}

TextStyle _customFont({double? fontSize, Color? color}) => TextStyle(
  fontFamily: 'Custom_Face_regular',
  fontSize: fontSize,
  color: color,
);

TextStyle _familyless({double? fontSize, Color? color}) =>
    TextStyle(fontSize: fontSize, color: color);
