// ABOUTME: Sends a viewer's answer to a question sticker as a private message to
// ABOUTME: the video's creator, citing the video and naming the question.

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/question_answer_target.dart';

part 'question_answer_state.dart';

/// Sends answers to the question sticker [QuestionAnswerTarget] names.
///
/// The answer is an ordinary NIP-17 message to the creator. It cites the
/// video, so their messages show it, and names the question in a
/// [questionAnswerTagName] tag, so they see what was asked.
class QuestionAnswerCubit extends Cubit<QuestionAnswerState>
    with CloseGuardedEmit<QuestionAnswerState> {
  QuestionAnswerCubit({
    required DmRepository dmRepository,
    required QuestionAnswerTarget target,
  }) : _dmRepository = dmRepository,
       _target = target,
       super(const QuestionAnswerState());

  final DmRepository _dmRepository;
  final QuestionAnswerTarget _target;

  /// The most characters an answer can have.
  static const int maxAnswerLength = 500;

  /// Sends [text] as the answer; a blank one, or one while another is on its
  /// way, is left alone.
  Future<void> submit(String text) async {
    final answer = text.trim();
    if (answer.isEmpty || state.status == QuestionAnswerStatus.sending) {
      return;
    }
    emit(const QuestionAnswerState(status: QuestionAnswerStatus.sending));
    try {
      final result = await _dmRepository.sendSharedVideo(
        recipientPubkey: _target.creatorPubkey,
        baseContent: answer,
        videoKind: NIP71VideoKinds.addressableShortVideo,
        videoAuthorPubkey: _target.creatorPubkey,
        videoDTag: _target.videoDTag,
        videoEventId: _target.videoId,
        additionalTags: [_target.questionTag],
        // An answer goes to its creator only, never as a plaintext copy.
        skipNip04Fallback: true,
        backgroundDelivery: true,
      );
      emitIfOpen(
        QuestionAnswerState(
          status: result.tooLong
              ? QuestionAnswerStatus.tooLong
              : result.success || result.retryablePending
              ? QuestionAnswerStatus.sent
              : QuestionAnswerStatus.failed,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        const QuestionAnswerState(status: QuestionAnswerStatus.failed),
      );
    }
  }
}
