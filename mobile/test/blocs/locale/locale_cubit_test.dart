// ABOUTME: Tests for LocaleCubit
// ABOUTME: Verifies load / set / clear behavior and service delegation.

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
