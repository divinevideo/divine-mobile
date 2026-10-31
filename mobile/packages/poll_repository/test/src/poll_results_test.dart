// ABOUTME: Tests how the votes on a poll are counted: one per pubkey, the
// ABOUTME: latest or for a quiz the first, and a slider's average.

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:test/test.dart';

const _pollId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

Event _vote(
  int voter,
  String optionId, {
  int createdAt = 1000,
  int id = 0,
  String pollId = _pollId,
  int kind = Poll.voteKind,
  List<List<String>>? tags,
}) => Event.fromJson({
  'id': _hex(id == 0 ? voter * 1000 + createdAt : id),
  'pubkey': _hex(voter),
  'created_at': createdAt,
  'kind': kind,
  'tags':
      tags ??
      [
        ['e', pollId],
        ['response', optionId],
      ],
  'content': '',
  'sig': '',
});

Poll _withId(Poll poll) => Poll(
  id: _pollId,
  question: poll.question,
  options: poll.options,
  kind: poll.kind,
  answerId: poll.answerId,
  emoji: poll.emoji,
);

void main() {
  final poll = _withId(
    Poll.choice(question: 'Which?', answers: const ['Red', 'Blue', 'Green']),
  );

  group(PollResults, () {
    group('counted', () {
      test('leaves out the answers nobody picked', () {
        final results = PollResults.counted(const {'0': 3, '1': 0});

        expect(results.counts, equals({'0': 3}));
        expect(results.ownVoteId, isNull);
      });

      test("counts the viewer's own vote once when the count lacks it", () {
        final results = PollResults.counted(const {'0': 3}, ownVoteId: '1');

        expect(results.counts, equals({'0': 3, '1': 1}));
        expect(results.ownVoteId, equals('1'));
      });

      test("keeps a count that already holds the viewer's vote", () {
        final results = PollResults.counted(const {'1': 5}, ownVoteId: '1');

        expect(results.counts, equals({'1': 5}));
      });
    });

    group('tally', () {
      test('counts each pubkey once, by its latest vote', () {
        final results = PollResults.tally(poll, [
          _vote(1, '0'),
          _vote(1, '1', createdAt: 2000),
          _vote(2, '1'),
          _vote(3, '2'),
        ]);

        expect(results.counts, equals({'1': 2, '2': 1}));
        expect(results.total, equals(3));
      });

      test('settles two votes of the same second by their id', () {
        final results = PollResults.tally(poll, [
          _vote(1, '1', id: 9),
          _vote(1, '0', id: 5),
        ]);

        expect(results.counts, equals({'1': 1}));
      });

      test('counts a quiz answer by the first one given', () {
        final quiz = _withId(
          Poll.choice(
            question: 'Capital?',
            answers: const ['Zurich', 'Bern'],
            answerIndex: 1,
          ),
        );

        final results = PollResults.tally(quiz, [
          _vote(1, '0'),
          _vote(1, '1', createdAt: 2000),
        ]);

        expect(results.counts, equals({'0': 1}));
      });

      test('counts only the first response of a vote', () {
        final results = PollResults.tally(poll, [
          _vote(
            1,
            '',
            tags: [
              ['e', _pollId],
              ['response', '2'],
              ['response', '0'],
            ],
          ),
          _vote(
            2,
            '',
            tags: [
              ['e', _pollId],
              ['response', 'x'],
              ['response', '0'],
            ],
          ),
        ]);

        expect(results.counts, equals({'2': 1}));
      });

      test('ignores what is no vote on this poll', () {
        final results = PollResults.tally(poll, [
          _vote(1, '0', kind: 7),
          _vote(2, '0', pollId: _hex(99)),
          _vote(
            3,
            '',
            tags: [
              ['e', _pollId],
            ],
          ),
          _vote(4, 'nope'),
        ]);

        expect(results.total, equals(0));
      });

      test("tells the viewer's own vote", () {
        final results = PollResults.tally(poll, [
          _vote(1, '0'),
          _vote(2, '2'),
        ], viewerPubkey: _hex(2));

        expect(results.ownVoteId, equals('2'));
        expect(results.hasVoted, isTrue);
        expect(
          PollResults.tally(poll, [_vote(1, '0')]).hasVoted,
          isFalse,
        );
      });
    });

    group('shareOf', () {
      test('is the part of the votes an answer has', () {
        const results = PollResults(counts: {'0': 1, '1': 3});

        expect(results.shareOf('1'), equals(0.75));
        expect(results.countOf('2'), equals(0));
        expect(const PollResults().shareOf('0'), equals(0));
      });
    });

    group('averageOn', () {
      test('is where a slider is rated on average, along its scale', () {
        final slider = _withId(Poll.slider(question: 'Hungry?', emoji: '😋'));
        const results = PollResults(counts: {'20': 1, '80': 2, 'x': 4});

        expect(results.averageOn(slider), closeTo(0.6, 1e-9));
        expect(const PollResults().averageOn(slider), isNull);
      });
    });

    group('withOwnVote', () {
      test('moves the viewer to their new answer', () {
        const results = PollResults(counts: {'0': 1, '1': 2}, ownVoteId: '0');

        expect(
          results.withOwnVote('1'),
          equals(const PollResults(counts: {'1': 3}, ownVoteId: '1')),
        );
        expect(
          const PollResults(counts: {'1': 2}, ownVoteId: '1').withOwnVote('0'),
          equals(const PollResults(counts: {'1': 1, '0': 1}, ownVoteId: '0')),
        );
      });

      test('adds a first vote', () {
        expect(
          const PollResults().withOwnVote('2'),
          equals(const PollResults(counts: {'2': 1}, ownVoteId: '2')),
        );
      });
    });
  });

  group(PollSnapshot, () {
    test('holds a poll with its results', () {
      final snapshot = PollSnapshot(poll: poll, results: const PollResults());

      expect(
        snapshot,
        equals(PollSnapshot(poll: poll, results: const PollResults())),
      );
    });
  });
}
