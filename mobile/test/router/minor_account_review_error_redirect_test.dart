// ABOUTME: Regression tests for the router's handling of an *errored* minor
// ABOUTME: account review status (non-404/501 API failure) so it cannot loop.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/minor_account_review_screen.dart'
    show MinorAccountReviewLoadingScreen, MinorAccountReviewScreen;
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';

import '../helpers/test_provider_overrides.dart';

class _NotReadyNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

void main() {
  group('Minor account review router error handling', () {
    late MockAuthService mockAuthService;

    setUp(() {
      resetNavigationState();
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('user-pubkey');
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    Future<void> pumpRouter(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void registerContainerTearDown(
      WidgetTester tester,
      ProviderContainer container,
    ) {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
    }

    testWidgets(
      'an errored review status does not strand an authenticated user',
      (tester) async {
        // A non-404/501 failure from getMinorAccountReviewStatus() surfaces as
        // an AsyncError on currentMinorAccountReviewStatusProvider. The router
        // must fail *open* for an account it cannot prove is restricted: it
        // should land the user on a usable destination instead of bouncing
        // between the review loading screen and the review screen forever.
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            bugReportServiceProvider.overrideWith((ref) => BugReportService()),
            nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => throw StateError('review status unavailable'),
            ),
            currentAccountDeletionAttemptProvider.overrideWith(
              (ref) async => null,
            ),
          ],
        );
        registerContainerTearDown(tester, container);
        await pumpRouter(tester, container);

        final router = container.read(goRouterProvider);
        final landing = router.routeInformationProvider.value.uri.toString();

        // It must NOT get stuck on the review screen for an account whose
        // restriction could not be confirmed.
        expect(
          landing,
          isNot(MinorAccountReviewScreen.path),
          reason:
              'Authenticated user with an errored (not restricted) review '
              'status should not be held on the review screen.',
        );
      },
    );

    testWidgets(
      'an errored review status keeps the user on their current route',
      (tester) async {
        // SupportCenterScreen stands in for any non-feed authenticated route:
        // it avoids rendering the heavy feed AppShell, so the assertion is
        // about the redirect decision, not the destination's widget tree.
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            bugReportServiceProvider.overrideWith((ref) => BugReportService()),
            nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => throw StateError('review status unavailable'),
            ),
            currentAccountDeletionAttemptProvider.overrideWith(
              (ref) async => null,
            ),
          ],
        );
        registerContainerTearDown(tester, container);
        await pumpRouter(tester, container);

        final router = container.read(goRouterProvider);
        router.go(SupportCenterScreen.path);
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.toString(),
          SupportCenterScreen.path,
        );
      },
    );

    testWidgets(
      'an errored review status on the loading gate fails open to destination',
      (tester) async {
        // The loading gate carries the intended destination in its `from`
        // query param. When the status errors out, the user must be returned
        // to that destination, never funneled onto the restricted-account
        // screen. Routing an errored (unconfirmed) status to the review screen
        // is what produced the loading ↔ review loop in issue #5195.
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            bugReportServiceProvider.overrideWith((ref) => BugReportService()),
            nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => throw StateError('review status unavailable'),
            ),
            currentAccountDeletionAttemptProvider.overrideWith(
              (ref) async => null,
            ),
          ],
        );
        registerContainerTearDown(tester, container);
        await pumpRouter(tester, container);

        final router = container.read(goRouterProvider);
        router.go(
          Uri(
            path: MinorAccountReviewLoadingScreen.path,
            queryParameters: const {'from': SupportCenterScreen.path},
          ).toString(),
        );
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.toString(),
          SupportCenterScreen.path,
        );
      },
    );
  });
}
