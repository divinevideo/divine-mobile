// ABOUTME: Tests for LocaleCubit
// ABOUTME: Verifies load / set / clear behavior and service delegation.

import 'dart:async';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/services/locale_preference_service.dart';

class _MockLocalePreferenceService extends Mock
    implements LocalePreferenceService {}

void main() {
  group(LocaleCubit, () {
    late _MockLocalePreferenceService service;

    setUp(() {
      service = _MockLocalePreferenceService();
      when(() => service.setLocale(any())).thenAnswer((_) async {});
      when(() => service.clearLocale()).thenAnswer((_) async {});
    });

    LocaleCubit build() => LocaleCubit(localePreferenceService: service);

    group('initial load', () {
      test('starts with no locale when service has nothing saved', () async {
        when(() => service.getLocale()).thenReturn(null);

        final cubit = build();

        expect(cubit.state, const LocaleState());
        expect(cubit.state.locale, isNull);

        await cubit.close();
      });

      test('emits saved locale on construction', () async {
        when(() => service.getLocale()).thenReturn('es');

        final cubit = build();

        expect(cubit.state.locale, const Locale('es'));

        await cubit.close();
      });
    });

    group('setLocale', () {
      blocTest<LocaleCubit, LocaleState>(
        'persists and emits the new locale',
        setUp: () => when(() => service.getLocale()).thenReturn(null),
        build: build,
        act: (cubit) => cubit.setLocale('tr'),
        expect: () => const [LocaleState(locale: Locale('tr'))],
        verify: (_) {
          verify(() => service.setLocale('tr')).called(1);
        },
      );
    });

    group('clearLocale', () {
      blocTest<LocaleCubit, LocaleState>(
        'clears the saved locale and emits null locale',
        setUp: () => when(() => service.getLocale()).thenReturn('es'),
        build: build,
        act: (cubit) => cubit.clearLocale(),
        expect: () => const [LocaleState()],
        verify: (_) {
          verify(() => service.clearLocale()).called(1);
        },
      );
    });

    group('preloading the UI language', () {
      late Completer<void> download;
      late List<Locale?> preloaded;

      setUp(() {
        when(() => service.getLocale()).thenReturn(null);
        download = Completer<void>();
        preloaded = [];
      });

      LocaleCubit buildPreloading() => LocaleCubit(
        localePreferenceService: service,
        preloadLocale: (locale) {
          preloaded.add(locale);
          return download.future;
        },
      );

      test('switches only once the new language has downloaded', () async {
        final cubit = buildPreloading();
        addTearDown(cubit.close);

        final switched = cubit.setLocale('de');
        await pumpEventQueue();

        // A context-less service built now would still read the English
        // fallback on the web, so the app must not be in German yet.
        expect(preloaded, [const Locale('de')]);
        expect(cubit.state.locale, isNull);

        download.complete();
        await switched;

        expect(cubit.state.locale, const Locale('de'));
      });

      test(
        'keeps the latest selection when an older download finishes last',
        () async {
          final downloads = {
            'de': Completer<void>(),
            'es': Completer<void>(),
          };
          final cubit = LocaleCubit(
            localePreferenceService: service,
            preloadLocale: (locale) => downloads[locale!.languageCode]!.future,
          );
          addTearDown(cubit.close);

          final german = cubit.setLocale('de');
          await pumpEventQueue();
          final spanish = cubit.setLocale('es');
          await pumpEventQueue();

          downloads['es']!.complete();
          await spanish;
          expect(cubit.state.locale, const Locale('es'));

          downloads['de']!.complete();
          await german;

          expect(cubit.state.locale, const Locale('es'));
        },
      );

      test('preloads the device language before following it', () async {
        when(() => service.getLocale()).thenReturn('es');
        final cubit = buildPreloading();
        addTearDown(cubit.close);

        final cleared = cubit.clearLocale();
        await pumpEventQueue();

        expect(preloaded, [null]);
        expect(cubit.state.locale, const Locale('es'));

        download.complete();
        await cleared;

        expect(cubit.state.locale, isNull);
      });
    });

    group(LocaleState, () {
      test('instances with equal locales are equal', () {
        expect(
          const LocaleState(locale: Locale('es')),
          equals(const LocaleState(locale: Locale('es'))),
        );
      });

      test('instances with different locales are not equal', () {
        expect(
          const LocaleState(locale: Locale('es')),
          isNot(equals(const LocaleState(locale: Locale('tr')))),
        );
      });

      test('default state has null locale', () {
        expect(const LocaleState().locale, isNull);
      });
    });
  });
}
