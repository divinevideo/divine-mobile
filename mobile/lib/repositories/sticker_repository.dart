// ABOUTME: Loads the sticker catalog from bundled assets, composing the
// ABOUTME: locale-free structural manifest with only the active locale's
// ABOUTME: descriptions (plus the English fallback) so unused translations
// ABOUTME: are never parsed — keeping the door open for lazy/background packs.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:models/models.dart';

/// Loads [StickerData] from the bundled sticker manifest.
///
/// The manifest is split into a locale-free structural file
/// (`assets/stickers/stickers.json`, holding asset paths and search tags) and
/// one strings file per locale (`assets/stickers/i18n/<locale>.json`, mapping
/// each sticker's asset path to its description). Only the requested locale and
/// the English fallback are read, so the picker never parses all 18 languages
/// just to show one.
class StickerRepository {
  /// Creates a [StickerRepository].
  ///
  /// [assetBundle] defaults to [rootBundle]; inject a fake in tests.
  StickerRepository({AssetBundle? assetBundle})
    : _bundle = assetBundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _manifestPath = 'assets/stickers/stickers.json';
  static const _i18nDirectory = 'assets/stickers/i18n';
  static const String _fallbackLocaleCode = LocalizedText.fallbackLocaleCode;

  /// Loads every sticker with descriptions resolved for [localeCode] and the
  /// English fallback.
  ///
  /// Throws a [FlutterError] / [FormatException] if the structural manifest or
  /// the English strings file is missing or malformed (a build invariant). A
  /// missing or unreadable per-locale strings file is tolerated — those
  /// stickers fall back to English.
  Future<List<StickerData>> loadStickers(String localeCode) async {
    final manifest =
        json.decode(await _bundle.loadString(_manifestPath)) as List<dynamic>;
    final englishStrings = await _loadStrings(_fallbackLocaleCode);
    final localeStrings = localeCode == _fallbackLocaleCode
        ? const <String, String>{}
        : await _loadStringsOrEmpty(localeCode);

    return manifest.map((entry) {
      final map = entry as Map<String, dynamic>;
      final assetPath = map['assetPath'] as String?;
      final networkUrl = map['networkUrl'] as String?;
      final key = assetPath ?? networkUrl ?? '';

      return StickerData(
        assetPath: assetPath,
        networkUrl: networkUrl,
        description: LocalizedText({
          if (englishStrings[key] != null)
            _fallbackLocaleCode: englishStrings[key]!,
          if (localeStrings[key] != null) localeCode: localeStrings[key]!,
        }),
        tags: (map['tags'] as List<dynamic>).cast<String>(),
        packData: StickerPackData.fallback,
      );
    }).toList();
  }

  Future<Map<String, String>> _loadStrings(String localeCode) async {
    final raw = json.decode(
      await _bundle.loadString('$_i18nDirectory/$localeCode.json'),
    ) as Map<String, dynamic>;
    return raw.map((key, value) => MapEntry(key, value as String));
  }

  Future<Map<String, String>> _loadStringsOrEmpty(String localeCode) async {
    try {
      return await _loadStrings(localeCode);
    } catch (_) {
      // Missing or unreadable strings file for this locale — descriptions fall
      // back to English rather than failing the whole picker over one locale's
      // cosmetic labels. The consistency test guards the bundled files, so this
      // only degrades genuinely absent or corrupt locales.
      return const <String, String>{};
    }
  }
}
