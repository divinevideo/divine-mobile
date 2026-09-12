// ABOUTME: Localized route error UI for unknown paths via GoRouter.errorBuilder
// ABOUTME: Covers GoRouter.errorBuilder and RouteErrorScreen from app routes (#3371)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  MockAuthService authenticatedAuth() {
    final mockAuth = createMockAuthService();
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.currentPublicKeyHex).thenReturn(syntheticTestPubkey);
    when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuth.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    when(() => mockAuth.hasExpiredOAuthSession).thenReturn(false);
    return mockAuth;
  }

  group(RouteErrorScreen, () {
    testWidgets('errorBuilder shows RouteErrorScreen for unknown location', (
      tester,
    ) async {
      final strings = AppLocalizationsEn();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authenticatedAuth()),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await _pumpRouter(tester, container);

      container
          .read(goRouterProvider)
          .go('/__route_error_smoke_not_in_route_table__');
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.text(strings.routeUnknownPath), findsOneWidget);
    });
  });

  // The pooled fullscreen route's no-args redirect is covered at the route
  // helper level in fullscreen_feed_redirect_test.dart. A widget assertion for
  // the redirect target would require rendering the full home feed, which this
  // focused error-route harness does not provide.
}

Future<void> _pumpRouter(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: container.read(goRouterProvider),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
