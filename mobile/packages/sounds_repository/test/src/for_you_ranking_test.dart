import 'package:models/models.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

void main() {
  group('rankForYouSounds', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    AudioEvent followedSound(
      String id, {
      required double ageDays,
      String pubkey = 'friend',
    }) => AudioEvent(
      id: id,
      pubkey: pubkey,
      createdAt: nowSeconds - (ageDays * 86400).round(),
    );

    AudioEvent divineSound(int index) => AudioEvent(
      id: '${AudioEvent.bundledMarker}_$index',
      pubkey: AudioEvent.bundledMarker,
      createdAt: index,
    );

    test('leads with today, then Divine, then an old upload', () {
      final ranked = rankForYouSounds(
        followed: [
          followedSound('old', ageDays: 30),
          followedSound('today', ageDays: 0),
        ],
        divine: [divineSound(0)],
        now: now,
      );

      expect(ranked.map((sound) => sound.id), [
        'today',
        '${AudioEvent.bundledMarker}_0',
        'old',
      ]);
    });

    test('lets a six-day-old upload pass the tail of Divine sounds', () {
      final ranked = rankForYouSounds(
        followed: [followedSound('six-days', ageDays: 6)],
        divine: [for (var i = 0; i < 40; i++) divineSound(i)],
        now: now,
      );

      // 1.8 * 0.97^k drops below the upload's 1.25 from the 13th sound on.
      expect(ranked.indexWhere((sound) => sound.id == 'six-days'), 12);
    });

    test('counts each further sound by one person a tenth less', () {
      final ranked = rankForYouSounds(
        followed: [
          followedSound('busy-1', ageDays: 0, pubkey: 'busy'),
          followedSound('busy-2', ageDays: 0, pubkey: 'busy'),
          followedSound('busy-3', ageDays: 0, pubkey: 'busy'),
          followedSound('other', ageDays: 0.5, pubkey: 'other'),
        ],
        divine: const [],
        now: now,
      );

      // busy scores 2, 1.8 and 1.62; other's half-day-old sound 1.89.
      expect(ranked.map((sound) => sound.id), [
        'busy-1',
        'other',
        'busy-2',
        'busy-3',
      ]);
    });

    test('keeps the Divine order through a day and mixes it the next', () {
      final divine = [for (var i = 0; i < 20; i++) divineSound(i)];
      List<String> order(DateTime at) => [
        for (final sound in rankForYouSounds(
          followed: const [],
          divine: divine,
          now: at,
        ))
          sound.id,
      ];

      final morning = order(DateTime.utc(2026, 11, 2, 8));
      expect(order(DateTime.utc(2026, 11, 2, 22)), morning);
      expect(order(DateTime.utc(2026, 11, 3, 8)), isNot(morning));
    });

    test('keeps equally new uploads in the order they came', () {
      final ranked = rankForYouSounds(
        followed: [
          followedSound('first', ageDays: 3, pubkey: 'a'),
          followedSound('second', ageDays: 3, pubkey: 'b'),
        ],
        divine: const [],
        now: now,
      );

      expect(ranked.map((sound) => sound.id), ['first', 'second']);
    });
  });
}
