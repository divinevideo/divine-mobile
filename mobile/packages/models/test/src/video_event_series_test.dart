// ABOUTME: Tests the series a video says it is an episode of, read from its
// ABOUTME: marked `a` tag and kept through feed snapshots and copies.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.seriesCoordinate', () {
    final author = 'a' * 64;
    final someoneElse = 'd' * 64;
    final series = '30005:$author:our-story';

    VideoEvent video(List<List<String>> tags) => VideoEvent.fromNostrEvent(
      Event(
        author,
        34236,
        [
          const ['d', 'episode-3'],
          const ['url', 'https://media.divine.video/episode-3.mp4'],
          ...tags,
        ],
        'Episode 3',
        createdAt: 1778120201,
      ),
    );

    test('reads the address on the tag marked as a series', () {
      final episode = video([
        ['a', '34236:$someoneElse:original', '', 'mention'],
        ['a', series, '', videoSeriesTagMarker],
      ]);

      expect(episode.seriesCoordinate, equals(series));
    });

    test('ignores an address that is not marked as a series', () {
      final episode = video([
        ['a', series],
        ['a', series, ''],
        ['a', series, '', 'mention'],
      ]);

      expect(episode.seriesCoordinate, isNull);
    });

    for (final (reason, coordinate) in [
      ('is not a curated list', '30000:$author:our-story'),
      ('has an uppercase pubkey', '30005:${'A' * 64}:our-story'),
      ('has a short pubkey', '30005:${'a' * 63}:our-story'),
      ('has no d-tag', '30005:$author:'),
      ('has no d-tag separator', '30005:$author'),
      ('is a list by someone else', '30005:$someoneElse:our-story'),
    ]) {
      test('ignores an address that $reason', () {
        final episode = video([
          ['a', coordinate, '', videoSeriesTagMarker],
        ]);

        expect(episode.seriesCoordinate, isNull);
      });
    }

    test('skips unusable addresses for a later usable one', () {
      final episode = video([
        ['a', '30005:$someoneElse:their-story', '', videoSeriesTagMarker],
        ['a', '30000:$author:our-story', '', videoSeriesTagMarker],
        ['a', series, '', videoSeriesTagMarker],
      ]);

      expect(episode.seriesCoordinate, equals(series));
    });

    test('keeps its series through a feed snapshot', () {
      final original = video([
        ['a', series, '', videoSeriesTagMarker],
      ]);

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.seriesCoordinate, equals(series));
    });

    test('reads the series of the tags it is copied with', () {
      final original = video([
        ['a', series, '', videoSeriesTagMarker],
      ]);

      expect(
        original.copyWith(title: 'Renamed').seriesCoordinate,
        equals(series),
      );
      expect(
        original.copyWith(nostrEventTags: const []).seriesCoordinate,
        isNull,
      );
    });

    test('keeps the series of a video without tags through a copy', () {
      final restored = VideoEvent.fromJson(
        video([
          ['a', series, '', videoSeriesTagMarker],
        ]).toJson(),
      );
      expect(restored.nostrEventTags, isEmpty);

      expect(
        restored.copyWith(title: 'Renamed').seriesCoordinate,
        equals(series),
      );
      expect(
        VideoEvent.createRepostEvent(
          originalEvent: restored,
          repostEventId: '2' * 64,
          reposterPubkey: someoneElse,
          repostedAt: DateTime.utc(2026, 11, 26),
        ).seriesCoordinate,
        equals(series),
      );
    });
  });
}
