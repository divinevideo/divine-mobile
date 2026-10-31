// ABOUTME: Tests the poll event a video's poll, quiz or slider is published as,
// ABOUTME: and how one is read back from an event.

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:test/test.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pollId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Event _event({
  required List<List<String>> tags,
  String content = 'Which one?',
  int kind = Poll.eventKind,
}) => Event.fromJson({
  'id': _pollId,
  'pubkey': _author,
  'created_at': 1000,
  'kind': kind,
  'tags': tags,
  'content': content,
  'sig': '',
});

void main() {
  group(Poll, () {
    group('choice', () {
      test('numbers the answers in order', () {
        final poll = Poll.choice(
          question: 'Which?',
          answers: const ['Red', 'Blue'],
        );

        expect(poll.kind, equals(PollKind.poll));
        expect(
          poll.options,
          equals(const [
            PollOption(id: '0', label: 'Red'),
            PollOption(id: '1', label: 'Blue'),
          ]),
        );
        expect(poll.answerId, isNull);
      });

      test('makes a quiz of a poll with a right answer', () {
        final quiz = Poll.choice(
          question: 'Capital?',
          answers: const ['Zurich', 'Bern'],
          answerIndex: 1,
        );

        expect(quiz.kind, equals(PollKind.quiz));
        expect(quiz.answerId, equals('1'));
      });
    });

    group('slider', () {
      test('rates in eleven steps from 0 to 100', () {
        final slider = Poll.slider(question: 'Hungry?', emoji: '😋');

        expect(slider.kind, equals(PollKind.slider));
        expect(slider.emoji, equals('😋'));
        expect(
          slider.options.map((option) => option.id),
          equals([
            '0',
            '10',
            '20',
            '30',
            '40',
            '50',
            '60',
            '70',
            '80',
            '90',
            '100',
          ]),
        );
      });

      test('takes the step nearest a point along the scale', () {
        final slider = Poll.slider(question: 'Hungry?', emoji: '😋');

        expect(slider.sliderOptionAt(0.64), equals('60'));
        expect(slider.sliderOptionAt(0.66), equals('70'));
        expect(slider.sliderOptionAt(-1), equals('0'));
        expect(slider.sliderOptionAt(2), equals('100'));
      });

      test('reads a step as its value only on a slider', () {
        final slider = Poll.slider(question: 'Hungry?', emoji: '😋');
        final poll = Poll.choice(question: 'Which?', answers: const ['1', '2']);

        expect(slider.valueOf('70'), equals(70));
        expect(slider.valueOf('75'), isNull);
        expect(poll.valueOf('1'), isNull);
      });
    });

    group('toTags', () {
      test('publishes a quiz with its answer, as a single choice', () {
        final quiz = Poll.choice(
          question: 'Capital?',
          answers: const ['Zurich', 'Bern'],
          answerIndex: 1,
        );

        expect(
          quiz.toTags(relayUrl: 'wss://relay.divine.video'),
          equals([
            ['option', '0', 'Zurich'],
            ['option', '1', 'Bern'],
            ['relay', 'wss://relay.divine.video'],
            ['polltype', 'singlechoice'],
            ['answer', '1'],
          ]),
        );
      });

      test('publishes a slider with its emoji and no relay', () {
        final tags = Poll.slider(question: 'Hungry?', emoji: '😋').toTags();

        expect(tags.last, equals(['slider', '😋']));
        expect(tags.where((tag) => tag[0] == 'relay'), isEmpty);
      });
    });

    group('voteTags', () {
      test('names the poll and the answer', () {
        expect(
          Poll.voteTags(_pollId, '1', relayUrl: 'wss://relay.divine.video'),
          equals([
            ['e', _pollId, 'wss://relay.divine.video'],
            ['response', '1'],
          ]),
        );
        expect(Poll.voteTags(_pollId, '1').first, equals(['e', _pollId]));
      });
    });

    group('fromEvent', () {
      test('reads back the poll it publishes', () {
        final quiz = Poll.choice(
          question: 'Capital?',
          answers: const ['Zurich', 'Bern'],
          answerIndex: 1,
        );

        final read = Poll.fromEvent(
          _event(content: quiz.question, tags: quiz.toTags()),
        );

        expect(read?.id, equals(_pollId));
        expect(read?.authorPubkey, equals(_author));
        expect(read?.kind, equals(PollKind.quiz));
        expect(read?.options, equals(quiz.options));
        expect(read?.answerId, equals('1'));
        expect(
          read,
          equals(
            Poll(
              id: _pollId,
              authorPubkey: _author,
              question: quiz.question,
              options: quiz.options,
              kind: PollKind.quiz,
              answerId: '1',
            ),
          ),
        );
      });

      test('reads back a slider', () {
        final slider = Poll.slider(question: 'Hungry?', emoji: '😋');

        final read = Poll.fromEvent(
          _event(content: slider.question, tags: slider.toTags()),
        );

        expect(read?.kind, equals(PollKind.slider));
        expect(read?.emoji, equals('😋'));
      });

      test('skips broken and repeated answers', () {
        final read = Poll.fromEvent(
          _event(
            tags: [
              ['option', 'a', 'Red'],
              ['option', 'a', 'Again'],
              ['option', '', 'No id'],
              ['option', 'c'],
              ['option', 'b', 'Blue'],
            ],
          ),
        );

        expect(read?.options.map((option) => option.label), ['Red', 'Blue']);
      });

      test('reads an answer that is no option, or a slider of other '
          'steps, as an ordinary poll', () {
        final read = [
          _event(
            tags: [
              ['option', 'a', 'Red'],
              ['option', 'b', 'Blue'],
              ['answer', 'z'],
            ],
          ),
          _event(
            tags: [
              ['option', 'a', 'Red'],
              ['option', '50', 'Half'],
              ['slider', '😋'],
            ],
          ),
        ].map(Poll.fromEvent);

        for (final poll in read) {
          expect(poll?.kind, equals(PollKind.poll));
          expect(poll?.answerId, isNull);
          expect(poll?.emoji, isNull);
        }
      });

      test('drops an event that is no poll with a question and two '
          'answers', () {
        final answers = [
          ['option', 'a', 'Red'],
          ['option', 'b', 'Blue'],
        ];
        expect(
          [
            _event(tags: answers, kind: 1),
            _event(tags: answers, content: '  '),
            _event(tags: answers.sublist(1)),
          ].map(Poll.fromEvent),
          everyElement(isNull),
        );
      });
    });
  });
}
