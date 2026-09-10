// ABOUTME: BLoC for managing profile saved (bookmarked) videos grid
// ABOUTME: Coordinates between BookmarksRepository (NIP-51 kind 10003) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage). Own profile only.

import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_page_size.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_sync_completion.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_saved_videos_event.dart';
part 'profile_saved_videos_state.dart';

/// BLoC for managing profile saved (bookmarked) videos.
///
/// Coordinates between:
/// - [BookmarksRepository]: Provides NIP-51 global bookmarks (kind 10003) — only
///   items of type `'e'` (event bookmarks) are treated as saved videos.
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Bookmarks are a private user artifact, so this BLoC is only wired for the
/// current user's own profile.
class ProfileSavedVideosBloc
    extends Bloc<ProfileSavedVideosEvent, ProfileSavedVideosState> {
  ProfileSavedVideosBloc({
    required Future<BookmarksRepository> bookmarksRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    required Stream<String> removedVideoIds,
    required bool Function(VideoEvent video) deletedVideoFilter,
  }) : _bookmarksRepositoryFuture = bookmarksRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _deletedVideoFilter = deletedVideoFilter,
       super(const ProfileSavedVideosState()) {
    on<ProfileSavedVideosSyncRequested>(
      _onSyncRequested,
      // Sequential, not droppable: a dropped event never reaches the handler,
      // so nothing would complete its completer and pull-to-refresh would spin
      // forever. Rapid syncs queue instead of coalescing.
      transformer: sequential(),
    );
    on<ProfileSavedVideosLoadMoreRequested>(_onLoadMoreRequested);
    on<ProfileSavedVideosVideoRemoved>(
      _onVideoRemoved,
      transformer: sequential(),
    );
    _removedVideoIdsSubscription = removedVideoIds.listen((videoId) {
      if (isClosed) return;
      add(ProfileSavedVideosVideoRemoved(videoId));
    });
  }

  /// Resolved lazily on the first sync — [bookmarksRepositoryProvider] is an
  /// async provider so the service isn't immediately available at widget
  /// build time.
  final Future<BookmarksRepository> _bookmarksRepositoryFuture;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;
  late final StreamSubscription<String> _removedVideoIdsSubscription;
  final bool Function(VideoEvent video) _deletedVideoFilter;

  /// Cache key for the saved-videos snapshot (bookmarks are private, so the
  /// key is scoped to the signed-in user for sign-out invalidation).
  String get _cacheKey => '$_currentUserPubkey:profile_saved_videos';

  /// Handle sync request using stale-while-revalidate backed by [CacheSync].
  ///
  /// On reopen the persisted snapshot is served immediately; revalidation then
  /// syncs the bookmark list from the relay and reconciles it against the shown
  /// videos — no bulk re-fetch / re-serialize.
  ///
  /// [ProfileSavedVideosSyncRequested.completer] fires only once all of that is
  /// done, snapshot write included, so a refresh waiter is released exactly
  /// when the bloc is free to take the next sync.
  Future<void> _onSyncRequested(
    ProfileSavedVideosSyncRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    try {
      await _syncAndRevalidate(emit);
    } finally {
      completeProfileTabSync(event.completer);
    }
  }

  Future<void> _syncAndRevalidate(Emitter<ProfileSavedVideosState> emit) async {
    // Flag the revalidation whenever a settled result is on screen — an empty
    // one included — so the sticky cache-revalidation bar runs for the whole
    // re-sync. A re-sync that stays empty emits a state equal to the current
    // one, which bloc suppresses, so without this transition the bar would
    // never appear for an empty tab.
    if (state.status != ProfileSavedVideosStatus.initial &&
        !state.isRefreshing) {
      emit(state.copyWith(isRefreshing: true));
    }

    final cached = await _readCachedSnapshot();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: cached.videos,
          savedEventIds: cached.itemIds,
          nextPageOffset: cached.nextPageOffset,
          hasMoreContent: cached.hasMoreContent,
          isRefreshing: true,
          clearError: true,
        ),
      );
    }

    try {
      final freshIds = await _resolveSavedIds();
      if (isClosed) return;

      if (state.videos.isEmpty) {
        await _coldLoad(freshIds, emit);
      } else {
        await _warmRevalidate(freshIds, emit);
      }
    } catch (e, stackTrace) {
      Log.error(
        'ProfileSavedVideosBloc: Failed to load saved videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      if (state.videos.isNotEmpty) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.failure,
          isRefreshing: false,
          error: ProfileSavedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Reconciles the bookmark list against the relay, then reads the
  /// event-type IDs from it.
  ///
  /// Bookmarks are a NIP-51 kind 10003 list, and this is the only read
  /// surface for it — without the sync, Saved would show the
  /// SharedPreferences cache alone and stay empty on a fresh install. Mirrors
  /// how the Liked and Reposted tabs call `syncUserReactions()` /
  /// `syncUserReposts()` from their own sync handlers.
  ///
  /// A failed sync is not fatal here: the cached list is still worth showing,
  /// and the caller is only reading. (The write path treats the same failure
  /// as fatal, because republishing an unreconciled list destroys bookmarks.)
  Future<List<String>> _resolveSavedIds() async {
    final bookmarksRepository = await _bookmarksRepositoryFuture;
    await bookmarksRepository.syncGlobalBookmarks();
    return bookmarksRepository.globalBookmarks
        .where((item) => item.type == 'e')
        .map((item) => item.id)
        .toList();
  }

  /// Cold path: nothing cached. Fetch the first page for [savedEventIds].
  Future<void> _coldLoad(
    List<String> savedEventIds,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (savedEventIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: [],
          savedEventIds: [],
          nextPageOffset: 0,
          hasMoreContent: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
      await _persistSnapshot(_emptySnapshot);
      return;
    }

    final firstPageIds = savedEventIds
        .take(ProfileTabPagination.pageSize)
        .toList();
    final fetchResult = await _fetchVideos(firstPageIds, cacheResults: true);
    final videos = fetchResult.videos;
    if (isClosed) return;

    final snapshot = ProfileVideoListSnapshot(
      videos: videos,
      itemIds: savedEventIds,
      nextPageOffset: firstPageIds.length,
      hasMoreContent: savedEventIds.length > firstPageIds.length,
    );
    emit(
      state.copyWith(
        status: ProfileSavedVideosStatus.success,
        videos: videos,
        savedEventIds: savedEventIds,
        nextPageOffset: snapshot.nextPageOffset,
        hasMoreContent: snapshot.hasMoreContent,
        isRefreshing: false,
        lastFetchResolvedVideoCount: videos.isEmpty
            ? fetchResult.resolvedVideoCount
            : null,
        clearError: true,
      ),
    );
    await _persistSnapshot(snapshot);
  }

  /// Warm path: cached videos are already on screen. Reconcile against the
  /// fresh bookmark list (drop unsaved, fetch newly-saved in the window).
  Future<void> _warmRevalidate(
    List<String> freshIds,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (listEquals(freshIds, state.savedEventIds) &&
        !_isWindowUnderfilled(freshIds) &&
        !state.videos.any(_deletedVideoFilter)) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }

    final reconciled = await _reconcile(freshIds);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileSavedVideosStatus.success,
        videos: reconciled.videos,
        savedEventIds: freshIds,
        nextPageOffset: reconciled.nextPageOffset,
        hasMoreContent: reconciled.hasMoreContent,
        isRefreshing: false,
        lastFetchResolvedVideoCount: reconciled.resolvedVideoCount,
        clearError: true,
      ),
    );
    await _persistSnapshot(
      ProfileVideoListSnapshot(
        videos: reconciled.videos,
        itemIds: freshIds,
        nextPageOffset: reconciled.nextPageOffset,
        hasMoreContent: reconciled.hasMoreContent,
      ),
    );
  }

  /// Reconciles displayed videos against a fresh [freshIds] list: keeps saved
  /// videos still present, drops the rest, and fetches only the newly-saved
  /// IDs in the loaded window. Bounded so it never bulk-fetches.
  Future<
    ({
      List<VideoEvent> videos,
      int nextPageOffset,
      bool hasMoreContent,
      int resolvedVideoCount,
    })
  >
  _reconcile(List<String> freshIds) async {
    final byId = {
      for (final video in state.videos)
        if (!_deletedVideoFilter(video)) video.id: video,
    };
    // Anchor on the previous top ID rather than a length delta, so a capped
    // persisted ID list can't balloon the reconcile window into a full
    // re-fetch on reopen (see ProfileLikedVideosBloc for the rationale).
    final newAtTop = _newItemsAtTop(freshIds);
    // Floored at one page so a window that was once shorter than a page can
    // recover; see ProfileLikedVideosBloc for the lock-in it prevents.
    final loadedWindow =
        max(state.nextPageOffset, state.videos.length) + newAtTop;
    final windowSize = max(
      loadedWindow,
      ProfileTabPagination.pageSize,
    ).clamp(0, freshIds.length);
    final windowIds = freshIds.take(windowSize).toList();

    final missingIds = windowIds.where((id) => !byId.containsKey(id)).toList();
    // Counts this window's fetch only. A video carried over in [byId] but
    // absent from [windowIds] is no longer saved, so it is no evidence that
    // the window resolved — seeding the count with it would send an
    // all-unresolved window back to the empty state this fix exists to avoid.
    var resolvedVideoCount = 0;
    if (missingIds.isNotEmpty) {
      final fetchResult = await _fetchVideos(missingIds, cacheResults: true);
      resolvedVideoCount = fetchResult.resolvedVideoCount;
      for (final video in fetchResult.videos) {
        byId[video.id] = video;
      }
    }

    final videos = windowIds
        .map((id) => byId[id])
        .whereType<VideoEvent>()
        .toList();
    return (
      videos: videos,
      nextPageOffset: windowIds.length,
      hasMoreContent: windowIds.length < freshIds.length,
      resolvedVideoCount: videos.isEmpty ? resolvedVideoCount : 0,
    );
  }

  /// Number of fresh IDs prepended above the previous top item, located by
  /// finding the old top ID in [freshIds]. Returns 0 when there is no prior
  /// list or the old top is gone, so a capped persisted list can never
  /// balloon the reconcile window into a full re-fetch.
  int _newItemsAtTop(List<String> freshIds) {
    if (state.savedEventIds.isEmpty) return 0;
    final index = freshIds.indexOf(state.savedEventIds.first);
    return index < 0 ? 0 : index;
  }

  /// Whether the loaded window holds less than a page while [ids] still has
  /// unconsumed entries — the state a short first load leaves behind, which
  /// must be topped up even when the ID list itself is unchanged. See
  /// ProfileLikedVideosBloc for the lock-in this prevents.
  bool _isWindowUnderfilled(List<String> ids) =>
      state.nextPageOffset < ProfileTabPagination.pageSize &&
      state.nextPageOffset < ids.length;

  static const ProfileVideoListSnapshot _emptySnapshot =
      ProfileVideoListSnapshot(
        videos: [],
        itemIds: [],
        nextPageOffset: 0,
        hasMoreContent: false,
      );

  Future<ProfileVideoListSnapshot?> _readCachedSnapshot() async {
    try {
      final snapshot = await CacheSync.read<ProfileVideoListSnapshot>(
        key: _cacheKey,
        fromJson: ProfileVideoListSnapshot.fromJson,
      );
      return snapshot == null ? null : _filterDeletedSnapshot(snapshot);
    } on Object catch (e) {
      Log.warning(
        'ProfileSavedVideosBloc: Failed to read cached snapshot - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      return null;
    }
  }

  ProfileVideoListSnapshot _filterDeletedSnapshot(
    ProfileVideoListSnapshot snapshot,
  ) {
    final deletedVideoIds = snapshot.videos
        .where(_deletedVideoFilter)
        .map((video) => video.id)
        .toSet();
    if (deletedVideoIds.isEmpty) return snapshot;

    final videos = snapshot.videos
        .where((video) => !deletedVideoIds.contains(video.id))
        .toList();
    final pruned = pruneProfileVideoListIds(
      itemIds: snapshot.itemIds,
      removedIds: deletedVideoIds,
      nextPageOffset: snapshot.nextPageOffset,
    );
    return ProfileVideoListSnapshot(
      videos: videos,
      itemIds: pruned.itemIds,
      nextPageOffset: pruned.nextPageOffset,
      hasMoreContent: snapshot.hasMoreContent,
    );
  }

  Future<void> _persistSnapshot(ProfileVideoListSnapshot snapshot) async {
    try {
      await CacheSync.write<ProfileVideoListSnapshot>(
        key: _cacheKey,
        value: ProfileVideoListSnapshot.capped(
          videos: snapshot.videos,
          itemIds: snapshot.itemIds,
          nextPageOffset: snapshot.nextPageOffset,
          hasMoreContent: snapshot.hasMoreContent,
        ),
        toJson: (s) => s.toJson(),
      );
    } on Object catch (e) {
      Log.warning(
        'ProfileSavedVideosBloc: Failed to persist snapshot - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Handle load more request — fetches the next page of videos.
  ///
  /// Uses [state.nextPageOffset] to track the position in
  /// [state.savedEventIds] and fetches the next [ProfileTabPagination.pageSize] IDs. The
  /// offset advances by the number of IDs consumed, not the number of videos
  /// loaded (some IDs may not resolve to videos due to relay unavailability
  /// or format filtering).
  Future<void> _onLoadMoreRequested(
    ProfileSavedVideosLoadMoreRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (state.status != ProfileSavedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final offset = state.nextPageOffset;
    final totalCount = state.savedEventIds.length;

    if (offset >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileSavedVideosBloc: Loading more videos '
      '(offset: $offset, total: $totalCount)',
      name: 'ProfileSavedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPageIds = state.savedEventIds
          .skip(offset)
          .take(ProfileTabPagination.pageSize)
          .toList();
      final fetchResult = await _fetchVideos(nextPageIds, cacheResults: true);
      final newVideos = fetchResult.videos;

      Log.info(
        'ProfileSavedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );

      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNewVideos = newVideos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      final newOffset = offset + nextPageIds.length;
      final allVideos = [...state.videos, ...uniqueNewVideos];
      final hasMore = newOffset < totalCount;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          nextPageOffset: newOffset,
          // The page just fetched is now the evidence behind an empty list,
          // so it has to replace the earlier page's count. Without this a
          // first page that resolved nothing keeps asserting failure even
          // after a later page resolved videos that were filtered out here.
          lastFetchResolvedVideoCount: allVideos.isEmpty
              ? fetchResult.resolvedVideoCount
              : null,
        ),
      );
      await _persistSnapshot(
        ProfileVideoListSnapshot(
          videos: allVideos,
          itemIds: state.savedEventIds,
          nextPageOffset: newOffset,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'ProfileSavedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onVideoRemoved(
    ProfileSavedVideosVideoRemoved event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    final removedVideoIds = <String>{event.videoId};
    final videos = <VideoEvent>[];
    for (final video in state.videos) {
      final isRemoved = video.id == event.videoId || _deletedVideoFilter(video);
      if (isRemoved) {
        removedVideoIds.add(video.id);
      } else {
        videos.add(video);
      }
    }

    final pruned = pruneProfileVideoListIds(
      itemIds: state.savedEventIds,
      removedIds: removedVideoIds,
      nextPageOffset: state.nextPageOffset,
    );
    if (videos.length == state.videos.length &&
        pruned.itemIds.length == state.savedEventIds.length &&
        pruned.nextPageOffset == state.nextPageOffset) {
      return;
    }

    emit(
      state.copyWith(
        videos: videos,
        savedEventIds: pruned.itemIds,
        nextPageOffset: pruned.nextPageOffset,
      ),
    );
    await _persistSnapshot(
      ProfileVideoListSnapshot(
        videos: videos,
        itemIds: pruned.itemIds,
        nextPageOffset: pruned.nextPageOffset,
        hasMoreContent: state.hasMoreContent,
      ),
    );
  }

  /// Fetch videos for the given event IDs via [VideosRepository], which
  /// handles cache-first lookups (SQLite local storage → relay fallback).
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first-page loads to
  /// avoid bloating the cache.
  ///
  /// Returns videos in the same order as [eventIds], excluding videos not
  /// found in cache or relay and videos whose format is unsupported on the
  /// current platform.
  Future<({List<VideoEvent> videos, int resolvedVideoCount})> _fetchVideos(
    List<String> eventIds, {
    bool cacheResults = false,
  }) async {
    if (eventIds.isEmpty) {
      return (videos: <VideoEvent>[], resolvedVideoCount: 0);
    }

    final videos = await _videosRepository.getVideosByIds(
      eventIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileSavedVideosBloc: Fetched ${videos.length}/${eventIds.length} '
      'videos (cacheResults: $cacheResults)',
      name: 'ProfileSavedVideosBloc',
      category: LogCategory.video,
    );

    return (
      videos: videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
      resolvedVideoCount: videos.length,
    );
  }

  @override
  Future<void> close() {
    _removedVideoIdsSubscription.cancel();
    return super.close();
  }
}
