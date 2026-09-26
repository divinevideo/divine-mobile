// ABOUTME: Router gating with a last-known review status (#9495): last seen
// ABOUTME: active skips the wait, last seen restricted ignores the placeholder.

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
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

class _NotReadyNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

class _MockRepository extends Mock implements MinorAccountReviewRepository {}

/// The state a status provider holds while refetching after [previous]: a
/// retained value, which is what a resume refetch carries.
Future<AsyncValue<MinorAccountReviewStatus>> _refetchingAfter(
  MinorAccountReviewStatus previous,
) async {
  final fetches = [
    Future.value(previous),
    Completer<MinorAccountReviewStatus>().future,
  ];
  final status = FutureProvider<MinorAccountReviewStatus>(
    (ref) => fetches.removeAt(0),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(status.future);
  container.invalidate(status);
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
  });

  group('router gating with a last-known review status', () {
    const cacheKey = 'minor_account_review_restricted_user-pubkey';

    late AuthState authState;
    late StreamController<AuthState> authStates;
    late MockAuthService authService;
    late Completer<MinorAccountReviewStatus> fetch;
    late _MockRepository repository;

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
      // Created inside the test body so it completes in the fake-async zone.
      fetch = Completer<MinorAccountReviewStatus>();
      repository = _MockRepository();
      when(repository.fetchCurrentStatus).thenAnswer((_) => fetch.future);
      SharedPreferences.setMockInitialValues({
        cacheKey: ?cachedRestricted,
      });
      final container = ProviderContainer(
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
    });
  });
}
