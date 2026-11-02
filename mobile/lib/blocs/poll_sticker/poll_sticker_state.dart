part of 'poll_sticker_cubit.dart';

/// Whether the poll behind a sticker is there to vote on.
enum PollStickerStatus {
  /// Being read from the relays.
  loading,

  /// Read, with the votes on it.
  ready,

  /// Not found, not the poll the sticker shows, or the relays could not be
  /// read; the sticker stays as the frames show it.
  unavailable,
}

/// Where the viewer's last vote is.
enum PollVoteStatus {
  /// No vote cast here.
  idle,

  /// On its way to the relays.
  sending,

  /// Taken by a relay.
  sent,

  /// Could not be sent, and taken back.
  failed,
}

/// The poll behind a sticker, the votes on it and the viewer's own.
class PollStickerState extends Equatable {
  const PollStickerState({
    this.status = PollStickerStatus.loading,
    this.poll,
    this.results = const PollResults(),
    this.voteStatus = PollVoteStatus.idle,
    this.isFirstVote = false,
  });

  final PollStickerStatus status;

  /// The poll, once read.
  final Poll? poll;

  /// The votes on it, the viewer's included.
  final PollResults results;

  final PollVoteStatus voteStatus;

  /// Whether the vote just sent was the first the viewer cast on this phone,
  /// after which they are told, once, that votes are public.
  final bool isFirstVote;

  /// The share of the votes each answer has, in the order of the answers.
  List<double> get shares => [
    for (final option in poll?.options ?? const <PollOption>[])
      results.shareOf(option.id),
  ];

  /// The index of the answer the viewer picked, or `null` before they vote.
  int? get ownAnswerIndex => _indexOf(results.ownVoteId);

  /// The index of a quiz's right answer.
  int? get rightAnswerIndex => _indexOf(poll?.answerId);

  /// Where a slider stands on average, from 0 to 1.
  double? get sliderAverage {
    final poll = this.poll;
    return poll == null ? null : results.averageOn(poll);
  }

  /// Where the viewer put a slider's emoji, from 0 to 1, or `null` before
  /// they rated it.
  double? get ownSliderValue {
    final own = results.ownVoteId;
    final value = own == null ? null : poll?.valueOf(own);
    return value == null ? null : value / Poll.maxSliderValue;
  }

  int? _indexOf(String? optionId) {
    if (optionId == null) return null;
    final index =
        poll?.options.indexWhere((option) => option.id == optionId) ?? -1;
    return index < 0 ? null : index;
  }

  PollStickerState copyWith({
    PollStickerStatus? status,
    Poll? poll,
    PollResults? results,
    PollVoteStatus? voteStatus,
    bool? isFirstVote,
  }) => PollStickerState(
    status: status ?? this.status,
    poll: poll ?? this.poll,
    results: results ?? this.results,
    voteStatus: voteStatus ?? this.voteStatus,
    isFirstVote: isFirstVote ?? this.isFirstVote,
  );

  @override
  List<Object?> get props => [status, poll, results, voteStatus, isFirstVote];
}
