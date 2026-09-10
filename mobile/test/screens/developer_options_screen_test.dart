// ABOUTME: Widget tests for DeveloperOptionsScreen layout and debug simulations.
// ABOUTME: Covers settings-menu width and the protected-minor override toggles (#5721).

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../helpers/invite_availability_harness.dart';
import '../helpers/scroll.dart';

Future<SharedPreferences> mockPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<InviteAvailabilityCubit> pumpScreen(
  WidgetTester tester,
  SharedPreferences prefs, {
  InviteAvailabilityCubit? availabilityCubit,
  ShorebirdUpdater Function()? shorebirdUpdaterFactory,
}) async {
  final cubit = availabilityCubit ?? seededInviteAvailabilityCubit();
  if (availabilityCubit == null) {
    addTearDown(cubit.close);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: wrapWithInviteAvailability(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: DeveloperOptionsScreen(
            shorebirdUpdaterFactory: shorebirdUpdaterFactory,
          ),
        ),
        cubit: cubit,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

class _AvailableShorebirdUpdater implements ShorebirdUpdater {
  final firstRead = Completer<void>();

  @override
  bool get isAvailable => true;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async =>
      UpdateStatus.upToDate;

  @override
  Future<Patch?> readCurrentPatch() async {
    if (!firstRead.isCompleted) firstRead.complete();
    return const Patch(number: 7);
  }

  @override
  Future<Patch?> readNextPatch() async => const Patch(number: 7);

  @override
  Future<void> update({UpdateTrack? track}) async {}
}

Future<void> tapTile(WidgetTester tester, String title) async {
  // Tap the whole ListTile rather than just its text: a tap on the text's
  // centre lands off-target on some layouts (this is what failed on Linux CI
  // but passed on macOS). Some groups below make hit-test warnings fatal so
  // this cannot slip through their local runs again.
  final tile = find.widgetWithText(ListTile, title);
  await scrollUntilTappable(tester, tile, 300);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  group('renders', () {
    testWidgets(
      'renders the available Shorebird section through screen wiring',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        var factoryCalls = 0;
        final updater = _AvailableShorebirdUpdater();
        await pumpScreen(
          tester,
          await mockPrefs(),
          shorebirdUpdaterFactory: () {
            factoryCalls++;
            return updater;
          },
        );

        expect(factoryCalls, 1);
        expect(find.text(l10n.devOptionsShorebirdTitle), findsOneWidget);
        await tester.runAsync(() => updater.firstRead.future);
        await tester.pumpAndSettle();
        expect(find.text('7'), findsOneWidget);
        expect(find.text(l10n.devOptionsShorebirdNotChecked), findsOneWidget);
      },
    );

    testWidgets(
      'DeveloperOptionsScreen constrains menu content width on wide screens',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpScreen(tester, await mockPrefs());

        final listViewWidth = tester.getSize(find.byType(ListView).first).width;
        expect(listViewWidth, moreOrLessEquals(600));
      },
    );
  });

  group('interactions', () {
    testWidgets('disabling developer mode turns off the flag and pops back', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      final envService = EnvironmentService();
      await envService.initialize(sharedPreferences: prefs);
      await envService.enableDeveloperMode();
      expect(envService.isDeveloperModeEnabled, isTrue);

      final availabilityCubit = seededInviteAvailabilityCubit();
      addTearDown(availabilityCubit.close);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push(DeveloperOptionsScreen.path),
                  child: const Text('open-developer-options'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: DeveloperOptionsScreen.path,
            builder: (context, state) => wrapWithInviteAvailability(
              const DeveloperOptionsScreen(),
              cubit: availabilityCubit,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            environmentServiceProvider.overrideWithValue(envService),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-developer-options'));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperOptionsScreen), findsOneWidget);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tapTile(tester, l10n.devOptionsDisableDeveloperMode);

      expect(envService.isDeveloperModeEnabled, isFalse);
      expect(prefs.getBool('developer_mode_enabled'), isFalse);
      // Returned to the previous screen; the dev options entry is gone.
      expect(find.byType(DeveloperOptionsScreen), findsNothing);
      expect(find.text('open-developer-options'), findsOneWidget);
    });
  });

  group('protected-minor simulation (#5721)', () {
    late bool previousHitTestWarningShouldBeFatal;

    setUp(() {
      previousHitTestWarningShouldBeFatal =
          WidgetController.hitTestWarningShouldBeFatal;
      // Make a tap that misses its target a hard failure for these tests, so
      // the clipped-tile geometry flake (which passed on macOS and failed on
      // Linux CI) cannot slip through a local run again.
      WidgetController.hitTestWarningShouldBeFatal = true;
    });

    tearDown(() {
      WidgetController.hitTestWarningShouldBeFatal =
          previousHitTestWarningShouldBeFatal;
    });

    testWidgets('simulate protected minor sets the override to true', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Simulate protected minor (13-15)');

      expect(
        ProtectedMinorOverrideServiceReader(prefs).value,
        isTrue,
        reason: 'tapping simulate must force the override on',
      );
    });

    testWidgets('simulate non-minor sets the override to false', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Simulate non-minor');

      expect(ProtectedMinorOverrideServiceReader(prefs).value, isFalse);
    });

    testWidgets('clear override removes the stored override', (tester) async {
      final prefs = await mockPrefs();
      await prefs.setBool('protected_minor_override', true);
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Clear override');

      expect(ProtectedMinorOverrideServiceReader(prefs).value, isNull);
    });

    testWidgets('current-state row reflects a forced-protected override', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await prefs.setBool('protected_minor_override', true);
      await pumpScreen(tester, prefs);

      final stateRow = find.textContaining('Override: forced protected');
      await tester.scrollUntilVisible(stateRow, 300);
      expect(stateRow, findsOneWidget);
    });
  });

  group('signup invite availability override', () {
    late bool previousHitTestWarningShouldBeFatal;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      previousHitTestWarningShouldBeFatal =
          WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
    });

    tearDown(() {
      WidgetController.hitTestWarningShouldBeFatal =
          previousHitTestWarningShouldBeFatal;
    });

    testWidgets('shows the server value and default override', (tester) async {
      await pumpScreen(tester, await mockPrefs());

      final currentState = find.textContaining(
        l10n.devOptionsInviteAvailabilityServerEnabled,
      );
      await tester.scrollUntilVisible(currentState, 300);
      await tester.pumpAndSettle();
      expect(currentState, findsOneWidget);
      expect(
        find.textContaining(l10n.devOptionsInviteAvailabilityOverrideNone),
        findsOneWidget,
      );
    });

    testWidgets('force disabled updates the running cubit immediately', (
      tester,
    ) async {
      final cubit = seededInviteAvailabilityCubit();
      addTearDown(cubit.close);

      await pumpScreen(tester, await mockPrefs(), availabilityCubit: cubit);
      expect(cubit.state.isEnabled, isTrue);

      await tapTile(tester, l10n.devOptionsInviteAvailabilityForceDisabled);

      expect(
        cubit.state.developerOverride,
        InviteAvailabilityOverride.forceDisabled,
      );
      expect(cubit.state.isEnabled, isFalse);
      expect(
        find.text(l10n.devOptionsInviteAvailabilityForceDisabledToast),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.devOptionsInviteAvailabilityOverrideDisabled),
        findsOneWidget,
      );
    });

    testWidgets('force enabled wins over a disabled server value', (
      tester,
    ) async {
      final cubit = seededInviteAvailabilityCubit(
        serverMode: OnboardingMode.open,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, await mockPrefs(), availabilityCubit: cubit);
      expect(cubit.state.isEnabled, isFalse);

      await tapTile(tester, l10n.devOptionsInviteAvailabilityForceEnabled);

      expect(
        cubit.state.developerOverride,
        InviteAvailabilityOverride.forceEnabled,
      );
      expect(cubit.state.isEnabled, isTrue);
      expect(
        find.text(l10n.devOptionsInviteAvailabilityForceEnabledToast),
        findsOneWidget,
      );
    });

    testWidgets('live switching covers every override state', (tester) async {
      final cubit = seededInviteAvailabilityCubit();
      addTearDown(cubit.close);

      await pumpScreen(tester, await mockPrefs(), availabilityCubit: cubit);

      await tapTile(tester, l10n.devOptionsInviteAvailabilityForceDisabled);
      expect(cubit.state.isEnabled, isFalse);

      await tapTile(tester, l10n.devOptionsInviteAvailabilityForceEnabled);
      expect(
        cubit.state.developerOverride,
        InviteAvailabilityOverride.forceEnabled,
      );
      expect(cubit.state.isEnabled, isTrue);

      await tapTile(tester, l10n.devOptionsInviteAvailabilityUseServer);
      expect(
        cubit.state.developerOverride,
        InviteAvailabilityOverride.useServer,
      );
      expect(cubit.state.isEnabled, isTrue);
    });
  });
}

/// Reads the override the way the service stores it, without reaching into
/// the service's private key from multiple places.
class ProtectedMinorOverrideServiceReader {
  ProtectedMinorOverrideServiceReader(this.prefs);
  final SharedPreferences prefs;
  bool? get value => prefs.getBool('protected_minor_override');
}
