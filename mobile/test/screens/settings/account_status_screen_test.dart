// ABOUTME: Widget tests for the account status screen: the appeal and exit
// ABOUTME: paths appear for a restricted account and not for a healthy one.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/go_router.dart';
import '../../helpers/url_launcher_test_double.dart';

Future<void> _pumpWith(
  WidgetTester tester,
  AccountEnforcementKind kind, {
  MockGoRouter? goRouter,
  bool publishRestrictionConfirmed = false,
  OpenSupportMessages? openSupportMessages,
  ComposeSupportEmail? composeEmail,
}) async {
  // Tall surface: the body is a ListView, which only builds what fits, and the
  // longer enforcement copy would otherwise push the appeal and exit buttons
  // outside the built viewport.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final app = MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AccountStatusScreen(
      publishRestrictionConfirmed: publishRestrictionConfirmed,
      openSupportMessages: openSupportMessages,
      composeEmail: composeEmail,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountEnforcementStatusProvider.overrideWith(
          (ref) async => AccountEnforcementStatus(kind: kind),
        ),
      ],
      child: goRouter == null
          ? app
          : MockGoRouterProvider(goRouter: goRouter, child: app),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('AccountStatusScreen', () {
    testWidgets('a suspended account is offered the appeal and exit paths', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.suspended);

      expect(find.text(l10n.accountStatusSuspendedHeading), findsOneWidget);
      expect(find.text(l10n.supportContactSupport), findsOneWidget);
      expect(find.text(l10n.accountStatusMoveAccount), findsOneWidget);
      expect(
        find.text(l10n.accountStatusKeysUnaffectedHeading),
        findsOneWidget,
      );
    });

    testWidgets('a banned account is offered the appeal and exit paths', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.banned);

      expect(find.text(l10n.accountStatusBannedHeading), findsOneWidget);
      expect(find.text(l10n.supportContactSupport), findsOneWidget);
    });

    testWidgets('a publish-confirmed unknown restriction gets an appeal path', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.unknownRestriction);

      expect(find.text(l10n.supportContactSupport), findsOneWidget);
    });

    testWidgets('an unrestricted account is greeted, not reported to', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.noRestrictionReported);

      expect(find.text(l10n.accountStatusAllClearHeading), findsOneWidget);
      expect(find.text(l10n.supportContactSupport), findsNothing);
      expect(find.text(l10n.accountStatusMoveAccount), findsNothing);
    });

    testWidgets(
      'a publish-confirmed restriction overrides an active status response',
      (tester) async {
        await _pumpWith(
          tester,
          AccountEnforcementKind.noRestrictionReported,
          publishRestrictionConfirmed: true,
        );

        expect(find.text(l10n.accountStatusRestrictedHeading), findsOneWidget);
        expect(find.text(l10n.supportContactSupport), findsOneWidget);
        expect(find.text(l10n.accountStatusMoveAccount), findsOneWidget);
      },
    );

    testWidgets('signed out explains the state without a futile retry', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.signedOut);

      expect(find.text(l10n.accountStatusSignedOutHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusRetry), findsNothing);
    });

    testWidgets('appeal opens support messages without navigating', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(() => goRouter.push(any())).thenAnswer((_) async => null);
      var openCalls = 0;

      await _pumpWith(
        tester,
        AccountEnforcementKind.suspended,
        goRouter: goRouter,
        openSupportMessages: () async {
          openCalls++;
          return true;
        },
      );

      await tester.tap(find.text(l10n.supportContactSupport));
      await tester.pumpAndSettle();

      expect(openCalls, 1);
      verifyNever(() => goRouter.push(any()));
    });

    testWidgets('appeal falls back to email when messages cannot open', (
      tester,
    ) async {
      String? emailBody;
      await _pumpWith(
        tester,
        AccountEnforcementKind.suspended,
        openSupportMessages: () async => false,
        composeEmail:
            ({
              required toEmail,
              required subject,
              required body,
              sharePositionOrigin,
            }) async {
              emailBody = body;
            },
      );

      await tester.tap(find.text(l10n.supportContactSupport));
      await tester.pumpAndSettle();

      expect(emailBody, contains(l10n.supportCouldNotOpenMessages));
      expect(emailBody, contains(l10n.supportContactSupportSubtitle));
    });

    testWidgets('appeal falls back to email when opening messages throws', (
      tester,
    ) async {
      var composed = false;
      await _pumpWith(
        tester,
        AccountEnforcementKind.suspended,
        openSupportMessages: () async => throw Exception('native failure'),
        composeEmail:
            ({
              required toEmail,
              required subject,
              required body,
              sharePositionOrigin,
            }) async {
              composed = true;
            },
      );

      await tester.tap(find.text(l10n.supportContactSupport));
      await tester.pumpAndSettle();

      expect(composed, isTrue);
    });

    testWidgets('appeal reports when its email fallback cannot open', (
      tester,
    ) async {
      await _pumpWith(
        tester,
        AccountEnforcementKind.suspended,
        openSupportMessages: () async => false,
        composeEmail: ({
          required toEmail,
          required subject,
          required body,
          sharePositionOrigin,
        }) async => throw Exception('email failure'),
      );

      await tester.tap(find.text(l10n.supportContactSupport));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.authCouldNotOpenEmail(AppConstants.supportEmail)),
        findsOneWidget,
      );
    });

    testWidgets('appeal shows progress and ignores a repeated tap', (
      tester,
    ) async {
      final opening = Completer<bool>();
      var openCalls = 0;
      await _pumpWith(
        tester,
        AccountEnforcementKind.suspended,
        openSupportMessages: () {
          openCalls++;
          return opening.future;
        },
      );

      await tester.tap(find.text(l10n.supportContactSupport));
      await tester.pump();
      await tester.tap(find.text(l10n.supportContactSupport));

      expect(openCalls, 1);
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

      opening.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
    });

    testWidgets('move your account leaves for the portability page', (
      tester,
    ) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      final launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      await _pumpWith(tester, AccountEnforcementKind.suspended);

      await tester.tap(find.text(l10n.accountStatusMoveAccount));
      await tester.pumpAndSettle();

      // The exit flow lives on the web, so it must leave the app rather than
      // resolve to an in-app route.
      expect(launcher.launched.single.url, AppConstants.accountPortabilityUrl);
      expect(launcher.launched.single.useExternalApplication, isTrue);
    });

    testWidgets('opening the screen refetches an already-cached status', (
      tester,
    ) async {
      // Settings keeps the provider alive underneath, so without this the
      // screen would render whatever was cached before the user was
      // suspended. Deleting the initState refetch must turn this red.
      var call = 0;
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) async {
            call++;
            return const AccountEnforcementStatus(
              kind: AccountEnforcementKind.noRestrictionReported,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      // Resolve it once, as Settings would, so a value is already cached.
      final sub = container.listen(accountEnforcementStatusProvider, (_, _) {});
      await container.read(accountEnforcementStatusProvider.future);
      expect(call, 1);
      addTearDown(sub.close);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        call,
        2,
        reason: 'opening the screen must re-read, not serve the cached answer',
      );
    });

    testWidgets('a refresh shows loading, never the previous answer', (
      tester,
    ) async {
      // Riverpod's `when` defaults to skipLoadingOnRefresh: true, which renders
      // the PREVIOUS value while a refresh is in flight. On this screen that
      // means an account suspended after Settings resolved an earlier value
      // would keep that value, with no appeal or exit path, until the refetch
      // lands. Showing a spinner is the honest answer while we do not know.
      var call = 0;
      final pending = Completer<AccountEnforcementStatus>();
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) {
            call++;
            if (call == 1) {
              return Future.value(
                const AccountEnforcementStatus(
                  kind: AccountEnforcementKind.noRestrictionReported,
                ),
              );
            }
            return pending.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountStatusAllClearHeading), findsOneWidget);

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pump();

      expect(
        find.text(l10n.accountStatusAllClearHeading),
        findsNothing,
        reason: 'a stale answer must not survive a refresh',
      );
    });

    testWidgets(
      'a failed refresh discards a prior noRestrictionReported result',
      (tester) async {
        var call = 0;
        final container = ProviderContainer(
          overrides: [
            accountEnforcementStatusProvider.overrideWith((ref) async {
              call++;
              if (call == 1) {
                return const AccountEnforcementStatus(
                  kind: AccountEnforcementKind.noRestrictionReported,
                );
              }
              throw const AccountStatusUnavailable();
            }),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          accountEnforcementStatusProvider,
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(accountEnforcementStatusProvider.future);

        tester.view.physicalSize = const Size(1080, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AccountStatusScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.accountStatusAllClearHeading), findsNothing);
        expect(find.text(l10n.accountStatusUnavailableHeading), findsOneWidget);
        expect(
          find.text(l10n.accountStatusRetry),
          findsOneWidget,
          reason: 'an indeterminate lookup must remain retryable',
        );
      },
    );

    testWidgets('a failed refresh preserves a confirmed restriction', (
      tester,
    ) async {
      var call = 0;
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) async {
            call++;
            if (call == 1) {
              return const AccountEnforcementStatus(
                kind: AccountEnforcementKind.suspended,
              );
            }
            throw const AccountStatusUnavailable();
          }),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(accountEnforcementStatusProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(accountEnforcementStatusProvider.future);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountStatusSuspendedHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusLastKnownBody), findsOneWidget);
      expect(find.text(l10n.accountStatusRetry), findsOneWidget);
      expect(find.text(l10n.supportContactSupport), findsOneWidget);
    });

    testWidgets('an active account is offered no futile retry', (tester) async {
      // The successful response is settled, so there is nothing to retry.
      await _pumpWith(tester, AccountEnforcementKind.noRestrictionReported);

      expect(find.text(l10n.accountStatusAllClearHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusRetry), findsNothing);
    });
  });
}
