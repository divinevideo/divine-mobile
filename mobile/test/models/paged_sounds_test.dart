// ABOUTME: Tests for PagedSounds, the sound picker's page-by-page sound list.
// ABOUTME: Covers how a later page joins the sounds already loaded.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/paged_sounds.dart';

AudioEvent _sound(String id) => AudioEvent(
  id: id,
  pubkey: 'pubkey',
  createdAt: 1704067200,
  url: 'https://example.com/audio/$id.mp3',
);

void main() {
  group(PagedSounds, () {
    group('withPage', () {
      test('leaves out a sound an earlier page already listed', () {
        // Funnelcake pages its lists by offset, so a sound published or
        // re-ranked between two loads moves the rest down one place and
        // the next page starts with the last sound of this one.
        final list = PagedSounds.first((
          sounds: [_sound('a'), _sound('b')],
          usageCounts: const {'a': 1, 'b': 2},
          hasMore: true,
        ));

        final next = list.withPage((
          sounds: [_sound('b'), _sound('c')],
          usageCounts: const {'b': 2, 'c': 3},
          hasMore: true,
        ));

        expect(next.sounds.map((sound) => sound.id), ['a', 'b', 'c']);
        expect(next.hasMore, isTrue);
      });

      test('keeps paging after a page that only repeated sounds', () {
        final list = PagedSounds.first((
          sounds: [_sound('a')],
          usageCounts: const {'a': 1},
          hasMore: true,
        ));

        final next = list.withPage((
          sounds: [_sound('a')],
          usageCounts: const {'a': 1},
          hasMore: true,
        ));

        expect(next.sounds.map((sound) => sound.id), ['a']);
        expect(next.hasMore, isTrue);
      });
    });
  });
}
