// ABOUTME: Tests how the importer turns sound pack file names into titles.

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/sound_titles.dart';

void main() {
  group('titleFromFileName', () {
    test('splits camel case, underscores and numbering', () {
      expect(
        titleFromFileName('impactPunch_heavy_000.ogg', context: 'Kenney'),
        equals('Impact Punch Heavy 0'),
      );
      expect(
        titleFromFileName('HelicopterLoop6.wav', context: 'Arcade'),
        equals('Helicopter Loop 6'),
      );
      expect(
        titleFromFileName('jingles_SAX15.ogg', context: 'Jingle'),
        equals('Jingles SAX 15'),
      );
    });

    test('drops a leading recording date', () {
      expect(
        titleFromFileName(
          '2023-03-23 Lunar Descent - Reverse.wav',
          context: 'Sample',
        ),
        equals('Lunar Descent - Reverse'),
      );
    });

    test('keeps a note name such as C2 in one piece', () {
      expect(
        titleFromFileName('C2 - Sustain 2.wav', context: 'Foley'),
        equals('C2 - Sustain 2'),
      );
    });

    test('keeps small words lowercase after the first', () {
      expect(
        titleFromFileName("it's_a_tie.ogg", context: 'Voice'),
        equals("It's a Tie"),
      );
    });

    test('names the pack when the file name says nothing', () {
      expect(
        titleFromFileName('1.ogg', context: 'Voice'),
        equals('Voice 1'),
      );
    });
  });
}
