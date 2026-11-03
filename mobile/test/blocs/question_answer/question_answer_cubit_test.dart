// ABOUTME: Tests sending an answer to a question sticker: a private message to
// ABOUTME: the creator citing the video and naming the question.

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/models/question_answer_target.dart';

class _MockDmRepository extends Mock implements DmRepository {}

final String _creator = '1'.padLeft(64, '0');
final String _videoId = 'a'.padLeft(64, '0');

void main() {
  group(QuestionAnswerCubit, () {
    late _MockDmRepository dmRepository;
    final target = QuestionAnswerTarget(
      creatorPubkey: _creator,
      question: 'Ask me anything',
      videoId: _videoId,
      videoDTag: 'video-d',
    );

    setUp(() => dmRepository = _MockDmRepository());

    void answers(Future<NIP17SendResult> Function() result) => when(
      () => dmRepository.sendSharedVideo(
        recipientPubkey: any(named: 'recipientPubkey'),
        baseContent: any(named: 'baseContent'),
        videoKind: any(named: 'videoKind'),
        videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
        videoDTag: any(named: 'videoDTag'),
        videoEventId: any(named: 'videoEventId'),
        additionalTags: any(named: 'additionalTags'),
        skipNip04Fallback: any(named: 'skipNip04Fallback'),
        backgroundDelivery: any(named: 'backgroundDelivery'),
      ),
    ).thenAnswer((_) => result());

    QuestionAnswerCubit build() =>
        QuestionAnswerCubit(dmRepository: dmRepository, target: target);

    group('submit', () {
      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'sends the answer privately, citing the video and the question',
        setUp: () => answers(
          () async => NIP17SendResult.success(
            rumorEventId: _videoId,
            messageEventId: _videoId,
            recipientPubkey: _creator,
          ),
        ),
        build: build,
        act: (cubit) => cubit.submit('  Pizza  '),
        expect: () => const [
          QuestionAnswerState(status: QuestionAnswerStatus.sending),
          QuestionAnswerState(status: QuestionAnswerStatus.sent),
        ],
        verify: (_) => verify(
          () => dmRepository.sendSharedVideo(
            recipientPubkey: _creator,
            baseContent: 'Pizza',
            videoKind: NIP71VideoKinds.addressableShortVideo,
            videoAuthorPubkey: _creator,
            videoDTag: 'video-d',
            videoEventId: _videoId,
            additionalTags: [
              [questionAnswerTagName, 'Ask me anything', _videoId],
            ],
            skipNip04Fallback: true,
            backgroundDelivery: true,
          ),
        ).called(1),
      );

      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'leaves a blank answer alone',
        build: build,
        act: (cubit) => cubit.submit('   '),
        expect: () => const <QuestionAnswerState>[],
      );

      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'tells when the answer is too long',
        setUp: () =>
            answers(() async => const NIP17SendResult.tooLong('too long')),
        build: build,
        act: (cubit) => cubit.submit('Pizza'),
        skip: 1,
        expect: () => const [
          QuestionAnswerState(status: QuestionAnswerStatus.tooLong),
        ],
      );

      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'tells when the answer could not be sent',
        setUp: () =>
            answers(() async => const NIP17SendResult.failure('offline')),
        build: build,
        act: (cubit) => cubit.submit('Pizza'),
        skip: 1,
        expect: () => const [
          QuestionAnswerState(status: QuestionAnswerStatus.failed),
        ],
      );

      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'tells when sending threw',
        setUp: () => answers(() async => throw StateError('not ready')),
        build: build,
        act: (cubit) => cubit.submit('Pizza'),
        skip: 1,
        expect: () => const [
          QuestionAnswerState(status: QuestionAnswerStatus.failed),
        ],
        errors: () => [isA<StateError>()],
      );

      blocTest<QuestionAnswerCubit, QuestionAnswerState>(
        'sends one answer at a time',
        build: build,
        seed: () => const QuestionAnswerState(
          status: QuestionAnswerStatus.sending,
        ),
        act: (cubit) => cubit.submit('Pizza'),
        expect: () => const <QuestionAnswerState>[],
      );
    });
  });

  group(QuestionAnswerTarget, () {
    test('needs a creator, a video and a question', () {
      expect(
        QuestionAnswerTarget(
          creatorPubkey: _creator,
          question: 'Q?',
          videoDTag: 'd',
        ).isValid,
        isTrue,
      );
      expect(
        [
          QuestionAnswerTarget(
            creatorPubkey: 'nope',
            question: 'Q?',
            videoId: _videoId,
          ),
          QuestionAnswerTarget(
            creatorPubkey: _creator,
            question: ' ',
            videoId: _videoId,
          ),
          QuestionAnswerTarget(creatorPubkey: _creator, question: 'Q?'),
        ].map((target) => target.isValid),
        everyElement(isFalse),
      );
    });
  });
}
