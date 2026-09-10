// ABOUTME: Route-seam tests for FeatureFlagScreen (#6481).
// ABOUTME: Covers path registration and crash-safe back navigation on cold entry.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

final _settingsRoutesProvider = Provider<List<RouteBase>>(settingsRoutes);

void main() {
  group('FeatureFlagScreen routing', () {
    late _MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = _MockSharedPreferences();
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

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '${FeatureFlagScreen.path} resolves through the real settings routes',
      (tester) async {
        final container = buildContainer();
        final router = GoRouter(
          initialLocation: FeatureFlagScreen.path,
          routes: container.read(_settingsRoutesProvider),
          errorBuilder: (_, _) =>
              const Scaffold(body: Text('UNRESOLVED-ROUTE')),
        );
        addTearDown(router.dispose);

        await pumpRouter(tester, router);

        expect(find.byType(FeatureFlagScreen), findsOneWidget);
        expect(find.text('UNRESOLVED-ROUTE'), findsNothing);
      },
    );

    testWidgets('cold entry nests under settings and pops back to settings', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: FeatureFlagScreen.path,
        routes: [
          GoRoute(
            path: SettingsScreen.path,
            builder: (_, _) => const Scaffold(body: Text('SETTINGS-STUB')),
            routes: [
              GoRoute(
                path: FeatureFlagScreen.subpath,
                builder: (_, _) => const FeatureFlagScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await pumpRouter(tester, router);
      expect(find.byType(FeatureFlagScreen), findsOneWidget);
      expect(
        router.canPop(),
        isTrue,
        reason:
            'Feature flags should be a real settings child route, so back is '
            'a pop to Settings rather than a fallback navigation.',
      );

      await tester.tap(find.byType(DiVineAppBarLeading));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SETTINGS-STUB'), findsOneWidget);
      expect(find.byType(FeatureFlagScreen), findsNothing);
    });

    testWidgets('back from a pushed entry returns to the pushing screen', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: SettingsScreen.path,
        routes: [
          GoRoute(
            path: SettingsScreen.path,
            builder: (_, _) => const Scaffold(body: Text('SETTINGS-STUB')),
            routes: [
              GoRoute(
                path: FeatureFlagScreen.subpath,
                builder: (_, _) => const FeatureFlagScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await pumpRouter(tester, router);
      router.push(FeatureFlagScreen.path);
      await tester.pumpAndSettle();
      expect(find.byType(FeatureFlagScreen), findsOneWidget);
      expect(router.canPop(), isTrue);

      await tester.tap(find.byType(DiVineAppBarLeading));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SETTINGS-STUB'), findsOneWidget);
    });
  });
}
