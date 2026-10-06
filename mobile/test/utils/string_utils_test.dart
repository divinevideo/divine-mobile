import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/string_utils.dart';

void main() {
  group(StringUtils, () {
    group('sanitizeUtf16', () {
      test('returns identical instance when input is plain ASCII', () {
        const input = 'hello world';
        expect(identical(StringUtils.sanitizeUtf16(input), input), isTrue);
      });

      test('returns identical instance when input is empty', () {
        const input = '';
        expect(identical(StringUtils.sanitizeUtf16(input), input), isTrue);
      });

      test('preserves a well-formed surrogate pair (emoji)', () {
        // U+1F600 GRINNING FACE = D83D DE00
        const input = 'hi 😀';
        final result = StringUtils.sanitizeUtf16(input);
        expect(result, equals(input));
        expect(result.runes.last, equals(0x1F600));
      });

      test('replaces an unpaired high surrogate', () {
        final input = 'a${String.fromCharCode(0xD83D)}b';
        expect(StringUtils.sanitizeUtf16(input), equals('a\uFFFDb'));
      });

      test('replaces an unpaired low surrogate', () {
        final input = 'a${String.fromCharCode(0xDE00)}b';
        expect(StringUtils.sanitizeUtf16(input), equals('a\uFFFDb'));
      });

      test('replaces a trailing unpaired high surrogate', () {
        final input = 'trail${String.fromCharCode(0xD83D)}';
        expect(StringUtils.sanitizeUtf16(input), equals('trail\uFFFD'));
      });

      test('replaces a high surrogate followed by a non-surrogate', () {
        final input = '${String.fromCharCode(0xD83D)}x';
        expect(StringUtils.sanitizeUtf16(input), equals('\uFFFDx'));
      });

      test('preserves adjacent valid pairs separated by an unpaired one', () {
        final input = '😀${String.fromCharCode(0xD83D)}😀';
        final result = StringUtils.sanitizeUtf16(input);
        expect(result, equals('😀\uFFFD😀'));
      });
    });

    group('removeBlankLines', () {
      test('drops empty and whitespace-only lines', () {
        expect(
          StringUtils.removeBlankLines('First line\n\n  \nSecond line'),
          equals('First line\nSecond line'),
        );
      });

      test('handles Windows and classic Mac line endings', () {
        expect(
          StringUtils.removeBlankLines('One\r\n\r\nTwo\r\rThree'),
          equals('One\nTwo\nThree'),
        );
      });

      test('keeps text without blank lines unchanged', () {
        expect(
          StringUtils.removeBlankLines('One\nTwo'),
          equals('One\nTwo'),
        );
      });

      for (final (name, codePoint) in const [
        ('a zero-width space', 0x200B),
        ('a word joiner', 0x2060),
        ('a soft hyphen', 0x00AD),
        ('a left-to-right mark', 0x200E),
        ('a hangul filler', 0x3164),
        ('a braille blank', 0x2800),
      ]) {
        test('drops a line holding only $name', () {
          final filler = String.fromCharCode(codePoint);

          expect(
            StringUtils.removeBlankLines('One\n$filler\nTwo'),
            equals('One\nTwo'),
          );
        });
      }

      for (final (name, codePoint) in const [
        ('a line separator', 0x2028),
        ('a paragraph separator', 0x2029),
        ('a next-line character', 0x0085),
      ]) {
        test('splits on $name', () {
          final separator = String.fromCharCode(codePoint);

          expect(
            StringUtils.removeBlankLines(['One', 'Two'].join(separator * 2)),
            equals('One\nTwo'),
          );
        });
      }

      test('keeps lines that mix invisible and visible characters', () {
        final zeroWidthSpace = String.fromCharCode(0x200B);
        final mixed = 'a${zeroWidthSpace}b';
        // Emoji sequences join with a zero-width joiner; the emoji keeps
        // the line visible.
        const womanTechnologist = '\u{1F469}\u{200D}\u{1F4BB}';

        expect(
          StringUtils.removeBlankLines(
            '$mixed\n$zeroWidthSpace\n$womanTechnologist',
          ),
          equals('$mixed\n$womanTechnologist'),
        );
      });
    });

    group('compactPlural', () {
      test('selects the plural form from the raw value', () {
        String plural(int n, String display) =>
            n == 1 ? '$display view' : '$display views';

        expect(StringUtils.compactPlural(1, plural), '1 view');
        expect(StringUtils.compactPlural(2, plural), '2 views');
      });

      test('displays the compact rendering, not the raw value', () {
        String plural(int n, String display) => display;

        expect(StringUtils.compactPlural(1200, plural), '1.2K');
        expect(StringUtils.compactPlural(1500000, plural), '1.5M');
      });

      test('selects on the raw value even once the display is abbreviated', () {
        // The regression this guards: selecting the plural on the *formatted*
        // string would make every count above 999 look like the same value.
        String plural(int n, String display) => '$n|$display';

        expect(StringUtils.compactPlural(1000, plural), '1000|1K');
      });
    });
  });
}
