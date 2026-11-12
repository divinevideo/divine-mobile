// ABOUTME: Unit tests for the router-refresh gate that keeps a resume/background
// ABOUTME: review-status refetch from tearing down a reel pushed on top mid-init,
// ABOUTME: plus the anonymous Secure-account conflict recovery redirect exception.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/providers/redirect_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockGoRouterState extends Mock implements GoRouterState {}

/// Exposes the container's [Ref] so tests can invoke [appRouterRedirect],
/// which reads providers off the ref GoRouter hands it in production.
final _refProbeProvider = Provider<Ref>((ref) => ref);

/// The retained-value loading emission a `ref.watch`-driven reload produces for
/// a provider currently holding [value]: an `AsyncLoading` that still carries
/// the prior value (`isLoading` && `hasValue`). This is the shape the router
/// listener sees mid-refetch when the review-status provider reloads — distinct
/// from a cold `AsyncLoading` (no value), which the other tests cover.
Future<AsyncValue<MinorAccountReviewStatus>> _retainedLoadingEmission(
  MinorAccountReviewStatus value,
) async {
  final bump = StateProvider((ref) => 0);
  final provider = FutureProvider<MinorAccountReviewStatus>((ref) async {
    ref.watch(bump);
    return value;
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await container.read(provider.future);
  final loadingEmissions = <AsyncValue<MinorAccountReviewStatus>>[];
  container.listen(provider, (previous, next) {
    if (next.isLoading) loadingEmissions.add(next);
  });
  container.read(bump.notifier).state++;
  await container.read(provider.future);
  return loadingEmissions.single;
}

void main() {
  group('minorAccountReviewStatusAffectsRouting', () {
    final active = MinorAccountReviewStatus.active();
    const restricted = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    );
    const restrictedWithConversation = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'case-1',
        state: MinorReviewCaseState.underModeratorReview,
        suspectedAgeBand: SuspectedAgeBand.unknown,
        allowedResolution: MinorReviewResolutionType.unknown,
        instructions: MinorReviewInstructions(title: '', body: ''),
        supportEmail: 'support@divine.video',
        moderationConversationId: 'conversation-1',
      ),
    );

    test('does not refresh when a refetch resolves to the same status', () {
      // The resume scenario: the provider re-emits a fresh-but-equal active
      // value. The instances differ by identity, so the pre-fix code refreshed;
      // the routing signature is unchanged, so the gate must skip it.
      expect(
        minorAccountReviewStatusAffectsRouting(
          AsyncData(active),
          AsyncData(MinorAccountReviewStatus.active()),
        ),
        isFalse,
      );
    });

    test('does not refresh across a refetch that keeps the active value', () async {
      // A real resume refetch emits a loading state that still carries the
      // prior value, then resolves back to active. Neither edge changes the
      // routing signature, so the gate must stay false. Guards the `!hasValue`
      // half of `loadingWithoutValue`: a plain `isLoading` check would flip the
      // signature mid-refetch and wrongly refresh, tearing down a reel on top.
      final retainedLoading = await _retainedLoadingEmission(active);
      expect(retainedLoading.isLoading && retainedLoading.hasValue, isTrue);

      // active data -> retained loading
      expect(
        minorAccountReviewStatusAffectsRouting(
          AsyncData(active),
          retainedLoading,
        ),
        isFalse,
      );
      // retained loading -> fresh active data
      expect(
        minorAccountReviewStatusAffectsRouting(
          retainedLoading,
          AsyncData(MinorAccountReviewStatus.active()),
        ),
        isFalse,
      );
    });

    test(
      'does not refresh across a refetch that keeps the restricted value',
      () async {
        // Same edges for a restricted account. The loading emission is an
        // `AsyncLoading` whose `.value` still holds the restricted status while
        // `asData` is null. Reading `asData?.value` instead of `.value` in the
        // signature would drop the restriction mid-refetch, flip the signature,
        // and refresh — so this pins the `.value` read the gate relies on.
        final retainedLoading = await _retainedLoadingEmission(restricted);
        expect(retainedLoading, isA<AsyncLoading<MinorAccountReviewStatus>>());
        expect(retainedLoading.value, restricted);

        // restricted data -> retained loading
        expect(
          minorAccountReviewStatusAffectsRouting(
            const AsyncData(restricted),
            retainedLoading,
          ),
          isFalse,
        );
        // retained loading -> fresh restricted data
        expect(
          minorAccountReviewStatusAffectsRouting(
            retainedLoading,
            const AsyncData(restricted),
          ),
          isFalse,
        );
      },
    );

    test('refreshes when the restriction decision flips', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          AsyncData(active),
          const AsyncData(restricted),
        ),
        isTrue,
      );
    });

    test('refreshes when a cold load resolves to a value', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          const AsyncLoading<MinorAccountReviewStatus>(),
          AsyncData(active),
        ),
        isTrue,
      );
    });

    test('refreshes when a moderation conversation appears on the case', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          const AsyncData(restricted),
          const AsyncData(restrictedWithConversation),
        ),
        isTrue,
      );
    });

    test('first emission refreshes only when it can gate routing', () {
      // A first unrestricted value needs no refresh — GoRouter evaluates the
      // redirect on the next navigation anyway, and there is nothing to gate.
      expect(
        minorAccountReviewStatusAffectsRouting(null, AsyncData(active)),
        isFalse,
      );
      // A first restricted value, or a first cold-load without a value, must
      // refresh so the gate fires.
      expect(
        minorAccountReviewStatusAffectsRouting(
          null,
          const AsyncData(restricted),
        ),
        isTrue,
      );
      expect(
        minorAccountReviewStatusAffectsRouting(
          null,
          const AsyncLoading<MinorAccountReviewStatus>(),
        ),
        isTrue,
      );
    });
  });

  group('anonymous Secure-account conflict recovery redirect', () {
    late _MockAuthService authService;

    setUp(() {
      resetNavigationState();
      authService = _MockAuthService();
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(() => authService.isAnonymous).thenReturn(true);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    });

    // Defaults to a resolved active status so the minor-account-review gates
    // fall through to the authenticated auth-route handling this group
    // exercises; pass a restricted status to assert the gate ordering holds.
    Future<ProviderContainer> buildContainer({
      MinorAccountReviewStatus? reviewStatus,
    }) async {
      final status = reviewStatus ?? MinorAccountReviewStatus.active();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => status,
          ),
          checkEmptyFollowingRedirectProvider.overrideWith(
            (ref, location) => null,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAccountDeletionAttemptProvider.future);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      return container;
    }

    GoRouterState stateFor(String location) {
      final uri = Uri.parse(location);
      final state = _MockGoRouterState();
      when(() => state.uri).thenReturn(uri);
      when(() => state.matchedLocation).thenReturn(uri.path);
      return state;
    }

    test(
      'lets an anonymous authenticated user reach login options when arriving '
      'from conflict recovery (email param present)',
      () async {
        final container = await buildContainer();
        final ref = container.read(_refProbeProvider);

        final result = appRouterRedirect(
          ref,
          stateFor('/welcome/login-options?email=user%40example.com'),
        );

        // Null: no redirect, the recovery sign-in destination stays visible.
        expect(result, isNull);
      },
    );

    test(
      'still bounces an anonymous authenticated user to the feed on plain '
      'login options with no recovery param',
      () async {
        final container = await buildContainer();
        final ref = container.read(_refProbeProvider);

        final result = appRouterRedirect(
          ref,
          stateFor('/welcome/login-options'),
        );

        expect(result, VideoFeedPage.pathForIndex(0));
      },
    );

    test(
      'still routes a restricted-minor anonymous user to review even with the '
      'recovery email param — the recovery exception must not outrank the '
      'load-bearing minor-review gate',
      () async {
        final container = await buildContainer(
          reviewStatus: const MinorAccountReviewStatus(
            restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
          ),
        );
        final ref = container.read(_refProbeProvider);

        final result = appRouterRedirect(
          ref,
          stateFor('/welcome/login-options?email=user%40example.com'),
        );

        expect(result, MinorAccountReviewScreen.path);
      },
    );
  });

  group('signed-out support access', () {
    Future<String?> redirectFor({
      required AuthState authState,
      required String location,
    }) async {
      resetNavigationState();
      final authService = _MockAuthService();
      when(() => authService.authState).thenReturn(authState);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAccountDeletionAttemptProvider.future);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      final state = _MockGoRouterState();
      final uri = Uri.parse(location);
      when(() => state.uri).thenReturn(uri);
      when(() => state.matchedLocation).thenReturn(uri.path);

      return appRouterRedirect(container.read(_refProbeProvider), state);
    }

    test('keeps the Support Center reachable while unauthenticated', () async {
      expect(
        await redirectFor(
          authState: AuthState.unauthenticated,
          location: SupportCenterScreen.path,
        ),
        isNull,
      );
    });

    test('keeps the Support Center reachable while awaiting TOS', () async {
      expect(
        await redirectFor(
          authState: AuthState.awaitingTosAcceptance,
          location: SupportCenterScreen.path,
        ),
        isNull,
      );
    });

    test('keeps signed-out feature requests behind the auth gate', () async {
      expect(
        await redirectFor(
          authState: AuthState.unauthenticated,
          location: FeatureRequestScreen.path,
        ),
        WelcomeScreen.path,
      );
    });

    test('keeps signed-out bug reports behind the auth gate', () async {
      expect(
        await redirectFor(
          authState: AuthState.unauthenticated,
          location: BugReportScreen.path,
        ),
        WelcomeScreen.path,
      );
    });
  });

  group('logging a location that carries a secret (#10385)', () {
    // NIP-19's published test vector; it controls no real account.
    const nsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    Future<String> loggedWhileRedirecting({
      required AuthState authState,
      required String location,
      MinorAccountReviewStatus? reviewStatus,
    }) async {
      resetNavigationState();
      final authService = _MockAuthService();
      when(() => authService.authState).thenReturn(authState);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => reviewStatus ?? MinorAccountReviewStatus.active(),
          ),
          checkEmptyFollowingRedirectProvider.overrideWith(
            (ref, location) => null,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAccountDeletionAttemptProvider.future);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      final state = _MockGoRouterState();
      final uri = Uri.parse(location);
      when(() => state.uri).thenReturn(uri);
      when(() => state.matchedLocation).thenReturn(uri.path);

      await LogCaptureService().clearAllLogs();
      appRouterRedirect(container.read(_refProbeProvider), state);
      return [
        for (final entry in LogCaptureService().getRecentLogs()) entry.message,
      ].join('\n');
    }

    // The redirect logs several redacted lines into one capture, so each
    // assertion reads only its own line: any other line's redaction would
    // satisfy a check over all of them.
    String loggedLine(String logged, String marker) =>
        logged.split('\n').singleWhere((line) => line.contains(marker));

    test('does not log the nsec of a signed-out profile location', () async {
      final logged = await loggedWhileRedirecting(
        authState: AuthState.unauthenticated,
        location: '/profile/$nsec',
      );

      // Unbracketed: each line's own redaction, not the sink's.
      expect(
        loggedLine(logged, 'Router redirect: location='),
        contains('/profile/REDACTED'),
      );
      expect(
        loggedLine(logged, 'unauthenticated on'),
        contains('/profile/REDACTED'),
      );
      expect(logged.toLowerCase(), isNot(contains('nsec1')));
    });

    test('does not log the nsec of a universal link', () async {
      final logged = await loggedWhileRedirecting(
        authState: AuthState.authenticated,
        location: 'https://divine.video/profile/$nsec',
      );

      // Unbracketed: the redirect target's own redaction, not the sink's.
      // The link before the arrow is redacted too, so read only the target.
      expect(
        loggedLine(logged, 'Router redirect: universal link').split(' → ').last,
        contains('/profile/REDACTED'),
      );
      expect(logged.toLowerCase(), isNot(contains('nsec1')));
    });

    test('does not log the nsec of a divine:// link', () async {
      final logged = await loggedWhileRedirecting(
        authState: AuthState.authenticated,
        location: 'divine:///profile/$nsec',
      );

      // Unbracketed: the redirect target's own redaction, not the sink's.
      // The link before the arrow is redacted too, so read only the target.
      expect(
        loggedLine(logged, 'Router redirect: divine scheme').split(' -> ').last,
        contains('/profile/REDACTED'),
      );
      expect(logged.toLowerCase(), isNot(contains('nsec1')));
    });

    test('does not log the nsec when a restricted account is held', () async {
      final logged = await loggedWhileRedirecting(
        authState: AuthState.authenticated,
        location: '/profile/$nsec',
        reviewStatus: const MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        ),
      );

      // Unbracketed: the line's own redaction, not the sink's.
      expect(
        loggedLine(logged, 'restricted account on'),
        contains('/profile/REDACTED'),
      );
      expect(logged.toLowerCase(), isNot(contains('nsec1')));
    });
  });
}
