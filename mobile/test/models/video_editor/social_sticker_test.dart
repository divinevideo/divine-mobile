// ABOUTME: Tests the social sticker model: its meta round trip, when it can be
// ABOUTME: placed, and the hashtags and mentions the stickers add to a post.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show AudioEvent, UserProfile, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:poll_repository/poll_repository.dart' show Poll;
import 'package:pro_image_editor/pro_image_editor.dart';

const _pubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

WidgetLayer _layer(Map<String, dynamic> meta) => WidgetLayer(
  widget: const SizedBox(),
  meta: meta,
  exportConfigs: WidgetLayerExportConfigs(id: '1', meta: meta),
);

void main() {
  group(SocialStickerData, () {
    group('toMeta and fromMeta', () {
      test('round-trip every kind of social sticker', () {
        final stickers = [
          const SocialStickerData(
            kind: SocialStickerKind.mention,
            style: InfoStickerStyle.neon,
            pubkey: _pubkey,
            name: 'alice',
          ),
          const SocialStickerData(
            kind: SocialStickerKind.hashtag,
            hashtag: 'summer',
          ),
          const SocialStickerData(
            kind: SocialStickerKind.link,
            url: 'https://divine.video/',
            linkTitle: 'Divine',
          ),
          const SocialStickerData(
            kind: SocialStickerKind.soundCredit,
            style: InfoStickerStyle.glass,
            soundTitle: 'Song',
            soundArtist: 'Artist',
            soundDesign: SocialStickerSoundDesign.cassette,
            lyric: 'A line',
          ),
          SocialStickerData(
            kind: SocialStickerKind.countdown,
            style: InfoStickerStyle.brand,
            countdownTitle: 'Summer',
            countdownEnd: DateTime.utc(2027, 6, 21, 18),
            localeName: 'de_CH',
            use24HourFormat: true,
          ),
          const SocialStickerData(
            kind: SocialStickerKind.reply,
            style: InfoStickerStyle.dark,
            pubkey: _pubkey,
            name: 'alice',
            replyEventId: _pubkey,
            replyImageUrl: 'https://divine.video/thumb.jpg',
            replyToVideo: true,
          ),
        ];

        for (final sticker in stickers) {
          expect(SocialStickerData.fromMeta(sticker.toMeta()), equals(sticker));
        }
      });

      test('reads no sticker from an info sticker or an unknown kind', () {
        const info = InfoStickerData(
          kind: InfoStickerKind.battery,
          localeName: 'en',
        );
        final unknown = const SocialStickerData(
          kind: SocialStickerKind.hashtag,
        ).toMeta()..['socialKind'] = 'question';

        expect(SocialStickerData.fromMeta(info.toMeta()), isNull);
        expect(SocialStickerData.fromMeta(unknown), isNull);
      });

      test('falls back to the first pill look for a look it cannot take', () {
        final meta = const SocialStickerData(
          kind: SocialStickerKind.hashtag,
          hashtag: 'summer',
        ).toMeta()..['style'] = InfoStickerStyle.analog.name;

        expect(
          SocialStickerData.fromMeta(meta)!.style,
          equals(InfoStickerStyle.light),
        );
      });
    });

    group('isComplete', () {
      test('needs a valid public key and a name for a mention', () {
        const mention = SocialStickerData(
          kind: SocialStickerKind.mention,
          pubkey: _pubkey,
          name: 'alice',
        );

        expect(mention.isComplete, isTrue);
        expect(mention.copyWith(pubkey: 'npub1alice').isComplete, isFalse);
        expect(
          const SocialStickerData(
            kind: SocialStickerKind.mention,
            pubkey: _pubkey,
          ).isComplete,
          isFalse,
        );
      });

      test('needs a hashtag that can be published', () {
        expect(
          const SocialStickerData(
            kind: SocialStickerKind.hashtag,
            hashtag: 'summer',
          ).isComplete,
          isTrue,
        );
        expect(
          const SocialStickerData(
            kind: SocialStickerKind.hashtag,
            hashtag: '!!',
          ).isComplete,
          isFalse,
        );
      });
    });

    group('normalizeLinkUrl', () {
      test('adds https to an address typed without a scheme', () {
        expect(
          SocialStickerData.normalizeLinkUrl(' divine.video/about '),
          equals('https://divine.video/about'),
        );
      });

      test('keeps an http or https address', () {
        expect(
          SocialStickerData.normalizeLinkUrl('http://example.com'),
          equals('http://example.com'),
        );
      });

      test('rejects what is not a web address of a named host', () {
        for (final raw in [
          'ftp://example.com',
          'javascript://example.com',
          'localhost',
          'two words.com',
          '',
        ]) {
          expect(SocialStickerData.normalizeLinkUrl(raw), isNull, reason: raw);
        }
      });
    });

    group('withLink', () {
      test('shows the domain until a title is given', () {
        const link = SocialStickerData(kind: SocialStickerKind.link);

        final untitled = link.withLink(url: 'www.divine.video', title: ' ');
        final titled = link.withLink(url: 'www.divine.video', title: 'Divine');

        expect(untitled.linkTitle, isNull);
        expect(untitled.linkDomain, equals('divine.video'));
        expect(titled.linkTitle, equals('Divine'));
      });
    });

    group('sound stickers', () {
      const credit = SocialStickerData(
        kind: SocialStickerKind.soundCredit,
        style: InfoStickerStyle.dark,
        soundTitle: 'Song',
        soundArtist: 'Artist',
        lyric: 'A line',
      );
      VideoStickerRegion region(String? label) => VideoStickerRegion(
        kind: VideoStickerKind.sound,
        target: '',
        centerX: 0.5,
        centerY: 0.5,
        width: 0.3,
        height: 0.1,
        style: 'dark',
        label: label,
      );

      test('come back as the still note they were published as', () {
        final rebuilt = SocialStickerData.ofRegion(region(credit.tapLabel));

        expect(credit.tapLabel, equals('Song\nArtist\nA line'));
        expect(rebuilt, equals(credit));
      });

      test('credit the sound named on their first two lines', () {
        AudioEvent sound({String? creatorName}) => AudioEvent(
          id: 'sound',
          pubkey: _pubkey,
          createdAt: 0,
          title: 'Song',
          creatorName: creatorName,
        );

        expect(
          SocialStickerData.regionCreditsSound(
            region('Song\nArtist\nA line'),
            sound(creatorName: 'Artist'),
          ),
          isTrue,
        );
        expect(
          SocialStickerData.regionCreditsSound(region('Song'), sound()),
          isTrue,
        );
        expect(
          SocialStickerData.regionCreditsSound(
            region('Song\nOther band'),
            sound(creatorName: 'Artist'),
          ),
          isFalse,
        );
      });
    });

    group('ofRegion', () {
      VideoStickerRegion region(
        VideoStickerKind kind,
        String target, {
        String? style = 'dark',
        String? label = 'label',
      }) => VideoStickerRegion(
        kind: kind,
        target: target,
        centerX: 0.5,
        centerY: 0.5,
        width: 0.2,
        height: 0.1,
        style: style,
        label: label,
      );

      test('rebuilds the sticker a published video shows', () {
        final link = SocialStickerData.ofRegion(
          region(VideoStickerKind.link, 'https://divine.video/', label: 'Us'),
        );
        final mention = SocialStickerData.ofRegion(
          region(VideoStickerKind.mention, _pubkey, label: 'alice'),
        );

        expect(link?.style, equals(InfoStickerStyle.dark));
        expect(link?.url, equals('https://divine.video/'));
        expect(link?.linkTitle, equals('Us'));
        expect(mention?.pubkey, equals(_pubkey));
        expect(mention?.name, equals('alice'));
      });

      test('rebuilds nothing without a pill look or a text', () {
        expect(
          [
            region(VideoStickerKind.hashtag, 'summer', style: 'camcorder'),
            region(VideoStickerKind.hashtag, 'summer', style: 'sparkle'),
            region(VideoStickerKind.hashtag, 'summer', style: null),
            region(VideoStickerKind.hashtag, 'summer', label: null),
          ].map(SocialStickerData.ofRegion),
          everyElement(isNull),
        );
      });

      test('rebuilds a countdown in a solid look, and no place or reply', () {
        final countdown = SocialStickerData.ofRegion(
          region(
            VideoStickerKind.countdown,
            '1813600800',
            style: 'light',
            label: 'Summer',
          ),
        );

        expect(countdown?.countdownTitle, equals('Summer'));
        expect(countdown?.countdownEnd, equals(DateTime.utc(2027, 6, 21, 18)));
        expect(
          [
            region(VideoStickerKind.countdown, '1813600800'),
            region(VideoStickerKind.place, 'Zermatt', style: 'light'),
            region(VideoStickerKind.reply, _pubkey, style: 'light'),
          ].map(SocialStickerData.ofRegion),
          everyElement(isNull),
        );
      });

      test('reads back the text the publish recorded', () {
        const sticker = SocialStickerData(
          kind: SocialStickerKind.hashtag,
          style: InfoStickerStyle.glass,
          hashtag: 'Summer',
        );

        final rebuilt = SocialStickerData.ofRegion(
          region(
            VideoStickerKind.hashtag,
            sticker.tapTarget!,
            style: sticker.style.name,
            label: sticker.tapLabel,
          ),
        );

        expect(rebuilt, equals(sticker));
      });
    });

    group('mentionOf', () {
      test('names the person by their handle without its @', () {
        final profile = UserProfile(
          pubkey: _pubkey,
          name: 'alice',
          displayName: 'Alice A.',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'event',
        );

        final mention = SocialStickerData.mentionOf(profile);

        expect(mention.pubkey, equals(_pubkey));
        expect(mention.name, equals('alice'));
      });
    });

    group('soundCreditFor', () {
      AudioEvent sound({String? title, String? creatorName}) => AudioEvent(
        id: 'sound',
        pubkey: _pubkey,
        createdAt: 0,
        title: title,
        creatorName: creatorName,
      );

      test('credits a sound with a title and an artist', () {
        final credit = SocialStickerData.soundCreditFor(
          sound(title: ' Song ', creatorName: 'Artist'),
        );

        expect(credit?.soundTitle, equals('Song'));
        expect(credit?.soundArtist, equals('Artist'));
      });

      test("credits the artist of a sound from Divine's library", () {
        final credit = SocialStickerData.soundCreditFor(
          AudioEvent(
            id: '${AudioEvent.bundledMarker}_song',
            pubkey: _pubkey,
            createdAt: 0,
            title: 'Song',
            source: 'Artist',
          ),
        );

        expect(credit?.soundArtist, equals('Artist'));
        expect(credit?.soundId, equals('bundled_song'));
        expect(credit?.tapTarget, equals('bundled_song'));
      });

      test('offers each sound once, in order', () {
        final credits = SocialStickerData.soundCreditsFor([
          sound(title: 'Song', creatorName: 'Artist'),
          sound(title: 'Other', creatorName: 'Band'),
          sound(title: 'Song', creatorName: 'Artist'),
          sound(creatorName: 'Nameless'),
        ]);

        expect(credits.map((c) => c.soundTitle), equals(['Song', 'Other']));
      });

      test('credits a sound without an artist by its title', () {
        final credit = SocialStickerData.soundCreditFor(sound(title: 'Song'));

        expect(credit?.soundTitle, equals('Song'));
        expect(credit?.soundArtist, isNull);
        expect(credit?.isComplete, isTrue);
      });

      test('offers no credit for a sound without a title', () {
        expect(
          SocialStickerData.soundCreditFor(sound(creatorName: 'Artist')),
          isNull,
        );
      });
    });

    group('countdown', () {
      test('starts at the full hour after a day from now', () {
        expect(
          SocialStickerData.defaultCountdownEnd(DateTime(2026, 10, 30, 14, 25)),
          equals(DateTime(2026, 10, 31, 15)),
        );
      });

      test('is tapped by its end in Unix seconds and shows its title', () {
        final countdown = SocialStickerData(
          kind: SocialStickerKind.countdown,
          countdownTitle: ' Summer ',
          countdownEnd: DateTime.utc(2027, 6, 21, 18),
        );

        expect(countdown.tapKind, equals(VideoStickerKind.countdown));
        expect(countdown.tapTarget, equals('1813600800'));
        expect(countdown.tapLabel, equals('Summer'));
      });

      test('cannot be placed without a title', () {
        final countdown = SocialStickerData.countdown(now: DateTime(2026));

        expect(countdown.isComplete, isFalse);
        expect(countdown.tapTarget, isNull);
      });
    });

    group('replyTo', () {
      const comment = VideoReplyContext(
        rootEventId:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        rootEventKind: 34236,
        rootAuthorPubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        parentCommentId: _pubkey,
        parentAuthorPubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        replyToName: 'alice',
        replyToText: 'Which one?\n\nThe red  one',
        replyToImageUrl: 'https://divine.video/alice.jpg',
      );

      test('shows the comment it replies to on one line', () {
        final reply = SocialStickerData.replyTo(comment)!;

        expect(reply.replyEventId, equals(_pubkey));
        expect(reply.pubkey, equals(comment.parentAuthorPubkey));
        expect(reply.replyText, equals('Which one? The red one'));
        expect(reply.replyToVideo, isFalse);
        expect(reply.tapLabel, equals('alice\nWhich one? The red one'));
      });

      test('cuts a long comment short', () {
        final reply = SocialStickerData.replyTo(
          VideoReplyContext(
            rootEventId: comment.rootEventId,
            rootEventKind: comment.rootEventKind,
            rootAuthorPubkey: comment.rootAuthorPubkey,
            parentCommentId: _pubkey,
            replyToName: 'alice',
            replyToText: 'ha' * 100,
          ),
        )!;

        expect(
          reply.replyText!.length,
          equals(SocialStickerData.maxReplyTextLength),
        );
        expect(reply.replyText, endsWith('…'));
      });

      test('shows the video it replies to by its thumbnail', () {
        final reply = SocialStickerData.replyTo(
          VideoReplyContext(
            rootEventId: comment.rootEventId,
            rootEventKind: comment.rootEventKind,
            rootAuthorPubkey: comment.rootAuthorPubkey,
            replyToName: 'bob',
            replyToImageUrl: 'https://divine.video/thumb.jpg',
          ),
        )!;

        expect(reply.replyEventId, equals(comment.rootEventId));
        expect(reply.replyText, isNull);
        expect(reply.replyToVideo, isTrue);
        expect(reply.tapTarget, equals(comment.rootEventId));
      });

      test('shows nothing without a name to show', () {
        expect(
          SocialStickerData.replyTo(
            VideoReplyContext(
              rootEventId: comment.rootEventId,
              rootEventKind: comment.rootEventKind,
              rootAuthorPubkey: comment.rootAuthorPubkey,
            ),
          ),
          isNull,
        );
      });
    });

    group('polls', () {
      const quiz = SocialStickerData(
        kind: SocialStickerKind.quiz,
        pollQuestion: ' Vine launched in… ',
        pollOptions: ['2013', ' 2015 '],
        quizAnswer: 0,
      );

      test('needs a question and two to four answers, a quiz its right '
          'one and a slider its emoji', () {
        expect(quiz.isComplete, isTrue);
        expect(
          [
            SocialStickerData.poll(SocialStickerKind.poll),
            quiz.copyWith(pollOptions: ['2013', '  ']),
            quiz.copyWith(pollOptions: ['1', '2', '3', '4', '5']),
            quiz.copyWith(quizAnswer: 2),
            const SocialStickerData(
              kind: SocialStickerKind.slider,
              pollQuestion: 'Hungry?',
            ),
          ].map((sticker) => sticker.isComplete),
          everyElement(isFalse),
        );
        expect(
          SocialStickerData.poll(
            SocialStickerKind.slider,
          ).copyWith(pollQuestion: 'Hungry?').isComplete,
          isTrue,
        );
      });

      test('is published without a poll id, and its question and answers '
          'come back from the tag', () {
        final region = VideoStickerRegion.fromTag(
          VideoStickerRegion(
            kind: quiz.tapKind,
            target: quiz.tapTarget!,
            centerX: 0.5,
            centerY: 0.5,
            width: 0.6,
            height: 0.3,
            style: quiz.style.name,
            label: quiz.tapLabel,
          ).toTag(),
        )!;

        expect(region.kind, equals(VideoStickerKind.quiz));
        expect(region.target, isEmpty);
        expect(
          SocialStickerData.ofRegion(region),
          equals(
            const SocialStickerData(
              kind: SocialStickerKind.quiz,
              pollQuestion: 'Vine launched in…',
              pollOptions: ['2013', '2015'],
            ),
          ),
        );
      });

      test('keeps its question, answers and right answer in a draft', () {
        expect(SocialStickerData.fromMeta(quiz.toMeta()), equals(quiz));
      });

      test('is published as the poll it asks', () {
        expect(
          quiz.toPoll(),
          equals(
            Poll.choice(
              question: 'Vine launched in…',
              answers: const ['2013', '2015'],
              answerIndex: 0,
            ),
          ),
        );
        expect(
          const SocialStickerData(
            kind: SocialStickerKind.slider,
            pollQuestion: 'Hungry?',
            sliderEmoji: '😋',
          ).toPoll(),
          equals(Poll.slider(question: 'Hungry?', emoji: '😋')),
        );
      });
    });

    group('withLyric', () {
      test('drops a blank line of lyrics', () {
        const credit = SocialStickerData(
          kind: SocialStickerKind.soundCredit,
          soundTitle: 'Song',
          soundArtist: 'Artist',
          lyric: 'A line',
        );

        expect(credit.withLyric('  ').lyric, isNull);
      });
    });
  });

  group(SocialStickerCredits, () {
    final hashtag = _layer(
      const SocialStickerData(
        kind: SocialStickerKind.hashtag,
        hashtag: 'summer',
      ).toMeta(),
    );
    final mention = _layer(
      SocialStickerData(
        kind: SocialStickerKind.mention,
        pubkey: _pubkey.toUpperCase(),
        name: 'alice',
      ).toMeta(),
    );
    final soundCredit = _layer(
      const SocialStickerData(
        kind: SocialStickerKind.soundCredit,
        soundTitle: 'Song',
        soundArtist: 'Artist',
      ).toMeta(),
    );

    final link = _layer(
      const SocialStickerData(
        kind: SocialStickerKind.link,
        url: 'https://divine.video/',
      ).toMeta(),
    );

    group('of', () {
      test('collects the hashtags, mentioned public keys and links', () {
        final credits = SocialStickerCredits.of([
          hashtag,
          mention,
          link,
          soundCredit,
        ]);

        expect(credits.hashtags, equals({'summer'}));
        expect(credits.mentionPubkeys, equals({_pubkey}));
        expect(credits.links, equals({'https://divine.video/'}));
        expect(credits.poll, isNull);
      });

      test('carries the poll of the first poll sticker', () {
        SocialStickerData poll(String question) => SocialStickerData(
          kind: SocialStickerKind.poll,
          pollQuestion: question,
          pollOptions: const ['Red', 'Blue'],
        );

        final credits = SocialStickerCredits.of([
          _layer(poll('First?').toMeta()),
          _layer(poll('Second?').toMeta()),
        ]);

        expect(credits.poll?.question, equals('First?'));
      });
    });

    group('hashtagsWith', () {
      test("keeps the stickers' hashtags when the post has too many", () {
        final credits = SocialStickerCredits.of([hashtag]);
        final tags = [for (var i = 0; i < 10; i++) 'tag$i'];

        final published = credits.hashtagsWith(tags);

        expect(published, hasLength(10));
        expect(published.first, equals('summer'));
        expect(published, isNot(contains('tag9')));
      });
    });
  });
}
