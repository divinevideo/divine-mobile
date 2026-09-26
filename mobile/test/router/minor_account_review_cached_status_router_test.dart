// ABOUTME: Router gating with a saved review status (#9495): an account never
// ABOUTME: seen restricted skips the wait, one seen restricted does not.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/minor_account_review_status_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

class _NotReadyNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

class _MockRepository extends Mock implements MinorAccountReviewRepository {}

/// The state a status provider holds during a refetch, after it settled on
/// [previous] and, with [thenFailed], on a failed fetch after that. The
/// refetch is an invalidation, as a resume or "check again" makes, or with
/// [reload] a dependency change, as an auth flip makes.
Future<AsyncValue<MinorAccountReviewStatus>> _refetchingAfter(
  MinorAccountReviewStatus previous, {
  bool thenFailed = false,
  bool reload = false,
}) async {
  final fetches = <Future<MinorAccountReviewStatus> Function()>[
    () async => previous,
    if (thenFailed) () async => throw StateError('status unavailable'),
    () => Completer<MinorAccountReviewStatus>().future,
  ];
  final status = FutureProvider<MinorAccountReviewStatus>(
    (ref) => fetches.removeAt(0)(),
    retry: (_, _) => null,
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(status.future);
  if (thenFailed) {
    container.invalidate(status, asReload: true);
    await expectLater(container.read(status.future), throwsStateError);
  }
  container.invalidate(status, asReload: reload);
  return container.read(status);
}

void main() {
  group('minorAccountReviewRoutingStatus', () {
    test("keeps a restriction's case through a background refetch", () async {
      const restricted = MinorAccountReviewStatus(
        restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        currentCase: MinorReviewCase(
          id: 'case-refetch',
          state: MinorReviewCaseState.restrictedPendingParentalConsent,
          suspectedAgeBand: SuspectedAgeBand.age13To15,
          allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
          instructions: MinorReviewInstructions(title: '', body: ''),
          supportEmail: 'support@divine.video',
        ),
      );
      final live = await _refetchingAfter(restricted);
      expect(live.isLoading, isTrue);

      final routed = minorAccountReviewRoutingStatus(
        live,
        lastKnownRestricted: () => true,
      );

      expect(routed.value?.currentCase?.id, equals('case-refetch'));
    });

    test('fails open on a fetch error despite a cached restriction', () {
      final routed = minorAccountReviewRoutingStatus(
        AsyncError(StateError('status unavailable'), StackTrace.empty),
        lastKnownRestricted: () => true,
      );

      expect(routed.hasError, isTrue);
      expect(routed.value, isNull);
    });

    test('keeps failing open while a failed fetch is refetched', () async {
      final live = await _refetchingAfter(
        MinorAccountReviewStatus.active(),
        thenFailed: true,
      );
      expect(live.isRefreshing && live.hasError, isTrue);

      final routed = minorAccountReviewRoutingStatus(
        live,
        lastKnownRestricted: () => true,
      );

      expect(routed, same(live));
    });

    test('keeps failing open through a reload after a failed fetch', () async {
      final live = await _refetchingAfter(
        MinorAccountReviewStatus.active(),
        thenFailed: true,
        reload: true,
      );
      expect(live.isReloading && live.hasError, isTrue);

      final routed = minorAccountReviewRoutingStatus(
        live,
        lastKnownRestricted: () => true,
      );

      expect(routed, same(live));
    });

    test('keeps routing on a settled result while it is refetched', () async {
      final live = await _refetchingAfter(MinorAccountReviewStatus.active());
      expect(live.isRefreshing, isTrue);

      final routed = minorAccountReviewRoutingStatus(
        live,
        lastKnownRestricted: () => true,
      );

      expect(routed, same(live));
    });
  });

  group('router gating with a last-known review status', () {
    final cacheKey = MinorAccountReviewStatusStore.storageKey('user-pubkey');

    late AuthState authState;
    late StreamController<AuthState> authStates;
    late MockAuthService authService;
    late Completer<MinorAccountReviewStatus> fetch;
    late Completer<MinorAccountReviewStatus> refetch;
    late _MockRepository repository;
    late ProviderContainer container;

    setUp(() {
      resetNavigationState();
      authStates = StreamController<AuthState>.broadcast();
      addTearDown(authStates.close);
      authService = createMockAuthService();
      when(() => authService.authState).thenAnswer((_) => authState);
      when(
        () => authService.isAuthenticated,
      ).thenAnswer((_) => authState == AuthState.authenticated);
      when(() => authService.currentPublicKeyHex).thenReturn('user-pubkey');
      when(() => authService.authStateStream)
          .thenAnswer((_) => authStates.stream);
    });

    MinorAccountReviewStatus restrictedStatus() =>
        const MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
          currentCase: MinorReviewCase(
            id: 'case-router',
            state: MinorReviewCaseState.restrictedPendingUserResponse,
            suspectedAgeBand: SuspectedAgeBand.age13To15,
            allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
            instructions: MinorReviewInstructions(
              title: 'Account review required',
              body: 'We need parental consent information.',
            ),
            supportEmail: 'support@divine.video',
          ),
        );

    /// Builds the router at [LegalScreen.path], a screen a restricted account
    /// may not stay on. A [startState] of `checking` is a cold start, where
    /// the router exists before auth restore settles; `authenticated` is a
    /// container opened for an account already signed in, as an account
    /// switch does.
    Future<GoRouter> pumpRouter(
      WidgetTester tester, {
      required AuthState startState,
      bool? cachedRestricted,
    }) async {
      authState = startState;
      // Created inside the test body so they complete in the fake-async zone.
      fetch = Completer<MinorAccountReviewStatus>();
      refetch = Completer<MinorAccountReviewStatus>();
      repository = _MockRepository();
      var fetches = 0;
      when(
        repository.fetchCurrentStatus,
      ).thenAnswer((_) => (fetches++ == 0 ? fetch : refetch).future);
      SharedPreferences.setMockInitialValues({
        cacheKey: ?cachedRestricted,
      });
      container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockAuthService: authService,
            mockSharedPreferences: await SharedPreferences.getInstance(),
          ),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          minorAccountReviewRepositoryProvider.overrideWithValue(repository),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          routerInitialLocationProvider.overrideWithValue(
            LegalScreen.path,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      final router = container.read(goRouterProvider);
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
      await tester.pump();
      return router;
    }

    Future<void> finishAuthRestore(WidgetTester tester) async {
      authState = AuthState.authenticated;
      authStates.add(AuthState.authenticated);
      await tester.pump();
      await tester.pump();
    }

    /// Refetches the status the way a resume or "check again" does. As in the
    /// app, nothing watches the router, so the status only rebuilds when the
    /// next redirect reads it.
    Future<void> refetchStatus(WidgetTester tester) async {
      container.invalidate(currentMinorAccountReviewStatusProvider);
      await tester.pump();
    }

    String location(GoRouter router) =>
        router.routeInformationProvider.value.uri.path;

    group('account opened already signed in', () {
      testWidgets('waits on the loading screen with no last-known status', (
        tester,
      ) async {
        final router = await pumpRouter(
          tester,
          startState: AuthState.authenticated,
        );
        expect(location(router), MinorAccountReviewLoadingScreen.path);

        fetch.complete(MinorAccountReviewStatus.active());
        await tester.pumpAndSettle();
        expect(location(router), LegalScreen.path);
      });

      testWidgets('routes without waiting when its last status was active', (
        tester,
      ) async {
        final router = await pumpRouter(
          tester,
          startState: AuthState.authenticated,
          cachedRestricted: false,
        );
        expect(location(router), LegalScreen.path);

        fetch.complete(MinorAccountReviewStatus.active());
        await tester.pumpAndSettle();
        expect(location(router), LegalScreen.path);
      });

      testWidgets(
        'moves to the review screen when the fetch returns a restriction',
        (tester) async {
          final router = await pumpRouter(
            tester,
            startState: AuthState.authenticated,
            cachedRestricted: false,
          );
          expect(location(router), LegalScreen.path);

          fetch.complete(restrictedStatus());
          await tester.pumpAndSettle();
          expect(location(router), MinorAccountReviewScreen.path);
        },
      );

      testWidgets(
        'is not stranded on the loading screen by a superseded fetch',
        (tester) async {
          final router = await pumpRouter(
            tester,
            startState: AuthState.authenticated,
            cachedRestricted: false,
          );
          await refetchStatus(tester);
          fetch.complete(restrictedStatus());
          await tester.pump();
          router.refresh();
          await tester.pumpAndSettle();

          refetch.complete(MinorAccountReviewStatus.active());
          await tester.pumpAndSettle();
          expect(location(router), LegalScreen.path);
        },
      );
    });

    group('cold start', () {
      testWidgets('waits for the fetch when the account was last restricted', (
        tester,
      ) async {
        final router = await pumpRouter(
          tester,
          startState: AuthState.checking,
          cachedRestricted: true,
        );
        await finishAuthRestore(tester);
        expect(location(router), MinorAccountReviewLoadingScreen.path);

        fetch.complete(restrictedStatus());
        await tester.pumpAndSettle();
        expect(location(router), MinorAccountReviewScreen.path);
      });

      testWidgets('returns to the destination once a restriction is lifted', (
        tester,
      ) async {
        final router = await pumpRouter(
          tester,
          startState: AuthState.checking,
          cachedRestricted: true,
        );
        await finishAuthRestore(tester);
        expect(location(router), MinorAccountReviewLoadingScreen.path);

        fetch.complete(MinorAccountReviewStatus.active());
        await tester.pumpAndSettle();
        expect(location(router), LegalScreen.path);
      });

      testWidgets(
        'stays on the destination while a timed-out fetch is retried',
        (tester) async {
          final router = await pumpRouter(
            tester,
            startState: AuthState.checking,
            cachedRestricted: true,
          );
          await finishAuthRestore(tester);
          await tester.pump(const Duration(seconds: 10));
          await tester.pumpAndSettle();
          expect(location(router), LegalScreen.path);

          await refetchStatus(tester);
          router.refresh();
          await tester.pumpAndSettle();
          expect(location(router), LegalScreen.path);

          refetch.complete(MinorAccountReviewStatus.active());
          await tester.pumpAndSettle();
          expect(location(router), LegalScreen.path);
        },
      );
    });
  });
}
