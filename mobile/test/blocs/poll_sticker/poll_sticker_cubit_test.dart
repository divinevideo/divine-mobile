// ABOUTME: Tests the poll behind a sticker on a playing video: reading it with
// ABOUTME: its votes, and the viewer's vote shown at once or taken back.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/poll_sticker/poll_sticker_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPollRepository extends Mock implements PollRepository {}

final String _pollId = 'c' * 64;
final String _author = 'a' * 64;

Poll _published(Poll poll) => Poll(
  id: _pollId,
  authorPubkey: _author,
  question: poll.question,
  options: poll.options,
  kind: poll.kind,
  answerId: poll.answerId,
  emoji: poll.emoji,
);

final Poll _poll = _published(
  Poll.choice(question: 'Which one?', answers: const ['Red', 'Blue']),
);

final Poll _quiz = _published(
  Poll.choice(
    question: 'Vine launched in…',
    answers: const ['2013', '2015'],
    answerIndex: 0,
  ),
);

void main() {
  group(PollStickerCubit, () {
    late _MockPollRepository repository;
    late SharedPreferences preferences;

    setUpAll(() => registerFallbackValue(_poll));

    setUp(() async {
      repository = _MockPollRepository();
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    PollStickerCubit build({PollKind kind = PollKind.poll, int answers = 2}) =>
        PollStickerCubit(
          repository: repository,
          preferences: preferences,
          pollId: _pollId,
          authorPubkey: _author,
          kind: kind,
          answerCount: answers,
        );

    void stubFetch(Poll poll, [PollResults results = const PollResults()]) =>
        when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenAnswer((_) async => PollSnapshot(poll: poll, results: results));

    group('load', () {
      blocTest<PollStickerCubit, PollStickerState>(
        'reads the poll with its votes',
        setUp: () => stubFetch(
          _poll,
          const PollResults(counts: {'0': 1, '1': 3}, ownVoteId: '1'),
        ),
        build: build,
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.status, equals(PollStickerStatus.ready));
          expect(cubit.state.shares, equals([0.25, 0.75]));
          expect(cubit.state.ownAnswerIndex, equals(1));
        },
      );

      blocTest<PollStickerCubit, PollStickerState>(
        'is unavailable for a poll other than the one the sticker shows',
        setUp: () => stubFetch(_quiz),
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PollStickerState(status: PollStickerStatus.unavailable),
        ],
      );

      blocTest<PollStickerCubit, PollStickerState>(
        'is unavailable when no relay has the poll or none can be read',
        setUp: () => when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenThrow(Exception('offline')),
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PollStickerState(status: PollStickerStatus.unavailable),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('voted', () {
      blocTest<PollStickerCubit, PollStickerState>(
        'shows the vote at once and says when it was the first',
        setUp: () {
          stubFetch(_poll, const PollResults(counts: {'0': 1}));
          when(() => repository.vote(any(), any())).thenAnswer((_) async {});
        },
        build: build,
        act: (cubit) async {
          await cubit.load();
          await cubit.voted('1');
        },
        skip: 1,
        expect: () => [
          PollStickerState(
            status: PollStickerStatus.ready,
            poll: _poll,
            results: const PollResults(
              counts: {'0': 1, '1': 1},
              ownVoteId: '1',
            ),
            voteStatus: PollVoteStatus.sending,
          ),
          PollStickerState(
            status: PollStickerStatus.ready,
            poll: _poll,
            results: const PollResults(
              counts: {'0': 1, '1': 1},
              ownVoteId: '1',
            ),
            voteStatus: PollVoteStatus.sent,
            isFirstVote: true,
          ),
        ],
        verify: (_) {
          verify(() => repository.vote(_poll, '1')).called(1);
          expect(
            preferences.getBool(PollStickerCubit.publicNoteShownKey),
            isTrue,
          );
        },
      );

      blocTest<PollStickerCubit, PollStickerState>(
        'takes the vote back when it cannot be sent',
        setUp: () {
          stubFetch(_poll, const PollResults(counts: {'0': 1}, ownVoteId: '0'));
          when(
            () => repository.vote(any(), any()),
          ).thenThrow(const PollVoteException('No relay took the vote'));
        },
        build: build,
        act: (cubit) async {
          await cubit.load();
          await cubit.voted('1');
        },
        verify: (cubit) {
          expect(cubit.state.voteStatus, equals(PollVoteStatus.failed));
          expect(
            cubit.state.results,
            equals(const PollResults(counts: {'0': 1}, ownVoteId: '0')),
          );
        },
        errors: () => [isA<PollVoteException>()],
      );

      blocTest<PollStickerCubit, PollStickerState>(
        'takes the vote back and reports whatever else stops it',
        setUp: () {
          stubFetch(_poll, const PollResults(counts: {'0': 1}));
          when(
            () => repository.vote(any(), any()),
          ).thenThrow(StateError('signer gone'));
        },
        build: build,
        act: (cubit) async {
          await cubit.load();
          await cubit.voted('1');
        },
        verify: (cubit) {
          expect(cubit.state.voteStatus, equals(PollVoteStatus.failed));
          expect(
            cubit.state.results,
            equals(const PollResults(counts: {'0': 1})),
          );
        },
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      test('keeps the note for a later vote when the video is gone before '
          'the vote went out', () async {
        stubFetch(_poll);
        final sent = Completer<void>();
        when(() => repository.vote(any(), any()))
            .thenAnswer((_) => sent.future);
        final cubit = build();
        await cubit.load();

        final voting = cubit.voted('1');
        await cubit.close();
        sent.complete();
        await voting;

        expect(
          preferences.getBool(PollStickerCubit.publicNoteShownKey),
          isNull,
        );
      });

      blocTest<PollStickerCubit, PollStickerState>(
        'keeps the answer a quiz was given',
        setUp: () => stubFetch(
          _quiz,
          const PollResults(counts: {'1': 1}, ownVoteId: '1'),
        ),
        build: () => build(kind: PollKind.quiz),
        act: (cubit) async {
          await cubit.load();
          await cubit.voted('0');
        },
        verify: (cubit) {
          expect(cubit.state.ownAnswerIndex, equals(1));
          expect(cubit.state.rightAnswerIndex, equals(0));
          verifyNever(() => repository.vote(any(), any()));
        },
      );
    });
  });

  group(PollStickerState, () {
    test('tells where a slider stands on average and where the viewer '
        'put it', () {
      final slider = _published(Poll.slider(question: 'Hungry?', emoji: '😋'));

      final state = PollStickerState(
        poll: slider,
        results: const PollResults(counts: {'20': 1, '60': 1}, ownVoteId: '60'),
      );

      expect(state.sliderAverage, closeTo(0.4, 1e-9));
      expect(state.ownSliderValue, closeTo(0.6, 1e-9));
    });
  });
}
