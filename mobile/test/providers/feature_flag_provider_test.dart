// ABOUTME: Tests for Riverpod providers managing feature flag service and state
// ABOUTME: Validates provider setup, dependency injection, and state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'listener_call_recorder.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _RecordingFeatureFlagService extends FeatureFlagService
    with ListenerCallRecorder {
  _RecordingFeatureFlagService(super._prefs, super._buildConfig);
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

    test('should provide individual flag checks', () async {
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

      // Set up specific flag value
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);
      await service.initialize();

      final isEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics),
      );
      expect(isEnabled, isTrue);

      container.dispose();
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
