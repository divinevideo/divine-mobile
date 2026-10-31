part of 'question_answer_cubit.dart';

/// Where sending an answer to a question sticker stands.
enum QuestionAnswerStatus {
  /// Being written.
  editing,

  /// On its way.
  sending,

  /// Sent, or queued to go out as soon as the relays answer.
  sent,

  /// Too long to send as one message.
  tooLong,

  /// Could not be sent.
  failed,
}

/// An answer to a question sticker as the viewer sends it.
class QuestionAnswerState extends Equatable {
  const QuestionAnswerState({this.status = QuestionAnswerStatus.editing});

  final QuestionAnswerStatus status;

  @override
  List<Object?> get props => [status];
}
