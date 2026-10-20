// ABOUTME: Tests that an account closed by age review is shown Account status
// ABOUTME: on launch, once per session, and that other bans are left alone.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/widgets/age_review_closure_launch_notice.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _closure = AccountEnforcementStatus(
  kind: AccountEnforcementKind.banned,
  category: AccountEnforcementCategory.ageReview,
);

Future<ProviderContainer> _pumpShell(
  WidgetTester tester,
  AccountEnforcementStatus status,
) async {
  final container = ProviderContainer(
    overrides: [
      activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
      accountEnforcementStatusProvider.overrideWith((ref) async => status),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const AgeReviewClosureLaunchNotice(child: Text('home')),
      ),
      GoRoute(
        path: AccountStatusScreen.path,
        name: AccountStatusScreen.routeName,
        builder: (context, state) => const Text('account-status'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('AgeReviewClosureLaunchNotice (support-trust-safety#260)', () {
    testWidgets('shows Account status on launch for an age-review closure', (
      tester,
    ) async {
      await _pumpShell(tester, _closure);

      expect(find.text('account-status'), findsOneWidget);
    });

    testWidgets('leaves a ban outside the age-review category on the feed', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        const AccountEnforcementStatus(kind: AccountEnforcementKind.banned),
      );

      expect(find.text('home'), findsOneWidget);
      expect(find.text('account-status'), findsNothing);
    });

    // A resume refetches the status. Pushing the screen again every time the
    // app comes back to the foreground would trap the account on it.
    testWidgets('does not show it again after a refetch in the same session', (
      tester,
    ) async {
      final container = await _pumpShell(tester, _closure);
      final router = GoRouter.of(tester.element(find.text('account-status')));

      router.pop();
      await tester.pumpAndSettle();
      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('account-status'), findsNothing);
    });

    // The shell can be rebuilt within a session; that is not a new launch.
    testWidgets('does not show it again when the shell is rebuilt', (
      tester,
    ) async {
      final container = await _pumpShell(tester, _closure);
      GoRouter.of(tester.element(find.text('account-status'))).pop();
      await tester.pumpAndSettle();

      final rebuilt = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const AgeReviewClosureLaunchNotice(child: Text('home')),
          ),
          GoRoute(
            path: AccountStatusScreen.path,
            name: AccountStatusScreen.routeName,
            builder: (context, state) => const Text('account-status'),
          ),
        ],
      );
      addTearDown(rebuilt.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            key: const ValueKey('rebuilt'),
            routerConfig: rebuilt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('account-status'), findsNothing);
    });

    // The app refetches status on every resume, and each fetch is a signed
    // request. Holding the provider for the whole session would make every
    // resume of every account pay for a notice that shows at most once.
    testWidgets('stops watching the status once it has an answer', (
      tester,
    ) async {
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            fetches++;
            return const AccountEnforcementStatus(
              kind: AccountEnforcementKind.noRestrictionReported,
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const AgeReviewClosureLaunchNotice(child: Text('home')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(fetches, 1);
    });
  });
}
