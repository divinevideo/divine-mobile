// ABOUTME: Lets a creator manage the video replies to one of their videos: pin
// ABOUTME: one to the front, hide single ones, and show them again.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

part 'video_replies_state.dart';

/// Reads the video replies to the creator's video [videoId], published at
/// [videoAddress], and saves which they pinned or hid.
///
/// A change shows at once and is saved behind it; one that cannot be saved
/// goes back to what it was.
class VideoRepliesCubit extends Cubit<VideoRepliesState>
    with CloseGuardedEmit<VideoRepliesState> {
  VideoRepliesCubit({
    required VideoResponsesRepository repository,
    required this.videoId,
    required String videoAddress,
    required String creatorPubkey,
  }) : _repository = repository,
       _videoAddress = videoAddress,
       _creatorPubkey = creatorPubkey,
       super(const VideoRepliesState());

  final VideoResponsesRepository _repository;

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
          replies: replies.videos,
          curation: curation,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: VideoRepliesStatus.failure));
    }
  }

  /// Pins [replyId] to the front, or unpins it when it is pinned already.
  Future<void> pinToggled(String replyId) => _save(
    state.curation.pinnedId == replyId
        ? state.curation.pinned(null)
        : state.curation.pinned(replyId),
  );

  /// Hides [replyId], or shows it again when it is hidden.
  Future<void> hideToggled(String replyId) => _save(
    state.curation.hiddenIds.contains(replyId)
        ? state.curation.shown(replyId)
        : state.curation.hidden(replyId),
  );

  Future<void> _save(RepliesCuration curation) async {
    if (state.saveStatus == VideoRepliesSaveStatus.saving) return;
    final before = state.curation;
    emit(
      state.copyWith(
        curation: curation,
        saveStatus: VideoRepliesSaveStatus.saving,
      ),
    );
    try {
      await _repository.saveCuration(curation, videoAddress: _videoAddress);
      emitIfOpen(state.copyWith(saveStatus: VideoRepliesSaveStatus.idle));
    } on RepliesCurationException catch (error, stackTrace) {
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
