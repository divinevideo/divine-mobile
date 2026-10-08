// ABOUTME: Unit tests for SubtitleLanguageSettingCubit — load snapshot, target
// ABOUTME: changes, and keep-original toggles against the preference service.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/subtitle_language_setting/subtitle_language_setting_cubit.dart';
import 'package:openvine/blocs/subtitle_language_setting/subtitle_language_setting_state.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubtitleLanguagePreferenceService extends Mock
    implements SubtitleLanguagePreferenceService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  group(SubtitleLanguageSettingCubit, () {
    late _MockSubtitleLanguagePreferenceService service;

    setUp(() {
      service = _MockSubtitleLanguagePreferenceService();
      when(service.initialize).thenAnswer((_) async {});
      when(() => service.targetLanguage).thenReturn(null);
      when(() => service.keepOriginalLanguages).thenReturn(const {});
      when(() => service.setTargetLanguage(any())).thenAnswer((_) async {});
      when(
        () => service.setKeepOriginalLanguages(any()),
      ).thenAnswer((_) async {});
    });

    SubtitleLanguageSettingCubit buildCubit() =>
        SubtitleLanguageSettingCubit(service: service);

    test(
      'refreshes an open setting after account preferences are cleared',
      () async {
        SharedPreferences.setMockInitialValues({
          SubtitleLanguagePreferenceService.targetLanguageStorageKey: 'es',
        });
        final realService = SubtitleLanguagePreferenceService();
        final cubit = SubtitleLanguageSettingCubit(service: realService);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.targetLanguage, 'es');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(
          SubtitleLanguagePreferenceService.targetLanguageStorageKey,
        );
        await realService.reloadFromStorage();
        expect(cubit.state.targetLanguage, isNull);
      },
    );

    group('load', () {
      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'emits the stored preferences, kept languages sorted by code',
        setUp: () {
          when(() => service.targetLanguage).thenReturn('pt');
          when(() => service.keepOriginalLanguages).thenReturn({'ko', 'ja'});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            targetLanguage: 'pt',
            keepOriginalLanguages: ['ja', 'ko'],
          ),
        ],
        verify: (_) => verify(service.initialize).called(1),
      );
    });

    group('setTargetLanguage', () {
      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'writes the language and emits what the service now holds',
        setUp: () {
          when(() => service.targetLanguage).thenReturn('de');
        },
        seed: () => const SubtitleLanguageSettingState(
          status: SubtitleLanguageSettingStatus.ready,
        ),
        build: buildCubit,
        act: (cubit) => cubit.setTargetLanguage('de'),
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            targetLanguage: 'de',
          ),
        ],
        verify: (_) => verify(() => service.setTargetLanguage('de')).called(1),
      );

      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'clears the language so subtitles follow the app again',
        seed: () => const SubtitleLanguageSettingState(
          status: SubtitleLanguageSettingStatus.ready,
          targetLanguage: 'de',
        ),
        build: buildCubit,
        act: (cubit) => cubit.setTargetLanguage(null),
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
          ),
        ],
        verify: (_) => verify(() => service.setTargetLanguage(null)).called(1),
      );

      test('drops the result when closed before the write lands', () async {
        final write = Completer<void>();
        when(
          () => service.setTargetLanguage(any()),
        ).thenAnswer((_) => write.future);
        final cubit = buildCubit();

        final pending = cubit.setTargetLanguage('de');
        await cubit.close();
        write.complete();

        await expectLater(pending, completes);
      });
    });

    group('toggleKeepOriginalLanguage', () {
      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'adds a language and persists the new set',
        setUp: () {
          when(() => service.keepOriginalLanguages).thenReturn({'ja'});
        },
        seed: () => const SubtitleLanguageSettingState(
          status: SubtitleLanguageSettingStatus.ready,
        ),
        build: buildCubit,
        act: (cubit) => cubit.toggleKeepOriginalLanguage('ja'),
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            keepOriginalLanguages: ['ja'],
          ),
        ],
        verify: (_) =>
            verify(() => service.setKeepOriginalLanguages({'ja'})).called(1),
      );

      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'removes a language that is already kept',
        setUp: () {
          when(() => service.keepOriginalLanguages).thenReturn({'ko'});
        },
        seed: () => const SubtitleLanguageSettingState(
          status: SubtitleLanguageSettingStatus.ready,
          keepOriginalLanguages: ['ja', 'ko'],
        ),
        build: buildCubit,
        act: (cubit) => cubit.toggleKeepOriginalLanguage('ja'),
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            keepOriginalLanguages: ['ko'],
          ),
        ],
        verify: (_) =>
            verify(() => service.setKeepOriginalLanguages({'ko'})).called(1),
      );

      blocTest<SubtitleLanguageSettingCubit, SubtitleLanguageSettingState>(
        'keeps both languages when a second tap lands before the first write',
        setUp: () {
          when(() => service.keepOriginalLanguages).thenReturn({'ja', 'ko'});
        },
        seed: () => const SubtitleLanguageSettingState(
          status: SubtitleLanguageSettingStatus.ready,
        ),
        build: buildCubit,
        act: (cubit) async {
          final write = Completer<void>();
          when(
            () => service.setKeepOriginalLanguages(any()),
          ).thenAnswer((_) => write.future);
          final first = cubit.toggleKeepOriginalLanguage('ja');
          final second = cubit.toggleKeepOriginalLanguage('ko');
          write.complete();
          await Future.wait([first, second]);
        },
        expect: () => const [
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            keepOriginalLanguages: ['ja'],
          ),
          SubtitleLanguageSettingState(
            status: SubtitleLanguageSettingStatus.ready,
            keepOriginalLanguages: ['ja', 'ko'],
          ),
        ],
        verify: (_) => verify(
          () => service.setKeepOriginalLanguages({'ja', 'ko'}),
        ).called(1),
      );
    });
  });
}
