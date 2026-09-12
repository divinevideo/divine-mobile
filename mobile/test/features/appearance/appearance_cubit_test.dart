// ABOUTME: Tests for appearance state, persistence, and theme-mode resolution.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';

class _MockAppearanceRepository extends Mock implements AppearanceRepository {}

void main() {
  group(AppearanceCubit, () {
    late _MockAppearanceRepository repository;

    setUp(() {
      repository = _MockAppearanceRepository();
    });

    test('starts with the default mode before loading preferences', () {
      final cubit = AppearanceCubit(repository);
      addTearDown(cubit.close);

      expect(cubit.state, defaultAppearanceMode);
    });

    blocTest<AppearanceCubit, AppearanceMode>(
      'loads the persisted mode',
      setUp: () {
        when(repository.load).thenAnswer((_) async => AppearanceMode.light);
      },
      build: () => AppearanceCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [AppearanceMode.light],
      verify: (_) => verify(repository.load).called(1),
    );

    blocTest<AppearanceCubit, AppearanceMode>(
      'keeps the default mode when load fails',
      setUp: () {
        when(repository.load).thenThrow(StateError('read failed'));
      },
      build: () => AppearanceCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => <AppearanceMode>[],
      verify: (_) => verify(repository.load).called(1),
    );

    blocTest<AppearanceCubit, AppearanceMode>(
      'emits the selected mode before saving it',
      setUp: () {
        when(
          () => repository.save(AppearanceMode.dark),
        ).thenAnswer((_) async {});
      },
      build: () => AppearanceCubit(repository),
      act: (cubit) => cubit.setMode(AppearanceMode.dark),
      expect: () => [AppearanceMode.dark],
      verify: (_) =>
          verify(() => repository.save(AppearanceMode.dark)).called(1),
    );

    blocTest<AppearanceCubit, AppearanceMode>(
      'keeps the selected mode when persistence fails',
      setUp: () {
        when(
          () => repository.save(AppearanceMode.light),
        ).thenThrow(StateError('write failed'));
      },
      build: () => AppearanceCubit(repository),
      act: (cubit) => cubit.setMode(AppearanceMode.light),
      expect: () => [AppearanceMode.light],
    );

    test('resolves System to the platform-reactive ThemeMode', () {
      expect(resolveThemeMode(mode: AppearanceMode.system), ThemeMode.system);
    });

    test('resolves explicit modes', () {
      // Light is the case the removed gate used to force back to dark, so
      // this also pins that a stored Light choice now survives.
      expect(resolveThemeMode(mode: AppearanceMode.light), ThemeMode.light);
      expect(resolveThemeMode(mode: AppearanceMode.dark), ThemeMode.dark);
    });
  });
}
