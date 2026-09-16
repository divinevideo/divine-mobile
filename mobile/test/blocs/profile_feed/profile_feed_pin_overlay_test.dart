// ABOUTME: Tests for overlayPinnedVideos — stored pin order, out-of-window
// ABOUTME: resolution, and exact-coordinate matching.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_pin_overlay.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video(String id, {String? dTag}) => VideoEvent(
  id: id,
  pubkey: _author,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://example.com/$id.mp4',
  addressableDTag: dTag,
);

String _coordinate(String dTag) => '34236:$_author:$dTag';

void main() {
  group('overlayPinnedVideos', () {
    test('leads with the pins in stored order, then the rest of the base in '
        'its own order', () {
      final base = [
        _video('a', dTag: 'a'),
        _video('b', dTag: 'b'),
        _video('c', dTag: 'c'),
        _video('d', dTag: 'd'),
      ];

      final result = overlayPinnedVideos(
        base: base,
        pinnedCoordinates: [_coordinate('c'), _coordinate('a')],
        resolved: const {},
      );

      expect(result.map((v) => v.id), ['c', 'a', 'b', 'd']);
    });

    test('falls back to a separately resolved video, and prefers the base '
        'copy when both exist', () {
      final baseCopy = _video('b-base', dTag: 'b');
      final resolvedCopy = _video('b-resolved', dTag: 'b');
      final old = _video('old', dTag: 'old');

      final result = overlayPinnedVideos(
        base: [
          _video('a', dTag: 'a'),
          baseCopy,
        ],
        pinnedCoordinates: [_coordinate('old'), _coordinate('b')],
        resolved: {_coordinate('old'): old, _coordinate('b'): resolvedCopy},
      );

      expect(result.map((v) => v.id), ['old', 'b-base', 'a']);
    });

    test('skips a coordinate that resolves nowhere and a duplicate entry', () {
      final result = overlayPinnedVideos(
        base: [
          _video('a', dTag: 'a'),
          _video('b', dTag: 'b'),
        ],
        pinnedCoordinates: [
          _coordinate('gone'),
          _coordinate('b'),
          _coordinate('b'),
        ],
        resolved: const {},
      );

      expect(result.map((v) => v.id), ['b', 'a']);
    });

    test('returns the base untouched when nothing is pinned or nothing '
        'resolves', () {
      final base = [_video('legacy'), _video('a', dTag: 'a')];

      expect(
        overlayPinnedVideos(
          base: base,
          pinnedCoordinates: const [],
          resolved: const {},
        ),
        same(base),
      );
      expect(
        overlayPinnedVideos(
          base: base,
          pinnedCoordinates: [_coordinate('gone')],
          resolved: const {},
        ),
        same(base),
      );
    });
  });
}
