// ABOUTME: Tests the id a sound's page opens it by: a library or Nostr sound
// ABOUTME: without the editor's track suffixes, and none for the others.

import 'package:models/models.dart';
import 'package:test/test.dart';

const _eventId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

AudioEvent _sound(String id) =>
    AudioEvent(id: id, pubkey: 'pubkey', createdAt: 0, title: 'Song');

void main() {
  group('AudioEvent.soundPageId', () {
    test("opens a library sound by its id, without a track's suffixes", () {
      expect(
        _sound('bundled_potato_flew-1793117068786').soundPageId,
        equals('bundled_potato_flew'),
      );
      expect(
        _sound('bundled_sound_2_copy_1793117068786123').soundPageId,
        equals('bundled_sound_2'),
      );
    });

    test('opens a Nostr sound by its event id', () {
      expect(_sound('$_eventId-1793117068786').soundPageId, equals(_eventId));
    });

    test('has no page id for a sound only its video carries', () {
      expect(
        [
          _sound('video_$_eventId'),
          _sound('${AudioEvent.localImportMarker}_song'),
        ].map((sound) => sound.soundPageId),
        everyElement(isNull),
      );
    });
  });
}
