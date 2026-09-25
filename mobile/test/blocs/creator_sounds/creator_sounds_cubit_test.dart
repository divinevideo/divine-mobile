import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/creator_sounds/creator_sounds_cubit.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockCreatorAnalyticsRepository extends Mock
    implements CreatorAnalyticsRepository {}

const _pubkey =
    '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

CreatorSound _sound(String id, int videoCount) => CreatorSound(
  id: id,
  title: id,
  createdAt: DateTime.utc(2026, 9),
  videoCount: videoCount,
);

void main() {
  group(CreatorSoundsCubit, () {
    late _MockCreatorAnalyticsRepository repository;

    setUp(() {
      repository = _MockCreatorAnalyticsRepository();
    });

    CreatorSoundsCubit buildCubit() =>
        CreatorSoundsCubit(repository: repository, pubkey: _pubkey);

    group('load', () {
      final ranked = List.generate(7, (index) => _sound('s$index', 7 - index));

      blocTest<CreatorSoundsCubit, CreatorSoundsState>(
        'emits the most used sounds, capped at the shown limit',
        setUp: () {
          when(
            () => repository.fetchCreatorSounds(_pubkey),
          ).thenAnswer((_) async => ranked);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const CreatorSoundsState(status: CreatorSoundsStatus.loading),
          CreatorSoundsState(
            status: CreatorSoundsStatus.success,
            sounds: ranked.take(CreatorSoundsCubit.shownSoundLimit).toList(),
          ),
        ],
      );

      blocTest<CreatorSoundsCubit, CreatorSoundsState>(
        'emits success with no sounds when the creator has none',
        setUp: () {
          when(
            () => repository.fetchCreatorSounds(_pubkey),
          ).thenAnswer((_) async => const []);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          CreatorSoundsState(status: CreatorSoundsStatus.loading),
          CreatorSoundsState(status: CreatorSoundsStatus.success),
        ],
      );

      blocTest<CreatorSoundsCubit, CreatorSoundsState>(
        'emits the failure kind of a failed load',
        setUp: () {
          when(() => repository.fetchCreatorSounds(_pubkey)).thenThrow(
            const CreatorAnalyticsLoadException(
              CreatorAnalyticsFailureKind.connectionIssue,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          CreatorSoundsState(status: CreatorSoundsStatus.loading),
          CreatorSoundsState(
            status: CreatorSoundsStatus.failure,
            failureKind: CreatorAnalyticsFailureKind.connectionIssue,
          ),
        ],
        errors: () => [isA<CreatorAnalyticsLoadException>()],
      );

      blocTest<CreatorSoundsCubit, CreatorSoundsState>(
        'reports an unexpected error and shows the generic failure',
        setUp: () {
          when(
            () => repository.fetchCreatorSounds(_pubkey),
          ).thenThrow(StateError('broken invariant'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          CreatorSoundsState(status: CreatorSoundsStatus.loading),
          CreatorSoundsState(
            status: CreatorSoundsStatus.failure,
            failureKind: CreatorAnalyticsFailureKind.unableToLoad,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<CreatorSoundsCubit, CreatorSoundsState>(
        'reloads after a failure',
        setUp: () {
          var calls = 0;
          when(() => repository.fetchCreatorSounds(_pubkey)).thenAnswer((
            _,
          ) async {
            calls++;
            if (calls == 1) {
              throw const CreatorAnalyticsLoadException(
                CreatorAnalyticsFailureKind.serverUnavailable,
              );
            }
            return [_sound('s0', 3)];
          });
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.load();
        },
        skip: 2,
        expect: () => [
          const CreatorSoundsState(status: CreatorSoundsStatus.loading),
          CreatorSoundsState(
            status: CreatorSoundsStatus.success,
            sounds: [_sound('s0', 3)],
          ),
        ],
        errors: () => [isA<CreatorAnalyticsLoadException>()],
      );

      test('ignores a load requested while one is running', () async {
        final pending = Completer<List<CreatorSound>>();
        when(
          () => repository.fetchCreatorSounds(_pubkey),
        ).thenAnswer((_) => pending.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final first = cubit.load();
        final second = cubit.load();
        pending.complete([_sound('s0', 3)]);
        await Future.wait([first, second]);

        verify(() => repository.fetchCreatorSounds(_pubkey)).called(1);
        expect(cubit.state.status, equals(CreatorSoundsStatus.success));
      });
    });
  });
}
