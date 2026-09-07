// ABOUTME: Tests for FeatureFlagScreen settings and management interface
// ABOUTME: Validates screen behavior, flag toggling, and override indicators

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('FeatureFlagScreen', () {
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

    Widget buildSubject({bool isDeveloperMode = false}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          isDeveloperModeEnabledProvider.overrideWithValue(isDeveloperMode),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeatureFlagScreen(),
        ),
      );
    }

    Future<void> initializeFeatureFlags(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FeatureFlagScreen)),
      );
      final service = container.read(featureFlagServiceProvider);
      await service.initialize();
      await tester.pumpAndSettle();
    }

    testWidgets('constrains menu content width on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await initializeFeatureFlags(tester);

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    });

    testWidgets('hides internal flags when developer mode is off', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await initializeFeatureFlags(tester);

      expect(
        find.text(FeatureFlag.enhancedAnalytics.displayName),
        findsOneWidget,
      );
      expect(
        find.text(FeatureFlag.communityContentWarnings.displayName),
        findsNothing,
      );
      expect(find.text(FeatureFlag.feedTuning.displayName), findsNothing);
      expect(
        find.bySemanticsIdentifier(
          SemanticIds.featureFlagAccountSwitching,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows internal flags when developer mode is on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(isDeveloperMode: true));
      await initializeFeatureFlags(tester);

      expect(
        find.text(FeatureFlag.enhancedAnalytics.displayName),
        findsOneWidget,
      );
      expect(
        find.text(FeatureFlag.communityContentWarnings.displayName),
        findsOneWidget,
      );
      expect(find.text(FeatureFlag.feedTuning.displayName), findsOneWidget);
    });

    testWidgets('should display all flags', (tester) async {
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

      for (final flag in FeatureFlag.values) {
        expect(find.text(flag.displayName), findsOneWidget);
        expect(find.text(flag.description), findsOneWidget);
      }
      // TOOD(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('should show app bar with title', (tester) async {
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

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Feature Flags'), findsOneWidget);
    });

    testWidgets('should toggle flags', (tester) async {
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

      // Find and tap the first switch
      final switches = find.byType(Switch);
      expect(switches, findsAtLeast(1));

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify that setBool was called for some flag
      verify(() => mockPrefs.setBool(any(), any())).called(1);
    });

    testWidgets('should show override indicators', (tester) async {
      // Set up one flag as having user override
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

      // Find the switch for enhancedAnalytics specifically
      final flagSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Enhanced Analytics'),
          matching: find.byType(Card),
        ),
        matching: find.byType(Switch),
      );
      expect(flagSwitch, findsOneWidget);

      // Check if the override switch shows true
      final switchWidget = tester.widget<Switch>(flagSwitch);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('should reset all flags on reset button press', (tester) async {
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

      // Find and tap the reset button
      final l10n = lookupAppLocalizations(const Locale('en'));
      final resetButton = find.bySemanticsLabel(
        l10n.featureFlagResetAllTooltip,
      );
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify that only visible/user-facing flags were reset.
      for (final flag in FeatureFlag.values) {
        if (flag.isInternal) {
          verifyNever(() => mockPrefs.remove('ff_${flag.name}'));
        } else {
          verify(() => mockPrefs.remove('ff_${flag.name}')).called(1);
        }
      }
    });

    testWidgets('should show flag states correctly', (tester) async {
      // Set up mixed flag states
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

      // Check that switches reflect the flag states
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, hasLength(FeatureFlag.values.length));

      // Find switches by looking for the flag display names
      expect(find.text('Enhanced Analytics'), findsOneWidget);
      // TOOD(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('should handle individual flag reset', (tester) async {
      // Set up a flag with user override
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

      // Rows carry no per-flag reset — an experimental flag reads off by
      // default, so an "overridden" badge next to it says nothing useful.
      // The app bar's reset-all action is the only way back to defaults.
      await tester.tap(
        find.bySemanticsLabel(
          lookupAppLocalizations(const Locale('en')).featureFlagResetAllTooltip,
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockPrefs.remove('ff_enhancedAnalytics')).called(1);
    });

    testWidgets('should be scrollable with many flags', (tester) async {
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

      // Verify the screen is scrollable
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
