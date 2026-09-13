// ABOUTME: Unit tests for universal_link_resolver — pure Uri -> path mapping
// ABOUTME: Covers divine.video host gating and every DeepLinkType branch

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';

void main() {
  group('divineUrlToPushRoute', () {
    test('maps video links to video detail routes', () {
      expect(
        divineUrlToPushRoute(Uri.parse('https://divine.video/video/abc123')),
        equals('/video/abc123'),
      );
    });

    test('preserves note1 video references for in-app resolution', () {
      const noteId =
          'note1w3jhxaq69g8m70m7g6g8j2rf7x0s5h7k0d0l0m9d3c4s5u6v7w8q9xyz0p';
      expect(
        divineUrlToPushRoute(Uri.parse('https://divine.video/video/$noteId')),
        equals('/video/$noteId'),
      );
    });

    test('accepts www.divine.video host alias', () {
      expect(
        divineUrlToPushRoute(
          Uri.parse('https://www.divine.video/profile/npub1abc123'),
        ),
        equals('/profile/npub1abc123'),
      );
    });

    test('maps local list links to the internal list route', () {
      expect(
        divineUrlToPushRoute(Uri.parse('https://divine.video/list/my-vines')),
        equals('/list/my-vines'),
      );
    });

    test('maps authored list links to the internal list route', () {
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      expect(
        divineUrlToPushRoute(
          Uri.parse('https://divine.video/list/$authorPubkey/my-vines'),
        ),
        equals('/list/$authorPubkey/my-vines'),
      );
    });
  });

  group('universalLinkToRouterPath', () {
    group('host gating', () {
      test('returns null for non-http schemes', () {
        expect(
          universalLinkToRouterPath(Uri.parse('divine://signer-callback')),
          isNull,
        );
      });

      test('returns null for unrelated hosts', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://example.com/search/music'),
          ),
          isNull,
        );
      });

      test('returns null for path-only URIs (in-app navigation)', () {
        expect(universalLinkToRouterPath(Uri.parse('/home/0')), isNull);
      });

      test('accepts divine.video host', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/music'),
          ),
          equals('/search-results/music'),
        );
      });

      test('accepts www.divine.video host alias', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://www.divine.video/search/music'),
          ),
          equals('/search-results/music'),
        );
      });

      test('returns null for login.divine.video — OAuth callback paths '
          'already match internal GoRoutes by coincidence', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://login.divine.video/search/music'),
          ),
          isNull,
        );
      });
    });

    group('search', () {
      test('maps /search/:term to /search-results/:term', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/flutter'),
          ),
          equals('/search-results/flutter'),
        );
      });

      test('maps /search/:term/:index by dropping the index', () {
        // The internal SearchResultsPage route does not accept a trailing
        // index, so it is intentionally dropped.
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/flutter/3'),
          ),
          equals('/search-results/flutter'),
        );
      });

      test('returns null for /search without a term', () {
        expect(
          universalLinkToRouterPath(Uri.parse('https://divine.video/search')),
          isNull,
        );
      });
    });

    group('profile', () {
      test('maps /profile/:npub to /profile/:npub', () {
        const npub =
            'npub1xyz000000000000000000000000000000000000000000000000000000000';
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/profile/$npub'),
          ),
          equals('/profile/$npub'),
        );
      });

      test('maps /profile/:npub/:index to /profile/:npub/:index', () {
        const npub =
            'npub1abc000000000000000000000000000000000000000000000000000000000';
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/profile/$npub/7'),
          ),
          equals('/profile/$npub/7'),
        );
      });
    });

    group('list', () {
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

      test('maps /list/:listId to the internal list route', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/list/my-vines'),
          ),
          equals('/list/my-vines'),
        );
      });

      test('maps /list/:listId on www host to the internal list route', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://www.divine.video/list/my-vines'),
          ),
          equals('/list/my-vines'),
        );
      });

      test('maps /list/:pubkey/:listId to the internal list route', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/list/$authorPubkey/my-vines'),
          ),
          equals('/list/$authorPubkey/my-vines'),
        );
      });

      test('preserves URL-encoded list identifiers', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/list/$authorPubkey/my%20vines'),
          ),
          equals('/list/$authorPubkey/my%20vines'),
        );
      });

      test('returns null for /list without a list id', () {
        expect(
          universalLinkToRouterPath(Uri.parse('https://divine.video/list')),
          isNull,
        );
      });
    });

    group('hashtag', () {
      test('maps /hashtag/:tag to /hashtag/:tag', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/hashtag/flutter'),
          ),
          equals('/hashtag/flutter'),
        );
      });

      test('preserves URL-encoded non-ASCII tags', () {
        // Uri.parse decodes the percent-encoded emoji into pathSegments;
        // HashtagScreenRouter.pathForTag then re-encodes it via
        // Uri.encodeComponent, so the round-trip is deterministic.
        final encoded = Uri.encodeComponent('🔥');
        final result = universalLinkToRouterPath(
          Uri.parse('https://divine.video/hashtag/$encoded'),
        );
        expect(result, equals('/hashtag/$encoded'));
      });
    });

    group('paths deferred to the DeepLinkService listener', () {
      test('/video/:id returns null (listener uses push for back-nav)', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/video/abc123'),
          ),
          isNull,
        );
      });

      test('unknown divine.video path returns null', () {
        expect(
          universalLinkToRouterPath(Uri.parse('https://divine.video/nope')),
          isNull,
        );
      });

      test('divine:// app routes return null — the custom scheme has its '
          'own resolver', () {
        expect(
          universalLinkToRouterPath(Uri.parse('divine:///saved-videos')),
          isNull,
        );
      });
    });
  });

  group('customSchemeToRouterPath', () {
    test('maps the authority-less saved-videos link to its route', () {
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///saved-videos')),
        equals('/saved-videos'),
      );
    });

    test('returns null for a NIP-46 signer callback', () {
      expect(
        customSchemeToRouterPath(
          Uri.parse(
            'divine://nostrconnect?x-source=aegis&relay=wss://localrelay.link:28443',
          ),
        ),
        isNull,
      );
    });

    test('returns null for an unlisted app route', () {
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///settings')),
        isNull,
      );
    });

    // Parity with the served AASA claim set: the custom scheme reaches
    // exactly what a web page can already reach over https (#6733).
    test('maps the universal-link claim paths to their routes', () {
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///video/abc123')),
        equals(VideoDetailScreen.pathForId('abc123')),
      );
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///profile/npub1abc123')),
        equals(ProfileScreenRouter.pathForNpub('npub1abc123')),
      );
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///hashtag/vines')),
        equals(HashtagScreenRouter.pathForTag('vines')),
      );
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///list/my-vines')),
        isNotNull,
      );
    });

    test('rewrites /search/* to the internal search-results route', () {
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///search/music')),
        equals(
          SearchResultsPage.pathForQuery('music', requestFocusOnMount: false),
        ),
      );
    });

    // The issue's own repro (#6733): the likers screen had to be reached by
    // long-press because the deep link would not route. DeepLinkService has
    // no DeepLinkType for it, so it resolves by path passthrough.
    test('passes deeper paths under a claimed prefix through verbatim', () {
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///video/abc123/likers')),
        equals('/video/abc123/likers'),
      );
    });

    test('preserves the query string on a passthrough path', () {
      expect(
        customSchemeToRouterPath(
          Uri.parse('divine:///video/abc123/likers?a=34236%3Apk%3Ad'),
        ),
        contains('a=34236'),
      );
    });

    test('returns null for a bare claimed prefix naming no destination', () {
      expect(customSchemeToRouterPath(Uri.parse('divine:///video')), isNull);
    });

    test('returns null for the authority form of a claimed prefix', () {
      // Only the authority-less form addresses routes; `video` in the
      // authority is an unrecognised callback host, not a path segment.
      expect(
        customSchemeToRouterPath(Uri.parse('divine://video/abc123')),
        isNull,
      );
    });

    test('returns null for a divine.video universal link', () {
      expect(
        customSchemeToRouterPath(
          Uri.parse('https://divine.video/video/abc123'),
        ),
        isNull,
      );
    });
  });
}
