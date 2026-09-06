import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/models/caption_mention.dart';

void main() {
  group('activeMentionQuery', () {
    test('returns the token being typed after the caret-nearest @', () {
      const text = 'hi @ali';
      expect(activeMentionQuery(text, text.length), equals('ali'));
    });

    test('keeps separators inside the token', () {
      // The handles this whole feature exists for: a dot or a hyphen must not
      // end the query, or the picker stops suggesting mid-name.
      expect(activeMentionQuery('to @OG-AB', 9), equals('OG-AB'));
      expect(
        activeMentionQuery('by @ickynicki.v2', 16),
        equals('ickynicki.v2'),
      );
    });

    test('returns an empty query for a bare @ so the list can open', () {
      expect(activeMentionQuery('hi @', 4), equals(''));
    });

    test('returns null once the token is closed by a space or newline', () {
      expect(activeMentionQuery('hi @ali there', 13), isNull);
      expect(activeMentionQuery('hi @ali\nthere', 13), isNull);
    });

    test('returns null when there is no @ before the caret', () {
      expect(activeMentionQuery('plain caption', 5), isNull);
      expect(activeMentionQuery('later @ali', 3), isNull);
    });

    test('returns null for an out-of-range caret', () {
      expect(activeMentionQuery('hi @ali', -1), isNull);
      expect(activeMentionQuery('hi @ali', 99), isNull);
    });
  });

  group('applyMentionSelection', () {
    test('replaces the typed token and reports the inserted range', () {
      final insertion = applyMentionSelection(
        text: 'hi @ali',
        cursor: 7,
        display: 'OG-AB',
      );

      expect(insertion, isNotNull);
      expect(insertion!.text, equals('hi @OG-AB '));
      expect(insertion.selection, equals(10));
      expect(insertion.start, equals(3));
      // End excludes the trailing space, so it bounds '@OG-AB' exactly.
      expect(
        insertion.text.substring(insertion.start, insertion.end),
        equals('@OG-AB'),
      );
    });

    test('keeps text after the caret', () {
      final insertion = applyMentionSelection(
        text: 'hi @ali and bye',
        cursor: 7,
        display: 'alice',
      );

      expect(insertion!.text, equals('hi @alice  and bye'));
    });

    test('returns null when there is no @ to replace', () {
      expect(
        applyMentionSelection(text: 'plain', cursor: 5, display: 'alice'),
        isNull,
      );
    });
  });

  group('pruneCaptionMentions', () {
    const alice = CaptionMention(
      display: 'alice',
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    const ogab = CaptionMention(
      display: 'OG-AB',
      pubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    test('drops mentions whose handle is no longer written', () {
      expect(
        pruneCaptionMentions(const [alice, ogab], 'thanks @OG-AB'),
        equals(const [ogab]),
      );
    });

    test('keeps mentions still present in the caption', () {
      const mentions = [alice, ogab];
      expect(
        pruneCaptionMentions(mentions, 'hi @alice and @OG-AB'),
        same(mentions),
      );
    });

    test('returns the same list when nothing is dropped', () {
      const mentions = <CaptionMention>[];
      expect(pruneCaptionMentions(mentions, 'anything'), same(mentions));
    });

    test('drops everything when the caption is cleared', () {
      expect(pruneCaptionMentions(const [alice, ogab], ''), isEmpty);
    });
  });
}
