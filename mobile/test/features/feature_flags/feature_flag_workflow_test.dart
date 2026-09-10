// ABOUTME: Widget-level workflow tests for the feature flag system
// ABOUTME: Validates flag service, providers, widgets, and screen working together
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('Feature Flag System Integration', () {
    late _MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = _MockSharedPreferences();

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
    });

    testWidgets('should provide complete feature flag management workflow', (
      tester,
    ) async {
      // Create a complete app with both settings screen and feature-gated content
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const TestHomeScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const FeatureFlagScreen(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
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
      expect(find.text('Enhanced Analytics'), findsOneWidget);

      // Enable the feature flag
      // Update mock to return true when getBool is called after toggle
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      final flagSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Enhanced Analytics'),
          matching: find.byType(Card),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(flagSwitch);
      await tester.pumpAndSettle();

      // Verify persistence call was made
      verify(() => mockPrefs.setBool('ff_enhancedAnalytics', true)).called(1);

      // Navigate back to home
      await tester.tap(find.byType(DivineAppBarIconButton).first);
      await tester.pumpAndSettle();

      // Verify feature is now enabled
      expect(find.text('Standard Camera UI'), findsNothing);
      expect(find.text('Enhanced Camera UI'), findsOneWidget);
    });

    testWidgets('should handle multiple flags independently', (tester) async {
      // Set up mixed initial state
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const FeatureFlagWidget(
                    flag: FeatureFlag.enhancedAnalytics,
                    disabled: Text('Standard Camera'),
                    child: Text('Enhanced Camera'),
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

      // Navigate to settings to verify switch states
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify switches are present - ListView.builder may not build all items in tests
      // so we verify we have at least some switches rather than exact count
      final switchWidgets = tester.widgetList<Switch>(find.byType(Switch));
      expect(
        switchWidgets.length,
        greaterThanOrEqualTo(2),
        reason: 'Should show switches for feature flags in settings',
      );

      // Verify the feature flag list items are present
      expect(find.text('Enhanced Analytics'), findsOneWidget);
    });

    testWidgets('should persist flag changes across app restarts', (
      tester,
    ) async {
      // Simulate first app launch with user changing flags
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagScreen(),
          ),
        ),
      );

      // Initialize service
      final container1 = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service1 = container1.read(featureFlagServiceProvider);
      await service1.initialize();
      await tester.pumpAndSettle();

      // Change a flag - find the enhancedAnalytics switch specifically
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      final flagSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Enhanced Analytics'),
          matching: find.byType(Card),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(flagSwitch);
      await tester.pumpAndSettle();

      // Verify persistence call
      verify(() => mockPrefs.setBool('ff_enhancedAnalytics', true)).called(1);

      // Simulate app restart by setting up persistence response
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      // Create new app instance (simulating restart)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TestContentScreen(),
          ),
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
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  FeatureFlagWidget(
                    flag: FeatureFlag.enhancedAnalytics,
                    disabled: Text('Standard Camera'),
                    child: Text('Enhanced Camera'),
                  ),
                  Expanded(child: FeatureFlagScreen()),
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
      final l10n = lookupAppLocalizations(const Locale('en'));
      final resetButton = find.bySemanticsLabel(
        l10n.featureFlagResetAllTooltip,
      );
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify visible/user-facing flags were reset without deleting hidden
      // internal overrides.
      for (final flag in FeatureFlag.values) {
        if (flag.isInternal) {
          verifyNever(() => mockPrefs.remove('ff_${flag.name}'));
        } else {
          verify(() => mockPrefs.remove('ff_${flag.name}')).called(1);
        }
      }

      // Simulate SharedPreferences after reset
      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      // Verify UI reflects reset state (build defaults)
      await tester.pumpAndSettle();
      // Since build defaults are false, should show standard camera
      expect(find.text('Standard Camera'), findsOneWidget);
      expect(find.text('Enhanced Camera'), findsNothing);
    });

    testWidgets('renders a stored override as the row state', (tester) async {
      // Set up one flag with user override; every other flag keeps its default.
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagScreen(),
          ),
        ),
      );

      // Initialize service
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();

      // The row's own switch is the override indicator — a flag forced on
      // reads on, and every flag left at its default reads off.
      final overriddenRow = find.ancestor(
        of: find.text(FeatureFlag.enhancedAnalytics.displayName),
        matching: find.byType(ListTile),
      );
      final overriddenSwitch = tester.widget<DivineSwitch>(
        find.descendant(of: overriddenRow, matching: find.byType(DivineSwitch)),
      );
      expect(overriddenSwitch.value, isTrue);

      // integratedApps shares enhancedAnalytics' false build default but has
      // no stored override, so it stays off.
      final defaultedRow = find.ancestor(
        of: find.text(FeatureFlag.integratedApps.displayName),
        matching: find.byType(ListTile),
      );
      final defaultedSwitch = tester.widget<DivineSwitch>(
        find.descendant(of: defaultedRow, matching: find.byType(DivineSwitch)),
      );
      expect(defaultedSwitch.value, isFalse);
    });

    testWidgets('should handle service errors gracefully', (tester) async {
      // Set up SharedPreferences to throw exceptions
      when(
        () => mockPrefs.setBool(any(), any()),
      ).thenThrow(Exception('Storage error'));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const FeatureFlagWidget(
                    flag: FeatureFlag.enhancedAnalytics,
                    disabled: Text('Standard Camera'),
                    child: Text('Enhanced Camera'),
                  ),
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => context.go('/settings'),
                      child: const Text('Open Settings'),
                    ),
                  ),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const FeatureFlagScreen(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
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
      final flagSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Enhanced Analytics'),
          matching: find.byType(Card),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(flagSwitch);
      await tester.pumpAndSettle();

      // App should still be functional
      expect(find.byType(FeatureFlagScreen), findsOneWidget);
      expect(find.text('Feature Flags'), findsOneWidget);

      // Navigate back to see if in-memory state was updated despite storage error
      await tester.tap(find.byType(DivineAppBarIconButton).first);
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
          const FeatureFlagWidget(
            flag: FeatureFlag.enhancedAnalytics,
            disabled: Text('Standard Camera UI'),
            child: Text('Enhanced Camera UI'),
          ),
          ElevatedButton(
            onPressed: () => context.go('/settings'),
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
    return const Scaffold(
      body: FeatureFlagWidget(
        flag: FeatureFlag.enhancedAnalytics,
        disabled: Text('Standard Camera'),
        child: Text('New Camera Feature Enabled'),
      ),
    );
  }
}
