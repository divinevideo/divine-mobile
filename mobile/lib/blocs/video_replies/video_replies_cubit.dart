// ABOUTME: Lets a creator manage the video replies to one of their videos: pin
// ABOUTME: one to the front, hide single ones, and show them again.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

part 'video_replies_state.dart';

/// Puts on each reply the content warnings the creator's settings call for,
/// leaving none out.
typedef RepliesWarnings = List<VideoEvent> Function(List<VideoEvent> replies);

/// Reads the video replies to the creator's video [videoId], published at
/// [videoAddress], and saves which they pinned or hid.
///
/// Every reply is listed, so the creator can hide it, each with the warnings
/// [RepliesWarnings] puts on it. A change shows at once and is saved behind
/// it; once saved, the page shows the curation that was published, with pins
/// and hides made on another device merged in, and one that cannot be saved
/// goes back to what it was.
class VideoRepliesCubit extends Cubit<VideoRepliesState>
    with CloseGuardedEmit<VideoRepliesState> {
  VideoRepliesCubit({
    required VideoResponsesRepository repository,
    required RepliesWarnings warnings,
    required this.videoId,
    required String videoAddress,
    required String creatorPubkey,
  }) : _repository = repository,
       _warnings = warnings,
       _videoAddress = videoAddress,
       _creatorPubkey = creatorPubkey,
       super(const VideoRepliesState());

  final VideoResponsesRepository _repository;
  final RepliesWarnings _warnings;

  /// The video whose replies these are.
  final String videoId;
  final String _videoAddress;
  final String _creatorPubkey;

  /// The most replies read.
  static const int maxReplies = 100;

  /// Reads the replies and how the creator curated them.
  Future<void> load() async {
    emit(state.copyWith(status: VideoRepliesStatus.loading));
    try {
      final (replies, curation) = await (
        _repository.fetchReplies(
          videoId: videoId,
          videoAddress: _videoAddress,
          limit: maxReplies,
        ),
        _repository.fetchCuration(
          creatorPubkey: _creatorPubkey,
          videoAddress: _videoAddress,
        ),
      ).wait;
      emitIfOpen(
        state.copyWith(
          status: VideoRepliesStatus.loaded,
          replies: _warnings(replies.videos),
          curation: curation,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: VideoRepliesStatus.failure));
    }
  }

  /// Pins the reply [replyKey] names, its [RepliesCuration.keyOf], to the
  /// front, or unpins it when it is pinned already. Pinning shows it again,
  /// also when the creator blocked its author.
  Future<void> pinToggled(String replyKey) {
    final curation = state.curation;
    if (curation.pinnedId == replyKey) return _save(curation.pinned(null));
    return _save(
      curation.pinned(replyKey, restoredEventId: _approvedVersion(replyKey)),
    );
  }

  /// Hides the reply [replyKey] names, its [RepliesCuration.keyOf], or shows
  /// it again when it is hidden, also when it is hidden because the creator
  /// blocked its author.
  Future<void> hideToggled(String replyKey) {
    final curation = state.curation;
    final reply = _replyOf(replyKey);
    final hidden = reply == null
        ? curation.hiddenIds.contains(replyKey)
        : curation.hides(reply);
    if (hidden) {
      return _save(
        curation.shown(replyKey, restoredEventId: _approvedVersion(replyKey)),
      );
    }
    return _save(
      curation.hidden(replyKey, eventId: reply?.id),
      // A restore of this version made on another device goes too.
      takenBackRestores: {?reply?.id},
    );
  }

  VideoEvent? _replyOf(String replyKey) => state.replies
      .where((reply) => RepliesCuration.keyOf(reply) == replyKey)
      .firstOrNull;

  /// The event id of the version of the reply [replyKey] names that showing
  /// or pinning it approves, when the creator blocked its author; `null`
  /// otherwise, as it then needs no approval.
  String? _approvedVersion(String replyKey) {
    final reply = _replyOf(replyKey);
    if (reply == null) return null;
    return state.curation.hiddenAuthors.contains(reply.pubkey)
        ? reply.id
        : null;
  }

  Future<void> _save(
    RepliesCuration curation, {
    Set<String> takenBackRestores = const {},
  }) async {
    if (state.saveStatus == VideoRepliesSaveStatus.saving) return;
    final before = state.curation;
    emit(
      state.copyWith(
        curation: curation,
        saveStatus: VideoRepliesSaveStatus.saving,
      ),
    );
    try {
      final reconciled = await _repository.saveCuration(
        curation,
        videoAddress: _videoAddress,
        previous: before,
        takenBackRestores: takenBackRestores,
      );
      emitIfOpen(
        state.copyWith(
          curation: reconciled,
          saveStatus: VideoRepliesSaveStatus.idle,
        ),
      );
    } catch (error, stackTrace) {
      // Any failure, not just a refused curation: left at saving, the page
      // would show the unsaved change as done and drop every later one.
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          curation: before,
          saveStatus: VideoRepliesSaveStatus.failed,
        ),
      );
    }
  }
}
