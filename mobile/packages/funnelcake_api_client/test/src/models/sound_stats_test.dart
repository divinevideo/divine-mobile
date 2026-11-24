import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
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
        final privateKey = generatePrivateKey();
        Map<String, dynamic> signed({int kind = 1063}) => (Event(
          getPublicKey(privateKey),
          kind,
          [
            ['d', 'clip'],
          ],
          '',
          createdAt: 1780000000,
        )..sign(privateKey)).toJson();

        test('reads the sound event and its source video', () {
          final event = signed();
          final source = signed(kind: 34236);

          final sound = SoundStats.fromJson({
            'event': event,
            'source_event': source,
          });

          expect(sound.event?.id, equals(event['id']));
          expect(sound.event?.kind, equals(1063));
          expect(sound.sourceEventKnown, isTrue);
          expect(sound.sourceEvent?.id, equals(source['id']));
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
          final unsigned = signed(kind: 34236)..remove('sig');
          final badTag = signed(kind: 34236)
            ..['tags'] = [
              ['d', 7],
            ];
          final changed = signed(kind: 34236)..['content'] = 'changed';

          for (final source in [unsigned, badTag, changed, 'video']) {
            final sound = SoundStats.fromJson({
              'event': badTag,
              'source_event': source,
            });

            expect(sound.event, isNull);
            expect(sound.sourceEventKnown, isFalse);
            expect(sound.sourceEvent, isNull);
          }
        });

        test(
          'leaves out a sound event whose id does not match its content',
          () {
            final sound = SoundStats.fromJson({
              'event': signed()..['content'] = 'changed',
            });

            expect(sound.event, isNull);
          },
        );
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
