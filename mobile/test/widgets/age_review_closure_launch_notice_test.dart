// ABOUTME: Tests that an account closed by age review is shown Account status
// ABOUTME: on launch, once per session, and that other bans are left alone.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/services/account_status_api_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/age_review_closure_launch_notice.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Answers each status request with the next queued response or error.
class _QueuedStatusClient extends AccountStatusApiClient {
  _QueuedStatusClient(this.results)
    : super(
        baseUri: Uri.parse('https://api.divine.video'),
        authHeaderProvider: ({required url, required method}) async => null,
      );

  final List<Object> results;

  @override
  Future<FunnelcakeAccountStatusResponse> fetchStatus({
    required String expectedPubkey,
  }) async {
    final result = results.removeAt(0);
    if (result is FunnelcakeAccountStatusResponse) return result;
    throw result;
  }
}

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

  final router = _router();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

GoRouter _router() => GoRouter(
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
    GoRoute(
      path: '/recorder',
      builder: (context, state) => const Text('recorder'),
    ),
  ],
);

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A closed account whose status [answer] settles, with the real Account
/// status screen reading it.
ProviderContainer _closureContainer(
  Completer<AccountEnforcementStatus> answer,
) {
  final container = ProviderContainer(
    overrides: [
      activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
      accountEnforcementStatusProvider.overrideWith((ref) => answer.future),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

GoRouter _routerWithAccountStatus() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const AgeReviewClosureLaunchNotice(child: Text('home')),
    ),
    GoRoute(
      path: AccountStatusScreen.path,
      name: AccountStatusScreen.routeName,
      builder: (context, state) => const AccountStatusScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const Text('settings'),
    ),
  ],
);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
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

    // A resume refetches the status whenever something else keeps it alive,
    // such as the account's own profile. Pushing the screen again every time
    // the app comes back to the foreground would trap the account on it.
    testWidgets('does not show it again after a refetch in the same session', (
      tester,
    ) async {
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            fetches++;
            return _closure;
          }),
        ],
      );
      addTearDown(container.dispose);
      final ownProfile = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(ownProfile.close);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('account-status'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(fetches, 2);
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

      final rebuilt = _router();
      addTearDown(rebuilt.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            key: const ValueKey('rebuilt'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: rebuilt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('account-status'), findsNothing);
    });

    // An Account status the user already opened covers the tabs, so the
    // notice leaves it alone rather than stacking a second one on top.
    testWidgets('does not stack a second Account status on a pushed one', (
      tester,
    ) async {
      final answer = Completer<AccountEnforcementStatus>();
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith(
            (ref) => answer.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.pushNamed(AccountStatusScreen.routeName));
      await tester.pumpAndSettle();
      answer.complete(_closure);
      await tester.pumpAndSettle();

      expect(
        find.text('account-status', skipOffstage: false),
        findsOneWidget,
      );
    });

    // While a session is being restored the provider reports signedOut, and
    // that is not the account's answer. Taking it as one stopped the notice
    // before the signed-in status ever arrived.
    testWidgets('waits past signedOut for the signed-in answer', (
      tester,
    ) async {
      final signedIn = NotifierProvider<_Flag, bool>(_Flag.new);
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith(
            (ref) async => ref.watch(signedIn)
                ? _closure
                : const AccountEnforcementStatus(
                    kind: AccountEnforcementKind.signedOut,
                  ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      container.read(signedIn.notifier).set(true);
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // A status something else already holds answers synchronously as soon as
    // the notice listens. Recording it as shown on the spot once modified a
    // provider mid-build, which threw in debug and left it marked shown but
    // never shown.
    testWidgets('shows an answer that was already cached when it mounts', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith(
            (ref) async => _closure,
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      await container.read(accountEnforcementStatusProvider.future);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // An answer already cached arrives inside the listen call, before the
    // notice holds the subscription, so letting go of it needs its own step.
    testWidgets('lets go of a status that was already cached when it mounts', (
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
      final keepAlive = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      await container.read(accountEnforcementStatusProvider.future);
      final router = _router();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      keepAlive.close();
      await tester.pumpAndSettle();
      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(fetches, 1);
    });

    // A refetch in flight still carries the previous answer. Stopping on it
    // would miss a closure that the refetch is about to report.
    testWidgets('waits for a refetch in flight rather than its stale value', (
      tester,
    ) async {
      final refetch = Completer<AccountEnforcementStatus>();
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) {
            fetches++;
            return fetches == 1
                ? Future.value(
                    const AccountEnforcementStatus(
                      kind: AccountEnforcementKind.noRestrictionReported,
                    ),
                  )
                : refetch.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      await container.read(accountEnforcementStatusProvider.future);
      container.invalidate(accountEnforcementStatusProvider);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      refetch.complete(_closure);
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // A failed launch fetch is not an answer. Listening on means the refetch
    // on the next resume can still bring the notice.
    testWidgets('keeps listening through a failed fetch', (tester) async {
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            fetches++;
            if (fetches == 1) throw const AccountStatusUnavailable();
            return _closure;
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
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
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(fetches, 1);
    });

    // For a local key the status request is signed synchronously inside the
    // read that starts it, so starting the read from initState put that work
    // in the build of the frame where the feed first appears.
    testWidgets('starts the status read after the first frame', (
      tester,
    ) async {
      SchedulerPhase? phase;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            phase = SchedulerBinding.instance.schedulerPhase;
            return const AccountEnforcementStatus(
              kind: AccountEnforcementKind.noRestrictionReported,
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(phase, SchedulerPhase.postFrameCallbacks);
    });

    // A failure that never clears, such as a remote signer declining the
    // request, would otherwise ask again on every resume all session.
    testWidgets('stops reading once a retry has failed too', (tester) async {
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            fetches++;
            if (fetches <= 2) throw const AccountStatusUnavailable();
            return _closure;
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();
      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(fetches, 2);
      expect(find.text('account-status'), findsNothing);
    });

    // A signer that cannot sign yet sent nothing, so it is not a failed read.
    // Counting it would spend the retry before the first real request.
    testWidgets('does not count a signer that is not ready yet', (
      tester,
    ) async {
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith((ref) async {
            fetches++;
            if (fetches <= 2) throw const AccountStatusSignerNotReady();
            return _closure;
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();
      container.invalidate(accountEnforcementStatusProvider);
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // An answer that arrives late, after a retry, can find the recorder, an
    // editor or a conversation open, and a launch can open the app-update
    // dialog. Pushing over them would skip their own exit steps, such as the
    // recorder's lock and pause, so the closure waits for the tabs.
    testWidgets('waits for the tabs to show a closure found under a screen', (
      tester,
    ) async {
      final answer = Completer<AccountEnforcementStatus>();
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith(
            (ref) => answer.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      unawaited(router.push('/recorder'));
      await tester.pumpAndSettle();
      answer.complete(_closure);
      await tester.pumpAndSettle();

      expect(find.text('recorder'), findsOneWidget);
      expect(
        find.text('account-status', skipOffstage: false),
        findsNothing,
      );
      expect(container.read(ageReviewClosureLaunchShownProvider), isEmpty);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // The account already has the explanation in front of it, so backing out
    // of that Account status must not bring a second.
    testWidgets('does not reopen an Account status the account had open', (
      tester,
    ) async {
      final answer = Completer<AccountEnforcementStatus>();
      final container = _closureContainer(answer);
      final router = _routerWithAccountStatus();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      unawaited(router.pushNamed(AccountStatusScreen.routeName));
      // Its spinner runs until the answer arrives, so this cannot settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      answer.complete(_closure);
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(AccountStatusScreen), findsNothing);
    });

    // A closure found under Settings waits for the tabs. If the account opens
    // Account status from Settings meanwhile, it has been told, so going back
    // to the tabs must not open it a second time.
    testWidgets('counts an Account status opened from a covering screen', (
      tester,
    ) async {
      final answer = Completer<AccountEnforcementStatus>();
      final container = _closureContainer(answer);
      final router = _routerWithAccountStatus();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      unawaited(router.push('/settings'));
      await tester.pumpAndSettle();
      answer.complete(_closure);
      await tester.pumpAndSettle();
      unawaited(router.pushNamed(AccountStatusScreen.routeName));
      await tester.pumpAndSettle();
      expect(find.byType(AccountStatusScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(AccountStatusScreen), findsNothing);
    });

    // The app-update dialog opens over the shell at launch. It is a pageless
    // route, which leaves the navigator differently from a page.
    testWidgets('waits for a dialog over the tabs to close', (tester) async {
      final answer = Completer<AccountEnforcementStatus>();
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkey),
          accountEnforcementStatusProvider.overrideWith(
            (ref) => answer.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _router();
      addTearDown(router.dispose);
      await _pumpApp(tester, container, router);

      unawaited(
        showDialog<void>(
          context: tester.element(find.text('home')),
          builder: (_) => const Text('update'),
        ),
      );
      await tester.pumpAndSettle();
      answer.complete(_closure);
      await tester.pumpAndSettle();
      expect(find.text('update'), findsOneWidget);
      expect(
        find.text('account-status', skipOffstage: false),
        findsNothing,
      );

      Navigator.of(tester.element(find.text('update'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('account-status'), findsOneWidget);
    });

    // The notice lets go of the status once it has answered, so the screen it
    // opens reads the status again. That read failing must not turn the
    // closure the notice just read into "we couldn't check your status".
    testWidgets('Account status keeps the closure when its own read fails', (
      tester,
    ) async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueuedStatusClient([
        const FunnelcakeAccountStatusResponse(
          FunnelcakeAccountStatus.banned,
          category: FunnelcakeEnforcementCategory.ageReview,
        ),
        const AccountStatusApiException(
          AccountStatusApiFailureKind.unavailable,
          'offline',
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          authServiceProvider.overrideWithValue(authService),
          accountEnforcementRepositoryProvider.overrideWithValue(
            AccountEnforcementRepository(apiClient: client),
          ),
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
            builder: (context, state) => const AccountStatusScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.results, isEmpty);
      expect(find.text(l10n.accountStatusAgeClosureHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusUnavailableHeading), findsNothing);
    });
  });
}
