// ABOUTME: Patrol e2e for server-controlled signup-invite availability.
// ABOUTME: Flips local_stack invite onboardingMode and relaunches the app.
// ABOUTME: Requires: mise run local_up + Android emulator.
// ABOUTME: Run with: mise run e2e_test integration_test/auth/invite_availability_e2e_test.dart

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:patrol/patrol.dart';

import '../helpers/invite_admin_helpers.dart';
import '../helpers/invite_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  ignorePlatformSemanticsHandle();

  Future<void> restoreOpenMode() async {
    await setInviteOnboardingMode('open');
  }

  group('signup invite availability', () {
    patrolTest(
      'open mode skips the signup gate and hides signed-in invite surfaces',
      ($) async {
        final tester = $.tester;
        addTearDown(restoreOpenMode);
        await setInviteOnboardingMode('open');

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        launchAppGuarded(app.main);
        await pumpUntilSettled(tester);

        await tester.tap(find.text(_en.authCreateNewAccount));
        await pumpUntilSettled(tester, maxSeconds: 8);

        expect(find.byType(InviteGateScreen), findsNothing);
        expect(find.text(_en.authAddInviteCode), findsNothing);
        expect(
          find.byType(DivineAuthTextField),
          findsNWidgets(3),
          reason:
              'open onboardingMode must skip the invite gate and show the '
              'create-account form',
        );

        await _createAnonymousAccount(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final router = container.read(goRouterProvider);
        router.go(SettingsScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(find.text(_en.settingsShareDivine), findsOneWidget);
        expect(
          inviteState(tester).status,
          InviteStatusLoadingStatus.initial,
          reason:
              'Disabled signup invites must not fetch invite-status or generate '
              'codes',
        );

        router.go(InvitesScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 8);
        expect(find.byType(InvitesView), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);

        drainAsyncErrors(tester);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    patrolTest(
      'invite-code-required shows the signup gate and signed-in invite surfaces',
      ($) async {
        final tester = $.tester;
        addTearDown(restoreOpenMode);
        await setInviteOnboardingMode('invite_code_required');

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        launchAppGuarded(app.main);
        await pumpUntilSettled(tester);

        await tester.tap(find.text(_en.authCreateNewAccount));
        final sawGate = await waitForText(tester, _en.authAddInviteCode);
        expect(
          sawGate,
          isTrue,
          reason:
              'invite_code_required must send Create account through the '
              'signup invite gate',
        );
        expect(find.byType(InviteGateScreen), findsOneWidget);
        expect(find.byType(DivineAuthTextField), findsNothing);

        final code = await generateAdminInviteCode();
        logPhase('Redeeming admin invite code $code');
        await tester.enterText(find.byType(TextField), code);
        await tester.tap(find.text(_en.authNext));

        final sawForm = await waitForWidget(
          tester,
          find.byType(DivineAuthTextField),
          maxSeconds: 20,
        );
        expect(
          sawForm,
          isTrue,
          reason: 'A valid invite code should unlock the create-account form',
        );

        await _createAnonymousAccount(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final router = container.read(goRouterProvider);
        router.go(SettingsScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(find.text(_en.settingsShareDivine), findsOneWidget);

        final granted = await waitForLoadedInviteStatus(tester);
        expect(granted.inviteStatus, isNotNull);
        router.go(InvitesScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 10);
        expect(find.byType(InvitesView), findsOneWidget);

        drainAsyncErrors(tester);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

Future<void> _createAnonymousAccount(WidgetTester tester) async {
  final skipButton = find.text(_en.authUseDivineNoBackup);
  expect(skipButton, findsOneWidget);
  await tester.tap(skipButton);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final confirmSkip = find.text(_en.authUseThisDeviceOnly);
  expect(confirmSkip, findsOneWidget);
  await tester.tap(confirmSkip);
  await pumpUntilSettled(tester, maxSeconds: 10);
}
