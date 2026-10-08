// ABOUTME: Tests for Riverpod providers managing feature flag service and state
// ABOUTME: Validates provider setup, dependency injection, and state management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'listener_call_recorder.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _RecordingFeatureFlagService extends FeatureFlagService
    with ListenerCallRecorder {
  _RecordingFeatureFlagService(super._prefs, super._buildConfig);
}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

/// Runs [body] in a guarded zone and returns every error that escaped it.
Future<List<Object>> _unhandledErrorsWhile(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    await body();
    await pumpEventQueue();
  }, (error, _) => errors.add(error));
  return errors;
}

void main() {
  group('FeatureFlagProvider', () {
    test('should provide service instance', () async {
      final mockPrefs = _MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          () => mockPrefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);
      expect(service, isA<FeatureFlagService>());

      container.dispose();
    });

    test('should provide flag state', () async {
      final mockPrefs = _MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          () => mockPrefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final state = container.read(featureFlagStateProvider);
      expect(state, isA<Map<FeatureFlag, bool>>());

      // Should have values for all flags
      expect(state.keys, containsAll(FeatureFlag.values));

      container.dispose();
    });

    test('loads persisted flag overrides after provider creation', () async {
      final mockPrefs = _MockSharedPreferences();

      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          () => mockPrefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        featureFlagStateProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      expect(
        container.read(isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics)),
        isTrue,
      );
    });

    test('should update when service notifies', () async {
      final mockPrefs = _MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          () => mockPrefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);

      // Initial state
      final initialEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
      );
      expect(initialEnabled, isFalse);

      // Change flag
      await service.setFlag(FeatureFlag.enhancedAnalytics, true);

      // State should update
      final newEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
      );
      expect(newEnabled, isTrue);

      container.dispose();
    });

    test('gates internal flag overrides on developer mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ff_communityContentWarnings': true,
        'ff_enhancedAnalytics': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final environment = container.read(environmentServiceProvider);
      await environment.initialize(sharedPreferences: prefs);

      final service = container.read(featureFlagServiceProvider);
      await service.initialize();

      expect(service.isEnabled(FeatureFlag.communityContentWarnings), isFalse);
      expect(service.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
      expect(prefs.getBool('ff_communityContentWarnings'), isTrue);

      await environment.enableDeveloperMode();
      await pumpEventQueue();

      expect(
        identical(container.read(featureFlagServiceProvider), service),
        isTrue,
        reason: 'a new instance would strand every ref.read capture',
      );
      expect(service.isEnabled(FeatureFlag.communityContentWarnings), isTrue);

      await environment.disableDeveloperMode();
      await pumpEventQueue();

      expect(service.isEnabled(FeatureFlag.communityContentWarnings), isFalse);
      expect(prefs.getBool('ff_communityContentWarnings'), isTrue);
    });

    group('when a persisted flag cannot be read', () {
      late CrashReporter originalReporter;
      late _RecordingCrashReporter reporter;
      late _MockSharedPreferences mockPrefs;
      late ProviderContainer container;

      setUp(() {
        originalReporter = detachedFailureReporter;
        addTearDown(() => detachedFailureReporter = originalReporter);
        reporter = _RecordingCrashReporter();
        detachedFailureReporter = reporter;

        mockPrefs = _MockSharedPreferences();
        // What SharedPreferences.getBool throws for a non-bool stored value.
        when(
          () => mockPrefs.getBool(any(that: startsWith('ff_'))),
        ).thenThrow(TypeError());
        container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        );
        addTearDown(container.dispose);
      });

      test('reports the failure at creation instead of leaking it', () async {
        final unhandledErrors = await _unhandledErrorsWhile(() async {
          container.read(featureFlagServiceProvider);
        });

        expect(unhandledErrors, isEmpty);
        expect(
          reporter.recordedErrors.single,
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<TypeError>(),
          ),
        );
      });

      test(
        'reports the failure on a developer-mode change instead of leaking it',
        () async {
          when(
            () => mockPrefs.setBool(any(), any()),
          ).thenAnswer((_) async => true);
          final environment = container.read(environmentServiceProvider);
          await environment.initialize(sharedPreferences: mockPrefs);
          container.read(featureFlagServiceProvider);

          final unhandledErrors = await _unhandledErrorsWhile(
            environment.enableDeveloperMode,
          );

          expect(unhandledErrors, isEmpty);
          expect(
            reporter.recordedErrors,
            hasLength(2),
            reason: 'creation and the developer-mode re-read both failed',
          );
        },
      );
    });
  });

  group('featureFlagStateProvider', () {
    late _RecordingFeatureFlagService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      service = _RecordingFeatureFlagService(prefs, const BuildConfiguration());
      await service.initialize();
    });

    test(
      'publishes flag changes to dependents without resubscribing',
      () async {
        final container = ProviderContainer(
          overrides: [featureFlagServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final enabledValues = <bool>[];
        final subscription = container.listen(
          isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
          (_, next) => enabledValues.add(next),
        );

        expect(
          container.read(
            isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
          ),
          isFalse,
        );
        expect(service.addListenerCalls, equals(1));

        await service.setFlag(FeatureFlag.enhancedAnalytics, true);
        await pumpEventQueue();

        expect(
          container.read(
            isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
          ),
          isTrue,
        );
        expect(enabledValues, equals([true]));
        expect(
          service.addListenerCalls,
          equals(1),
          reason: 'a notification must not rebuild the provider subscription',
        );

        subscription.close();
        await pumpEventQueue();
        expect(service.removeListenerCalls, equals(1));
      },
    );

    test(
      'does not notify dependents when a notification changes no flag',
      () async {
        final container = ProviderContainer(
          overrides: [featureFlagServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final notifications = <Map<FeatureFlag, bool>>[];
        final subscription = container.listen(
          featureFlagStateProvider,
          (_, next) => notifications.add(next),
        );

        final currentValue = service.isEnabled(FeatureFlag.enhancedAnalytics);
        await service.setFlag(FeatureFlag.enhancedAnalytics, currentValue);
        await pumpEventQueue();

        expect(
          notifications,
          isEmpty,
          reason: 'no flag value changed, so dependents must not renotify',
        );

        subscription.close();
      },
    );
  });
}
