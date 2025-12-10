// ABOUTME: Test for DivineFilter - validates extended filter JSON serialization
// ABOUTME: Covers sort, int# filters, cursor, and factory constructors

// No need for const constructors in tests
// ignore_for_file: prefer_const_constructors

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('DivineFilter', () {
    group('JSON Serialization', () {
      test('includes sort configuration in JSON', () {
        final filter = DivineFilter(
          baseFilter: Filter(kinds: [34236], limit: 50),
          sort: SortConfig(field: 'loop_count'),
        );

        final json = filter.toJson();

        expect(json['kinds'], [34236]);
        expect(json['limit'], 50);
        expect(json['sort'], {'field': 'loop_count', 'dir': 'desc'});
      });

      test('includes int# filters in JSON', () {
        final filter = DivineFilter(
          baseFilter: Filter(kinds: [34236]),
          intFilters: {
            'loop_count': IntRangeFilter(gte: 1000),
            'likes': IntRangeFilter(gte: 50, lte: 500),
          },
        );

        final json = filter.toJson();

        expect(json['int#loop_count'], {'gte': 1000});
        expect(json['int#likes'], {'gte': 50, 'lte': 500});
      });

      test('includes cursor for pagination', () {
        final filter = DivineFilter(
          baseFilter: Filter(kinds: [34236]),
          cursor: 'base64encodedcursor==',
        );

        final json = filter.toJson();

        expect(json['cursor'], 'base64encodedcursor==');
      });

      test('combines all extensions with base filter', () {
        final filter = DivineFilter(
          baseFilter: Filter(
            kinds: [34236],
            authors: ['pubkey123'],
            limit: 100,
          ),
          sort: SortConfig(field: 'likes', direction: SortDirection.asc),
          intFilters: {'views': IntRangeFilter(gte: 500)},
          cursor: 'pagination_cursor',
        );

        final json = filter.toJson();

        expect(json['kinds'], [34236]);
        expect(json['authors'], ['pubkey123']);
        expect(json['limit'], 100);
        expect(json['sort'], {'field': 'likes', 'dir': 'asc'});
        expect(json['int#views'], {'gte': 500});
        expect(json['cursor'], 'pagination_cursor');
      });

      test('omits extensions when not provided', () {
        final filter = DivineFilter(baseFilter: Filter(kinds: [34236]));

        final json = filter.toJson();

        expect(json.containsKey('sort'), false);
        expect(json.containsKey('cursor'), false);
        expect(json.keys.any((k) => k.startsWith('int#')), false);
      });
    });

    group('IntRangeFilter', () {
      test('supports all range operators', () {
        final filter = IntRangeFilter(gte: 10, lte: 100, gt: 5, lt: 105);

        final json = filter.toJson();

        expect(json['gte'], 10);
        expect(json['lte'], 100);
        expect(json['gt'], 5);
        expect(json['lt'], 105);
      });

      test('omits null operators', () {
        final filter = IntRangeFilter(gte: 100);

        final json = filter.toJson();

        expect(json['gte'], 100);
        expect(json.containsKey('lte'), false);
        expect(json.containsKey('gt'), false);
        expect(json.containsKey('lt'), false);
      });
    });

    group('SortConfig', () {
      test('defaults to descending direction', () {
        final sort = SortConfig(field: 'loop_count');

        final json = sort.toJson();

        expect(json['field'], 'loop_count');
        expect(json['dir'], 'desc');
      });

      test('supports ascending direction', () {
        final sort = SortConfig(
          field: 'created_at',
          direction: SortDirection.asc,
        );

        final json = sort.toJson();

        expect(json['field'], 'created_at');
        expect(json['dir'], 'asc');
      });
    });

    group('withCursor', () {
      test('creates copy with updated cursor', () {
        final original = DivineFilter(
          baseFilter: Filter(kinds: [34236]),
          sort: SortConfig(field: 'loop_count'),
          intFilters: {'likes': IntRangeFilter(gte: 50)},
        );

        final withCursor = original.withCursor('new_cursor_value');

        // Original unchanged
        expect(original.cursor, null);

        // New instance has cursor
        expect(withCursor.cursor, 'new_cursor_value');
        expect(withCursor.sort!.field, 'loop_count');
        expect(withCursor.intFilters!['likes']!.gte, 50);
      });
    });

    group('Factory Constructors', () {
      test('trending creates loop_count sorted filter', () {
        final filter = DivineFilter.trending(
          baseFilter: Filter(kinds: [34236], limit: 50),
        );

        final json = filter.toJson();

        expect(json['sort'], {'field': 'loop_count', 'dir': 'desc'});
      });

      test('trending with minLoops adds int# filter', () {
        final filter = DivineFilter.trending(
          baseFilter: Filter(kinds: [34236]),
          minLoops: 1000,
        );

        final json = filter.toJson();

        expect(json['sort']['field'], 'loop_count');
        expect(json['int#loop_count'], {'gte': 1000});
      });

      test('mostLiked creates likes sorted filter', () {
        final filter = DivineFilter.mostLiked(
          baseFilter: Filter(kinds: [34236]),
        );

        final json = filter.toJson();

        expect(json['sort'], {'field': 'likes', 'dir': 'desc'});
      });

      test('mostLiked with minLikes adds int# filter', () {
        final filter = DivineFilter.mostLiked(
          baseFilter: Filter(kinds: [34236]),
          minLikes: 100,
        );

        final json = filter.toJson();

        expect(json['sort']['field'], 'likes');
        expect(json['int#likes'], {'gte': 100});
      });

      test('mostViewed creates views sorted filter', () {
        final filter = DivineFilter.mostViewed(
          baseFilter: Filter(kinds: [34236]),
        );

        final json = filter.toJson();

        expect(json['sort'], {'field': 'views', 'dir': 'desc'});
      });

      test('mostViewed with minViews adds int# filter', () {
        final filter = DivineFilter.mostViewed(
          baseFilter: Filter(kinds: [34236]),
          minViews: 500,
        );

        final json = filter.toJson();

        expect(json['sort']['field'], 'views');
        expect(json['int#views'], {'gte': 500});
      });

      test('newest creates created_at sorted filter', () {
        final filter = DivineFilter.newest(baseFilter: Filter(kinds: [34236]));

        final json = filter.toJson();

        expect(json['sort'], {'field': 'created_at', 'dir': 'desc'});
      });
    });

    group('Real World Examples', () {
      test('trending feed with author and hashtag filters', () {
        final filter = DivineFilter.trending(
          baseFilter: Filter(
            kinds: [34236],
            authors: ['pubkey1', 'pubkey2'],
            t: ['music', 'dance'],
            limit: 50,
          ),
          minLoops: 500,
        );

        final json = filter.toJson();

        expect(json['kinds'], [34236]);
        expect(json['authors'], ['pubkey1', 'pubkey2']);
        expect(json['#t'], ['music', 'dance']); // Hashtags serialize as #t
        expect(json['limit'], 50);
        expect(json['sort']['field'], 'loop_count');
        expect(json['int#loop_count'], {'gte': 500});
      });

      test('popular hashtag videos', () {
        final filter = DivineFilter(
          baseFilter: Filter(kinds: [34236], t: ['comedy'], limit: 20),
          sort: SortConfig(field: 'likes'),
          intFilters: {
            'likes': IntRangeFilter(gte: 50),
            'loop_count': IntRangeFilter(gte: 1000),
          },
        );

        final json = filter.toJson();

        expect(json['#t'], ['comedy']); // Hashtags serialize as #t
        expect(json['sort']['field'], 'likes');
        expect(json['int#likes'], {'gte': 50});
        expect(json['int#loop_count'], {'gte': 1000});
      });

      test('pagination with cursor', () {
        final firstPage = DivineFilter.trending(
          baseFilter: Filter(kinds: [34236], limit: 20),
        );

        final firstPageJson = firstPage.toJson();
        expect(firstPageJson.containsKey('cursor'), false);

        // Simulate receiving cursor from EOSE
        final secondPage = firstPage.withCursor('cursor_from_relay');

        final secondPageJson = secondPage.toJson();
        expect(secondPageJson['cursor'], 'cursor_from_relay');
        expect(secondPageJson['sort']['field'], 'loop_count');
      });
    });
  });
}
