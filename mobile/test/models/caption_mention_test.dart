import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/caption_mention.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group(CaptionMention, () {
    group('toJson', () {
      test('round-trips through fromJson with offsets', () {
        const mention = CaptionMention(
          display: 'OG-AB',
          pubkey: _pubkey,
          start: 3,
          end: 9,
        );

        expect(CaptionMention.tryFromJson(mention.toJson()), equals(mention));
      });

      test('omits absent offsets and restores them as null', () {
        const mention = CaptionMention(display: 'alice', pubkey: _pubkey);
        final json = mention.toJson();

        expect(json.containsKey('start'), isFalse);
        expect(json.containsKey('end'), isFalse);
        expect(CaptionMention.tryFromJson(json), equals(mention));
      });
    });

    group('tryFromJson', () {
      test('returns null without a usable display and pubkey', () {
        expect(CaptionMention.tryFromJson(const {'pubkey': _pubkey}), isNull);
        expect(CaptionMention.tryFromJson(const {'display': 'a'}), isNull);
        expect(
          CaptionMention.tryFromJson(const {'display': '', 'pubkey': _pubkey}),
          isNull,
        );
        expect(
          CaptionMention.tryFromJson(const {'display': 'a', 'pubkey': 7}),
          isNull,
        );
      });

      test('ignores offsets that are not integers', () {
        final mention = CaptionMention.tryFromJson(const {
          'display': 'alice',
          'pubkey': _pubkey,
          'start': 'x',
          'end': 2.5,
        });

        expect(mention, isNotNull);
        expect(mention!.start, isNull);
        expect(mention.end, isNull);
      });
    });

    group('listFromJson', () {
      test('reads a persisted list', () {
        final raw = [
          const CaptionMention(display: 'alice', pubkey: _pubkey).toJson(),
          const CaptionMention(display: 'OG-AB', pubkey: _pubkey).toJson(),
        ];

        expect(
          CaptionMention.listFromJson(raw).map((m) => m.display),
          equals(['alice', 'OG-AB']),
        );
      });

      test('drops unreadable entries rather than failing the restore', () {
        // A draft written by a newer build must not break an older one.
        final raw = <Object>[
          const {'display': 'alice', 'pubkey': _pubkey},
          const {'unexpected': true},
          'not a map',
        ];

        expect(CaptionMention.listFromJson(raw), hasLength(1));
      });

      test('returns empty for a missing or non-list value', () {
        expect(CaptionMention.listFromJson(null), isEmpty);
        expect(CaptionMention.listFromJson('nope'), isEmpty);
      });
    });

    group('equality', () {
      test('separates mentions of the same account at different offsets', () {
        const first = CaptionMention(
          display: 'alice',
          pubkey: _pubkey,
          start: 0,
          end: 6,
        );
        const second = CaptionMention(
          display: 'alice',
          pubkey: _pubkey,
          start: 20,
          end: 26,
        );

        expect(first, isNot(equals(second)));
        expect(
          first,
          equals(
            const CaptionMention(
              display: 'alice',
              pubkey: _pubkey,
              start: 0,
              end: 6,
            ),
          ),
        );
      });
    });
  });
}
