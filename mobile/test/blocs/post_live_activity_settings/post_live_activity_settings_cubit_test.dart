// ABOUTME: Tests for PostLiveActivitySettingsCubit: loading the toggle and the
// ABOUTME: system switch, writing the toggle through, following system changes.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/post_live_activity_settings/post_live_activity_settings_cubit.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockPostLiveActivityRepository extends Mock
    implements PostLiveActivityRepository {}

void main() {
  group(PostLiveActivitySettingsCubit, () {
    late _MockPostLiveActivityRepository repository;
    late StreamController<bool> systemChanges;

    setUp(() {
      repository = _MockPostLiveActivityRepository();
      systemChanges = StreamController<bool>.broadcast();
      addTearDown(systemChanges.close);
      when(() => repository.isToggleOn).thenReturn(true);
      when(repository.isSystemEnabled).thenAnswer((_) async => true);
      when(() => repository.systemEnabledChanges)
          .thenAnswer((_) => systemChanges.stream);
      when(() => repository.setToggleOn(any())).thenAnswer((_) async {});
    });

    PostLiveActivitySettingsCubit build() =>
        PostLiveActivitySettingsCubit(repository: repository);

    group('load', () {
      blocTest<PostLiveActivitySettingsCubit, PostLiveActivitySettingsState>(
        'emits the stored toggle and the system switch',
        setUp: () {
          when(() => repository.isToggleOn).thenReturn(false);
          when(repository.isSystemEnabled).thenAnswer((_) async => false);
        },
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PostLiveActivitySettingsState(toggleOn: false, systemEnabled: false),
        ],
      );
    });

    group('setToggleOn', () {
      blocTest<PostLiveActivitySettingsCubit, PostLiveActivitySettingsState>(
        'writes the value through to the repository and emits it',
        build: build,
        act: (cubit) => cubit.setToggleOn(false),
        expect: () => const [
          PostLiveActivitySettingsState(toggleOn: false),
        ],
        verify: (_) => verify(() => repository.setToggleOn(false)).called(1),
      );
    });

    group('system switch changes', () {
      blocTest<PostLiveActivitySettingsCubit, PostLiveActivitySettingsState>(
        'follows the stream after load',
        build: build,
        act: (cubit) async {
          await cubit.load();
          systemChanges.add(false);
          await pumpEventQueue();
        },
        expect: () => const [
          PostLiveActivitySettingsState(),
          PostLiveActivitySettingsState(systemEnabled: false),
        ],
      );

      test('stops listening once closed', () async {
        final cubit = build();
        await cubit.load();
        await cubit.close();

        expect(systemChanges.hasListener, isFalse);
      });
    });
  });
}
