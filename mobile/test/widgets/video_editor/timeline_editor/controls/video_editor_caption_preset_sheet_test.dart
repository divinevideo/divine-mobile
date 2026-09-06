// ABOUTME: Tests for the caption preset picker's display-name resolution.
// ABOUTME: Rendering is not widget-tested: the tiles draw real Google Fonts,
// ABOUTME: which are not available in unit tests (same limitation as
// ABOUTME: video_editor_text_font_selector_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/caption_style_preset.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_preset_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final l10n = lookupAppLocalizations(const Locale('en'));

  group('captionPresetDisplayName', () {
    test('resolves a distinct localized name for every preset', () {
      final names = [
        for (final preset in CaptionStylePreset.presets)
          captionPresetDisplayName(l10n, preset.id),
      ];

      expect(names.toSet(), hasLength(CaptionStylePreset.presets.length));
      for (final name in names) {
        expect(name, isNotEmpty);
      }
    });

    test('falls back to the classic name for unknown ids', () {
      expect(
        captionPresetDisplayName(l10n, 'does-not-exist'),
        equals(l10n.videoEditorCaptionsPresetClassic),
      );
    });

    test('resolves localized names in other locales', () {
      final de = lookupAppLocalizations(const Locale('de'));

      expect(
        captionPresetDisplayName(de, 'classic'),
        equals(de.videoEditorCaptionsPresetClassic),
      );
      expect(captionPresetDisplayName(de, 'classic'), equals('Klassisch'));
    });
  });
}
