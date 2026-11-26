// ABOUTME: Guards the shipped sticker assets: the picker offers exactly the
// ABOUTME: DivineSticker set, every locale strings file covers its stickers
// ABOUTME: with no blanks, and no two stickers point at identical image files.

import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';

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

    test('offers exactly the DivineSticker set', () {
      // The OpenMoji SVGs stay bundled for drafts made before the move, but
      // the picker must not offer them again, and a sticker added to the
      // design set belongs in the picker too.
      expect(
        manifestKeys,
        equals({
          for (final sticker in DivineStickerName.values) sticker.assetPath,
        }),
      );
    });

    test('every sticker points at a bundled file', () {
      for (final key in manifestKeys) {
        expect(File(key).existsSync(), isTrue, reason: 'Missing $key.');
      }
    });

    test('no two stickers draw the same image', () {
      final manifest =
          json.decode(File(manifestPath).readAsStringSync()) as List<dynamic>;
      final pathsByImage = <String, List<String>>{};
      for (final entry in manifest) {
        final assetPath = (entry as Map<String, dynamic>)['assetPath'];
        if (assetPath is! String) continue;
        pathsByImage
            .putIfAbsent(
              base64.encode(File(assetPath).readAsBytesSync()),
              () => [],
            )
            .add(assetPath);
      }

      expect(
        pathsByImage.values.where((paths) => paths.length > 1),
        isEmpty,
        reason: 'Identical files show the same sticker twice in the picker.',
      );
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
