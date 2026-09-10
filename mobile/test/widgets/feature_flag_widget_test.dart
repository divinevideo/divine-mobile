// ABOUTME: Tests for FeatureFlagWidget conditional rendering component
// ABOUTME: Validates widget behavior based on feature flag state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('FeatureFlagWidget', () {
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

    testWidgets('should show child when flag enabled', (tester) async {
      // Set flag as enabled
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
            home: FeatureFlagWidget(
              flag: FeatureFlag.enhancedAnalytics,
              child: Text('Enabled Content'),
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagWidget(
              flag: FeatureFlag.enhancedAnalytics,
              disabled: Text('Disabled Content'),
              child: Text('Enabled Content'),
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const Text('Before'),
                  FeatureFlagWidget(
                    flag: FeatureFlag.enhancedAnalytics,
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagWidget(
              flag: FeatureFlag.enhancedAnalytics,
              disabled: Text('Disabled Content'),
              child: Text('Enabled Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially disabled
      expect(find.text('Disabled Content'), findsOneWidget);
      expect(find.text('Enabled Content'), findsNothing);

      // Enable the flag
      when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
      when(
        () => mockPrefs.containsKey('ff_enhancedAnalytics'),
      ).thenReturn(true);

      // Trigger a rebuild by getting the service and changing the flag
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagWidget)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.setFlag(FeatureFlag.enhancedAnalytics, true);

      await tester.pumpAndSettle();

      // Now should show enabled content
      expect(find.text('Enabled Content'), findsOneWidget);
      expect(find.text('Disabled Content'), findsNothing);
    });

    testWidgets('should handle multiple flags independently', (tester) async {
      // Set up different states for different flags
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
            home: Column(
              children: [
                FeatureFlagWidget(
                  flag: FeatureFlag.enhancedAnalytics,
                  disabled: Text('Camera UI Disabled'),
                  child: Text('Camera UI Enabled'),
                ),
                FeatureFlagWidget(
                  flag: FeatureFlag.accountSwitching,
                  disabled: Text('Account Switching Disabled'),
                  child: Text('Account Switching Enabled'),
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
      expect(find.text('Account Switching Enabled'), findsNothing);
      expect(find.text('Account Switching Disabled'), findsOneWidget);
    });

    testWidgets('should handle loading state gracefully', (tester) async {
      // Don't set up any mocks to simulate loading
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagWidget(
              flag: FeatureFlag.enhancedAnalytics,
              disabled: Text('Disabled Content'),
              loading: CircularProgressIndicator(),
              child: Text('Enabled Content'),
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
