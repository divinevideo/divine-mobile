// ABOUTME: Tests for FeatureFlagService managing feature flag state and persistence
// ABOUTME: Validates initialization, flag management, persistence, and state notifications

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';

import 'feature_flag_service_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('FeatureFlagService', () {
    late MockSharedPreferences mockPrefs;
    late FeatureFlagService service;

    setUp(() {
      mockPrefs = MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          mockPrefs.setBool('ff_${flag.name}', any),
        ).thenAnswer((_) async => true);
        when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      service = FeatureFlagService(mockPrefs, const BuildConfiguration());
    });

    group('initialization', () {
      test('should load saved flags from preferences', () async {
        when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
        when(mockPrefs.getBool('ff_enhancedVideoPlayer')).thenReturn(false);

        await service.initialize();

        expect(service.isEnabled(FeatureFlag.newCameraUI), isTrue);
        expect(service.isEnabled(FeatureFlag.enhancedVideoPlayer), isFalse);
      });

      test('should use build defaults when no saved preference', () async {
        when(mockPrefs.getBool(any)).thenReturn(null);

        await service.initialize();

        expect(
          service.isEnabled(FeatureFlag.debugTools),
          equals(const BuildConfiguration().getDefault(FeatureFlag.debugTools)),
        );
      });

      test('should prefer user settings over build defaults', () async {
        // Build default is false, user set to true
        when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);

        await service.initialize();

        expect(service.isEnabled(FeatureFlag.newCameraUI), isTrue);
      });
    });

    group('flag management', () {
      test('should save flag changes to preferences', () async {
        await service.setFlag(FeatureFlag.newCameraUI, true);

        verify(mockPrefs.setBool('ff_newCameraUI', true)).called(1);
      });

      test('should notify listeners on flag change', () async {
        // SKIP: Service refactored to use Riverpod instead of ChangeNotifier
        // Listener notification is now handled by Riverpod providers
      }, skip: true);

      test('should reset flag to build default', () async {
        when(mockPrefs.remove('ff_newCameraUI')).thenAnswer((_) async => true);

        await service.setFlag(FeatureFlag.newCameraUI, true);
        await service.resetFlag(FeatureFlag.newCameraUI);

        verify(mockPrefs.remove('ff_newCameraUI')).called(1);
        expect(
          service.isEnabled(FeatureFlag.newCameraUI),
          equals(
            const BuildConfiguration().getDefault(FeatureFlag.newCameraUI),
          ),
        );
      });

      test('should reset all flags', () async {
        when(mockPrefs.remove(any)).thenAnswer((_) async => true);

        await service.setFlag(FeatureFlag.newCameraUI, true);
        await service.setFlag(FeatureFlag.enhancedVideoPlayer, true);

        await service.resetAllFlags();

        for (final flag in FeatureFlag.values) {
          verify(mockPrefs.remove('ff_${flag.name}')).called(1);
        }
      });
    });

    group('state queries', () {
      test('should identify user overrides', () async {
        when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);
        when(mockPrefs.containsKey('ff_enhancedVideoPlayer')).thenReturn(false);

        expect(service.hasUserOverride(FeatureFlag.newCameraUI), isTrue);
        expect(
          service.hasUserOverride(FeatureFlag.enhancedVideoPlayer),
          isFalse,
        );
      });

      test('should provide flag metadata', () {
        final metadata = service.getFlagMetadata(FeatureFlag.newCameraUI);

        expect(metadata.flag, equals(FeatureFlag.newCameraUI));
        expect(metadata.isEnabled, isNotNull);
        expect(metadata.hasUserOverride, isNotNull);
        expect(metadata.buildDefault, isNotNull);
      });
    });

    group('state management', () {
      test('should return current state', () {
        final state = service.currentState;
        expect(state, isNotNull);

        // Should have values for all flags
        for (final flag in FeatureFlag.values) {
          expect(state.allFlags.containsKey(flag), isTrue);
        }
      });

      test('should update state when flags change', () async {
        final initialState = service.currentState;

        await service.setFlag(FeatureFlag.newCameraUI, true);

        final newState = service.currentState;
        expect(newState, isNot(equals(initialState)));
        expect(newState.isEnabled(FeatureFlag.newCameraUI), isTrue);
      });
    });
  });
}
