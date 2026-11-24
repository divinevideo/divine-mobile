import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/sound_reuse_source.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _audio =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _otherAudio =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _hash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

VideoEvent _video({
  String content = 'Approved',
  String dTag = 'clip:one',
  String url = 'https://example.com/video.mp4',
  String hash = _hash,
  String? reuse,
  String? linkedAudio,
}) => VideoEvent.fromNostrEvent(
  Event.fromJson({
    'id': 'd' * 64,
    'pubkey': _owner,
    'kind': 34236,
    'created_at': 1700000000,
    'content': content,
    'sig': '',
    'tags': [
      ['d', dTag],
      ['imeta', 'url $url', 'm video/mp4', 'x $hash'],
      if (reuse != null) ['allow_audio_reuse', reuse],
      if (linkedAudio != null) ['e', linkedAudio, '', 'audio'],
    ],
  }),
);

void main() {
  group('soundReuseSourceUnchanged', () {
    test('accepts a revision that changed only unrelated metadata', () {
      expect(
        soundReuseSourceUnchanged(
          _video(),
          _video(content: 'Edited description'),
          _audio,
        ),
        isTrue,
      );
    });

    test('refuses a revision at a different address', () {
      expect(
        soundReuseSourceUnchanged(_video(), _video(dTag: 'clip:two'), _audio),
        isFalse,
      );
    });

    test('refuses a revision with a different video file', () {
      expect(
        soundReuseSourceUnchanged(
          _video(),
          _video(url: 'https://example.com/replaced.mp4'),
          _audio,
        ),
        isFalse,
      );
    });

    test('refuses a revision whose file hash changed at the same URL', () {
      expect(
        soundReuseSourceUnchanged(_video(), _video(hash: 'e' * 64), _audio),
        isFalse,
      );
    });

    test('refuses a verified archive video', () {
      expect(
        soundReuseSourceUnchanged(
          _video(),
          _video().copyWith(isVerifiedArchive: true),
          _audio,
        ),
        isFalse,
      );
    });

    test('refuses an invalid reuse marker even when it is unchanged', () {
      expect(
        soundReuseSourceUnchanged(
          _video(reuse: 'maybe'),
          _video(reuse: 'maybe'),
          _audio,
        ),
        isFalse,
      );
    });

    test('refuses a reuse choice changed after the approval', () {
      expect(
        soundReuseSourceUnchanged(_video(), _video(reuse: 'false'), _audio),
        isFalse,
      );
    });

    test('accepts a revision that already carries this approval', () {
      expect(
        soundReuseSourceUnchanged(
          _video(),
          _video(reuse: 'true', linkedAudio: _audio),
          _audio,
        ),
        isTrue,
      );
    });

    test('refuses a revision that links a different sound', () {
      expect(
        soundReuseSourceUnchanged(
          _video(),
          _video(linkedAudio: _otherAudio),
          _audio,
        ),
        isFalse,
      );
    });
  });
}
