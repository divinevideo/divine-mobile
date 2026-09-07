import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';

void main() {
  group(LinkifiedTextSpanBuilder, () {
    const defaultStyle = TextStyle(color: Colors.white);
    const linkStyle = TextStyle(color: Colors.green);
    const mentionStyle = TextStyle(color: Colors.blue);

    test('returns one plain span when text has no link tokens', () {
      final spans = const LinkifiedTextSpanBuilder(
        text: 'plain bio text',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(spans, hasLength(1));
      expect(spans.single.text, equals('plain bio text'));
      expect(spans.single.style, equals(defaultStyle));
      expect(spans.single.recognizer, isNull);
    });

    test('creates tappable spans for bare domains and emails', () {
      final tappedUrls = <String>[];
      final spans = LinkifiedTextSpanBuilder(
        text: 'violetblue.com + hi@example.com',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        onUrlTap: (rawUrl) async => tappedUrls.add(rawUrl),
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals(['violetblue.com', 'hi@example.com']),
      );

      tappable.first.tap();
      tappable.last.tap();
      expect(tappedUrls, equals(['violetblue.com', 'hi@example.com']));
    });

    test('does not retry URL tokens from inside dotted plain text', () {
      final spans = LinkifiedTextSpanBuilder(
        text: '${'a.' * 4096} tail...example.com',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(spans.tappableSpans, isEmpty);
    });

    test('keeps trailing punctuation outside URL spans', () {
      final spans = const LinkifiedTextSpanBuilder(
        text: 'Visit violetblue.com.! More: https://example.com/path?:;',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(
        spans.map((span) => span.text).join(),
        equals('Visit violetblue.com.! More: https://example.com/path?:;'),
      );
      expect(
        spans.tappableSpans.map((span) => span.text),
        equals(['violetblue.com', 'https://example.com/path']),
      );
      expect(spans[2].text, startsWith('.!'));
      expect(spans.last.text, equals('?:;'));
      expect(spans[2].recognizer, isNull);
      expect(spans.last.recognizer, isNull);
    });

    test('preserves token precedence across supported token types', () {
      const profileHex =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const videoHex =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final npub = NostrKeyUtils.encodePubKey(profileHex);
      final tapped = <String>[];

      final spans = LinkifiedTextSpanBuilder(
        text: [
          'hi@example.com',
          '#tag',
          npub,
          'clip $videoHex',
          '@alice',
        ].join(' '),
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        profileLabelForHex: (hexPubkey) => 'profile-$hexPubkey',
        videoLabel: 'View video',
        onUrlTap: (rawUrl) async => tapped.add('url:$rawUrl'),
        onHashtagTap: (hashtag) => tapped.add('hashtag:$hashtag'),
        onProfileTap: (hexPubkey) => tapped.add('profile:$hexPubkey'),
        onVideoTap: (routeReference) => tapped.add('video:$routeReference'),
        onMentionTap: (username) => tapped.add('mention:$username'),
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals([
          'hi@example.com',
          '#tag',
          '@profile-$profileHex',
          'View video',
          '@alice',
        ]),
      );
      expect(
        tappable.map((span) => span.style),
        equals([linkStyle, linkStyle, mentionStyle, linkStyle, mentionStyle]),
      );

      for (final span in tappable) {
        span.tap();
      }

      expect(
        tapped,
        equals([
          'url:hi@example.com',
          'hashtag:tag',
          'profile:$profileHex',
          'video:$videoHex',
          'mention:alice',
        ]),
      );
    });

    test('routes plain mentions to profile when a mention pubkey matches', () {
      const alicePubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      String? tappedProfile;
      String? tappedMention;

      final spans = LinkifiedTextSpanBuilder(
        text: '@alice FOLLOW HER',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        profilePubkeyForMention: (username) =>
            username == 'alice' ? alicePubkey : null,
        onProfileTap: (hexPubkey) => tappedProfile = hexPubkey,
        onMentionTap: (username) => tappedMention = username,
      ).build();

      expect(
        spans.map((span) => span.text).join(),
        equals('@alice FOLLOW HER'),
      );

      spans.tappableSpans.single.tap();

      expect(tappedProfile, equals(alicePubkey));
      expect(tappedMention, isNull);
    });

    test('routes note1 references to normalized event ids', () {
      const eventId =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final note = Nip19.encodeNoteId(eventId);
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch $note',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(eventId));
    });

    test('routes nevent references to normalized event ids', () {
      const eventId =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final nevent = NIP19Tlv.encodeNevent(Nevent(id: eventId));
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch $nevent',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(eventId));
    });

    test('routes naddr references with the original normalized reference', () {
      const authorHex =
          '3333333333333333333333333333333333333333333333333333333333333333';
      final naddr = NIP19Tlv.encodeNaddr(
        Naddr(id: 'stable-video', author: authorHex, kind: 34236),
      );
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch nostr:$naddr',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(naddr));
    });

    test('keeps malformed event references tappable without crashing', () {
      const malformedNote = 'note1notavalidevent';
      const malformedNevent = 'nevent1notavalidevent';
      final tapped = <String>[];

      final spans = LinkifiedTextSpanBuilder(
        text: '$malformedNote nostr:$malformedNevent',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: tapped.add,
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals(['View video', 'View video']),
      );

      for (final span in tappable) {
        span.tap();
      }

      expect(tapped, equals([malformedNote, malformedNevent]));
    });

    test('routes profile-like hex references to profile taps', () {
      const profileHex =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      String? tappedProfile;

      final spans = LinkifiedTextSpanBuilder(
        text: 'author: $profileHex',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        profileLabelForHex: (_) => 'casey',
        onProfileTap: (hexPubkey) => tappedProfile = hexPubkey,
      ).build();

      final profileSpan = spans.tappableSpans.single;
      expect(profileSpan.text, equals('@casey'));
      profileSpan.tap();
      expect(tappedProfile, equals(profileHex));
    });

    test('leaves invalid profile Nostr IDs plain and unchanged', () {
      const invalidNpub = 'npub1invalidprofile';

      final spans = const LinkifiedTextSpanBuilder(
        text: invalidNpub,
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(spans, hasLength(1));
      expect(spans.single.text, equals(invalidNpub));
      expect(spans.single.style, equals(linkStyle));
      expect(spans.single.recognizer, isNull);
    });

    // Divine handles routinely carry a dot or a hyphen — a NIP-05 local part
    // allows both, and `ickynicki.v2` / `OG-AB` are real reported handles.
    // The tokenizer stopped at the first one, so `@OG-AB` linked to whoever
    // owns `OG` and left `-AB` as plain text.
    group('handles containing dots and hyphens', () {
      test('keeps a hyphenated handle in one mention span', () {
        String? tappedMention;

        final spans = LinkifiedTextSpanBuilder(
          text: 'dedicated to my home-girl @OG-AB',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: (username) => tappedMention = username,
        ).build();

        final mentionSpan = spans.tappableSpans.single;
        expect(mentionSpan.text, equals('@OG-AB'));
        mentionSpan.tap();
        expect(tappedMention, equals('OG-AB'));
      });

      test('keeps a dotted handle in one mention span', () {
        String? tappedMention;

        final spans = LinkifiedTextSpanBuilder(
          text: 'inspired by @ickynicki.v2',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: (username) => tappedMention = username,
        ).build();

        final mentionSpan = spans.tappableSpans.single;
        expect(mentionSpan.text, equals('@ickynicki.v2'));
        mentionSpan.tap();
        expect(tappedMention, equals('ickynicki.v2'));
      });

      test('leaves sentence punctuation after a handle outside the span', () {
        final spans = LinkifiedTextSpanBuilder(
          text: 'thanks @st.allison.',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: (_) {},
        ).build();

        expect(spans.tappableSpans.single.text, equals('@st.allison'));
        expect(
          spans.map((span) => span.text).join(),
          equals('thanks @st.allison.'),
        );
      });

      test('leaves a trailing separator outside the span', () {
        final spans = LinkifiedTextSpanBuilder(
          text: '@trailing- and @trailing.',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: (_) {},
        ).build();

        expect(
          spans.tappableSpans.map((span) => span.text),
          equals(['@trailing', '@trailing']),
        );
        expect(
          spans.map((span) => span.text).join(),
          equals('@trailing- and @trailing.'),
        );
      });

      test('still leaves an email address unlinked as a mention', () {
        final tappedUrls = <String>[];
        final mentions = <String>[];

        final spans = LinkifiedTextSpanBuilder(
          text: 'write to bob@example.com',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: mentions.add,
          onUrlTap: (rawUrl) async => tappedUrls.add(rawUrl),
        ).build();

        spans.tappableSpans.single.tap();
        expect(mentions, isEmpty);
        expect(tappedUrls, equals(['bob@example.com']));
      });
    });

    // `@<64-hex>` resolves on the first character after the `@`. The trailing
    // mention alternative opens with `[a-zA-Z]`, so a letter-initial hex is
    // taken as a 31-character mention while a digit-initial one has no letter
    // to consume and falls through to the hex reference alternative.
    // `notification_repository` mirrors this tokenizer without the mention
    // alternative and documents that divergence, so it is pinned here.
    group('@-prefixed 64-hex references', () {
      const letterInitialHex =
          'a1b2c3d4e5f60718293a4b5c6d7e8f90'
          'a1b2c3d4e5f60718293a4b5c6d7e8f90';
      const digitInitialHex =
          '01b2c3d4e5f60718293a4b5c6d7e8f90'
          'a1b2c3d4e5f60718293a4b5c6d7e8f90';

      test('truncates a letter-initial hex to a plain mention', () {
        String? tappedMention;

        final spans = LinkifiedTextSpanBuilder(
          text: '@$letterInitialHex',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          onMentionTap: (username) => tappedMention = username,
        ).build();

        final mentionSpan = spans.tappableSpans.single;
        expect(
          mentionSpan.text,
          equals('@${letterInitialHex.substring(0, 31)}'),
        );
        mentionSpan.tap();
        expect(tappedMention, equals(letterInitialHex.substring(0, 31)));
      });

      test('keeps a digit-initial hex whole as a video reference', () {
        String? tappedVideo;

        final spans = LinkifiedTextSpanBuilder(
          text: '@$digitInitialHex',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          videoLabel: 'View video',
          onVideoTap: (routeReference) => tappedVideo = routeReference,
        ).build();

        final videoSpan = spans.tappableSpans.single;
        expect(videoSpan.text, equals('View video'));
        videoSpan.tap();
        expect(tappedVideo, equals(digitInitialHex));
      });
    });

    // Unpaired UTF-16 surrogates make Flutter's paragraph builder throw
    // "string is not well-formed UTF-16" during layout, which is a crash
    // rather than a rendering glitch. They reach spans from two independent
    // directions, so both are pinned here.
    group('malformed UTF-16', () {
      // A lone high surrogate, e.g. an emoji cut in half in transit or a
      // half-escaped `\uD83D` in event JSON.
      final loneSurrogate = String.fromCharCode(0xD83D);

      test('replaces an unpaired surrogate in the source text', () {
        final spans = LinkifiedTextSpanBuilder(
          text: 'hi ${loneSurrogate}there',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
        ).build();

        expect(spans.map((span) => span.text).join(), equals('hi �there'));
      });

      test('replaces an unpaired surrogate in a resolved profile label', () {
        const profileHex =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

        final spans = LinkifiedTextSpanBuilder(
          text: 'author: $profileHex',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
          mentionStyle: mentionStyle,
          profileLabelForHex: (_) => 'ca${loneSurrogate}sey',
        ).build();

        expect(spans.tappableSpans.single.text, equals('@ca�sey'));
      });

      test('keeps a valid surrogate pair intact', () {
        final spans = const LinkifiedTextSpanBuilder(
          text: 'hi 😀 there',
          defaultStyle: defaultStyle,
          linkStyle: linkStyle,
        ).build();

        expect(spans.map((span) => span.text).join(), equals('hi 😀 there'));
      });
    });
  });
}

extension on List<InlineSpan> {
  List<TextSpan> get tappableSpans => whereType<TextSpan>()
      .where((span) => span.recognizer is TapGestureRecognizer)
      .toList();
}

/// The builder emits `InlineSpan` so a green heart can arrive as a
/// `WidgetSpan`; these keep the text-span assertions below readable.
extension on InlineSpan {
  String? get text => (this as TextSpan).text;

  GestureRecognizer? get recognizer => (this as TextSpan).recognizer;
}

extension on TextSpan {
  void tap() {
    (recognizer! as TapGestureRecognizer).onTap!();
  }
}
