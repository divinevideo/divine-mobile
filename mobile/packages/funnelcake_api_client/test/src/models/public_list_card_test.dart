import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _member =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

void main() {
  group(PublicListKind, () {
    test('carries the Nostr kind of each list type', () {
      expect(PublicListKind.people.value, 30000);
      expect(PublicListKind.videos.value, 30005);
    });
  });

  group(PublicListCard, () {
    group('fromJson', () {
      test('reads a video list card as production sends it', () {
        final card = PublicListCard.fromJson(const {
          'kind': 30005,
          'pubkey': _owner,
          'd_tag': 'music',
          'title': 'Music',
          'description': 'Songs I like',
          'item_count': 12,
          'member_count': 0,
          'video_count': 0,
          'loop_sum': 535,
          'members': <Object>[],
          'thumbnails': ['https://cdn.divine.video/a.jpg', 7],
          'updated_at': 1764330677,
        });

        expect(card.kind, 30005);
        expect(card.pubkey, _owner);
        expect(card.dTag, 'music');
        expect(card.title, 'Music');
        expect(card.description, 'Songs I like');
        expect(card.itemCount, 12);
        expect(card.loopSum, 535);
        expect(card.members, isEmpty);
        expect(card.thumbnails, ['https://cdn.divine.video/a.jpg']);
        expect(
          card.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1764330677000, isUtc: true),
        );
      });

      test('reads a people list card with its member preview', () {
        final card = PublicListCard.fromJson(const {
          'kind': 30000,
          'pubkey': _owner,
          'd_tag': 'friends',
          'title': 'Friends',
          'item_count': 32,
          'member_count': 32,
          'video_count': 51,
          'members': [_member],
          'updated_at': '2026-11-13T06:11:45Z',
        });

        expect(card.memberCount, 32);
        expect(card.videoCount, 51);
        expect(card.members, [_member]);
        expect(card.updatedAt, DateTime.utc(2026, 11, 13, 6, 11, 45));
      });

      test('falls back to empty values for missing optional fields', () {
        final card = PublicListCard.fromJson(const {
          'kind': 30005,
          'pubkey': _owner,
          'd_tag': 'bare',
          'updated_at': 'not a date',
        });

        expect(card.title, isEmpty);
        expect(card.description, isEmpty);
        expect(card.itemCount, 0);
        expect(card.memberCount, 0);
        expect(card.thumbnails, isEmpty);
        expect(
          card.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      });

      test('throws a FormatException for a card it cannot address', () {
        expect(
          () =>
              PublicListCard.fromJson(const {'kind': 30005, 'pubkey': _owner}),
          throwsFormatException,
        );
      });
    });
  });

  group(ListSearchResponse, () {
    group('fromJson', () {
      test('keeps the server ranking and the next cursor', () {
        final response = ListSearchResponse.fromJson(const {
          'data': [
            {'kind': 30005, 'pubkey': _owner, 'd_tag': 'best'},
            {'kind': 30005, 'pubkey': _owner, 'd_tag': 'next'},
          ],
          'pagination': {'next_cursor': 'o:2', 'has_more': true},
        });

        expect(response.cards.map((card) => card.dTag), ['best', 'next']);
        expect(response.nextCursor, 'o:2');
        expect(response.hasMore, isTrue);
      });

      test('ends the results when the server has no more', () {
        final response = ListSearchResponse.fromJson(const {
          'data': <Object>[],
          'pagination': {'next_cursor': null, 'has_more': false},
        });

        expect(response.nextCursor, isNull);
        expect(response.hasMore, isFalse);
      });

      test('skips cards it cannot read and keeps the rest', () {
        final response = ListSearchResponse.fromJson(const {
          'data': [
            'not a card',
            {'kind': 30005, 'pubkey': _owner},
            {'kind': 30005, 'pubkey': _owner, 'd_tag': 'kept'},
          ],
        });

        expect(response.cards.single.dTag, 'kept');
        expect(response.hasMore, isFalse);
      });

      test('throws a FormatException without a data list', () {
        expect(
          () => ListSearchResponse.fromJson(const {'data': 'nope'}),
          throwsFormatException,
        );
      });
    });
  });
}
