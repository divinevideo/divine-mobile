// ABOUTME: Unit tests for search term parsing and building in route_utils
// ABOUTME: Tests parseRoute() and buildRoute() with searchTerm parameter

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('parseRoute() - Search with terms', () {
    test(
      'parseRoute("/search/nostr") returns RouteContext with searchTerm',
      () {
        final result = parseRoute('/search/nostr');

        expect(result.type, RouteType.search);
        expect(result.searchTerm, 'nostr');
        expect(result.videoIndex, null);
      },
    );

    test(
      'parseRoute("/search/bitcoin/7") returns RouteContext with term and index',
      () {
        final result = parseRoute('/search/bitcoin/7');

        expect(result.type, RouteType.search);
        expect(result.searchTerm, 'bitcoin');
        expect(result.videoIndex, 7);
      },
    );

    test(
      'parseRoute("/search") returns RouteContext with no term or index',
      () {
        final result = parseRoute('/search');

        expect(result.type, RouteType.search);
        expect(result.searchTerm, null);
        expect(result.videoIndex, null);
      },
    );

    test(
      'parseRoute("/search/5") returns legacy format (index only, no term)',
      () {
        final result = parseRoute('/search/5');

        expect(result.type, RouteType.search);
        expect(result.searchTerm, null);
        expect(result.videoIndex, 5);
      },
    );
  });

  group('buildRoute() - Search with terms', () {
    test('buildRoute with searchTerm only returns /search/bitcoin', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: 'bitcoin',
      );

      final result = buildRoute(context);

      expect(result, '/search/bitcoin');
    });

    test(
      'buildRoute with searchTerm and videoIndex returns /search/lightning/3',
      () {
        final context = RouteContext(
          type: RouteType.search,
          searchTerm: 'lightning',
          videoIndex: 3,
        );

        final result = buildRoute(context);

        expect(result, '/search/lightning/3');
      },
    );

    test('buildRoute with no term or index returns /search', () {
      final context = RouteContext(type: RouteType.search);

      final result = buildRoute(context);

      expect(result, '/search');
    });

    test('buildRoute with legacy format (index only) returns /search/5', () {
      final context = RouteContext(type: RouteType.search, videoIndex: 5);

      final result = buildRoute(context);

      expect(result, '/search/5');
    });
  });

  group('Round-trip consistency', () {
    test('parseRoute(buildRoute(context)) preserves searchTerm', () {
      final original = RouteContext(
        type: RouteType.search,
        searchTerm: 'nostr',
      );

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });

    test('parseRoute(buildRoute(context)) preserves searchTerm + index', () {
      final original = RouteContext(
        type: RouteType.search,
        searchTerm: 'bitcoin',
        videoIndex: 42,
      );

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });
  });

  group('Phase 3: URL Encoding - parseRoute() edge cases', () {
    test('parseRoute("/search/hello%20world") decodes spaces correctly', () {
      final result = parseRoute('/search/hello%20world');

      expect(result.type, RouteType.search);
      expect(result.searchTerm, 'hello world');
      expect(result.videoIndex, null);
    });

    test('parseRoute("/search/%23bitcoin") decodes hash symbol correctly', () {
      final result = parseRoute('/search/%23bitcoin');

      expect(result.type, RouteType.search);
      expect(result.searchTerm, '#bitcoin');
      expect(result.videoIndex, null);
    });

    test(
      'parseRoute("/search/%2Fspecial") decodes forward slash correctly',
      () {
        final result = parseRoute('/search/%2Fspecial');

        expect(result.type, RouteType.search);
        expect(result.searchTerm, '/special');
        expect(result.videoIndex, null);
      },
    );

    test('parseRoute("/search/%F0%9F%9A%80") decodes emoji correctly', () {
      final result = parseRoute('/search/%F0%9F%9A%80');

      expect(result.type, RouteType.search);
      expect(result.searchTerm, '🚀');
      expect(result.videoIndex, null);
    });

    test('parseRoute("/search/hello%20world/5") decodes spaces with index', () {
      final result = parseRoute('/search/hello%20world/5');

      expect(result.type, RouteType.search);
      expect(result.searchTerm, 'hello world');
      expect(result.videoIndex, 5);
    });

    test('parseRoute("/search/%23bitcoin/3") decodes hash with index', () {
      final result = parseRoute('/search/%23bitcoin/3');

      expect(result.type, RouteType.search);
      expect(result.searchTerm, '#bitcoin');
      expect(result.videoIndex, 3);
    });
  });

  group('Phase 3: URL Encoding - buildRoute() edge cases', () {
    test('buildRoute encodes spaces in search term', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: 'hello world',
      );

      final result = buildRoute(context);

      expect(result, '/search/hello%20world');
    });

    test('buildRoute encodes hash symbol in search term', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: '#bitcoin',
      );

      final result = buildRoute(context);

      expect(result, '/search/%23bitcoin');
    });

    test('buildRoute encodes forward slash in search term', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: '/special',
      );

      final result = buildRoute(context);

      expect(result, '/search/%2Fspecial');
    });

    test('buildRoute encodes emoji in search term', () {
      final context = RouteContext(type: RouteType.search, searchTerm: '🚀');

      final result = buildRoute(context);

      expect(result, '/search/%F0%9F%9A%80');
    });

    test('buildRoute encodes spaces with index', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: 'hello world',
        videoIndex: 5,
      );

      final result = buildRoute(context);

      expect(result, '/search/hello%20world/5');
    });

    test('buildRoute encodes hash symbol with index', () {
      final context = RouteContext(
        type: RouteType.search,
        searchTerm: '#bitcoin',
        videoIndex: 3,
      );

      final result = buildRoute(context);

      expect(result, '/search/%23bitcoin/3');
    });
  });

  group('Phase 3: Round-trip with URL encoding', () {
    test('Round-trip preserves search term with spaces', () {
      final original = RouteContext(
        type: RouteType.search,
        searchTerm: 'hello world',
      );

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });

    test('Round-trip preserves search term with hash symbol', () {
      final original = RouteContext(
        type: RouteType.search,
        searchTerm: '#bitcoin',
      );

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });

    test('Round-trip preserves search term with forward slash', () {
      final original = RouteContext(
        type: RouteType.search,
        searchTerm: '/special',
      );

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });

    test('Round-trip preserves search term with emoji', () {
      final original = RouteContext(type: RouteType.search, searchTerm: '🚀');

      final url = buildRoute(original);
      final parsed = parseRoute(url);

      expect(parsed.type, original.type);
      expect(parsed.searchTerm, original.searchTerm);
      expect(parsed.videoIndex, original.videoIndex);
    });

    test(
      'Round-trip preserves complex search term with multiple special chars',
      () {
        final original = RouteContext(
          type: RouteType.search,
          searchTerm: 'hello world #bitcoin 🚀',
          videoIndex: 7,
        );

        final url = buildRoute(original);
        final parsed = parseRoute(url);

        expect(parsed.type, original.type);
        expect(parsed.searchTerm, original.searchTerm);
        expect(parsed.videoIndex, original.videoIndex);
      },
    );
  });
}
