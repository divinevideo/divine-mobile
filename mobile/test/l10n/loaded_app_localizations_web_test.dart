// ABOUTME: Tests the web localizations cache: English is always available, and
// ABOUTME: any other locale resolves synchronously once its download finished.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_de.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/loaded_app_localizations_web.dart';

void main() {
  group('loadedAppLocalizations', () {
    tearDown(resetLoadedAppLocalizations);

    test('has English before anything is downloaded', () {
      expect(
        loadedAppLocalizations(const Locale('en')),
        isA<AppLocalizationsEn>(),
      );
    });

    test('has no other locale until it is downloaded', () {
      expect(loadedAppLocalizations(const Locale('fr')), isNull);
    });
  });

  group('ensureAppLocalizationsLoaded', () {
    late Completer<AppLocalizations> download;
    late List<Locale> requested;

    setUp(() {
      download = Completer<AppLocalizations>();
      requested = [];
      loadDeferredAppLocalizations = (locale) {
        requested.add(locale);
        return download.future;
      };
    });

    tearDown(resetLoadedAppLocalizations);

    test('makes a slow locale available once its download finishes', () async {
      final loaded = ensureAppLocalizationsLoaded(const Locale('de'));
      var settled = false;
      unawaited(loaded.then((_) => settled = true));
      await pumpEventQueue();

      // Still downloading: a caller that waits for this future has not been
      // released yet, so it cannot capture the English fallback.
      expect(settled, isFalse);
      expect(loadedAppLocalizations(const Locale('de')), isNull);

      download.complete(AppLocalizationsDe());
      await loaded;

      expect(
        loadedAppLocalizations(const Locale('de')),
        isA<AppLocalizationsDe>(),
      );
    });

    test('shares one download between concurrent callers', () async {
      final first = ensureAppLocalizationsLoaded(const Locale('de'));
      final second = ensureAppLocalizationsLoaded(const Locale('de'));

      download.complete(AppLocalizationsDe());
      await Future.wait([first, second]);

      expect(requested, [const Locale('de')]);
    });

    test('does not download English, which ships in the main bundle', () async {
      await ensureAppLocalizationsLoaded(const Locale('en'));

      expect(requested, isEmpty);
    });

    test('retries a download that failed', () async {
      final failed = ensureAppLocalizationsLoaded(const Locale('de'));
      download.completeError(StateError('offline'));
      await expectLater(failed, throwsStateError);
      expect(loadedAppLocalizations(const Locale('de')), isNull);

      download = Completer<AppLocalizations>()..complete(AppLocalizationsDe());
      await ensureAppLocalizationsLoaded(const Locale('de'));

      expect(requested, hasLength(2));
      expect(
        loadedAppLocalizations(const Locale('de')),
        isA<AppLocalizationsDe>(),
      );
    });
  });
}
