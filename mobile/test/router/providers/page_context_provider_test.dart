// ABOUTME: Tests the route predicate that decides whether the user is
// ABOUTME: standing on their own profile.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

const _ownHex =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherHex =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final String _npub = NostrKeyUtils.encodePubKey(_ownHex);
final String _otherNpub = NostrKeyUtils.encodePubKey(_otherHex);

/// Encoded rather than pasted: a bech32 literal that does not decode would
/// make the negative cases pass because normalization returned null, not
/// because the comparison rejected a different identity.
final String _ownNprofile = NIP19Tlv.encodeNprofile(
  Nprofile(pubkey: _ownHex, relays: const ['wss://relay.divine.video']),
);

void main() {
  group('isOwnProfileLocation', () {
    test('is true on the profile grid', () {
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub(_npub), _ownHex),
        isTrue,
      );
    });

    test('is true on the profile feed at an index', () {
      // Tapping a thumbnail pushes /profile/<npub>/<index>; the user is
      // still standing on their own profile.
      expect(
        isOwnProfileLocation(RoutePaths.profileForIndex(_npub, 3), _ownHex),
        isTrue,
      );
    });

    test("is false on someone else's profile", () {
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub(_otherNpub), _ownHex),
        isFalse,
      );
    });

    test('is false on the home feed', () {
      expect(
        isOwnProfileLocation(RoutePaths.videoFeedForIndex(0), _ownHex),
        isFalse,
      );
    });

    test('is true on a deep link that names the profile in hex', () {
      // A `:npub` segment may be npub, nprofile, or bare hex. String-matching
      // the segment against the signed-in identity reports a deep link to
      // your own profile as somebody else's.
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub(_ownHex), _ownHex),
        isTrue,
      );
    });

    test("is true on the relative 'me' route", () {
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub('me'), _ownHex),
        isTrue,
      );
    });

    test('is false on an unknown location', () {
      // parseRoute falls back to home for anything it cannot model, which
      // must not read as "on my profile".
      expect(isOwnProfileLocation('/definitely-not-a-route', _ownHex), isFalse);
    });

    test('ignores a query string on the profile location', () {
      expect(
        isOwnProfileLocation(
          '${RoutePaths.profileForNpub(_npub)}?tab=likes',
          _ownHex,
        ),
        isTrue,
      );
    });
  });

  group('isOwnProfileGridRoute', () {
    // `/profile/<hex>` is a documented deep-link form
    // (DEEP_LINK_URL_REFERENCE.md), and nothing normalizes the segment on the
    // way in — the app itself only ever emits npub, so the other encodings
    // arrive from shared links and are never dogfooded.
    test('matches the signed-in user by npub', () {
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _npub),
          _ownHex,
        ),
        isTrue,
      );
    });

    test('matches a bare-hex deep link', () {
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.profile, npub: _ownHex),
          _ownHex,
        ),
        isTrue,
      );
    });

    test('matches an uppercase-hex deep link', () {
      // The hex validator is case-insensitive, so an uppercase segment is a
      // valid route that must not read as a different identity.
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _ownHex.toUpperCase()),
          _ownHex,
        ),
        isTrue,
      );
    });

    test('matches an nprofile deep link', () {
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _ownNprofile),
          _ownHex,
        ),
        isTrue,
      );
    });

    test("matches the relative 'me' route", () {
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.profile, npub: 'me'),
          _ownHex,
        ),
        isTrue,
      );
    });

    test("matches 'me' before the signed-in pubkey resolves", () {
      // 'me' names the own-profile route structurally. Gating it on a
      // resolved pubkey would flash a stranger's chrome during cold start.
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.profile, npub: 'me'),
          null,
        ),
        isTrue,
      );
    });

    test("does not match another user's npub", () {
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _otherNpub),
          _ownHex,
        ),
        isFalse,
      );
    });

    test("does not match another user's bare hex", () {
      // The widening direction: normalizing the segment must not make every
      // hex link read as yours. _otherHex is a real, decodable identity, so
      // this fails for the right reason rather than because it did not decode.
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.profile, npub: _otherHex),
          _ownHex,
        ),
        isFalse,
      );
    });

    test('does not match your own profile in video mode', () {
      // Index 0 is a real route, and video mode keeps the shell's app bar
      // even on your own profile.
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _npub, videoIndex: 0),
          _ownHex,
        ),
        isFalse,
      );
    });

    test('does not match a non-profile route', () {
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.home, videoIndex: 0),
          _ownHex,
        ),
        isFalse,
      );
    });

    test('does not match before the route context resolves', () {
      expect(isOwnProfileGridRoute(null, _ownHex), isFalse);
    });

    test('does not match an undecodable segment', () {
      expect(
        isOwnProfileGridRoute(
          const RouteContext(type: RouteType.profile, npub: 'not-an-npub'),
          _ownHex,
        ),
        isFalse,
      );
    });

    test('does not match a real npub when nobody is signed in', () {
      expect(
        isOwnProfileGridRoute(
          RouteContext(type: RouteType.profile, npub: _npub),
          null,
        ),
        isFalse,
      );
    });
  });
}
