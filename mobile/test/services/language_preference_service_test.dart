// ABOUTME: Tests for LanguagePreferenceService
// ABOUTME: Verifies language preference storage, device default fallback, and
// custom language override behavior

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(LanguagePreferenceService, () {
    late LanguagePreferenceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LanguagePreferenceService();
    });

    group('contentLanguage', () {
      test('returns device language code when no custom language is set', () {
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;
        expect(service.contentLanguage, equals(deviceLang));
      });

      test(
        'returns device language after initialize with empty prefs',
        () async {
          await service.initialize();
          final deviceLang = PlatformDispatcher.instance.locale.languageCode;
          expect(service.contentLanguage, equals(deviceLang));
        },
      );

      test(
        'returns saved language after initialize with existing preference',
        () async {
          SharedPreferences.setMockInitialValues({
            LanguagePreferenceService.prefsKey: 'es',
          });
          service = LanguagePreferenceService();
          await service.initialize();

          expect(service.contentLanguage, equals('es'));
        },
      );
    });

    group('setContentLanguage', () {
      test('persists and returns the set value', () async {
        await service.initialize();

        await service.setContentLanguage('pt');
        expect(service.contentLanguage, equals('pt'));

        // Verify it persisted to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(LanguagePreferenceService.prefsKey),
          equals('pt'),
        );
      });

      test('overrides device default', () async {
        await service.initialize();
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;

        // Before setting, returns device default
        expect(service.contentLanguage, equals(deviceLang));

        // After setting, returns custom value
        await service.setContentLanguage('ja');
        expect(service.contentLanguage, equals('ja'));
      });

      test('notifies listeners after setting a custom language', () async {
        await service.initialize();
        var notifications = 0;
        service.addListener(() {
          notifications++;
        });

        await service.setContentLanguage('pt');

        expect(notifications, equals(1));
      });

      test(
        'does not persist or notify when the language is unchanged',
        () async {
          await service.initialize();
          await service.setContentLanguage('pt');
          var notifications = 0;
          service.addListener(() {
            notifications++;
          });

          await service.setContentLanguage('pt');

          expect(notifications, isZero);
          expect(service.contentLanguage, equals('pt'));
        },
      );

      test('does not notify removed listeners', () async {
        await service.initialize();
        var notifications = 0;
        void listener() {
          notifications++;
        }

        service.addListener(listener);
        service.removeListener(listener);

        await service.setContentLanguage('pt');

        expect(notifications, isZero);
      });

      test('continues notifying listeners after one throws', () async {
        await service.initialize();
        final reportedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = reportedErrors.add;
        addTearDown(() => FlutterError.onError = originalOnError);

        var notifications = 0;
        service
          ..addListener(() => throw StateError('listener failed'))
          ..addListener(() {
            notifications++;
          });

        await service.setContentLanguage('pt');

        expect(notifications, equals(1));
        expect(reportedErrors, hasLength(1));
        expect(reportedErrors.single.exception, isA<StateError>());
      });
    });

    group('clearContentLanguage', () {
      test('reverts to device default after clearing', () async {
        await service.initialize();

        // Set a custom language
        await service.setContentLanguage('fr');
        expect(service.contentLanguage, equals('fr'));

        // Clear it
        await service.clearContentLanguage();
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;
        expect(service.contentLanguage, equals(deviceLang));
      });

      test('removes the key from SharedPreferences', () async {
        await service.initialize();

        await service.setContentLanguage('de');
        await service.clearContentLanguage();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LanguagePreferenceService.prefsKey), isNull);
      });

      test('notifies listeners after clearing a custom language', () async {
        await service.initialize();
        await service.setContentLanguage('de');
        var notifications = 0;
        service.addListener(() {
          notifications++;
        });

        await service.clearContentLanguage();

        expect(notifications, equals(1));
      });

      test('does not notify listeners after dispose', () async {
        await service.initialize();
        var notifications = 0;
        service.addListener(() {
          notifications++;
        });

        service.dispose();
        await service.clearContentLanguage();

        expect(notifications, isZero);
      });
    });

    group('isCustomLanguageSet', () {
      test('returns false when no custom language is set', () {
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns false after initialize with empty prefs', () async {
        await service.initialize();
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns true after setting a custom language', () async {
        await service.initialize();
        await service.setContentLanguage('ko');
        expect(service.isCustomLanguageSet, isTrue);
      });

      test('returns false after clearing a custom language', () async {
        await service.initialize();
        await service.setContentLanguage('ko');
        expect(service.isCustomLanguageSet, isTrue);

        await service.clearContentLanguage();
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns true after initialize with existing preference', () async {
        SharedPreferences.setMockInitialValues({
          LanguagePreferenceService.prefsKey: 'zh',
        });
        service = LanguagePreferenceService();
        await service.initialize();

        expect(service.isCustomLanguageSet, isTrue);
      });
    });

    group('displayNameFor', () {
      test('returns display name for known language codes', () {
        expect(
          LanguagePreferenceService.displayNameFor('en'),
          equals('English'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('es'),
          equals('Spanish'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('pt'),
          equals('Portuguese'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('ja'),
          equals('Japanese'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('bg'),
          equals('Bulgarian'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('te'),
          equals('Telugu'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('am'),
          equals('Amharic'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('vi'),
          equals('Vietnamese'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('zh'),
          equals('Chinese'),
        );
        expect(LanguagePreferenceService.displayNameFor('ur'), equals('Urdu'));
        expect(LanguagePreferenceService.displayNameFor('ms'), equals('Malay'));
      });

      test('returns uppercased code for unknown language codes', () {
        expect(LanguagePreferenceService.displayNameFor('xx'), equals('XX'));
      });
    });

    group('declaredContentLanguage', () {
      test('is null when the user never chose a language', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final service = LanguagePreferenceService();
        await service.initialize();

        expect(service.declaredContentLanguage, isNull);
        expect(service.contentLanguage, isNotEmpty);
      });

      test('is the explicit choice once the user sets one', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final service = LanguagePreferenceService();
        await service.initialize();
        await service.setContentLanguage('pt');

        expect(service.declaredContentLanguage, equals('pt'));
      });

      test('returns to null after the choice is cleared', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          LanguagePreferenceService.prefsKey: 'pt',
        });
        final service = LanguagePreferenceService();
        await service.initialize();
        await service.clearContentLanguage();

        expect(service.declaredContentLanguage, isNull);
      });
    });
  });
}
