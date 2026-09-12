// ABOUTME: Widget tests for environment indicator components
// ABOUTME: Tests badge, banner visibility and behavior across environments
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/widgets/environment_indicator.dart';

void main() {
  const stagingConfig = EnvironmentConfig(environment: AppEnvironment.staging);

  const pocConfig = EnvironmentConfig(environment: AppEnvironment.poc);

  group('EnvironmentBadge', () {
    testWidgets('shows STG badge for staging environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('shows POC badge for POC environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => pocConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('POC'), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('hides badge for production environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith(
              (ref) => EnvironmentConfig.production,
            ),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsNothing);
      expect(find.text('POC'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('hides badge when indicator is disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('badge has correct styling for staging', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EnvironmentBadge),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Color(stagingConfig.indicatorColorValue));
      expect(decoration.borderRadius, isA<BorderRadius>());
    });

    testWidgets('badge has correct styling for POC', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => pocConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EnvironmentBadge),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Color(pocConfig.indicatorColorValue));
    });
  });

  group('EnvironmentBanner', () {
    testWidgets('shows staging banner with correct text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(
        find.text('Environment: Staging - Tap for options'),
        findsOneWidget,
      );
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('shows POC banner with correct text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => pocConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(find.text('Environment: POC - Tap for options'), findsOneWidget);
    });

    testWidgets('hides banner for production environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith(
              (ref) => EnvironmentConfig.production,
            ),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(find.textContaining('Environment: Staging'), findsNothing);
      expect(find.textContaining('Environment: POC'), findsNothing);
      expect(find.textContaining('Environment: Test'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('hides banner when indicator is disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(find.text('Environment: Staging'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  EnvironmentBanner(
                    onTap: () {
                      tapped = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('banner has correct styling for staging', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );

      expect(container.color, Color(stagingConfig.indicatorColorValue));
    });

    testWidgets('banner has correct styling for POC', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => pocConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );

      expect(container.color, Color(pocConfig.indicatorColorValue));
    });
  });
}
