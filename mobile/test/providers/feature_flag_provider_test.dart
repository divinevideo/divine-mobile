// ABOUTME: Tests for Riverpod providers managing feature flag service and state
// ABOUTME: Validates provider setup, dependency injection, and state management

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';

import 'feature_flag_provider_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('FeatureFlagProvider', () {
    test('should provide service instance', () async {
      final mockPrefs = MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          mockPrefs.setBool('ff_${flag.name}', any),
        ).thenAnswer((_) async => true);
        when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);
      expect(service, isA<FeatureFlagService>());

      container.dispose();
    });

    test('should provide flag state', () async {
      final mockPrefs = MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          mockPrefs.setBool('ff_${flag.name}', any),
        ).thenAnswer((_) async => true);
        when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
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
      final mockPrefs = MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          mockPrefs.setBool('ff_${flag.name}', any),
        ).thenAnswer((_) async => true);
        when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      // Set up specific flag value
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);
      await service.initialize();

      final isEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.newCameraUI),
      );
      expect(isEnabled, isTrue);

      container.dispose();
    });

    test('should update when service notifies', () async {
      final mockPrefs = MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          mockPrefs.setBool('ff_${flag.name}', any),
        ).thenAnswer((_) async => true);
        when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );

      final service = container.read(featureFlagServiceProvider);

      // Initial state
      final initialEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.newCameraUI),
      );
      expect(initialEnabled, isFalse);

      // Change flag
      await service.setFlag(FeatureFlag.newCameraUI, true);

      // State should update
      final newEnabled = container.read(
        isFeatureEnabledProvider(FeatureFlag.newCameraUI),
      );
      expect(newEnabled, isTrue);

      container.dispose();
    });
  });
}
