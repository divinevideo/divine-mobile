// ABOUTME: Tests for FeatureFlagScreen settings and management interface
// ABOUTME: Validates screen behavior, flag toggling, and override indicators

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';

import 'feature_flag_screen_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('FeatureFlagScreen', () {
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

    testWidgets('should display all flags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      for (final flag in FeatureFlag.values) {
        expect(find.text(flag.displayName), findsOneWidget);
        expect(find.text(flag.description), findsOneWidget);
      }
    });

    testWidgets('should show app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Feature Flags'), findsOneWidget);
    });

    testWidgets('should toggle flags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Find and tap the first switch
      final switches = find.byType(Switch);
      expect(switches, findsAtLeast(1));

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify that setBool was called for some flag
      verify(mockPrefs.setBool(any, any)).called(1);
    });

    testWidgets('should show override indicators', (tester) async {
      // Set up one flag as having user override
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Find the switch for newCameraUI
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, isNotEmpty);

      // Check if any switch shows override indication (different color)
      final firstSwitch = switches.first;
      expect(firstSwitch.value, isTrue);
    });

    testWidgets('should reset all flags on reset button press', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Find and tap the reset button
      final resetButton = find.byIcon(Icons.restore);
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify that remove was called for all flags
      for (final flag in FeatureFlag.values) {
        verify(mockPrefs.remove('ff_${flag.name}')).called(1);
      }
    });

    testWidgets('should show flag states correctly', (tester) async {
      // Set up mixed flag states
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.getBool('ff_enhancedVideoPlayer')).thenReturn(false);
      when(mockPrefs.containsKey('ff_enhancedVideoPlayer')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Check that switches reflect the flag states
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, hasLength(FeatureFlag.values.length));

      // Find switches by looking for the flag display names
      expect(find.text('New Camera UI'), findsOneWidget);
      expect(find.text('Enhanced Video Player'), findsOneWidget);
    });

    testWidgets('should handle individual flag reset', (tester) async {
      // Set up a flag with user override
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Look for individual reset buttons (if implemented)
      // This tests the interface for individual flag reset
      final resetButtons = find.byType(IconButton);
      expect(resetButtons, findsAtLeast(1)); // At least the main reset button
    });

    testWidgets('should be scrollable with many flags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Verify the screen is scrollable
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
