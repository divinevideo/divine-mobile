// ABOUTME: Guards the shipped sticker assets: every locale strings file must
// ABOUTME: cover exactly the structural manifest's stickers, with no blanks —
// ABOUTME: so a hand-edited translation can never silently drift or go missing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

void main() {
  group('sticker manifest assets', () {
    // Tests run with the package root as the working directory.
    const manifestPath = 'assets/stickers/stickers.json';
    const i18nDirectory = 'assets/stickers/i18n';

    // Derived from the app's supported locales so adding a new app locale
    // surfaces here (its strings file must ship) instead of silently falling
    // back to English.
    final expectedLocales = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toList();

    late Set<String> manifestKeys;

    setUpAll(() {
      final manifest =
          json.decode(File(manifestPath).readAsStringSync()) as List<dynamic>;
      manifestKeys = manifest.map((entry) {
        final map = entry as Map<String, dynamic>;
        return (map['assetPath'] ?? map['networkUrl']) as String;
      }).toSet();
    });

    test('structural manifest carries no inline descriptions', () {
      final manifest =
          json.decode(File(manifestPath).readAsStringSync()) as List<dynamic>;

      for (final entry in manifest) {
        expect(
          (entry as Map<String, dynamic>).containsKey('description'),
          isFalse,
          reason: 'Descriptions belong in the per-locale i18n files.',
        );
      }
    });

    test('every supported locale has a strings file', () {
      for (final locale in expectedLocales) {
        expect(
          File('$i18nDirectory/$locale.json').existsSync(),
          isTrue,
          reason: 'Missing strings file for "$locale".',
        );
      }
    });

    for (final locale in expectedLocales) {
      test('"$locale" strings cover every sticker with non-blank text', () {
        final strings = json.decode(
          File('$i18nDirectory/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        expect(
          strings.keys.toSet(),
          manifestKeys,
          reason: '"$locale" keys must match the manifest exactly.',
        );
        for (final entry in strings.entries) {
          expect(
            (entry.value as String).trim(),
            isNotEmpty,
            reason: '"$locale" has a blank description for ${entry.key}.',
          );
        }
      });
    }
  });
}
