// ABOUTME: Unit tests for NotificationSettingsCubit — load, preference
// ABOUTME: persistence, reset-to-defaults, and mark-all-as-read.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

class _MockNotificationPreferencesService extends Mock
    implements NotificationPreferencesService {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
    registerFallbackValue(NotificationPreference.likesEnabled);
  });

  group(NotificationSettingsCubit, () {
    late _MockNotificationPreferencesService service;
    late _MockNotificationRepository repository;
    late Completer<void> inFlight;

    setUp(() {
      service = _MockNotificationPreferencesService();
      repository = _MockNotificationRepository();
      var stored = const NotificationPreferences();
      when(service.loadPreferences).thenAnswer((_) async => stored);
      when(() => service.updatePreference(any(), any()))
          .thenAnswer((call) async {
            final field = call.positionalArguments[0] as NotificationPreference;
            stored = NotificationPreferences.fromJson({
              ...stored.toJson(),
              field.name: call.positionalArguments[1] as bool,
            });
          });
      when(service.resetToDefaults).thenAnswer((_) async {
        stored = const NotificationPreferences();
      });
      when(repository.markAllAsRead).thenAnswer((_) async {});
    });

    // No repository: the signed-out shape, where mark-all-as-read is
    // permanently unavailable.
    NotificationSettingsCubit buildCubit() =>
        NotificationSettingsCubit(preferencesService: service);

    NotificationSettingsCubit buildCubitWithRepository() =>
        NotificationSettingsCubit(
          preferencesService: service,
          notificationRepository: repository,
        );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'load emits loading then ready with the loaded preferences',
      setUp: () {
        when(service.loadPreferences).thenAnswer(
          (_) async => const NotificationPreferences(likesEnabled: false),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => const [
        NotificationSettingsState(status: NotificationSettingsStatus.loading),
        NotificationSettingsState(
          status: NotificationSettingsStatus.ready,
          preferences: NotificationPreferences(likesEnabled: false),
        ),
      ],
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'setPreference persists the changed choice and reloads the preferences',
      build: buildCubit,
      act: (cubit) =>
          cubit.setPreference(NotificationPreference.commentsEnabled, false),
      expect: () => const [
        NotificationSettingsState(
          preferences: NotificationPreferences(commentsEnabled: false),
        ),
      ],
      verify: (_) {
        verify(
          () => service.updatePreference(
            NotificationPreference.commentsEnabled,
            false,
          ),
        ).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'resetToDefaults restores defaults and persists them',
      seed: () => const NotificationSettingsState(
        status: NotificationSettingsStatus.ready,
        preferences: NotificationPreferences(likesEnabled: false),
      ),
      build: buildCubit,
      act: (cubit) => cubit.resetToDefaults(),
      expect: () => const [
        NotificationSettingsState(status: NotificationSettingsStatus.ready),
      ],
      verify: (_) {
        verify(service.resetToDefaults).called(1);
      },
    );

    group('markAllAsRead', () {
      blocTest<NotificationSettingsCubit, NotificationSettingsState>(
        'emits inProgress then success on a successful write',
        build: buildCubitWithRepository,
        act: (cubit) => cubit.markAllAsRead(),
        expect: () => const [
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.inProgress,
          ),
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.success,
          ),
        ],
        verify: (_) {
          verify(repository.markAllAsRead).called(1);
        },
      );

      blocTest<NotificationSettingsCubit, NotificationSettingsState>(
        'emits inProgress then failure and reports the error when it throws',
        setUp: () {
          when(repository.markAllAsRead).thenThrow(Exception('server fail'));
        },
        build: buildCubitWithRepository,
        act: (cubit) => cubit.markAllAsRead(),
        expect: () => const [
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.inProgress,
          ),
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationSettingsCubit, NotificationSettingsState>(
        // Guards against reordering the null check after a status emit:
        // signed-out must produce no state churn at all.
        'emits nothing without a repository',
        build: buildCubit,
        act: (cubit) => cubit.markAllAsRead(),
        expect: () => const <NotificationSettingsState>[],
      );

      blocTest<NotificationSettingsCubit, NotificationSettingsState>(
        'drops a second call while the first is still in flight',
        setUp: () {
          inFlight = Completer<void>();
          when(repository.markAllAsRead).thenAnswer((_) => inFlight.future);
        },
        build: buildCubitWithRepository,
        act: (cubit) async {
          final first = cubit.markAllAsRead();
          // Deliberately not awaited: if the guard regresses, this call
          // blocks on the same completer, and awaiting it here would
          // deadlock the test instead of failing it.
          unawaited(cubit.markAllAsRead());
          inFlight.complete();
          await first;
        },
        expect: () => const [
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.inProgress,
          ),
          NotificationSettingsState(
            markAllAsReadStatus: MarkAllAsReadStatus.success,
          ),
        ],
        verify: (_) {
          verify(repository.markAllAsRead).called(1);
        },
      );
    });
  });
}
