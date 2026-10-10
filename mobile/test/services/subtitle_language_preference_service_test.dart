// ABOUTME: Tests for SubtitleLanguagePreferenceService target/keep-original
// ABOUTME: preferences and the shouldTranslate decision.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubtitleLanguagePreferenceService', () {
    late SubtitleLanguagePreferenceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SubtitleLanguagePreferenceService();
    });

    test('effective target defaults to the app locale', () async {
      await service.initialize();
      expect(service.effectiveTargetLanguage('en'), equals('en'));
    });

    test('explicit target overrides the app locale', () async {
      await service.initialize();
      await service.setTargetLanguage('pt');
      expect(service.effectiveTargetLanguage('en'), equals('pt'));
    });

    test('does not translate when the source equals the target', () async {
      await service.initialize();
      expect(
        service.shouldTranslate(sourceLanguage: 'en', appLocaleCode: 'en'),
        isFalse,
      );
    });

    test('translates when the source differs from the target', () async {
      await service.initialize();
      expect(
        service.shouldTranslate(sourceLanguage: 'ja', appLocaleCode: 'en'),
        isTrue,
      );
    });

    test('keeps a listed source language in the original', () async {
      await service.initialize();
      await service.setKeepOriginalLanguages({'ja'});
      expect(
        service.shouldTranslate(sourceLanguage: 'ja', appLocaleCode: 'en'),
        isFalse,
      );
    });

    test('treats a missing or unknown source as no translation', () async {
      await service.initialize();
      expect(
        service.shouldTranslate(sourceLanguage: null, appLocaleCode: 'en'),
        isFalse,
      );
      expect(
        service.shouldTranslate(sourceLanguage: 'und', appLocaleCode: 'en'),
        isFalse,
      );
    });

    test(
      'normalizes a region-qualified source to its primary subtag',
      () async {
        await service.initialize();
        await service.setKeepOriginalLanguages({'de-CH'});
        expect(
          service.shouldTranslate(sourceLanguage: 'de-DE', appLocaleCode: 'en'),
          isFalse,
        );
      },
    );

    test(
      'persists the target and keep-original set across instances',
      () async {
        await service.initialize();
        await service.setTargetLanguage('pt');
        await service.setKeepOriginalLanguages({'ja', 'ko'});

        final reloaded = SubtitleLanguagePreferenceService();
        await reloaded.initialize();

        expect(reloaded.targetLanguage, equals('pt'));
        expect(reloaded.keepOriginalLanguages, equals({'ja', 'ko'}));
      },
    );
  });
}
