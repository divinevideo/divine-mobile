// ABOUTME: A NIP-88 poll on a Divine video: its question and answers, a quiz's
// ABOUTME: right answer or a slider's emoji, and the tags of its events.

import 'package:equatable/equatable.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// What a viewer does with a [Poll].
enum PollKind {
  /// Picks one of two to four answers, and can change their pick.
  poll,

  /// Picks one answer and then sees the right one; the pick holds.
  quiz,

  /// Drags an emoji along a scale from 0 to 100.
  slider,
}

/// One answer of a [Poll]: the id a vote names it by and what it says.
class PollOption extends Equatable {
  /// Creates an answer.
  const PollOption({required this.id, required this.label});

  /// The id a vote names the answer by.
  final String id;

  /// What the answer says; a slider's step says its value.
  final String label;

  @override
  List<Object?> get props => [id, label];
}

/// A NIP-88 poll, published as a `kind:1068` event whose content is the
/// question and whose `option` tags are the answers.
///
/// A quiz adds Divine's `["answer", "<option id>"]` tag, which other clients
/// ignore and anyone can read in the raw event. A slider is a poll of eleven
/// steps from 0 to 100 with Divine's `["slider", "<emoji>"]` tag; other
/// clients show it as an ordinary poll.
class Poll extends Equatable {
  /// Creates a poll.
  const Poll({
    required this.question,
    required this.options,
    this.kind = PollKind.poll,
    this.answerId,
    this.emoji,
    this.id = '',
    this.authorPubkey = '',
  });

  /// A poll asking [question] with [answers] in order, or with an
  /// [answerIndex] a quiz whose right answer is that one.
  factory Poll.choice({
    required String question,
    required List<String> answers,
    int? answerIndex,
  }) {
    final options = [
      for (final (index, answer) in answers.indexed)
        PollOption(id: '$index', label: answer),
    ];
    return Poll(
      question: question,
      options: options,
      kind: answerIndex == null ? PollKind.poll : PollKind.quiz,
      answerId: answerIndex == null ? null : options[answerIndex].id,
    );
  }

  /// A slider asking [question], rated with [emoji].
  factory Poll.slider({required String question, required String emoji}) =>
      Poll(
        question: question,
        options: [
          for (var value = 0; value <= maxSliderValue; value += sliderStep)
            PollOption(id: '$value', label: '$value'),
        ],
        kind: PollKind.slider,
        emoji: emoji,
      );

  /// The kind of a poll event.
  static const int eventKind = 1068;

  /// The kind of a vote on a poll.
  static const int voteKind = 1018;

  /// The fewest answers a poll or a quiz has.
  static const int minOptions = 2;

  /// The most answers a poll or a quiz has.
  static const int maxOptions = 4;

  /// The top of a slider's scale.
  static const int maxSliderValue = 100;

  /// How far apart a slider's steps are.
  static const int sliderStep = 10;

  /// The id of the poll's event; empty before it is signed.
  final String id;

  /// The hex public key of whoever published the poll; empty before it is
  /// signed.
  final String authorPubkey;

  /// What a viewer does with the poll.
  final PollKind kind;

  /// The question.
  final String question;

  /// The answers, in the order they show.
  final List<PollOption> options;

  /// The id of a quiz's right answer.
  final String? answerId;

  /// The emoji a slider is rated with.
  final String? emoji;

  /// Whether [optionId] names one of the answers.
  bool hasOption(String optionId) =>
      options.any((option) => option.id == optionId);

  /// Where on a slider's scale [optionId] stands, or `null` when it names no
  /// step of it.
  int? valueOf(String optionId) {
    if (kind != PollKind.slider || !hasOption(optionId)) return null;
    return int.tryParse(optionId);
  }

  /// The step of a slider's scale nearest [value], from 0 to 1 along it.
  String sliderOptionAt(double value) {
    const steps = maxSliderValue ~/ sliderStep;
    final step = (value.clamp(0, 1) * steps).round();
    return '${step * sliderStep}';
  }

  /// The tags of the poll's event, its votes expected on [relayUrl].
  List<List<String>> toTags({String? relayUrl}) => [
    for (final option in options) ['option', option.id, option.label],
    if (relayUrl != null) ['relay', relayUrl],
    const ['polltype', 'singlechoice'],
    if (answerId case final answer?) [answerTagName, answer],
    if (emoji case final emoji?) [sliderTagName, emoji],
  ];

  /// The tags of a vote for [optionId] on the poll [pollId], cast on
  /// [relayUrl].
  static List<List<String>> voteTags(
    String pollId,
    String optionId, {
    String? relayUrl,
  }) => [
    ['e', pollId, ?relayUrl],
    ['response', optionId],
  ];

  /// The name of the tag naming a quiz's right answer.
  static const String answerTagName = 'answer';

  /// The name of the tag naming a slider's emoji.
  static const String sliderTagName = 'slider';

  /// The poll [event] publishes, or `null` when it is no poll with a
  /// question and at least [minOptions] answers.
  ///
  /// A quiz needs its answer among the answers, and a slider its emoji and
  /// only steps on its scale; otherwise the poll reads as an ordinary one.
  static Poll? fromEvent(Event event) {
    final question = event.content.trim();
    if (event.kind != eventKind || question.isEmpty) return null;
    final options = <PollOption>[];
    for (final tag in event.tags) {
      if (tag.length < 3 || tag[0] != 'option') continue;
      final id = tag[1].trim();
      final label = tag[2].trim();
      if (id.isEmpty || label.isEmpty) continue;
      if (options.any((option) => option.id == id)) continue;
      options.add(PollOption(id: id, label: label));
    }
    if (options.length < minOptions) return null;

    String? tagValue(String name) => event.tags
        .where((tag) => tag.length >= 2 && tag[0] == name)
        .map((tag) => tag[1].trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final emoji = tagValue(sliderTagName);
    final answerId = tagValue(answerTagName);
    final isSlider =
        emoji != null &&
        options.every((option) {
          final value = int.tryParse(option.id);
          return value != null && value >= 0 && value <= maxSliderValue;
        });
    final isQuiz =
        !isSlider &&
        answerId != null &&
        options.any((option) => option.id == answerId);
    return Poll(
      id: event.id,
      authorPubkey: event.pubkey,
      question: question,
      options: options,
      kind: isSlider
          ? PollKind.slider
          : isQuiz
          ? PollKind.quiz
          : PollKind.poll,
      answerId: isQuiz ? answerId : null,
      emoji: isSlider ? emoji : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    authorPubkey,
    kind,
    question,
    options,
    answerId,
    emoji,
  ];
}
