// ABOUTME: Cubit for the paged videos of every accepted holder of one badge.

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:videos_repository/videos_repository.dart';

part 'badge_videos_state.dart';

/// Loads and pages videos by a badge's accepted holders.
class BadgeVideosCubit extends Cubit<BadgeVideosState>
    with CloseGuardedEmit<BadgeVideosState> {
  /// Creates the cubit for the badge at [coordinate].
  BadgeVideosCubit({
    required BadgeRepository badgeRepository,
    required VideosRepository videosRepository,
    required BadgeCoordinate coordinate,
  }) : _badgeRepository = badgeRepository,
       _videosRepository = videosRepository,
       _coordinate = coordinate,
       super(const BadgeVideosState());

  final BadgeRepository _badgeRepository;
  final VideosRepository _videosRepository;
  final BadgeCoordinate _coordinate;

  /// The pager for the current holder snapshot; replaced on every [load].
  BadgeVideoPager? _pager;

  /// Resolves the holders and loads the first page.
  Future<void> load() async {
    emit(state.copyWith(status: BadgeVideosStatus.loading));
    try {
      final holders = await _badgeRepository.loadAcceptedHolders(_coordinate);
      final pager = _videosRepository.createBadgeVideoPager(holders);
      final videos = await pager.loadMore();
      if (isClosed) return;
      _pager = pager;
      emit(
        BadgeVideosState(
          status: BadgeVideosStatus.loaded,
          videos: videos,
          hasMore: pager.hasMore,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: BadgeVideosStatus.failure));
    }
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final pager = _pager;
    if (pager == null || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final videos = await pager.loadMore();
      if (!identical(pager, _pager)) return;
      emitIfOpen(
        state.copyWith(
          videos: [...state.videos, ...videos],
          hasMore: pager.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          isLoadingMore: false,
          loadMoreFailures: state.loadMoreFailures + 1,
        ),
      );
    }
  }
}
