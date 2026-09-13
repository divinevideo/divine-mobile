// ABOUTME: Tests for route normalization skip logic
// ABOUTME: Prevents universal links from being rewritten by internal canonicalization

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

void main() {
  const videoId =
      '672c4eb9fc29adb6b505713bc6da94af2244c1de55dc6f034e2bcdaba133ebbe';
  const pubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  group('shouldSkipRouteNormalization', () {
    test('skips divine video universal links', () {
      expect(
        shouldSkipRouteNormalization('https://divine.video/video/abc123'),
        isTrue,
      );
    });

    test('skips divine profile universal links', () {
      expect(
        shouldSkipRouteNormalization(
          'https://divine.video/profile/npub1abc123',
        ),
        isTrue,
      );
    });

    test('skips divine list universal links', () {
      expect(
        shouldSkipRouteNormalization('https://divine.video/list/my-vines'),
        isTrue,
      );
      expect(
        shouldSkipRouteNormalization(
          'https://www.divine.video/list/my-vines',
        ),
        isTrue,
      );
    });

    test('skips NIP-46 signer callbacks from native signer apps', () {
      expect(
        shouldSkipRouteNormalization(
          'divine://nostrconnect?x-source=aegis&relay=wss://localrelay.link:28443',
        ),
        isTrue,
      );
    });

    test('does not skip unrelated hosts', () {
      expect(
        shouldSkipRouteNormalization('https://example.com/video/abc123'),
        isFalse,
      );
    });

    test('does not skip modeled internal routes without query or fragment', () {
      final routes = {
        '/video/$videoId': 'video detail is fully modeled',
        '/home/0': 'canonical home path is fully modeled',
        '/home/-3': 'negative index can be normalized losslessly',
      };

      for (final entry in routes.entries) {
        expect(
          shouldSkipRouteNormalization(entry.key),
          isFalse,
          reason: entry.value,
        );
      }
    });

    test(
      'skips all query or fragment routes because canonicalization is lossy',
      () {
        final routes = {
          PooledFullscreenVideoFeedScreen.pathForVideoId(videoId):
              'pooled feed carries selected video identity in query',
          CreatePeopleListPage.pathWithInitialPubkey(pubkey):
              'create people list seeds a full pubkey in query',
          SearchResultsPage.pathForQuery('nostr', requestFocusOnMount: true):
              'search focus state lives in query',
          '${EmailVerificationScreen.path}?deviceCode=abc123':
              'email verification polling state lives in query',
          '${ResetPasswordScreen.path}?token=abc123':
              'password reset token lives in query',
          '/home/0#top': 'fragments cannot be rebuilt from RouteContext',
          '/video/$videoId/likers?a=34236%3A$pubkey%3Adtag':
              'engagement list filter state lives in query',
        };

        for (final entry in routes.entries) {
          expect(
            shouldSkipRouteNormalization(entry.key),
            isTrue,
            reason: entry.value,
          );
        }
      },
    );

    test('skips parse-but-build-shorter route families', () {
      final routes = {
        WelcomeScreen.path:
            'welcome subtree is GoRouter-owned and normalization-sensitive',
        WelcomeScreen.loginOptionsPath:
            'welcome subtree is GoRouter-owned and normalization-sensitive',
        '/apps/primal/sandbox':
            'app sandbox is not represented in RouteContext',
        '/video/$videoId/likers':
            'video engagement list suffix is not represented in RouteContext',
        '/video/$videoId/reposters':
            'video engagement list suffix is not represented in RouteContext',
        MinorAccountReviewScreen.path:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewScreen.welcomePath:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewLoadingScreen.path:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewParentConsentScreen.path:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewParentContactScreen.path:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewUnder13Screen.path:
            'minor account review flow is GoRouter-owned',
        MinorAccountReviewUnder13SupportScreen.path:
            'minor account review flow is GoRouter-owned',
      };

      for (final entry in routes.entries) {
        expect(
          shouldSkipRouteNormalization(entry.key),
          isTrue,
          reason: entry.value,
        );
      }
    });
  });

  group('normalization classification', () {
    test('normalizes modeled routes only', () {
      final routes = {
        '/home/-3': '/home/0',
        '/profile/$pubkey/-1': '/profile/$pubkey/0',
        '/hashtag/nostr%20video': '/hashtag/nostr%20video',
      };

      for (final entry in routes.entries) {
        final parsed = parseKnownRoute(entry.key);
        expect(parsed, isNotNull, reason: entry.key);
        expect(buildRoute(parsed!), entry.value, reason: entry.key);
      }
    });

    test('leaves unknown and incomplete routes to GoRouter', () {
      expect(
        parseKnownRoute('/search-results/nostr'),
        isNull,
        reason: 'search results are GoRouter-owned, not RouteContext modeled',
      );
      expect(
        parseKnownRoute('/verify-email'),
        isNull,
        reason: 'auth deep links are GoRouter-owned',
      );
      expect(
        parseKnownRoute('/wat/xyz'),
        isNull,
        reason: 'unknown routes should not be rewritten to home',
      );
      expect(
        parseKnownRoute('/following'),
        isNull,
        reason: 'incomplete dynamic routes should not throw or normalize',
      );
      expect(
        parseKnownRoute(ProfileSetupScreen.setupPath),
        isNull,
        reason: 'setup profile must not normalize to edit profile',
      );
    });

    test('leaves routes with unmodeled trailing segments to GoRouter', () {
      for (final route in [
        ExploreScreen.pathForTab('popular'),
        '/people-lists/new/extra',
        '/hashtag/dogs/3',
        '/video/$videoId/bogus',
        '/profile/$pubkey/0/extra',
      ]) {
        expect(
          parseKnownRoute(route),
          isNull,
          reason: 'unmodeled suffix must not be normalized away: $route',
        );
      }
    });
  });
}
