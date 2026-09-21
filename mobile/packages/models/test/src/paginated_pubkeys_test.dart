import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(PaginatedPubkeys, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const result = PaginatedPubkeys(pubkeys: ['abc', 'def']);

        expect(result.pubkeys, equals(['abc', 'def']));
        expect(result.total, equals(0));
        expect(result.hasMore, isFalse);
      });

      test('creates instance with all fields', () {
        const result = PaginatedPubkeys(
          pubkeys: ['abc'],
          total: 100,
          hasMore: true,
        );

        expect(result.pubkeys, hasLength(1));
        expect(result.total, equals(100));
        expect(result.hasMore, isTrue);
      });
    });

    group('empty', () {
      test('has no pubkeys and defaults', () {
        expect(PaginatedPubkeys.empty.pubkeys, isEmpty);
        expect(PaginatedPubkeys.empty.total, equals(0));
        expect(PaginatedPubkeys.empty.hasMore, isFalse);
      });
    });

    group('fromJson', () {
      test('parses followers key', () {
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['abc', 'def'],
          'total': 50,
          'has_more': true,
        });

        expect(result.pubkeys, equals(['abc', 'def']));
        expect(result.total, equals(50));
        expect(result.hasMore, isTrue);
      });

      test('parses following key', () {
        final result = PaginatedPubkeys.fromJson(const {
          'following': ['abc'],
          'total': 10,
          'has_more': false,
        });

        expect(result.pubkeys, equals(['abc']));
        expect(result.total, equals(10));
        expect(result.hasMore, isFalse);
      });

      test('parses pubkeys key as fallback', () {
        final result = PaginatedPubkeys.fromJson(const {
          'pubkeys': ['xyz'],
          'total': 1,
        });

        expect(result.pubkeys, equals(['xyz']));
        expect(result.total, equals(1));
      });

      test('defaults total to list length when missing', () {
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['a', 'b', 'c'],
        });

        expect(result.pubkeys, hasLength(3));
        expect(result.total, equals(3));
      });

      test('handles empty JSON', () {
        final result = PaginatedPubkeys.fromJson(const <String, dynamic>{});

        expect(result.pubkeys, isEmpty);
        expect(result.total, equals(0));
        expect(result.hasMore, isFalse);
      });

      test('prioritizes following over followers', () {
        final result = PaginatedPubkeys.fromJson(const {
          'following': ['a'],
          'followers': ['b', 'c'],
        });

        expect(result.pubkeys, equals(['a']));
      });

      // Envelope shape tolerance (divine-funnelcake#238 / issue #3521)
      test('parses post-#238 {data, pagination} envelope', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['pub1', 'pub2'],
          'pagination': {'has_more': true, 'next_cursor': '50'},
        });

        expect(result.pubkeys, equals(['pub1', 'pub2']));
        expect(result.hasMore, isTrue);
        expect(result.total, equals(2));
        expect(result.nextCursor, equals('50'));
      });

      test('data key takes precedence over following in envelope', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['env1'],
          'following': ['old1'],
          'pagination': {'has_more': false},
        });

        expect(result.pubkeys, equals(['env1']));
        expect(result.hasMore, isFalse);
      });

      test('has_more from pagination sub-object', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['x'],
          'pagination': {'has_more': true},
        });

        expect(result.hasMore, isTrue);
      });

      // The engagement endpoints (/api/videos/{id}/likers, /reposters) return
      // objects rather than bare strings — issue #6021.
      test('reads the pubkey field out of object-shaped entries', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': [
            {'pubkey': 'pub1', 'created_at': 1700000000, 'event_id': 'r1'},
            {'pubkey': 'pub2', 'created_at': 1699999999, 'event_id': 'r2'},
          ],
          'pagination': {'has_more': false},
        });

        expect(result.pubkeys, equals(['pub1', 'pub2']));
        expect(result.total, equals(2));
      });

      test('drops object entries with no usable pubkey', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': [
            {'pubkey': 'pub1'},
            {'created_at': 1700000000},
            {'pubkey': ''},
            {'pubkey': 42},
          ],
        });

        expect(result.pubkeys, equals(['pub1']));
        expect(result.total, equals(1));
      });
    });

    group('equality', () {
      test('equal when same pubkeys, total, and hasMore', () {
        const a = PaginatedPubkeys(pubkeys: ['abc', 'def'], total: 2);
        const b = PaginatedPubkeys(pubkeys: ['abc', 'def'], total: 2);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when different pubkeys', () {
        const a = PaginatedPubkeys(pubkeys: ['abc']);
        const b = PaginatedPubkeys(pubkeys: ['def']);

        expect(a, isNot(equals(b)));
      });

      test('not equal when different total', () {
        const a = PaginatedPubkeys(pubkeys: ['abc'], total: 1);
        const b = PaginatedPubkeys(pubkeys: ['abc'], total: 99);

        expect(a, isNot(equals(b)));
      });
    });

    group('nextCursor', () {
      // hasMore without a cursor is a dead end: the caller knows more exists
      // and has no way to ask for it. #9358 truncated the Liked-by list at
      // 500 for exactly this reason.
      test('is retained from the pagination envelope', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['pub1'],
          'pagination': {
            'has_more': true,
            'next_cursor': 'eyJvZmZzZXQiOjUwMH0',
          },
        });

        expect(result.hasMore, isTrue);
        expect(result.nextCursor, equals('eyJvZmZzZXQiOjUwMH0'));
      });

      test('is null on the last page', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['pub1'],
          'pagination': {'has_more': false},
        });

        expect(result.hasMore, isFalse);
        expect(result.nextCursor, isNull);
      });

      test('is null on the legacy shape, which carries no cursor', () {
        final result = PaginatedPubkeys.fromJson(const {
          'following': ['pub1'],
          'has_more': true,
        });

        expect(result.hasMore, isTrue);
        expect(result.nextCursor, isNull);
      });

      test('normalises an empty cursor to null so paging cannot loop', () {
        final result = PaginatedPubkeys.fromJson(const {
          'data': ['pub1'],
          'pagination': {'has_more': true, 'next_cursor': ''},
        });

        expect(result.nextCursor, isNull);
      });

      test('distinguishes two otherwise identical pages', () {
        const a = PaginatedPubkeys(
          pubkeys: ['abc'],
          hasMore: true,
          nextCursor: 'c1',
        );
        const b = PaginatedPubkeys(
          pubkeys: ['abc'],
          hasMore: true,
          nextCursor: 'c2',
        );

        expect(a, isNot(equals(b)));
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });

    group('appliedQuery', () {
      test('reads the echoed filter from the response', () {
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['abc'],
          'total': 1,
          'query': 'ali',
        });

        expect(result.appliedQuery, equals('ali'));
      });

      test('is null when the server reports no filter', () {
        // Also the shape an older deployment returns: it ignores the unknown
        // `q` key and answers with the plain page.
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['abc'],
          'total': 1,
        });

        expect(result.appliedQuery, isNull);
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const result = PaginatedPubkeys(
          pubkeys: ['abc', 'def'],
          total: 50,
          hasMore: true,
          nextCursor: 'c1',
        );

        expect(
          result.toString(),
          equals(
            'PaginatedPubkeys(count: 2, '
            'total: 50, hasMore: true, nextCursor: c1, appliedQuery: null)',
          ),
        );
      });

      test('shows the applied query so an ignored filter is diagnosable', () {
        const result = PaginatedPubkeys(pubkeys: ['abc'], appliedQuery: 'ali');

        expect(result.toString(), contains('appliedQuery: ali'));
      });
    });
  });
}
