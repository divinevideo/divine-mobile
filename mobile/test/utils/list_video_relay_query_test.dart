// ABOUTME: Tests for ListVideoRelayQuery: one REQ stays within the relay's
// ABOUTME: filter cap, and shared address filters keep only what was asked.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/list_video_relay_query.dart';

final String _author = 'a' * 64;
final String _otherAuthor = 'b' * 64;
final String _eventId = 'e' * 64;

String _coordinate(int index, {String? author}) =>
    '34236:${author ?? _author}:clip-$index';

Event _video({
  required String author,
  required String dTag,
  int kind = 34236,
}) => Event(author, kind, [
  ['d', dTag],
], '');

void main() {
  group(ListVideoRelayQuery, () {
    group('filters', () {
      test('asks for eleven coordinates in one filter', () {
        final query = ListVideoRelayQuery(
          eventIds: const [],
          coordinates: [for (var i = 0; i < 11; i++) _coordinate(i)],
        );

        final filters = query.filters;

        expect(filters, hasLength(1));
        expect(filters.single.kinds, [34236]);
        expect(filters.single.authors, [_author]);
        expect(filters.single.d, hasLength(11));
      });

      test('stays within the filter cap for a list of any length', () {
        final query = ListVideoRelayQuery(
          eventIds: [_eventId],
          coordinates: [for (var i = 0; i < 1000; i++) _coordinate(i)],
        );

        final filters = query.filters;

        expect(
          filters,
          hasLength(
            lessThanOrEqualTo(ListVideoRelayQuery.maxFiltersPerRequest),
          ),
        );
        expect(filters.first.ids, [_eventId]);
        expect(
          filters.skip(1).expand((filter) => filter.d!).toSet(),
          hasLength(1000),
        );
      });

      test('splits addresses across filters once a filter is full', () {
        final query = ListVideoRelayQuery(
          eventIds: const [],
          coordinates: [
            for (var i = 0; i < ListVideoRelayQuery.addressesPerFilter + 1; i++)
              _coordinate(i),
          ],
        );

        expect(query.filters, hasLength(2));
      });

      test('leaves out a coordinate that does not parse', () {
        final query = ListVideoRelayQuery(
          eventIds: const [],
          coordinates: ['not-a-coordinate', _coordinate(1)],
        );

        expect(query.filters.single.d, ['clip-1']);
      });

      test('asks for nothing when nothing is missing', () {
        final query = ListVideoRelayQuery(
          eventIds: const [],
          coordinates: const [],
        );

        expect(query.filters, isEmpty);
      });
    });

    group('asked', () {
      final query = ListVideoRelayQuery(
        eventIds: [_eventId],
        coordinates: [
          _coordinate(1),
          _coordinate(2, author: _otherAuthor),
        ],
      );

      test('is true for a video at a requested address', () {
        expect(query.asked(_video(author: _author, dTag: 'clip-1')), isTrue);
      });

      test('is false for a video a shared filter matched under another '
          "address's d-tag", () {
        // The filter lists both authors and both d-tags, so a relay also
        // answers with the first author's video at clip-2.
        expect(query.asked(_video(author: _author, dTag: 'clip-2')), isFalse);
      });

      test('is false for the same d-tag under another kind', () {
        expect(
          query.asked(_video(author: _author, dTag: 'clip-1', kind: 34235)),
          isFalse,
        );
      });

      test('is true for an event asked for by id', () {
        final event = _video(author: _author, dTag: 'unlisted');
        final byId = ListVideoRelayQuery(
          eventIds: [event.id.toUpperCase()],
          coordinates: const [],
        );

        expect(byId.asked(event), isTrue);
      });
    });
  });
}
