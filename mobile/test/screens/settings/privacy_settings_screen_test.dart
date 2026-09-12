// ABOUTME: Widget tests for PrivacySettingsScreen's analytics consent toggle.
// ABOUTME: Covers stored-preference rendering, the write, and both appearances.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/settings/privacy_settings_screen.dart';
import 'package:openvine/services/analytics_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group(PrivacySettingsScreen, () {
    late _MockAnalyticsService service;
    late bool storedPreference;
    late bool initialized;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      service = _MockAnalyticsService();
      storedPreference = false;
      initialized = false;
      when(
        () => service.analyticsEnabled,
      ).thenAnswer((_) => !initialized || storedPreference);
      when(service.initialize).thenAnswer((_) async {
        initialized = true;
      });
      when(() => service.setAnalyticsEnabled(any())).thenAnswer((
        invocation,
      ) async {
        storedPreference = invocation.positionalArguments.first as bool;
        return true;
      });
    });

    Future<void> pumpScreen(WidgetTester tester, {ThemeData? theme}) {
      return tester.pumpWidget(
        testMaterialApp(
          home: const PrivacySettingsScreen(),
          analyticsService: service,
          theme: theme ?? VineTheme.theme,
        ),
      );
    }

    DivineSwitch consentSwitch(WidgetTester tester) =>
        tester.widget<DivineSwitch>(find.byType(DivineSwitch));

    group('renders', () {
      testWidgets('shows the analytics section and consent copy', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(find.text(l10n.settingsPrivacyTitle), findsOneWidget);
        expect(
          find.text(l10n.privacySettingsAnalyticsSection),
          findsOneWidget,
        );
        expect(find.text(l10n.privacySettingsShareUsage), findsOneWidget);
        expect(
          find.text(l10n.privacySettingsShareUsageSubtitle),
          findsOneWidget,
        );
      });

      testWidgets('reflects a stored opt-out', (tester) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        // The row is live, so `false` is the answer that was read back and
        // not the value the tile carries while it is still loading.
        expect(consentSwitch(tester).onChanged, isNotNull);
        expect(consentSwitch(tester).value, isFalse);
      });

      testWidgets('reflects a stored opt-in', (tester) async {
        storedPreference = true;

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(consentSwitch(tester).value, isTrue);
      });

      testWidgets('cannot be flipped before the stored answer arrives', (
        tester,
      ) async {
        // Built inside the test body: a Completer created in setUp belongs to
        // another zone and never resolves inside the widget tester's.
        final storedPreferenceRead = Completer<void>();
        when(service.initialize).thenAnswer((_) async {
          await storedPreferenceRead.future;
          initialized = true;
        });

        await pumpScreen(tester);
        await tester.pump();

        expect(consentSwitch(tester).onChanged, isNull);

        storedPreferenceRead.complete();
        await tester.pumpAndSettle();

        expect(consentSwitch(tester).onChanged, isNotNull);
      });

      testWidgets('paints the light palette without a dark fallback', (
        tester,
      ) async {
        VineThemeColors.debugFallbackCount = 0;
        addTearDown(() => VineThemeColors.debugFallbackCount = 0);

        await pumpScreen(tester, theme: VineTheme.lightTheme);
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, VineTheme.lightColors.background);
        expect(VineThemeColors.debugFallbackCount, 0);
      });
    });

    group('interactions', () {
      testWidgets('tapping the row opts in and persists the choice', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();
        expect(consentSwitch(tester).value, isFalse);

        await tester.tap(find.text(l10n.privacySettingsShareUsage));
        await tester.pumpAndSettle();

        verify(() => service.setAnalyticsEnabled(true)).called(1);
        expect(consentSwitch(tester).value, isTrue);
      });

      testWidgets('flipping the switch opts out and persists the choice', (
        tester,
      ) async {
        storedPreference = true;

        await pumpScreen(tester);
        await tester.pumpAndSettle();
        expect(consentSwitch(tester).value, isTrue);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        verify(() => service.setAnalyticsEnabled(false)).called(1);
        expect(consentSwitch(tester).value, isFalse);
      });

      testWidgets('tells the person when the choice could not be saved', (
        tester,
      ) async {
        // Silence here would be the worst outcome: the switch would show a
        // decision that is gone at the next launch.
        storedPreference = true;
        when(
          () => service.setAnalyticsEnabled(any()),
        ).thenAnswer((_) async => false);

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        expect(find.text(l10n.privacySettingsSaveFailed), findsOneWidget);
      });

      testWidgets('says nothing when the choice was saved', (tester) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        expect(find.text(l10n.privacySettingsSaveFailed), findsNothing);
      });
    });
  });
}
