import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:models/models.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _raw = 'https://media.divine.video/$_hash';
const _mp4 = '$_raw/720p.mp4';
const _hls = '$_raw/hls/master.m3u8';
const _b2 = 'https://media-b2.divine.video/$_hash';

VideoEvent _video(String url) => VideoEvent(
  id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  pubkey: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2026),
  videoUrl: url,
);

List<String> _resolve(VideoEvent video, {bool enabled = true}) =>
    resolvePlaybackSources(
      video,
      urlResolver: (video) => _mp4,
      preferB2Original: enabled,
    );

void main() {
  group('B2 original playback sources', () {
    test('OFF retains the canonical ladder', () {
      expect(_resolve(_video(_raw), enabled: false), [_mp4, _hls, _raw]);
    });
    test('ON attempts the B2 original before every canonical rendition', () {
      final video = _video(_raw);
      expect(_resolve(video), [_b2, _mp4, _hls, _raw]);
      expect(video.videoUrl, _raw);
    });
    for (final host in [
      'media.divine.video',
      'cdn.divine.video',
      'blossom.divine.video',
    ]) {
      test('accepts original blobs on $host', () {
        expect(_resolve(_video('https://$host/$_hash')).first, _b2);
      });
    }
    for (final url in [
      'https://example.com/$_hash',
      'https://media.divine.video.evil.test/$_hash',
      'https://notdivine.video/$_hash',
      'https://unknown.divine.video/$_hash',
      'http://media.divine.video/$_hash',
      'https://media.divine.video:444/$_hash',
      'https://user:password@media.divine.video/$_hash',
      'https://media.divine.video/$_hash?token=synthetic',
      'https://media.divine.video/$_hash#fragment',
      'https://media.divine.video/$_hash/720p.mp4',
      'https://media.divine.video/$_hash/hls/master.m3u8',
      'https://media.divine.video/$_hash/',
      'https://media.divine.video/%61${_hash.substring(1)}',
      'https://media.divine.video/not-a-hash',
    ]) {
      test('does not opt in $url', () {
        expect(_resolve(_video(url)), isNot(contains(_b2)));
      });
    }
  });
}
