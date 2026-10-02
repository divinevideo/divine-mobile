// ABOUTME: BLoC for loading a user's comments across all videos.
// ABOUTME: Splits results into video replies and text comments for UI display.
// ABOUTME: Supports lazy loading and cursor-based pagination.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_sync_completion.dart';

part 'profile_comments_event.dart';
part 'profile_comments_state.dart';

/// BLoC that loads and paginates a user's comments (text + video replies).
class ProfileCommentsBloc
    extends Bloc<ProfileCommentsEvent, ProfileCommentsState> {
  /// Creates a new profile comments BLoC.
  ///
  /// Parameters:
  /// - [commentsRepository]: Repository for querying comments
  /// - [targetUserPubkey]: Hex public key of the user whose comments
  ///   to load
  /// - [includeVideoReplies]: Whether to include video replies alongside text
  ///   comments. Defaults to false to match [CommentsRepository]'s text-only
  ///   author comments query.
  ProfileCommentsBloc({
    required CommentsRepository commentsRepository,
    required String targetUserPubkey,
    bool includeVideoReplies = false,
  }) : _commentsRepository = commentsRepository,
       _targetUserPubkey = targetUserPubkey,
       _includeVideoReplies = includeVideoReplies,
       super(const ProfileCommentsState()) {
    on<ProfileCommentsSyncRequested>(
      _onSyncRequested,
      // Sequential so every sync runs — and therefore completes its completer,
      // which is what holds the profile pull-to-refresh indicator.
      transformer: sequential(),
    );
    on<ProfileCommentsLoadMoreRequested>(_onLoadMoreRequested);
  }

  final CommentsRepository _commentsRepository;
  final String _targetUserPubkey;
  final bool _includeVideoReplies;

  /// Loads the target user's comments, completing
  /// [ProfileCommentsSyncRequested.completer] once the load has settled so the
  /// profile pull-to-refresh can release its indicator.
  Future<void> _onSyncRequested(
    ProfileCommentsSyncRequested event,
    Emitter<ProfileCommentsState> emit,
  ) async {
    try {
      await _sync(emit);
    } finally {
      completeProfileTabSync(event.completer);
    }
  }

  Future<void> _sync(Emitter<ProfileCommentsState> emit) async {
    emit(state.copyWith(status: ProfileCommentsStatus.loading));

    try {
      final page = await _commentsRepository.loadCommentsByAuthor(
        authorPubkey: _targetUserPubkey,
        includeVideoReplies: _includeVideoReplies,
      );
      final comments = page.comments;

      final videoReplies = comments.where((c) => c.hasVideo).toList();
      final textComments = comments.where((c) => !c.hasVideo).toList();

      emit(
        state.copyWith(
          status: ProfileCommentsStatus.success,
          videoReplies: videoReplies,
          textComments: textComments,
          hasMoreContent: page.hasMore,
          paginationCursor: page.nextCursor,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ProfileCommentsStatus.failure));
    }
  }

  Future<void> _onLoadMoreRequested(
    ProfileCommentsLoadMoreRequested event,
    Emitter<ProfileCommentsState> emit,
  ) async {
    if (state.status != ProfileCommentsStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Subtract 1 second to avoid re-fetching the last comment
      // (Nostr `until` filter is inclusive)
      final before = state.paginationCursor?.subtract(
        const Duration(seconds: 1),
      );

      final page = await _commentsRepository.loadCommentsByAuthor(
        authorPubkey: _targetUserPubkey,
        before: before,
        includeVideoReplies: _includeVideoReplies,
      );
      final comments = page.comments;

      final newVideoReplies = comments.where((c) => c.hasVideo).toList();
      final newTextComments = comments.where((c) => !c.hasVideo).toList();

      // Deduplicate against existing comments
      final existingIds = {
        ...state.videoReplies.map((c) => c.id),
        ...state.textComments.map((c) => c.id),
      };
      final uniqueVideoReplies = newVideoReplies
          .where((c) => !existingIds.contains(c.id))
          .toList();
      final uniqueTextComments = newTextComments
          .where((c) => !existingIds.contains(c.id))
          .toList();

      emit(
        state.copyWith(
          videoReplies: [...state.videoReplies, ...uniqueVideoReplies],
          textComments: [...state.textComments, ...uniqueTextComments],
          isLoadingMore: false,
          hasMoreContent: page.hasMore,
          paginationCursor: page.nextCursor,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
