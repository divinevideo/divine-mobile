// ABOUTME: divine:// deep links must clear the same auth/minor-review gates
// ABOUTME: as the plain path they address — the redirect runs only once

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Hands the test a real [Ref] so [appRouterRedirect] can be driven through a
/// GoRouter instead of being called in isolation.
final _refProvider = Provider<Ref>((ref) => ref);

// go_router applies the legacy top-level redirect at most once per navigation
// and does not re-evaluate the location it redirects to
// (`RouteConfiguration.applyTopLegacyRedirect`). Anything appRouterRedirect
// returns is therefore final, so resolving a divine:// URI to a destination
// and returning it there would skip every gate below it. These tests drive the
// whole redirect and compare each divine:// link against the plain path it
// addresses: the two must land in the same place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  Future<String> resolve(
    WidgetTester tester, {
    required String target,
    required AuthState authState,
    bool restricted = false,
    String? nostrConnectUrl,
  }) async {
    final authService = _MockAuthService();
    when(() => authService.authState).thenReturn(authState);
    when(() => authService.nostrConnectUrl).thenReturn(nostrConnectUrl);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.currentPublicKeyHex).thenReturn('abc123');
    when(
      () => authService.onSignerCallbackReceived(
        relayUrl: any(named: 'relayUrl'),
      ),
    ).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        // The authenticated-auth-route branch consults this on first
        // navigation; the empty-following bounce is not what these tests are
        // about.
        hasFollowingInCacheProvider.overrideWithValue(true),
        currentAccountDeletionAttemptProvider.overrideWith((ref) async => null),
        currentMinorAccountReviewStatusProvider.overrideWith(
          (ref) async => restricted
              ? const MinorAccountReviewStatus(
                  restrictionStatus:
                      AccountRestrictionStatus.restrictedMinorReview,
                )
              : MinorAccountReviewStatus.active(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Settle the status so the redirect sees a value rather than AsyncLoading,
    // which has its own loading-screen bounce.
    await container.read(currentAccountDeletionAttemptProvider.future);
    await container.read(currentMinorAccountReviewStatusProvider.future);

    final ref = container.read(_refProvider);
    final router = GoRouter(
      initialLocation: WelcomeScreen.path,
      redirect: (_, state) => appRouterRedirect(ref, state),
      routes: [
        for (final path in <String>[
          WelcomeScreen.path,
          NostrConnectScreen.path,
          VideoFeedPage.pathForIndex(0),
          MinorAccountReviewScreen.path,
          SavedVideosScreen.path,
          SettingsScreen.path,
          VideoDetailScreen.path,
          '${VideoDetailScreen.path}/likers',
          ProfileScreenRouter.pathWithNpub,
          HashtagScreenRouter.path,
          SearchResultsPage.path,
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

  // Each entry is (divine:// link, the plain path it addresses).
  const allowListed = <(String, String)>[
    ('divine:///saved-videos', SavedVideosScreen.path),
    ('divine:///video/abc123', '/video/abc123'),
    ('divine:///video/abc123/likers', '/video/abc123/likers'),
    ('divine:///profile/npub1abc', '/profile/npub1abc'),
    ('divine:///hashtag/art', '/hashtag/art'),
    ('divine:///search/music', '/search-results/music'),
  ];

  group('a restricted-minor account', () {
    testWidgets('cannot escape the review screen through an allow-listed '
        'divine:// link', (tester) async {
      for (final (link, plainPath) in allowListed) {
        final viaScheme = await resolve(
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
          viaScheme,
          equals(viaPath),
          reason:
              '$link reached $viaScheme while $plainPath was gated to '
              '$viaPath. A restricted account must not get a way around the '
              'review screen by opening a custom-scheme link.',
        );
      }
    });

    testWidgets('cannot reach the feed through an unlisted divine:// link', (
      tester,
    ) async {
      for (final link in const <String>[
        'divine://nostrconnect',
        'divine:///developer-options',
        'divine:///settings',
        'divine://attacker.example?relay=wss://evil.example',
      ]) {
        expect(
          await resolve(
            tester,
            target: link,
            authState: AuthState.authenticated,
            restricted: true,
          ),
          equals(MinorAccountReviewScreen.path),
          reason: '$link must not land a restricted account in the app.',
        );
      }
    });
  });

  group('a signed-out user', () {
    testWidgets('is sent to welcome by an allow-listed divine:// link', (
      tester,
    ) async {
      for (final (link, plainPath) in allowListed) {
        expect(
          await resolve(
            tester,
            target: link,
            authState: AuthState.unauthenticated,
          ),
          equals(WelcomeScreen.path),
          reason:
              '$link must be gated exactly like $plainPath, which bounces a '
              'signed-out user to welcome.',
        );
      }
    });
  });

  group('an ordinary signed-in user', () {
    testWidgets('still reaches every allow-listed divine:// destination', (
      tester,
    ) async {
      for (final (link, plainPath) in allowListed) {
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

    testWidgets('lands on the feed for a stray signer callback', (
      tester,
    ) async {
      expect(
        await resolve(
          tester,
          target: 'divine://nostrconnect',
          authState: AuthState.authenticated,
        ),
        equals(VideoFeedPage.pathForIndex(0)),
      );
    });
  });

  // The one deliberate ungated case: /nostr-connect is an auth route, so
  // gating it would hand a signed-in user straight back to the feed and drop
  // the pairing they just approved.
  group('a live NIP-46 pairing', () {
    testWidgets('returns to nostr connect even when signed in', (tester) async {
      expect(
        await resolve(
          tester,
          target:
              'divine://nostrconnect?x-source=aegis'
              '&relay=wss://localrelay.link:28443',
          authState: AuthState.authenticated,
          nostrConnectUrl: 'nostrconnect://deadbeef',
        ),
        equals(NostrConnectScreen.path),
      );
    });

    testWidgets('returns to nostr connect when signed out', (tester) async {
      expect(
        await resolve(
          tester,
          target: 'divine://nostrconnect',
          authState: AuthState.unauthenticated,
          nostrConnectUrl: 'nostrconnect://deadbeef',
        ),
        equals(NostrConnectScreen.path),
      );
    });
  });

  group('ordinary in-app navigation', () {
    testWidgets('is unaffected — no divine:// rewrite in play', (tester) async {
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
