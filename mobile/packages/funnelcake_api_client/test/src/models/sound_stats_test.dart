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
          'created_at': 1781214822.0,
          'usage_count': 12.0,
        });

        expect(sound.usageCount, equals(12));
        expect(sound.createdAt.millisecondsSinceEpoch, equals(1781214822000));
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
    });
  });
}
