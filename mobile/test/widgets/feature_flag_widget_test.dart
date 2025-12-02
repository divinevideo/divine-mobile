// ABOUTME: Tests for FeatureFlagWidget conditional rendering component
// ABOUTME: Validates widget behavior based on feature flag state

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';

import 'feature_flag_widget_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('FeatureFlagWidget', () {
    late MockSharedPreferences mockPrefs;

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
    });

    testWidgets('should show child when flag enabled', (tester) async {
      // Set flag as enabled
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: FeatureFlagWidget(
              flag: FeatureFlag.newCameraUI,
              child: const Text('Enabled Content'),
            ),
          ),
        ),
      );

      // Initialize the service with the test preferences
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();

      await tester.pumpAndSettle();
      expect(find.text('Enabled Content'), findsOneWidget);
    });

    testWidgets('should show fallback when flag disabled', (tester) async {
      // Flag is disabled by default (null/false)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: FeatureFlagWidget(
              flag: FeatureFlag.newCameraUI,
              disabled: const Text('Disabled Content'),
              child: const Text('Enabled Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Disabled Content'), findsOneWidget);
      expect(find.text('Enabled Content'), findsNothing);
    });

    testWidgets('should show nothing when flag disabled and no fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Text('Before'),
                  FeatureFlagWidget(
                    flag: FeatureFlag.newCameraUI,
                    child: Container(
                      height: 100,
                      width: 100,
                      color: Colors.red,
                      child: const Text('Should not show'),
                    ),
                  ),
                  const Text('After'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Should not show'), findsNothing);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('should update when flag changes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: FeatureFlagWidget(
              flag: FeatureFlag.newCameraUI,
              disabled: const Text('Disabled Content'),
              child: const Text('Enabled Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially disabled
      expect(find.text('Disabled Content'), findsOneWidget);
      expect(find.text('Enabled Content'), findsNothing);

      // Enable the flag
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      // Trigger a rebuild by getting the service and changing the flag
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.setFlag(FeatureFlag.newCameraUI, true);

      await tester.pumpAndSettle();

      // Now should show enabled content
      expect(find.text('Enabled Content'), findsOneWidget);
      expect(find.text('Disabled Content'), findsNothing);
    });

    testWidgets('should handle multiple flags independently', (tester) async {
      // Set up different states for different flags
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.getBool('ff_enhancedVideoPlayer')).thenReturn(false);
      when(mockPrefs.containsKey('ff_enhancedVideoPlayer')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: Column(
              children: [
                FeatureFlagWidget(
                  flag: FeatureFlag.newCameraUI,
                  disabled: const Text('Camera UI Disabled'),
                  child: const Text('Camera UI Enabled'),
                ),
                FeatureFlagWidget(
                  flag: FeatureFlag.enhancedVideoPlayer,
                  disabled: const Text('Video Player Disabled'),
                  child: const Text('Video Player Enabled'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initialize the service with the test preferences
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget).first),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();

      await tester.pumpAndSettle();

      expect(find.text('Camera UI Enabled'), findsOneWidget);
      expect(find.text('Camera UI Disabled'), findsNothing);
      expect(find.text('Video Player Enabled'), findsNothing);
      expect(find.text('Video Player Disabled'), findsOneWidget);
    });

    testWidgets('should handle loading state gracefully', (tester) async {
      // Don't set up any mocks to simulate loading
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: FeatureFlagWidget(
              flag: FeatureFlag.newCameraUI,
              disabled: const Text('Disabled Content'),
              loading: const CircularProgressIndicator(),
              child: const Text('Enabled Content'),
            ),
          ),
        ),
      );

      // Should show disabled content (default behavior when not explicitly loading)
      await tester.pumpAndSettle();
      expect(find.text('Disabled Content'), findsOneWidget);
    });
  });
}
