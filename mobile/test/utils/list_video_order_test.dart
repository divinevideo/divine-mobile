// ABOUTME: Tests putting a curated list's resolved videos back into the
// ABOUTME: list's own order, by event id and by author and d-tag.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/list_video_order.dart';

import '../helpers/test_pubkeys.dart';

final String _author = testPubkeyFromSeed(1);
final String _other = testPubkeyFromSeed(2);
final String _eventId = 'e' * 64;

VideoEvent _video({
  required String id,
  String? pubkey,
  String? dTag,
  String? vineId,
  int? eventKind,
}) => VideoEvent(
  id: id,
  pubkey: pubkey ?? _author,
  createdAt: 1778120000,
  content: '',
  timestamp: DateTime.utc(2026, 11, 26),
  videoUrl: 'https://example.com/$id.mp4',
  vineId: vineId,
  eventKind: eventKind,
  rawTags: dTag == null ? const {} : {'d': dTag},
);

List<String> _ids(List<VideoEvent> videos) => [
  for (final video in videos) video.id,
];

void main() {
  group(ListVideoOrder, () {
    group('sort', () {
      test('puts videos in the order the list names them', () {
        final order = ListVideoOrder([
          '34236:$_author:part-1',
          _eventId,
          '34236:$_author:part-3',
        ]);

        final sorted = order.sort([
          _video(id: 'third', dTag: 'part-3'),
          _video(id: _eventId),
          _video(id: 'first', dTag: 'part-1'),
        ]);

        expect(_ids(sorted), equals(['first', _eventId, 'third']));
      });

      test('places a late video at its list position, not at the end', () {
        final order = ListVideoOrder([
          '34236:$_author:part-1',
          '34236:$_author:part-2',
          '34236:$_author:part-3',
        ]);
        final cached = [
          _video(id: 'first', dTag: 'part-1'),
          _video(id: 'third', dTag: 'part-3'),
        ];

        final sorted = order.sort([
          ...cached,
          _video(id: 'second', dTag: 'part-2'),
        ]);

        expect(_ids(sorted), equals(['first', 'second', 'third']));
      });

      test('keeps a video no reference names after the rest', () {
        final order = ListVideoOrder(['34236:$_author:part-1']);

        final sorted = order.sort([
          _video(id: 'stray', dTag: 'elsewhere'),
          _video(id: 'first', dTag: 'part-1'),
          _video(id: 'stray-2', dTag: 'also-elsewhere'),
        ]);

        expect(_ids(sorted), equals(['first', 'stray', 'stray-2']));
      });

      test('matches an event id in any case', () {
        final order = ListVideoOrder([
          '34236:$_author:part-1',
          _eventId.toUpperCase(),
        ]);

        final sorted = order.sort([
          _video(id: _eventId),
          _video(id: 'first', dTag: 'part-1'),
        ]);

        expect(_ids(sorted), equals(['first', _eventId]));
      });

      test('does not take another author video at the same d-tag', () {
        final order = ListVideoOrder([
          '34236:$_author:part-2',
          '34236:$_author:part-1',
        ]);

        final sorted = order.sort([
          _video(id: 'theirs', pubkey: _other, dTag: 'part-1'),
          _video(id: 'second', dTag: 'part-2'),
        ]);

        expect(_ids(sorted), equals(['second', 'theirs']));
      });

      test('distinguishes video kinds with the same author and d-tag', () {
        final order = ListVideoOrder([
          '34236:$_author:shared',
          '34235:$_author:shared',
        ]);
        final sorted = order.sort([
          _video(id: 'normal', dTag: 'shared', eventKind: 34235),
          _video(id: 'short', dTag: 'shared', eventKind: 34236),
        ]);

        expect(_ids(sorted), equals(['short', 'normal']));
      });
    });

    group('positionOf', () {
      test('places a video by the d-tag the cache matched it on', () {
        final order = ListVideoOrder([
          '34236:$_author:first',
          '34236:$_author:legacy-vine',
        ]);

        expect(
          order.positionOf(_video(id: 'old', vineId: 'legacy-vine')),
          equals(1),
        );
      });

      test('keeps the first position of a video the list names twice', () {
        final order = ListVideoOrder([
          '34236:$_author:part-1',
          '34236:$_author:part-2',
          '34236:$_author:part-1',
        ]);

        expect(
          order.positionOf(_video(id: 'first', dTag: 'part-1')),
          equals(0),
        );
      });

      test('reads a d-tag that holds a colon whole', () {
        final order = ListVideoOrder(['34236:$_author:part:one']);

        expect(
          order.positionOf(_video(id: 'first', dTag: 'part:one')),
          equals(0),
        );
      });

      for (final malformed in [
        '34236:$_author',
        '34236::part-1',
        '34236:$_author:',
        'invalid:$_author:part-1',
      ]) {
        test('names nothing with the malformed address $malformed', () {
          final order = ListVideoOrder([malformed]);

          expect(
            ListVideoOrder.indexOfReference(malformed, [
              _video(id: 'first', dTag: 'part-1'),
            ]),
            equals(-1),
          );
          expect(
            order.positionOf(_video(id: 'first', dTag: 'part-1')),
            isNull,
          );
        });
      }
    });
  });
}
