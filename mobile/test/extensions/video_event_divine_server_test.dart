// ABOUTME: Tests for isFromDivineServer detection logic
// ABOUTME: Verifies all Divine subdomains are recognized as first-party

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoEvent _createVideoWithUrl(
  String url, {
  Map<String, String>? rawTags,
  List<List<String>>? tags,
}) {
  final eventTags =
      tags ??
      <List<String>>[
        ['url', url],
        for (final entry in (rawTags ?? const <String, String>{}).entries)
          [entry.key, entry.value],
      ];
  final event = Event.fromJson({
    'id': 'aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
    'pubkey':
        'bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
    'created_at': 1234567890,
    'kind': 34236,
    'content': '',
    'tags': eventTags,
    'sig': 'cccc1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
  });
  return VideoEvent.fromNostrEvent(event);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    bandwidthTracker.clearSamples();
    await bandwidthTracker.setQualityOverride(null);
  });

  group('isFromDivineServer', () {
    test('returns true for cdn.divine.video', () {
      final video = _createVideoWithUrl(
        'https://cdn.divine.video/abc123/video.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for stream.divine.video', () {
      final video = _createVideoWithUrl(
        'https://stream.divine.video/abc123/playlist.m3u8',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for media.divine.video', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/abc123.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for blossom.divine.video', () {
      final video = _createVideoWithUrl(
        'https://blossom.divine.video/'
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for bare divine.video domain', () {
      final video = _createVideoWithUrl('https://divine.video/video.mp4');
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns false for external hosts', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/abc123.mp4',
      );
      expect(video.isFromDivineServer, isFalse);
    });

    test('returns false for other video hosts', () {
      final video = _createVideoWithUrl('https://nostr.build/video/abc123.mp4');
      expect(video.isFromDivineServer, isFalse);
    });

    test(
      'returns false for hosts that only contain divine.video in the URL',
      () {
        final video = _createVideoWithUrl(
          'https://notdivine.video.evil.com/video.mp4',
        );
        expect(video.isFromDivineServer, isFalse);
      },
    );
  });

  group('shouldShowNotDivineBadge', () {
    test('returns false for divine-hosted video', () {
      final video = _createVideoWithUrl(
        'https://cdn.divine.video/abc123/video.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns false for blossom.divine.video-hosted video', () {
      final video = _createVideoWithUrl(
        'https://blossom.divine.video/'
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns true for externally hosted video', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/abc123.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isTrue);
    });

    test('returns false for an archive Vine funnelcake verifies', () {
      final video = _createVideoWithUrl(
        'https://example.com/video.mp4',
      ).copyWith(rawTags: const {'platform': 'vine'}, isVerifiedArchive: true);
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns false for a tagged Vine funnelcake could not check', () {
      final video = _createVideoWithUrl('https://example.com/video.mp4')
          .copyWith(
            rawTags: const {'platform': 'vine'},
            isArchiveVerificationUnknown: true,
          );
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns true for an external video with only a self-applied '
        'platform=vine tag', () {
      final event = Event.fromJson({
        'id':
            'aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        'pubkey':
            'bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        'created_at': 1473050841,
        'kind': 34236,
        'content': '',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['loops', '10000'],
          ['platform', 'vine'],
        ],
        'sig':
            'cccc1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      });
      final video = VideoEvent.fromNostrEvent(event);
      expect(video.isOriginalVine, isTrue);
      expect(video.shouldShowNotDivineBadge, isTrue);
    });
  });

  group('getOptimalVideoUrlForPlatform', () {
    test('returns MP4 720p for Divine-hosted videos by default', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('uses MP4 720p for bare media.divine.video blob URLs', () {
      const hash =
          '191679cbbeea3e4e3539d46b558e66fbadb673733af1ada0161a6e8b1cf61bea';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('uses MP4 720p even when imeta only advertises the raw blob', () {
      const hash =
          'e770667c1a62cc394602fc07462fa0d7ba83441002d9aac662fb88d0cc575338';
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash',
        tags: const [
          [
            'imeta',
            'url https://media.divine.video/$hash',
            'm video/mp4',
            'x $hash',
          ],
        ],
      );

      // A raw-only imeta is a publish-time snapshot; the 720p.mp4 usually
      // exists by playback time, and the runtime chain falls back to the raw
      // blob when it does not.
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('keeps MP4 720p when imeta advertises processed variants', () {
      const hash =
          'e770667c1a62cc394602fc07462fa0d7ba83441002d9aac662fb88d0cc575338';
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash',
        tags: const [
          [
            'imeta',
            'url',
            'https://media.divine.video/$hash/720p.mp4',
            'url',
            'https://media.divine.video/$hash',
            'm',
            'video/mp4',
            'x',
            hash,
          ],
        ],
      );

      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('returns original URL for non-Divine videos', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/test/video.mp4',
      );

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://blossom.primal.net/test/video.mp4'),
      );
    });
  });

  group('getOptimalVideoUrlForPlatform developer override', () {
    // videoFormatPreference is a process-global singleton; reset it after each
    // test so the forced format does not leak into other suites.
    tearDown(() => videoFormatPreference.setFormat(null));

    test(
      'raw override wins over the default MP4 for a raw-only upload',
      () async {
        const hash =
            'e770667c1a62cc394602fc07462fa0d7ba83441002d9aac662fb88d0cc575338';
        final video = _createVideoWithUrl(
          'https://media.divine.video/$hash',
          tags: const [
            [
              'imeta',
              'url https://media.divine.video/$hash',
              'm video/mp4',
              'x $hash',
            ],
          ],
        );
        // Default (no override) would be 720p.mp4; the override must force raw.
        expect(
          video.getOptimalVideoUrlForPlatform(),
          equals('https://media.divine.video/$hash/720p.mp4'),
        );

        await videoFormatPreference.setFormat(VideoPlaybackFormat.raw);

        expect(
          video.getOptimalVideoUrlForPlatform(),
          equals('https://media.divine.video/$hash'),
        );
      },
    );

    test('mp4_480p override applies to classic Vine originals', () async {
      const hash =
          'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d';
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash',
        rawTags: const {'platform': 'vine'},
      );
      expect(video.isOriginalVine, isTrue);

      await videoFormatPreference.setFormat(VideoPlaybackFormat.mp4_480p);

      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/480p.mp4'),
      );
    });
  });

  group('hash-only Divine media URLs', () {
    const hash =
        'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d';

    test('returns MP4 cache URL for Divine videos', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    // Prefer the smaller faststart derivative for classic Vine originals too;
    // the playback ladder retains the bare blob only as its final fallback.
    test('uses MP4 720p for classic Vine originals', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash',
        rawTags: const {'platform': 'vine'},
      );

      expect(video.isOriginalVine, isTrue);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('skips single-file caching for classic Vine originals', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash',
        rawTags: const {'platform': 'vine'},
      );

      expect(video.isOriginalVine, isTrue);
      expect(video.getCacheableVideoUrlForPlatform(), isNull);
    });

    test('uses MP4 720p for all Divine hosts including cdn.divine.video', () {
      final video = _createVideoWithUrl('https://cdn.divine.video/$hash');

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });
  });

  group('previewPlaybackSources', () {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('keeps the bare blob last for extensionless Divine URLs', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(
        video.previewPlaybackSources,
        equals([
          'https://media.divine.video/$hash/720p.mp4',
          'https://media.divine.video/$hash/hls/master.m3u8',
          'https://media.divine.video/$hash',
        ]),
      );
    });

    test('falls back to HLS after the raw blob when raw playback is '
        'forced', () async {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      await videoFormatPreference.setFormat(VideoPlaybackFormat.raw);
      addTearDown(() => videoFormatPreference.setFormat(null));

      expect(
        video.previewPlaybackSources,
        equals([
          'https://media.divine.video/$hash',
          'https://media.divine.video/$hash/hls/master.m3u8',
        ]),
      );
    });

    test('offers the HLS rung as a master playlist, not a media playlist', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      // A media playlist (stream_720p.m3u8) carries no #EXT-X-STREAM-INF, so
      // anything that parses variants out of it resolves to nothing. The
      // master is the rung the feed uses and the one the native player takes.
      expect(
        video.previewPlaybackSources[1],
        endsWith('/hls/master.m3u8'),
      );
    });

    test('leaves non-Divine videos with their single original source', () {
      final video = _createVideoWithUrl('https://example.com/video.mp4');

      expect(
        video.previewPlaybackSources,
        equals(['https://example.com/video.mp4']),
      );
    });
  });
}
