// ABOUTME: https://divine.video universal links must clear the same auth and
// ABOUTME: minor-review gates as the plain path — the redirect runs only once

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Hands the test a real [Ref] so [appRouterRedirect] can be driven through a
/// GoRouter instead of being called in isolation.
final _refProvider = Provider<Ref>((ref) => ref);

const _npub = 'npub180cvv07tjdrrgpa9jzd0cdkej42kwsaxq9rz7gvdpjx6nz004f9uulstw6';
const _listAuthor =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

// go_router applies the top-level redirect at most once per navigation and does
// not re-evaluate the location it redirects to
// (`RouteConfiguration.applyTopLegacyRedirect`). Anything appRouterRedirect
// returns is therefore final, so resolving a universal link to a destination
// and returning it there skipped every gate below it (#7146). These tests drive
// the whole redirect and compare each https link against the plain path it
// addresses: the two must land in the same place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  Future<String> resolve(
    WidgetTester tester, {
    required String target,
    required AuthState authState,
    bool restricted = false,
    bool reviewStatusPending = false,
  }) async {
    final authService = _MockAuthService();
    when(() => authService.authState).thenReturn(authState);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        // The authenticated-auth-route branch consults this on first
        // navigation; the empty-following bounce is not what these tests are
        // about.
        hasFollowingInCacheProvider.overrideWithValue(true),
        currentAccountDeletionAttemptProvider.overrideWith((ref) async => null),
        currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
          if (reviewStatusPending) {
            // Never completes, so the redirect sees AsyncLoading with no value
            // — the cold-load shape that bounces through the loading screen.
            return Completer<MinorAccountReviewStatus>().future;
          }
          return restricted
              ? const MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                )
              : MinorAccountReviewStatus.active();
        }),
      ],
    );
    addTearDown(container.dispose);
    if (reviewStatusPending) {
      container.read(currentMinorAccountReviewStatusProvider);
    } else {
      // Settle the status so the redirect sees a value rather than
      // AsyncLoading, which has its own loading-screen bounce.
      await container.read(currentMinorAccountReviewStatusProvider.future);
    }
    await container.read(currentAccountDeletionAttemptProvider.future);

    final ref = container.read(_refProvider);
    final router = GoRouter(
      initialLocation: WelcomeScreen.path,
      redirect: (_, state) => appRouterRedirect(ref, state),
      routes: [
        for (final path in <String>[
          WelcomeScreen.path,
          VideoFeedPage.pathForIndex(0),
          MinorAccountReviewScreen.path,
          MinorAccountReviewLoadingScreen.path,
          SettingsScreen.path,
          ProfileScreenRouter.pathWithNpub,
          HashtagScreenRouter.path,
          SearchResultsPage.path,
          CuratedListFeedScreen.path,
          CuratedListByAuthorScreen.path,
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go(target);
    await tester.pumpAndSettle();
    return router.state.uri.toString();
  }

  // Each entry is (universal link, the plain path it addresses), covering both
  // /list shapes. profile, hashtag, search and list are exactly the types
  // universalLinkToRouterPath resolves; video and savedVideos,
  // signerCallback and unknown return null and already fell through to the
  // gates.
  const links = <(String, String)>[
    ('https://divine.video/profile/$_npub', '/profile/$_npub'),
    ('https://divine.video/hashtag/art', '/hashtag/art'),
    ('https://divine.video/search/music', '/search-results/music'),
    ('https://divine.video/list/my-vines', '/list/my-vines'),
    (
      'https://divine.video/list/$_listAuthor/my-vines',
      '/list/$_listAuthor/my-vines',
    ),
  ];

  group('a restricted-minor account', () {
    testWidgets('cannot escape the review screen through a universal link', (
      tester,
    ) async {
      for (final (link, plainPath) in links) {
        final viaLink = await resolve(
          tester,
          target: link,
          authState: AuthState.authenticated,
          restricted: true,
        );
        final viaPath = await resolve(
          tester,
          target: plainPath,
          authState: AuthState.authenticated,
          restricted: true,
        );

        expect(
          viaPath,
          equals(MinorAccountReviewScreen.path),
          reason: '$plainPath should be gated for a restricted account.',
        );
        expect(
          viaLink,
          equals(viaPath),
          reason:
              '$link reached $viaLink while $plainPath was gated to $viaPath. '
              'A restricted account must not get a way around the review '
              'screen by opening a shared https link.',
        );
      }
    });
  });

  group('a signed-out visitor', () {
    testWidgets('is sent to welcome by a universal link', (tester) async {
      for (final (link, plainPath) in links) {
        expect(
          await resolve(
            tester,
            target: link,
            authState: AuthState.unauthenticated,
          ),
          equals(WelcomeScreen.path),
          reason:
              '$link must be gated exactly like $plainPath, which bounces a '
              'signed-out visitor to welcome.',
        );
      }
    });
  });

  group('an ordinary signed-in user', () {
    testWidgets('still reaches every universal-link destination', (
      tester,
    ) async {
      for (final (link, plainPath) in links) {
        expect(
          await resolve(
            tester,
            target: link,
            authState: AuthState.authenticated,
          ),
          equals(plainPath),
          reason: '$link should open $plainPath.',
        );
      }
    });

    testWidgets('waits on the review loading screen with the rewritten path', (
      tester,
    ) async {
      // The loading screen round-trips `from` back through the redirect, so it
      // has to carry the internal path — handing it the raw https URL would
      // re-resolve the link a second time on the way back.
      expect(
        await resolve(
          tester,
          target: 'https://divine.video/search/music',
          authState: AuthState.authenticated,
          reviewStatusPending: true,
        ),
        equals(
          Uri(
            path: MinorAccountReviewLoadingScreen.path,
            queryParameters: const {'from': '/search-results/music'},
          ).toString(),
        ),
      );
    });
  });

  group('ordinary in-app navigation', () {
    testWidgets('is unaffected — no universal-link rewrite in play', (
      tester,
    ) async {
      expect(
        await resolve(
          tester,
          target: SettingsScreen.path,
          authState: AuthState.authenticated,
        ),
        equals(SettingsScreen.path),
      );
      expect(
        await resolve(
          tester,
          target: SettingsScreen.path,
          authState: AuthState.unauthenticated,
        ),
        equals(WelcomeScreen.path),
      );
    });
  });
}
