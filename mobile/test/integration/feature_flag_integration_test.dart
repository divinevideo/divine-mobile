// ABOUTME: Integration tests for complete feature flag system end-to-end functionality
// ABOUTME: Validates flag service, providers, widgets, and screen working together

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';

import 'feature_flag_integration_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('Feature Flag System Integration', () {
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

    testWidgets('should provide complete feature flag management workflow', (
      tester,
    ) async {
      // Create a complete app with both settings screen and feature-gated content
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: const TestHomeScreen(),
            routes: {'/settings': (context) => const FeatureFlagScreen()},
          ),
        ),
      );

      // Initialize service and wait for widgets to rebuild
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TestHomeScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Wait one more frame to ensure all providers have updated
      await tester.pump();

      // Verify initial state - feature should be disabled by default
      expect(find.text('Enhanced Camera UI'), findsNothing);
      expect(find.text('Standard Camera UI'), findsOneWidget);

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify settings screen loaded
      expect(find.text('Feature Flags'), findsOneWidget);
      expect(find.text('New Camera UI'), findsOneWidget);

      // Enable the new camera UI feature
      final switches = find.byType(Switch);

      // Update mock to return true when getBool is called after toggle
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify persistence call was made
      verify(mockPrefs.setBool('ff_newCameraUI', true)).called(1);

      // Navigate back to home
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify feature is now enabled
      expect(find.text('Standard Camera UI'), findsNothing);
      expect(find.text('Enhanced Camera UI'), findsOneWidget);
    });

    testWidgets('should handle multiple flags independently', (tester) async {
      // Set up mixed initial state
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.getBool('ff_enhancedVideoPlayer')).thenReturn(false);
      when(mockPrefs.containsKey('ff_enhancedVideoPlayer')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FeatureFlagWidget(
                    flag: FeatureFlag.newCameraUI,
                    disabled: const Text('Standard Camera'),
                    child: const Text('Enhanced Camera'),
                  ),
                  FeatureFlagWidget(
                    flag: FeatureFlag.enhancedVideoPlayer,
                    disabled: const Text('Standard Player'),
                    child: const Text('Enhanced Player'),
                  ),
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeatureFlagScreen(),
                        ),
                      ),
                      child: const Text('Open Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget).first),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Verify independent flag states
      expect(find.text('Enhanced Camera'), findsOneWidget);
      expect(find.text('Standard Camera'), findsNothing);
      expect(find.text('Standard Player'), findsOneWidget);
      expect(find.text('Enhanced Player'), findsNothing);

      // Navigate to settings to verify switch states
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify switches are present - ListView.builder may not build all items in tests
      // so we verify we have at least some switches rather than exact count
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(
        switches.length,
        greaterThanOrEqualTo(2),
        reason: 'Should show switches for feature flags in settings',
      );

      // Verify the feature flag list items are present
      expect(find.text('New Camera UI'), findsOneWidget);
      expect(find.text('Enhanced Video Player'), findsOneWidget);
    });

    testWidgets('should persist flag changes across app restarts', (
      tester,
    ) async {
      // Simulate first app launch with user changing flags
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: FeatureFlagScreen()),
        ),
      );

      // Initialize service
      final container1 = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service1 = container1.read(featureFlagServiceProvider);
      await service1.initialize();
      await tester.pumpAndSettle();

      // Change a flag
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      // Verify persistence call
      verify(mockPrefs.setBool('ff_newCameraUI', true)).called(1);

      // Simulate app restart by setting up persistence response
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);

      // Create new app instance (simulating restart)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(home: TestContentScreen()),
        ),
      );

      // Initialize service in new app instance
      final container2 = ProviderScope.containerOf(
        tester.element(find.byType(TestContentScreen)),
      );
      final service2 = container2.read(featureFlagServiceProvider);
      await service2.initialize();
      await tester.pumpAndSettle();

      // Verify flag state was restored
      expect(find.text('New Camera Feature Enabled'), findsOneWidget);
      expect(find.text('Standard Camera'), findsNothing);
    });

    testWidgets('should handle flag reset functionality', (tester) async {
      // Set up flags with user overrides
      when(mockPrefs.getBool('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.containsKey('ff_newCameraUI')).thenReturn(true);
      when(mockPrefs.getBool('ff_enhancedVideoPlayer')).thenReturn(false);
      when(mockPrefs.containsKey('ff_enhancedVideoPlayer')).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FeatureFlagWidget(
                    flag: FeatureFlag.newCameraUI,
                    disabled: const Text('Standard Camera'),
                    child: const Text('Enhanced Camera'),
                  ),
                  const Expanded(child: FeatureFlagScreen()),
                ],
              ),
            ),
          ),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Verify initial state with overrides
      expect(find.text('Enhanced Camera'), findsOneWidget);

      // Reset all flags
      final resetButton = find.byIcon(Icons.restore);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify all flags were reset
      for (final flag in FeatureFlag.values) {
        verify(mockPrefs.remove('ff_${flag.name}')).called(1);
      }

      // Simulate SharedPreferences after reset
      for (final flag in FeatureFlag.values) {
        when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      // Verify UI reflects reset state (build defaults)
      await tester.pumpAndSettle();
      // Since build defaults are false, should show standard camera
      expect(find.text('Standard Camera'), findsOneWidget);
      expect(find.text('Enhanced Camera'), findsNothing);
    });

    testWidgets('should show override indicators correctly', (tester) async {
      // Set up one flag with user override, one with default
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

      // Look for override indicators (edit icons)
      final editIcons = find.byIcon(Icons.edit);
      expect(editIcons, findsAtLeast(1));

      // Look for individual reset buttons
      final undoIcons = find.byIcon(Icons.undo);
      expect(undoIcons, findsAtLeast(1));
    });

    testWidgets('should handle service errors gracefully', (tester) async {
      // Set up SharedPreferences to throw exceptions
      when(mockPrefs.setBool(any, any)).thenThrow(Exception('Storage error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FeatureFlagWidget(
                    flag: FeatureFlag.newCameraUI,
                    disabled: const Text('Standard Camera'),
                    child: const Text('Enhanced Camera'),
                  ),
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeatureFlagScreen(),
                        ),
                      ),
                      child: const Text('Open Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // Initially should show standard camera
      expect(find.text('Standard Camera'), findsOneWidget);
      expect(find.text('Enhanced Camera'), findsNothing);

      // Navigate to settings
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Try to toggle a flag - should not crash the app but should update UI
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      // App should still be functional
      expect(find.byType(FeatureFlagScreen), findsOneWidget);
      expect(find.text('Feature Flags'), findsOneWidget);

      // Navigate back to see if in-memory state was updated despite storage error
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should show enhanced camera (in-memory state updated despite storage error)
      expect(find.text('Enhanced Camera'), findsOneWidget);
      expect(find.text('Standard Camera'), findsNothing);
    });
  });
}

/// Test home screen with navigation to settings
class TestHomeScreen extends ConsumerWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          FeatureFlagWidget(
            flag: FeatureFlag.newCameraUI,
            disabled: const Text('Standard Camera UI'),
            child: const Text('Enhanced Camera UI'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}

/// Test content screen for persistence testing
class TestContentScreen extends ConsumerWidget {
  const TestContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: FeatureFlagWidget(
        flag: FeatureFlag.newCameraUI,
        disabled: const Text('Standard Camera'),
        child: const Text('New Camera Feature Enabled'),
      ),
    );
  }
}
