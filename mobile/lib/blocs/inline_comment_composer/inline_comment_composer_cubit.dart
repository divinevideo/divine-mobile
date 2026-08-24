// ABOUTME: Cubit for the inline comment composer bar shown at the bottom of
// ABOUTME: the fullscreen video player on Explore / Search / Profile surfaces.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:unified_logger/unified_logger.dart';

part 'inline_comment_composer_state.dart';

/// Lightweight cubit that owns the publish flow for the inline comment bar
/// at the bottom of [PooledFullscreenVideoFeedScreen].
///
/// Unlike the full bottom-sheet trio (`CommentsListBloc` +
/// `CommentComposerBloc` + `CommentReactionsBloc`), this cubit does not
/// load, paginate, or hold a list of comments — the bar's UX is "tap, type,
/// send" and never surfaces other people's comments. State is therefore
/// just a single [InlineCommentComposerStatus] enum; the active video is
/// supplied per-call to [submit] so the cubit holds no mutable video
/// reference.
class InlineCommentComposerCubit extends Cubit<InlineCommentComposerState>
    with CloseGuardedEmit<InlineCommentComposerState> {
  InlineCommentComposerCubit({
    required CommentsRepository commentsRepository,
    ConsumptionAnalyticsTracker? consumptionAnalytics,
  }) : _commentsRepository = commentsRepository,
       _consumptionAnalytics = consumptionAnalytics,
       super(const InlineCommentComposerState());

  final CommentsRepository _commentsRepository;
  final ConsumptionAnalyticsTracker? _consumptionAnalytics;

  /// Posts [content] as a top-level comment on [video].
  ///
  /// Trims and validates input locally; empty submissions are a no-op so
  /// the UI can wire this to a button without guarding emptiness itself.
  /// Errors from the repository are caught and reported via [addError]
  /// (gated through [Reportable] is unnecessary here — comment-publish
  /// failures are an expected domain error path, see
  /// `rules/error_handling.md`).
  Future<void> submit({
    required VideoEvent video,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (state.status == InlineCommentComposerStatus.submitting) return;

    emitIfOpen(state.copyWith(status: InlineCommentComposerStatus.submitting));

    try {
      await _commentsRepository.postComment(
        content: trimmed,
        rootEventId: video.id,
        rootEventKind: NIP71VideoKinds.addressableShortVideo,
        rootEventAuthorPubkey: video.pubkey,
        rootAddressableId: video.addressableId,
      );
      unawaited(
        _consumptionAnalytics?.commentSent(
          targetVideoId: video.id,
          targetPubkey: video.pubkey,
        ),
      );
      emitIfOpen(state.copyWith(status: InlineCommentComposerStatus.submitted));
    } catch (error, stackTrace) {
      Log.error(
        'Inline comment publish failed',
        name: 'InlineCommentComposerCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: InlineCommentComposerStatus.failure));
    }
  }

  /// Returns the cubit to [InlineCommentComposerStatus.idle].
  ///
  /// Called by the bar after the success / failure snackbar has been shown
  /// so the next tap-and-send cycle starts from a clean state.
  void acknowledge() {
    if (state.status == InlineCommentComposerStatus.idle) return;
    emitIfOpen(state.copyWith(status: InlineCommentComposerStatus.idle));
  }
}
