// ABOUTME: Pins the sound credit line a video's content carries to its parser,
// ABOUTME: so the publisher, the display and the edit flow cannot drift.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

const _ccBy = 'https://creativecommons.org/licenses/by/4.0/';

AudioEvent _sound({
  String? title = 'Monkeys Spinning Monkeys',
  String? creatorName = 'Kevin MacLeod (incompetech.com)',
  String? licenseName = 'CC BY 4.0',
  String? licenseUrl = _ccBy,
}) => AudioEvent(
  id: 'a' * 64,
  pubkey: 'b' * 64,
  createdAt: 1,
  title: title,
  creatorName: creatorName,
  licenseName: licenseName,
  licenseUrl: licenseUrl,
);

VideoEvent _video(String content) => VideoEvent(
  id: 'c' * 64,
  pubkey: 'd' * 64,
  createdAt: 1,
  content: content,
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
);

void main() {
  const line =
      '♪ Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com), '
      'CC BY 4.0 $_ccBy (edited)';

  group('soundCreditLine', () {
    test('credits title, creator and licence, and says it was edited', () {
      expect(soundCreditLine(_sound()), equals(line));
    });

    test('is null for a licence that asks no credit', () {
      expect(
        soundCreditLine(
          _sound(
            licenseName: 'CC0 1.0',
            licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
          ),
        ),
        isNull,
      );
    });

    test('credits a shipped sound by its source', () {
      final shipped = AudioEvent.fromBundledSound(
        VineSound(
          id: 'freesound_yay',
          title: 'YAY!',
          assetPath: 'assets/sounds/yay.mp3',
          duration: const Duration(seconds: 4),
          artist: 'IFartInUrGeneralDirection',
          license: 'CC BY 4.0',
          licenseUrl: _ccBy,
          sourceUrl: 'https://freesound.org/people/x/sounds/61691/',
        ),
      );

      expect(
        soundCreditLine(shipped),
        equals(
          '♪ YAY! – IFartInUrGeneralDirection via Freesound, '
          'CC BY 4.0 $_ccBy (edited)',
        ),
      );
    });

    test('keeps the line on one line and leaves out what is missing', () {
      expect(
        soundCreditLine(_sound(title: 'Two\nLines', creatorName: null)),
        equals('♪ Two Lines, CC BY 4.0 $_ccBy (edited)'),
      );
    });

    // The link comes from the sound's own event, and the poster never sees
    // the line before it is signed into their post.
    test('writes only a Creative Commons licence link', () {
      for (final link in [
        'https://phish.example/licenses/by/4.0/',
        'http://creativecommons.org/licenses/by/4.0/',
        'https://creativecommons.org.phish.example/licenses/by/4.0/',
        'javascript:alert(1)',
      ]) {
        expect(
          soundCreditLine(_sound(licenseUrl: link)),
          equals(
            '♪ Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com), '
            'CC BY 4.0 (edited)',
          ),
          reason: link,
        );
      }
      expect(
        soundCreditLine(
          _sound(
            licenseUrl: 'https://www.creativecommons.org/licenses/by/3.0/',
          ),
        ),
        endsWith(
          'CC BY 4.0 https://www.creativecommons.org/licenses/by/3.0/ '
          '(edited)',
        ),
      );
    });
  });

  group('soundCreditLines', () {
    test('credits each sound once, in order, and skips the uncredited', () {
      const second = '♪ Elevator Music – YellowTree, CC BY 4.0 $_ccBy (edited)';

      expect(
        soundCreditLines([
          _sound(),
          _sound(licenseName: 'CC0 1.0', licenseUrl: null),
          _sound(title: 'Elevator Music', creatorName: 'YellowTree'),
          _sound(),
        ]),
        equals([line, second]),
      );
    });
  });

  group('withSoundCreditLines', () {
    const second = '♪ Elevator Music – YellowTree, CC BY 4.0 $_ccBy (edited)';

    test('puts the lines after the caption, separated by a blank line', () {
      expect(
        withSoundCreditLines('my caption', [line, second]),
        equals('my caption\n\n$line\n$second'),
      );
    });

    test('is the lines alone for a video without a caption', () {
      expect(withSoundCreditLines('', [line]), equals(line));
    });

    test('leaves the caption alone without lines', () {
      expect(withSoundCreditLines('my caption', []), equals('my caption'));
    });

    test('writes a repeated line once', () {
      expect(
        withSoundCreditLines('my caption', [line, line]),
        equals('my caption\n\n$line'),
      );
    });
  });

  group('soundCreditsFromContent', () {
    test('reads the work and licence back', () {
      expect(
        soundCreditsFromContent('my caption\n\n$line'),
        equals([
          const SoundCredit(
            line: line,
            work: 'Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com)',
            license: 'CC BY 4.0',
          ),
        ]),
      );
    });

    test('reads every line of the block, in order', () {
      const second = '♪ Radio Announcement – Someone, CC BY 3.0 (edited)';

      expect(
        soundCreditsFromContent('my caption\n\n$line\n$second'),
        equals([
          const SoundCredit(
            line: line,
            work: 'Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com)',
            license: 'CC BY 4.0',
          ),
          const SoundCredit(
            line: second,
            work: 'Radio Announcement – Someone',
            license: 'CC BY 3.0',
          ),
        ]),
      );
    });

    test('finds them before an Inspired By line', () {
      final npub = Nip19.encodePubKey('e' * 64);
      final content =
          'my caption\n\n$line\n\n${inspiredByAttributionLine(npub)}';

      expect(
        soundCreditsFromContent(content).map((credit) => credit.line),
        equals([line]),
      );
    });

    test('keeps a comma in the work', () {
      expect(
        soundCreditsFromContent(
          '♪ Hello, World – Someone, CC BY 4.0 $_ccBy (edited)',
        ).single.work,
        equals('Hello, World – Someone'),
      );
    });

    test('reads a line without terms as the work alone', () {
      expect(
        soundCreditsFromContent('♪ Hello World (edited)'),
        equals([
          const SoundCredit(
            line: '♪ Hello World (edited)',
            work: 'Hello World',
          ),
        ]),
      );
    });

    test('ignores a caption that only mentions a song', () {
      expect(
        soundCreditsFromContent('♪ singing along (edited) today'),
        isEmpty,
      );
      expect(soundCreditsFromContent('loving this ♪ x (edited)'), isEmpty);
    });

    test('ignores a credit-shaped caption line not set apart by a blank '
        'line', () {
      expect(soundCreditsFromContent('my caption\n$line'), isEmpty);
    });
  });

  group('stripSoundCredit', () {
    test('removes the line and the blank line before it', () {
      expect(stripSoundCredit('my caption\n\n$line'), equals('my caption'));
    });

    test('removes every line of the block', () {
      expect(
        stripSoundCredit('my caption\n\n$line\n$line'),
        equals('my caption'),
      );
    });

    test('leaves content without a credit alone', () {
      expect(stripSoundCredit('my caption'), equals('my caption'));
    });
  });

  group('VideoEvent', () {
    test('displays the caption without the credit or Inspired By line', () {
      final npub = Nip19.encodePubKey('e' * 64);
      final video = _video(
        'my caption\n\n$line\n\n${inspiredByAttributionLine(npub)}',
      );

      expect(video.displayContent, equals('my caption'));
      expect(
        video.soundCredits.map((credit) => credit.license),
        equals(['CC BY 4.0']),
      );
    });

    test('has no sound credits without the line', () {
      expect(_video('my caption').soundCredits, isEmpty);
    });
  });
}
