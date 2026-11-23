import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group(SoundStats, () {
    group('fromJson', () {
      test('falls back to empty values when fields are missing', () {
        final sound = SoundStats.fromJson(const {});

        expect(sound.id, isEmpty);
        expect(sound.pubkey, isEmpty);
        expect(sound.title, isEmpty);
        expect(sound.usageCount, equals(0));
        expect(
          sound.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
        );
      });

      test('reads numeric fields sent as doubles', () {
        final sound = SoundStats.fromJson(const {
          'created_at': 1780000000.0,
          'usage_count': 12.0,
        });

        expect(sound.usageCount, equals(12));
        expect(sound.createdAt.millisecondsSinceEpoch, equals(1780000000000));
      });

      group('events', () {
        Map<String, dynamic> signed(String id, {int kind = 1063}) => {
          'id': id,
          'pubkey': 'a' * 64,
          'created_at': 1780000000,
          'kind': kind,
          'tags': [
            ['d', 'clip'],
          ],
          'content': '',
          'sig': 'b' * 128,
        };

        test('reads the sound event and its source video', () {
          final sound = SoundStats.fromJson({
            'event': signed('sound'),
            'source_event': signed('video', kind: 34236),
          });

          expect(sound.event?.id, equals('sound'));
          expect(sound.event?.kind, equals(1063));
          expect(sound.sourceEventKnown, isTrue);
          expect(sound.sourceEvent?.id, equals('video'));
          expect(sound.sourceEvent?.tags, [
            ['d', 'clip'],
          ]);
        });

        test('reads a null source as no visible video', () {
          final sound = SoundStats.fromJson(const {'source_event': null});

          expect(sound.sourceEventKnown, isTrue);
          expect(sound.sourceEvent, isNull);
        });

        test('reads a missing source as unknown', () {
          final sound = SoundStats.fromJson(const {});

          expect(sound.event, isNull);
          expect(sound.sourceEventKnown, isFalse);
          expect(sound.sourceEvent, isNull);
        });

        test('reads an unreadable source as unknown, not as gone', () {
          final unsigned = signed('video')..remove('sig');
          final badTag = signed('video')
            ..['tags'] = [
              ['d', 7],
            ];

          for (final source in [unsigned, badTag, 'video']) {
            final sound = SoundStats.fromJson({
              'event': badTag,
              'source_event': source,
            });

            expect(sound.event, isNull);
            expect(sound.sourceEventKnown, isFalse);
            expect(sound.sourceEvent, isNull);
          }
        });
      });
    });

    group('equality', () {
      SoundStats build({int usageCount = 3}) => SoundStats(
        id: 'sound',
        pubkey: 'pubkey',
        title: 'Title',
        createdAt: DateTime.utc(2026, 9),
        usageCount: usageCount,
      );

      test('treats sounds with identical fields as equal', () {
        expect(build(), equals(build()));
        expect(build().hashCode, equals(build().hashCode));
      });

      test('distinguishes sounds with different usage counts', () {
        expect(build(), isNot(equals(build(usageCount: 4))));
      });

      test('distinguishes sounds whose source video is known', () {
        final known = SoundStats(
          id: 'sound',
          pubkey: 'pubkey',
          title: 'Title',
          createdAt: DateTime.utc(2026, 9),
          usageCount: 3,
          sourceEventKnown: true,
        );

        expect(build(), isNot(equals(known)));
        expect(build().hashCode, isNot(equals(known.hashCode)));
      });
    });
  });
}
