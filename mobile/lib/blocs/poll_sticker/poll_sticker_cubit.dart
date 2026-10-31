// ABOUTME: Loads the poll a poll, quiz or slider sticker on a playing video
// ABOUTME: points to, with the votes on it, and casts the viewer's vote.

import 'package:collection/collection.dart' show ListEquality;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'poll_sticker_state.dart';

/// The poll behind one poll, quiz or slider sticker on the active video, and
/// the viewer's vote on it.
class PollStickerCubit extends Cubit<PollStickerState>
    with CloseGuardedEmit<PollStickerState> {
  /// Reads the poll [pollId] by [authorPubkey], whose video shows it, through
  /// [repository]. The sticker in the video is a [kind] asking [question], with
  /// [answers] or a slider's [emoji]; a poll of another kind, or asking or
  /// offering anything else, is not the one it shows, and reads as unavailable.
  PollStickerCubit({
    required PollRepository repository,
    required SharedPreferences preferences,
    required this.pollId,
    required this.authorPubkey,
    required this.kind,
    required this.question,
    this.answers = const [],
    this.emoji,
  }) : _repository = repository,
       _preferences = preferences,
       super(const PollStickerState());

  final PollRepository _repository;
  final SharedPreferences _preferences;

  /// The id of the poll's event.
  final String pollId;

  /// The creator of the video, who published the poll.
  final String authorPubkey;

  /// What the sticker in the video is.
  final PollKind kind;

  /// The question the sticker in the video asks.
  final String question;

  /// The answers the sticker in the video shows; a slider shows none.
  final List<String> answers;

  /// The emoji a slider in the video is rated with.
  final String? emoji;

  /// Set once the viewer was told that votes are public, after their first.
  static const String publicNoteShownKey = 'poll_votes_public_note_shown';

  /// Being told once is about the person holding the phone, not an account.
  static const List<String> deviceScopedPrefsKeys = [publicNoteShownKey];

  /// Reads the poll and the votes on it.
  Future<void> load() async {
    final PollSnapshot? snapshot;
    try {
      snapshot = await _repository.fetchPoll(
        pollId,
        authorPubkey: authorPubkey,
      );
    } catch (error, stackTrace) {
      // Unexpected: a read no relay answers finds no poll rather than throwing.
      // The sticker stays as the frames show it.
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PollStickerStatus.unavailable));
      return;
    }
    final poll = snapshot?.poll;
    if (snapshot == null || poll == null || !_isShownPoll(poll)) {
      emitIfOpen(state.copyWith(status: PollStickerStatus.unavailable));
      return;
    }
    emitIfOpen(
      state.copyWith(
        status: PollStickerStatus.ready,
        poll: poll,
        results: snapshot.results,
      ),
    );
  }

  /// Whether [poll] is the one the sticker shows, so a vote goes to the answer
  /// the viewer sees: of its kind, asking the same, and with the same answers
  /// or emoji.
  bool _isShownPoll(Poll poll) =>
      poll.kind == kind &&
      poll.question == question &&
      (kind == PollKind.slider
          ? poll.emoji == emoji
          : const ListEquality<String>().equals([
              for (final option in poll.options) option.label,
            ], answers));

  /// Votes for [optionId] as the viewer.
  ///
  /// The vote shows at once and is taken back if it cannot be sent. A quiz
  /// takes one answer, and a vote for the answer already picked, or while
  /// one is on its way, does nothing.
  Future<void> voted(String optionId) async {
    final poll = state.poll;
    final before = state.results;
    if (poll == null ||
        state.voteStatus == PollVoteStatus.sending ||
        before.ownVoteId == optionId ||
        (poll.kind == PollKind.quiz && before.hasVoted)) {
      return;
    }
    emit(
      state.copyWith(
        results: before.withOwnVote(optionId),
        voteStatus: PollVoteStatus.sending,
      ),
    );
    try {
      await _repository.vote(poll, optionId);
    } on PollVoteException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(results: before, voteStatus: PollVoteStatus.failed),
      );
      return;
    } catch (error, stackTrace) {
      addError(Reportable(error, context: 'voted'), stackTrace);
      emitIfOpen(
        state.copyWith(results: before, voteStatus: PollVoteStatus.failed),
      );
      return;
    }
    // Gone with the video: the note is kept for a vote the viewer sees go out.
    if (isClosed) return;
    final isFirstVote = !(_preferences.getBool(publicNoteShownKey) ?? false);
    if (isFirstVote) await _preferences.setBool(publicNoteShownKey, true);
    emitIfOpen(
      state.copyWith(
        voteStatus: PollVoteStatus.sent,
        isFirstVote: isFirstVote,
      ),
    );
  }
}
