// ABOUTME: Tests the tappable sticker areas of a video: their event tag, which
// ABOUTME: targets a viewer may open, and where on the frame a tap lands.

import 'dart:math' as math;

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _link = VideoStickerRegion(
  kind: VideoStickerKind.link,
  target: 'https://divine.video/about',
  centerX: 0.5,
  centerY: 0.25,
  width: 0.4,
  height: 0.05,
);

void main() {
  group(VideoStickerRegion, () {
    group('toTag', () {
      test('publishes a still sticker shown the whole video', () {
        expect(
          _link.toTag(),
          equals([
            'sticker',
            'link',
            'https://divine.video/about',
            '0.5 0.25 0.4 0.05',
            '0',
          ]),
        );
      });

      test('publishes its turn in degrees and its window in ms', () {
        const region = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.12346,
          centerY: 0.5,
          width: 0.3,
          height: 0.1,
          rotation: -math.pi / 12,
          start: Duration(milliseconds: 1500),
          end: Duration(milliseconds: 4200),
        );

        expect(
          region.toTag(),
          equals([
            'sticker',
            'hashtag',
            'summer',
            '0.1235 0.5 0.3 0.1',
            '-15',
            '1500',
            '4200',
          ]),
        );
      });
    });

    group('fromTag', () {
      test('publishes the look and text after the window', () {
        const region = VideoStickerRegion(
          kind: VideoStickerKind.mention,
          target: _pubkey,
          centerX: 0.5,
          centerY: 0.5,
          width: 0.2,
          height: 0.1,
          style: 'dark',
          label: 'alice',
        );

        expect(
          region.toTag(),
          equals([
            'sticker',
            'mention',
            _pubkey,
            '0.5 0.5 0.2 0.1',
            '0',
            '',
            '',
            'dark',
            'alice',
          ]),
        );
        expect(VideoStickerRegion.fromTag(region.toTag()), equals(region));
      });

      test("reads a sound sticker, which opens the video's own sound", () {
        final region = VideoStickerRegion.fromTag([
          'sticker',
          'sound',
          '',
          '0.5 0.5 0.3 0.1',
          '0',
          '',
          '',
          'light',
          'Song\nArtist',
        ]);

        expect(region?.kind, equals(VideoStickerKind.sound));
        expect(region?.target, isEmpty);
        expect(region?.label, equals('Song\nArtist'));
        expect(VideoStickerRegion.fromTag(region!.toTag()), equals(region));
      });

      test("keeps a sound's own page id and drops anything else", () {
        String? target(String raw) => VideoStickerRegion.fromTag([
          'sticker',
          'sound',
          raw,
          '0.5 0.5 0.3 0.1',
          '0',
        ])?.target;

        expect(target('bundled_potato_flew'), equals('bundled_potato_flew'));
        expect(target('C' * 64), equals('c' * 64));
        expect(target('https://example.com/song'), isEmpty);
        expect(target('bundled_../../x'), isEmpty);
      });

      test('drops a text too long to show', () {
        final region = VideoStickerRegion.fromTag([
          'sticker',
          'hashtag',
          'summer',
          '0.5 0.5 0.2 0.1',
          '0',
          '',
          '',
          'light',
          'x' * (VideoStickerRegion.maxLabelLength + 1),
        ]);

        expect(region?.label, isNull);
        expect(region?.style, equals('light'));
      });

      test('mends a broken text so it can be drawn', () {
        final region = VideoStickerRegion.fromTag([
          'sticker',
          'hashtag',
          'sum\uD800mer',
          '0.5 0.5 0.2 0.1',
          '0',
          '',
          '',
          'light',
          'sum\uD800mer',
        ]);

        expect(region?.label, equals('sum\uFFFDmer'));
        expect(region?.target, equals('sum\uFFFDmer'));
      });

      test('reads back what it publishes', () {
        const region = VideoStickerRegion(
          kind: VideoStickerKind.mention,
          target: _pubkey,
          centerX: 0.25,
          centerY: 0.75,
          width: 0.5,
          height: 0.125,
          rotation: math.pi / 6,
          end: Duration(seconds: 3),
        );

        final restored = VideoStickerRegion.fromTag(region.toTag());

        expect(restored?.target, equals(_pubkey));
        expect(restored?.end, equals(const Duration(seconds: 3)));
        expect(restored?.start, isNull);
        expect(restored?.rotation, closeTo(math.pi / 6, 1e-9));
        expect(restored?.width, equals(0.5));
      });

      test('reads a hashtag and a pubkey in lower case', () {
        expect(
          VideoStickerRegion.fromTag([
            'sticker',
            'hashtag',
            '#Summer',
            '0.5 0.5 0.2 0.1',
            '0',
          ])?.target,
          equals('summer'),
        );
        expect(
          VideoStickerRegion.fromTag([
            'sticker',
            'mention',
            _pubkey.toUpperCase(),
            '0.5 0.5 0.2 0.1',
            '0',
          ])?.target,
          equals(_pubkey),
        );
      });

      test('ignores a target a viewer could not safely open', () {
        List<String> tag(String kind, String target) => [
          'sticker',
          kind,
          target,
          '0.5 0.5 0.2 0.1',
          '0',
        ];

        expect(
          [
            tag('link', 'javascript://alert'),
            tag('link', 'https://'),
            tag('mention', 'npub1notahexkey'),
            tag('hashtag', 'two words'),
            tag('poll', 'https://divine.video'),
          ].map(VideoStickerRegion.fromTag),
          everyElement(isNull),
        );
      });

      test('ignores an area or a window that is not one', () {
        List<String> tag(String area, [List<String> window = const []]) => [
          'sticker',
          'link',
          'https://divine.video',
          area,
          '0',
          ...window,
        ];

        expect(
          [
            tag('0.5 0.5 0.2'),
            tag('0.5 0.5 0 0.1'),
            tag('0.5 0.5 0.2 NaN'),
            tag('0.5 0.5 0.2 0.1', ['2000', '1000']),
            tag('0.5 0.5 0.2 0.1', ['-5']),
            tag('1e308 0.5 0.2 0.1'),
            tag('0.5 -3 0.2 0.1'),
          ].map(VideoStickerRegion.fromTag),
          everyElement(isNull),
        );
      });

      test('reads a huge angle as what it turns past whole turns', () {
        final region = VideoStickerRegion.fromTag([
          'sticker',
          'link',
          'https://divine.video',
          '0.5 0.5 0.2 0.1',
          '1e308',
        ]);

        expect(region?.rotation.isFinite, isTrue);
        expect(
          VideoStickerRegion.fromTag([
            'sticker',
            'link',
            'https://divine.video',
            '0.5 0.5 0.2 0.1',
            '-405',
          ])?.rotation,
          closeTo(-math.pi / 4, 1e-9),
        );
      });

      List<String> tagOf(String kind, String target) => [
        'sticker',
        kind,
        target,
        '0.5 0.5 0.2 0.1',
        '0',
      ];

      test('reads a place by its full name', () {
        expect(
          VideoStickerRegion.fromTag(
            tagOf('place', ' Zermatt, Wallis, Schweiz '),
          )?.target,
          equals('Zermatt, Wallis, Schweiz'),
        );
      });

      test('drops a place on more than one line', () {
        expect(
          VideoStickerRegion.fromTag(tagOf('place', 'Zermatt\nWallis')),
          isNull,
        );
      });

      test('reads the moment a countdown ends', () {
        final region = VideoStickerRegion.fromTag(
          tagOf('countdown', '1782064800'),
        );

        expect(region?.countdownEnd, equals(DateTime.utc(2026, 6, 21, 18)));
      });

      test('drops a countdown that is no Unix time in seconds', () {
        for (final target in ['soon', '0', '-5', '253402300800']) {
          expect(
            VideoStickerRegion.fromTag(tagOf('countdown', target)),
            isNull,
            reason: target,
          );
        }
      });

      test('reads a reply by its event id in lower case', () {
        expect(
          VideoStickerRegion.fromTag(
            tagOf('reply', _pubkey.toUpperCase()),
          )?.target,
          equals(_pubkey),
        );
        expect(VideoStickerRegion.fromTag(tagOf('reply', 'note1abc')), isNull);
      });

      List<String> voteTag(String kind, String target, String label) => [
        ...tagOf(kind, target),
        '',
        '',
        'light',
        label,
      ];

      test('reads a poll by its event id in lower case', () {
        final region = VideoStickerRegion.fromTag(
          voteTag('poll', _pubkey.toUpperCase(), 'Which one?\nRed\nBlue'),
        );

        expect(region?.kind, equals(VideoStickerKind.poll));
        expect(region?.target, equals(_pubkey));
        expect(region?.labelLines, equals(['Which one?', 'Red', 'Blue']));
      });

      test('takes a poll that names no event id as one with no vote', () {
        expect(
          VideoStickerRegion.fromTag(
            voteTag('quiz', 'note1abc', 'Capital?\nBern\nZurich'),
          )?.target,
          isEmpty,
        );
      });

      test('drops a poll without a question and two to four answers', () {
        for (final label in [
          '',
          'Which one?\nRed',
          'Which one?\nA\nB\nC\nD\nE',
          'Which one?\n\nBlue',
        ]) {
          expect(
            VideoStickerRegion.fromTag(voteTag('poll', _pubkey, label)),
            isNull,
            reason: label,
          );
        }
      });

      test('reads a slider with its question and emoji only', () {
        expect(
          VideoStickerRegion.fromTag(
            voteTag('slider', _pubkey, 'How hungry?\n😋'),
          )?.labelLines,
          equals(['How hungry?', '😋']),
        );
        expect(
          VideoStickerRegion.fromTag(
            voteTag('slider', _pubkey, 'How hungry?\n😋\nmore'),
          ),
          isNull,
        );
      });
    });

    group('withTarget', () {
      test('points the same sticker at another target', () {
        const poll = VideoStickerRegion(
          kind: VideoStickerKind.poll,
          target: '',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.3,
          style: 'light',
          label: 'Which one?\nRed\nBlue',
        );

        final published = poll.withTarget(_pubkey);

        expect(published.target, equals(_pubkey));
        expect(
          published.toTag()..removeAt(2),
          equals(poll.toTag()..removeAt(2)),
        );
      });
    });

    group('countdownEnd', () {
      test('is null for any other kind', () {
        expect(_link.countdownEnd, isNull);
      });
    });

    group('isOnFrame', () {
      test('holds while any of the turned sticker can reach the frame', () {
        expect(_link.isOnFrame, isTrue);
        expect(
          [
            const VideoStickerRegion(
              kind: VideoStickerKind.hashtag,
              target: 'summer',
              centerX: -0.4,
              centerY: 0.5,
              width: 0.2,
              height: 0.1,
            ),
            const VideoStickerRegion(
              kind: VideoStickerKind.hashtag,
              target: 'summer',
              centerX: 0.5,
              centerY: 1.4,
              width: 0.2,
              height: 0.1,
            ),
          ].map((region) => region.isOnFrame),
          everyElement(isFalse),
        );
      });
    });

    group('isShownAt', () {
      test('shows the sticker from its start until just before its end', () {
        const region = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.2,
          height: 0.1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
        );

        expect(region.isShownAt(const Duration(milliseconds: 999)), isFalse);
        expect(region.isShownAt(const Duration(seconds: 1)), isTrue);
        expect(region.isShownAt(const Duration(seconds: 2)), isFalse);
      });
    });
  });

  group('VideoEvent.stickerRegions', () {
    VideoEvent video(List<List<String>> tags) => VideoEvent.fromNostrEvent(
      Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        [
          const ['d', 'video-stickers'],
          const ['url', 'https://media.divine.video/stickers.mp4'],
          ...tags,
        ],
        'Video with stickers',
        createdAt: 1778120201,
      ),
    );

    test('reads the sticker tags and skips broken ones', () {
      final regions = video([
        _link.toTag(),
        const ['sticker', 'link', 'javascript://alert', '0.5 0.5 0.2 0.1', '0'],
      ]).stickerRegions;

      expect(regions, equals([_link]));
    });

    test('keeps its stickers through a feed snapshot', () {
      final original = video([_link.toTag()]);

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.stickerRegions, equals([_link]));
    });
  });
}
