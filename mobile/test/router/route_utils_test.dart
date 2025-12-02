// ABOUTME: Tests for route parsing and building utilities
// ABOUTME: Verifies route URL parsing and construction

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('parseRoute', () {
    test('parses home route with index', () {
      final result = parseRoute('/home/5');

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 5);
      expect(result.npub, isNull);
      expect(result.hashtag, isNull);
    });

    test('parses explore route with index', () {
      final result = parseRoute('/explore/3');

      expect(result.type, RouteType.explore);
      expect(result.videoIndex, 3);
    });

    test('parses profile route with npub and index', () {
      final result = parseRoute('/profile/npub1abc123/2');

      expect(result.type, RouteType.profile);
      expect(result.npub, 'npub1abc123');
      expect(result.videoIndex, 2);
    });

    test('parses hashtag route with tag and index', () {
      final result = parseRoute('/hashtag/nostr/1');

      expect(result.type, RouteType.hashtag);
      expect(result.hashtag, 'nostr');
      expect(result.videoIndex, 1);
    });

    test('parses camera route', () {
      final result = parseRoute('/camera');

      expect(result.type, RouteType.camera);
      expect(result.videoIndex, isNull);
    });

    test('parses settings route', () {
      final result = parseRoute('/settings');

      expect(result.type, RouteType.settings);
      expect(result.videoIndex, isNull);
    });

    test('defaults to home/0 for unknown route', () {
      final result = parseRoute('/unknown/path');

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 0);
    });

    test('handles missing index defaulting to 0', () {
      final result = parseRoute('/home');

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 0);
    });
  });

  group('buildRoute', () {
    test('builds home route with index', () {
      final context = RouteContext(type: RouteType.home, videoIndex: 5);

      expect(buildRoute(context), '/home/5');
    });

    test('builds explore route with index', () {
      final context = RouteContext(type: RouteType.explore, videoIndex: 3);

      expect(buildRoute(context), '/explore/3');
    });

    test('builds profile route with npub and index', () {
      final context = RouteContext(
        type: RouteType.profile,
        npub: 'npub1abc123',
        videoIndex: 2,
      );

      expect(buildRoute(context), '/profile/npub1abc123/2');
    });

    test('builds hashtag route with tag and index', () {
      final context = RouteContext(
        type: RouteType.hashtag,
        hashtag: 'nostr',
        videoIndex: 1,
      );

      expect(buildRoute(context), '/hashtag/nostr/1');
    });

    test('builds camera route', () {
      final context = RouteContext(type: RouteType.camera);

      expect(buildRoute(context), '/camera');
    });

    test('builds settings route', () {
      final context = RouteContext(type: RouteType.settings);

      expect(buildRoute(context), '/settings');
    });

    test('defaults missing index to 0 for video routes', () {
      final context = RouteContext(type: RouteType.home);

      expect(buildRoute(context), '/home/0');
    });
  });

  group('round-trip consistency', () {
    test('parse then build returns original URL', () {
      final urls = [
        '/home/5',
        '/explore/3',
        '/profile/npub1abc123/2',
        '/hashtag/nostr/1',
        '/camera',
        '/settings',
      ];

      for (final url in urls) {
        final parsed = parseRoute(url);
        final rebuilt = buildRoute(parsed);
        expect(rebuilt, url, reason: 'Failed for $url');
      }
    });
  });
}
