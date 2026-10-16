import 'package:test/test.dart';
import 'package:user_ranking/user_ranking.dart';

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _c = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _d = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _e = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
final _now = DateTime.utc(2026, 10, 15);
String _nameOf(String pubkey) => pubkey;
UserRankingSignals _maxedMutual() => UserRankingSignals(
  pubkey: _b,
  youFollow: true,
  followsYou: true,
  videoCount: 999,
  hasVerifiedNip05: true,
  lastPostedAt: _now,
);

void main() {
  group('scoreUser', () {
    test('absent signals contribute zero', () {
      expect(scoreUser(const UserRankingSignals(pubkey: _a), now: _now), 0);
    });
    test('interaction starts at 100', () {
      expect(
        scoreUser(
          UserRankingSignals(pubkey: _a, lastInteractionAt: _now),
          now: _now,
        ),
        100,
      );
    });
    test('interaction halves after fourteen days', () {
      expect(
        scoreUser(
          UserRankingSignals(
            pubkey: _a,
            lastInteractionAt: _now.subtract(const Duration(days: 14)),
          ),
          now: _now,
        ),
        50,
      );
    });
    test('interaction decay includes fractional days', () {
      expect(
        scoreUser(
          UserRankingSignals(
            pubkey: _a,
            lastInteractionAt: _now.subtract(const Duration(days: 7)),
          ),
          now: _now,
        ),
        closeTo(70.710678, 0.000001),
      );
    });
    test('future interaction has age zero', () {
      expect(
        scoreUser(
          UserRankingSignals(
            pubkey: _a,
            lastInteractionAt: _now.add(const Duration(days: 1)),
          ),
          now: _now,
        ),
        100,
      );
    });
    test('mutual replaces rather than stacks relationship weights', () {
      expect(
        scoreUser(
          const UserRankingSignals(
            pubkey: _a,
            youFollow: true,
            followsYou: true,
          ),
          now: _now,
        ),
        40,
      );
    });
    test('following only scores twenty', () {
      expect(
        scoreUser(
          const UserRankingSignals(
            pubkey: _a,
            youFollow: true,
            followsYou: false,
          ),
          now: _now,
        ),
        20,
      );
    });
    test('unknown incoming relationship still allows following boost', () {
      expect(
        scoreUser(
          const UserRankingSignals(pubkey: _a, youFollow: true),
          now: _now,
        ),
        20,
      );
    });
    test('follower only scores ten', () {
      expect(
        scoreUser(
          const UserRankingSignals(pubkey: _a, followsYou: true),
          now: _now,
        ),
        10,
      );
    });
    test('explicit non-follower contributes zero', () {
      expect(
        scoreUser(
          const UserRankingSignals(pubkey: _a, followsYou: false),
          now: _now,
        ),
        0,
      );
    });
    test('verified identity contributes three', () {
      expect(
        scoreUser(
          const UserRankingSignals(pubkey: _a, hasVerifiedNip05: true),
          now: _now,
        ),
        3,
      );
    });
    test('fresh posting contributes ten', () {
      expect(
        scoreUser(
          UserRankingSignals(pubkey: _a, lastPostedAt: _now),
          now: _now,
        ),
        10,
      );
    });
    test('posting halves after seven days', () {
      expect(
        scoreUser(
          UserRankingSignals(
            pubkey: _a,
            lastPostedAt: _now.subtract(const Duration(days: 7)),
          ),
          now: _now,
        ),
        5,
      );
    });
    test('future posting has age zero', () {
      expect(
        scoreUser(
          UserRankingSignals(
            pubkey: _a,
            lastPostedAt: _now.add(const Duration(days: 1)),
          ),
          now: _now,
        ),
        10,
      );
    });
    for (final (count, expected) in [
      (0, 0.0),
      (9, 5 / 3),
      (999, 5.0),
      (9999, 5.0),
      (0x7fffffffffffffff, 5.0),
      (-1, 0.0),
      (-100, 0.0),
    ]) {
      test('video count $count contributes $expected', () {
        expect(
          scoreUser(
            UserRankingSignals(pubkey: _a, videoCount: count),
            now: _now,
          ),
          closeTo(expected, 0.000001),
        );
      });
    }
    test('never-messaged mutual tops out at fifty-eight', () {
      expect(scoreUser(_maxedMutual(), now: _now), 58);
    });
  });

  group('isKnown', () {
    test('an interaction alone makes someone known', () {
      expect(
        isKnown(UserRankingSignals(pubkey: _a, lastInteractionAt: _now)),
        isTrue,
      );
    });
    test('following alone makes someone known', () {
      expect(
        isKnown(const UserRankingSignals(pubkey: _a, youFollow: true)),
        isTrue,
      );
    });
    test('a follower alone is not known', () {
      expect(
        isKnown(const UserRankingSignals(pubkey: _a, followsYou: true)),
        isFalse,
      );
    });
    test('activity and verification do not imply a relationship', () {
      expect(
        isKnown(
          UserRankingSignals(
            pubkey: _a,
            followsYou: false,
            videoCount: 999,
            hasVerifiedNip05: true,
            lastPostedAt: _now,
          ),
        ),
        isFalse,
      );
      expect(isKnown(const UserRankingSignals(pubkey: _a)), isFalse);
    });
  });

  group('rankUsers', () {
    test('ten-day interaction outranks a maxed never-messaged mutual', () {
      final recent = UserRankingSignals(
        pubkey: _a,
        lastInteractionAt: _now.subtract(const Duration(days: 10)),
      );
      expect(rankUsers([_maxedMutual(), recent], now: _now, nameOf: _nameOf), [
        _a,
        _b,
      ]);
    });
    test('twelve-day interaction can be overtaken', () {
      final older = UserRankingSignals(
        pubkey: _a,
        lastInteractionAt: _now.subtract(const Duration(days: 12)),
      );
      expect(rankUsers([older, _maxedMutual()], now: _now, nameOf: _nameOf), [
        _b,
        _a,
      ]);
    });
    test('score ties use case-insensitive name then full pubkey', () {
      final names = {_a: 'alpha', _b: 'ALPHA', _c: 'Zulu'};
      expect(
        rankUsers(
          const [
            UserRankingSignals(pubkey: _c),
            UserRankingSignals(pubkey: _b),
            UserRankingSignals(pubkey: _a),
          ],
          now: _now,
          nameOf: (key) => names[key]!,
        ),
        [_a, _b, _c],
      );
    });
    test('empty and single-candidate lists are supported', () {
      expect(rankUsers([], now: _now, nameOf: _nameOf), isEmpty);
      expect(
        rankUsers(
          const [UserRankingSignals(pubkey: _a)],
          now: _now,
          nameOf: _nameOf,
        ),
        [_a],
      );
    });
    test('does not mutate the input list', () {
      const candidates = [
        UserRankingSignals(pubkey: _b),
        UserRankingSignals(pubkey: _a),
      ];
      expect(candidates.map((s) => s.pubkey), [_b, _a]);
      rankUsers(candidates, now: _now, nameOf: _nameOf);
      expect(candidates.map((s) => s.pubkey), [_b, _a]);
    });
    test(
      'interaction tier uses recency before score and leads non-interactors',
      () {
        final candidates = [
          _maxedMutual(),
          UserRankingSignals(
            pubkey: _a,
            lastInteractionAt: _now.subtract(const Duration(days: 100)),
          ),
          UserRankingSignals(
            pubkey: _c,
            lastInteractionAt: _now.subtract(const Duration(days: 101)),
            youFollow: true,
          ),
          const UserRankingSignals(pubkey: _d),
        ];
        expect(
          rankUsers(
            candidates,
            now: _now,
            nameOf: _nameOf,
            interactionTierFirst: true,
          ),
          [_a, _c, _b, _d],
        );
        expect(
          rankUsers(
            candidates.reversed,
            now: _now,
            nameOf: _nameOf,
            interactionTierFirst: true,
          ),
          [_a, _c, _b, _d],
        );
      },
    );
    test('equal interaction timestamps use score then name and pubkey', () {
      final candidates = [
        UserRankingSignals(pubkey: _c, lastInteractionAt: _now),
        UserRankingSignals(
          pubkey: _b,
          lastInteractionAt: _now,
          youFollow: true,
        ),
        UserRankingSignals(pubkey: _a, lastInteractionAt: _now),
      ];
      expect(
        rankUsers(
          candidates,
          now: _now,
          nameOf: (_) => 'same',
          interactionTierFirst: true,
        ),
        [_b, _a, _c],
      );
    });
  });

  group('promoteKnown', () {
    test('ranks known users first and keeps followers in arrival order', () {
      const page = [_e, _b, _d, _a, _c];
      final signals = {
        _a: const UserRankingSignals(pubkey: _a, youFollow: true),
        _b: const UserRankingSignals(pubkey: _b, followsYou: true),
        _d: const UserRankingSignals(pubkey: _d),
        _e: const UserRankingSignals(
          pubkey: _e,
          videoCount: 999,
          hasVerifiedNip05: true,
        ),
      };
      expect(promoteKnown(page, signals, now: _now, nameOf: _nameOf), [
        _a,
        _e,
        _b,
        _d,
        _c,
      ]);
      expect(page, [_e, _b, _d, _a, _c]);
    });
    test('only page members are promoted', () {
      expect(
        promoteKnown(
          const [_c],
          const {_a: UserRankingSignals(pubkey: _a, youFollow: true)},
          now: _now,
          nameOf: _nameOf,
        ),
        [_c],
      );
    });
    test('known score ties use the standard name tiebreaker', () {
      expect(
        promoteKnown(
          const [_a, _b],
          const {
            _a: UserRankingSignals(pubkey: _a, youFollow: true),
            _b: UserRankingSignals(pubkey: _b, youFollow: true),
          },
          now: _now,
          nameOf: (key) => key == _a ? 'Zulu' : 'Alpha',
        ),
        [_b, _a],
      );
    });
    test('missing signals retain arrival order', () {
      expect(
        promoteKnown(const [_c, _a, _b], const {}, now: _now, nameOf: _nameOf),
        [_c, _a, _b],
      );
      expect(
        promoteKnown(const [], const {}, now: _now, nameOf: _nameOf),
        isEmpty,
      );
    });
  });

  group('UserRankingSignals', () {
    test('equal inputs are interchangeable as collection keys', () {
      final first = UserRankingSignals(
        pubkey: _a,
        lastInteractionAt: DateTime.utc(2026),
        youFollow: true,
        followsYou: true,
        hasVerifiedNip05: true,
        videoCount: 9,
        lastPostedAt: DateTime.utc(2025),
      );
      final same = UserRankingSignals(
        pubkey: _a,
        lastInteractionAt: DateTime.utc(2026),
        youFollow: true,
        followsYou: true,
        hasVerifiedNip05: true,
        videoCount: 9,
        lastPostedAt: DateTime.utc(2025),
      );
      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect({first: 'cached'}[same], 'cached');
      expect(first == first, isTrue);
    });
    test('every signal participates in equality', () {
      const absent = UserRankingSignals(pubkey: _a);
      final different = <Object>[
        const UserRankingSignals(pubkey: _b),
        UserRankingSignals(pubkey: _a, lastInteractionAt: _now),
        const UserRankingSignals(pubkey: _a, youFollow: true),
        const UserRankingSignals(pubkey: _a, followsYou: false),
        const UserRankingSignals(pubkey: _a, hasVerifiedNip05: true),
        const UserRankingSignals(pubkey: _a, videoCount: 0),
        UserRankingSignals(pubkey: _a, lastPostedAt: _now),
        Object(),
      ];
      for (final value in different) {
        expect(absent, isNot(value));
      }
    });
  });
}
