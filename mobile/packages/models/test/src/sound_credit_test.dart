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
  });

  group('withSoundCreditLine', () {
    test('puts the line after the caption, separated by a blank line', () {
      expect(
        withSoundCreditLine('my caption', line),
        equals('my caption\n\n$line'),
      );
    });

    test('is the line alone for a video without a caption', () {
      expect(withSoundCreditLine('', line), equals(line));
    });

    test('leaves the caption alone without a line', () {
      expect(withSoundCreditLine('my caption', null), equals('my caption'));
    });
  });

  group('soundCreditFromContent', () {
    test('reads the work and licence back', () {
      expect(
        soundCreditFromContent('my caption\n\n$line'),
        equals(
          const SoundCredit(
            line: line,
            work: 'Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com)',
            license: 'CC BY 4.0',
          ),
        ),
      );
    });

    test('finds it before an Inspired By line', () {
      final npub = Nip19.encodePubKey('e' * 64);
      final content =
          'my caption\n\n$line\n\n${inspiredByAttributionLine(npub)}';

      expect(soundCreditFromContent(content)?.line, equals(line));
    });

    test('keeps a comma in the work', () {
      expect(
        soundCreditFromContent(
          '♪ Hello, World – Someone, CC BY 4.0 $_ccBy (edited)',
        )?.work,
        equals('Hello, World – Someone'),
      );
    });

    test('ignores a caption that only mentions a song', () {
      expect(soundCreditFromContent('♪ singing along (edited) today'), isNull);
      expect(soundCreditFromContent('loving this ♪ x (edited)'), isNull);
    });
  });

  group('stripSoundCredit', () {
    test('removes the line and the blank line before it', () {
      expect(stripSoundCredit('my caption\n\n$line'), equals('my caption'));
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
      expect(video.soundCredit?.license, equals('CC BY 4.0'));
    });

    test('has no sound credit without the line', () {
      expect(_video('my caption').soundCredit, isNull);
    });
  });
}
