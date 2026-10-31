// ABOUTME: The question sticker a viewer answers privately: whose video, which
// ABOUTME: one, and what it asks; and the tag the answer carries in a DM.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show DmMessage, NostrHexUtils;

/// The name of the tag a private answer to a question sticker carries, with
/// the question it answers and the video's event id, so the creator's
/// messages show what was asked and can answer it with a video.
const String questionAnswerTagName = DmMessage.questionTagName;

/// The question sticker a viewer answers in a private message to the
/// creator of the video it is on.
class QuestionAnswerTarget extends Equatable {
  const QuestionAnswerTarget({
    required this.creatorPubkey,
    required this.question,
    this.videoId,
    this.videoDTag,
  });

  /// The hex pubkey of the video's creator, who gets the answer.
  final String creatorPubkey;

  /// What the sticker asks.
  final String question;

  /// The video's event id, when it is known.
  final String? videoId;

  /// The video's d-tag, which names it across edits, when it is known.
  final String? videoDTag;

  /// Whether the answer has someone to go to, a video to cite and a
  /// question to name.
  bool get isValid =>
      NostrHexUtils.isValidPubkey(creatorPubkey) &&
      question.trim().isNotEmpty &&
      (NostrHexUtils.isValidEventId(videoId ?? '') ||
          (videoDTag?.isNotEmpty ?? false));

  /// The tag the answer carries, naming the question and, when it is known,
  /// the video's event id.
  List<String> get questionTag => [
    questionAnswerTagName,
    question.trim(),
    ?videoId,
  ];

  @override
  List<Object?> get props => [creatorPubkey, question, videoId, videoDTag];
}
