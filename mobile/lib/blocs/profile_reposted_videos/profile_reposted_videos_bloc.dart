// ABOUTME: BLoC for managing profile reposted videos grid
// ABOUTME: Coordinates between RepostsRepository (for IDs) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage)

import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_page_size.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_sync_completion.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_reposted_videos_event.dart';
part 'profile_reposted_videos_state.dart';

/// BLoC for managing profile reposted videos.
///
/// Coordinates between:
/// - [RepostsRepository]: Provides reposted addressable IDs (sync for own,
///   fetch for other)
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Handles:
/// - Syncing repost records from RepostsRepository
/// - Resolving addressable IDs to VideoEvents with cache-first pattern
/// - Filtering: excludes unsupported video formats
/// - Listening for repost changes to update the list
/// - Pagination: loads videos in batches of [ProfileTabPagination.pageSize]
class ProfileRepostedVideosBloc
    extends Bloc<ProfileRepostedVideosEvent, ProfileRepostedVideosState> {
  ProfileRepostedVideosBloc({
    required RepostsRepository repostsRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    required Stream<String> removedVideoIds,
    required bool Function(VideoEvent video) deletedVideoFilter,
    String? targetUserPubkey,
  }) : _repostsRepository = repostsRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _targetUserPubkey = targetUserPubkey,
       _deletedVideoFilter = deletedVideoFilter,
       super(const ProfileRepostedVideosState()) {
    on<ProfileRepostedVideosSyncRequested>(
      _onSyncRequested,
      // Sequential, not droppable: a dropped event never reaches the handler,
      // so nothing would complete its completer and pull-to-refresh would spin
      // forever. Rapid syncs queue instead of coalescing.
      transformer: sequential(),
    );
    on<ProfileRepostedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileRepostedVideosReconcileRequested>(
      _onReconcileRequested,
      transformer: sequential(),
    );
    on<ProfileRepostedVideosLoadMoreRequested>(_onLoadMoreRequested);
    on<ProfileRepostedVideosVideoRemoved>(
      _onVideoRemoved,
      transformer: sequential(),
    );
    _removedVideoIdsSubscription = removedVideoIds.listen((videoId) {
      if (isClosed) return;
      addIfOpen(ProfileRepostedVideosVideoRemoved(videoId));
    });
  }

  final RepostsRepository _repostsRepository;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;
  late final StreamSubscription<String> _removedVideoIdsSubscription;
  final bool Function(VideoEvent video) _deletedVideoFilter;

  /// The pubkey of the user whose reposts to display.
  /// If null or same as current user, uses RepostsRepository sync.
  /// If different, fetches reposts directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _currentUserPubkey;

  /// Cache key for this profile's reposted-videos snapshot.
  ///
  /// Follows the `${pubkey}:${operation}` convention (RFC #4244) so
  /// `CacheSync.invalidatePrefix(currentPubkey)` at sign-out clears the
  /// signed-out user's own-profile entry.
  String get _cacheKey {
    final pubkey = _targetUserPubkey ?? _currentUserPubkey;
    return '$pubkey:profile_reposted_videos';
  }

  /// Handle sync request using stale-while-revalidate backed by [CacheSync].
  ///
  /// On reopen the persisted snapshot is deserialized once and served
  /// immediately; revalidation then only refreshes the reposted-ID list and
  /// reconciles it against the shown videos (no bulk re-fetch / re-serialize).
  ///
  /// [ProfileRepostedVideosSyncRequested.completer] fires only once all of that
  /// is done, snapshot write included, so a refresh waiter is released exactly
  /// when the bloc is free to take the next sync.
  Future<void> _onSyncRequested(
    ProfileRepostedVideosSyncRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    try {
      await _syncAndRevalidate(emit);
    } finally {
      completeProfileTabSync(event.completer);
    }
  }

  Future<void> _syncAndRevalidate(
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    // Flag the revalidation whenever a settled result is on screen — an empty
    // one included — so the sticky cache-revalidation bar runs for the whole
    // re-sync. A re-sync that stays empty emits a state equal to the current
    // one, which bloc suppresses, so without this transition the bar would
    // never appear for an empty tab.
    if (state.status != ProfileRepostedVideosStatus.initial &&
        !state.isRefreshing) {
      emit(state.copyWith(isRefreshing: true));
    }

    final cached = await _readCachedSnapshot();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.success,
          videos: cached.videos,
          repostedAddressableIds: cached.itemIds,
          nextPageOffset: cached.nextPageOffset,
          hasMoreContent: cached.hasMoreContent,
          isRefreshing: true,
          clearError: true,
        ),
      );
    }

    try {
      if (state.videos.isEmpty) {
        await _coldLoad(emit);
      } else {
        await _warmRevalidate(emit);
      }
    } catch (e, stackTrace) {
      Log.error(
        'ProfileRepostedVideosBloc: Sync failed - $e',
        name: 'ProfileRepostedVideosBloc',
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
          status: ProfileRepostedVideosStatus.failure,
          isRefreshing: false,
          error: _errorFor(e),
        ),
      );
    }
  }

  /// Cold path: nothing cached. Resolve the reposted-ID list (own profile
  /// prefers the instant local list, falling back to the relay) and fetch the
  /// first page.
  Future<void> _coldLoad(Emitter<ProfileRepostedVideosState> emit) async {
    final List<String> addressableIds;
    if (_isOtherUserProfile) {
      addressableIds = await _repostsRepository.fetchUserReposts(
        _targetUserPubkey!,
      );
    } else {
      final localIds = await _repostsRepository
          .getOrderedRepostedAddressableIds();
      if (localIds.isNotEmpty) {
        _scheduleBackgroundRelaySync();
        addressableIds = localIds;
      } else {
        addressableIds =
            (await _repostsRepository.syncUserReposts()).orderedAddressableIds;
      }
    }
    if (isClosed) return;

    if (addressableIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.success,
          videos: [],
          repostedAddressableIds: [],
          nextPageOffset: 0,
          hasMoreContent: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
      await _persistSnapshot(_emptySnapshot);
      return;
    }

    final firstPageIds = addressableIds
        .take(ProfileTabPagination.pageSize)
        .toList();
    final fetchResult = await _fetchVideos(firstPageIds, cacheResults: true);
    final videos = fetchResult.videos;
    if (isClosed) return;

    final snapshot = ProfileVideoListSnapshot(
      videos: videos,
      itemIds: addressableIds,
      nextPageOffset: firstPageIds.length,
      hasMoreContent: addressableIds.length > firstPageIds.length,
    );
    emit(
      state.copyWith(
        status: ProfileRepostedVideosStatus.success,
        videos: videos,
        repostedAddressableIds: addressableIds,
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

  /// Warm path: cached videos are already on screen. Refresh the reposted-ID
  /// list against the relay and reconcile it against the shown videos.
  Future<void> _warmRevalidate(Emitter<ProfileRepostedVideosState> emit) async {
    final List<String> freshIds;
    if (_isOtherUserProfile) {
      freshIds = await _repostsRepository.fetchUserReposts(_targetUserPubkey!);
    } else {
      freshIds =
          (await _repostsRepository.syncUserReposts()).orderedAddressableIds;
    }
    if (isClosed) return;

    if (listEquals(freshIds, state.repostedAddressableIds) &&
        !_isWindowUnderfilled(freshIds) &&
        !state.videos.any(_deletedVideoFilter)) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }

    final reconciled = await _reconcile(freshIds);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileRepostedVideosStatus.success,
        videos: reconciled.videos,
        repostedAddressableIds: freshIds,
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

  /// Reconciles displayed videos against a fresh [freshIds] list: keeps reposts
  /// still present, drops the rest, and fetches only the newly-reposted IDs in
  /// the loaded window. Bounded so it never bulk-fetches.
  Future<
    ({
      List<VideoEvent> videos,
      int nextPageOffset,
      bool hasMoreContent,
      int resolvedVideoCount,
    })
  >
  _reconcile(List<String> freshIds) async {
    final byId = <String, VideoEvent>{};
    for (final video in state.videos) {
      if (_deletedVideoFilter(video)) continue;
      final id = _computeAddressableId(video);
      if (id != null) byId[id] = video;
    }
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
    // absent from [windowIds] is no longer reposted, so it is no evidence
    // that the window resolved — seeding the count with it would send an
    // all-unresolved window back to the empty state this fix exists to avoid.
    var resolvedVideoCount = 0;
    if (missingIds.isNotEmpty) {
      final fetchResult = await _fetchVideos(missingIds, cacheResults: true);
      resolvedVideoCount = fetchResult.resolvedVideoCount;
      for (final video in fetchResult.videos) {
        final id = _computeAddressableId(video);
        if (id != null) byId[id] = video;
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
    if (state.repostedAddressableIds.isEmpty) return 0;
    final index = freshIds.indexOf(state.repostedAddressableIds.first);
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

  /// Reads and deserializes the persisted snapshot once; `null` on miss or
  /// failure (cache problems must never break the load).
  Future<ProfileVideoListSnapshot?> _readCachedSnapshot() async {
    try {
      final snapshot = await CacheSync.read<ProfileVideoListSnapshot>(
        key: _cacheKey,
        fromJson: ProfileVideoListSnapshot.fromJson,
      );
      return snapshot == null ? null : _filterDeletedSnapshot(snapshot);
    } on Object catch (e) {
      Log.warning(
        'ProfileRepostedVideosBloc: Failed to read cached snapshot - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      return null;
    }
  }

  ProfileVideoListSnapshot _filterDeletedSnapshot(
    ProfileVideoListSnapshot snapshot,
  ) {
    final deletedAddressableIds = snapshot.videos
        .where(_deletedVideoFilter)
        .map(_computeAddressableId)
        .whereType<String>()
        .toSet();
    if (deletedAddressableIds.isEmpty) return snapshot;

    final videos = snapshot.videos
        .where((video) => !_deletedVideoFilter(video))
        .toList();
    final pruned = pruneProfileVideoListIds(
      itemIds: snapshot.itemIds,
      removedIds: deletedAddressableIds,
      nextPageOffset: snapshot.nextPageOffset,
    );
    return ProfileVideoListSnapshot(
      videos: videos,
      itemIds: pruned.itemIds,
      nextPageOffset: pruned.nextPageOffset,
      hasMoreContent: snapshot.hasMoreContent,
    );
  }

  /// Persists [snapshot] under [_cacheKey] so reopening restores it.
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
        'ProfileRepostedVideosBloc: Failed to persist snapshot - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Fire-and-forget relay sync that keeps the in-memory reposted list fresh
  /// for the live subscription after serving an instant local snapshot.
  void _scheduleBackgroundRelaySync() {
    unawaited(
      _repostsRepository
          .syncUserReposts()
          .then((_) {
            Log.debug(
              'ProfileRepostedVideosBloc: Background relay sync completed',
              name: 'ProfileRepostedVideosBloc',
              category: LogCategory.video,
            );
          })
          .catchError((Object e) {
            Log.warning(
              'ProfileRepostedVideosBloc: Background sync failed - $e',
              name: 'ProfileRepostedVideosBloc',
              category: LogCategory.video,
            );
          }),
    );
  }

  ProfileRepostedVideosError _errorFor(Object error) =>
      error is SyncFailedException || error is FetchRepostsFailedException
      ? ProfileRepostedVideosError.syncFailed
      : ProfileRepostedVideosError.loadFailed;

  /// Subscribe to reposted IDs changes and reconcile the video list reactively.
  ///
  /// Dispatches [ProfileRepostedVideosReconcileRequested] on change so the
  /// async handler can fetch a newly-reposted clip — `emit.forEach`'s callback
  /// is synchronous and cannot await. Own profile only.
  Future<void> _onSubscriptionRequested(
    ProfileRepostedVideosSubscriptionRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    if (_isOtherUserProfile) return;

    await emit.forEach<Set<String>>(
      _repostsRepository.watchRepostedAddressableIds(),
      onData: (repostedIdsSet) {
        final newIds = repostedIdsSet.toList();
        if (listEquals(newIds, state.repostedAddressableIds) ||
            state.status == ProfileRepostedVideosStatus.initial ||
            state.status == ProfileRepostedVideosStatus.syncing) {
          return state;
        }
        Log.info(
          'ProfileRepostedVideosBloc: Reposted IDs changed, reconciling list',
          name: 'ProfileRepostedVideosBloc',
          category: LogCategory.video,
        );
        addIfOpen(ProfileRepostedVideosReconcileRequested(newIds));
        return state;
      },
    );
  }

  /// Reconcile the displayed videos against a fresh reposted-ID list.
  Future<void> _onReconcileRequested(
    ProfileRepostedVideosReconcileRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    final freshIds = event.addressableIds;
    if (listEquals(freshIds, state.repostedAddressableIds)) return;

    try {
      final reconciled = await _reconcile(freshIds);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileRepostedVideosStatus.success,
          videos: reconciled.videos,
          repostedAddressableIds: freshIds,
          nextPageOffset: reconciled.nextPageOffset,
          hasMoreContent: reconciled.hasMoreContent,
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
    } catch (e, stackTrace) {
      Log.error(
        'ProfileRepostedVideosBloc: Failed to reconcile reposts - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
    }
  }

  /// Handle load more request - fetches the next page of videos and grows the
  /// persisted snapshot so reopening restores the full scrolled list.
  Future<void> _onLoadMoreRequested(
    ProfileRepostedVideosLoadMoreRequested event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    if (state.status != ProfileRepostedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final offset = state.nextPageOffset;
    final totalCount = state.repostedAddressableIds.length;

    if (offset >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPageIds = state.repostedAddressableIds
          .skip(offset)
          .take(ProfileTabPagination.pageSize)
          .toList();
      final fetchResult = await _fetchVideos(nextPageIds, cacheResults: true);
      final newVideos = fetchResult.videos;

      final existingIds = state.videos
          .map(_computeAddressableId)
          .whereType<String>()
          .toSet();
      final uniqueNewVideos = newVideos.where((v) {
        final id = _computeAddressableId(v);
        return id == null || !existingIds.contains(id);
      }).toList();

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
          itemIds: state.repostedAddressableIds,
          nextPageOffset: newOffset,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'ProfileRepostedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileRepostedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onVideoRemoved(
    ProfileRepostedVideosVideoRemoved event,
    Emitter<ProfileRepostedVideosState> emit,
  ) async {
    final removedAddressableIds = <String>{};
    final videos = <VideoEvent>[];
    for (final video in state.videos) {
      final isRemoved = video.id == event.videoId || _deletedVideoFilter(video);
      if (isRemoved) {
        final addressableId = _computeAddressableId(video);
        if (addressableId != null) removedAddressableIds.add(addressableId);
      } else {
        videos.add(video);
      }
    }
    final pruned = pruneProfileVideoListIds(
      itemIds: state.repostedAddressableIds,
      removedIds: removedAddressableIds,
      nextPageOffset: state.nextPageOffset,
    );
    if (videos.length == state.videos.length &&
        pruned.itemIds.length == state.repostedAddressableIds.length &&
        pruned.nextPageOffset == state.nextPageOffset) {
      return;
    }

    emit(
      state.copyWith(
        videos: videos,
        repostedAddressableIds: pruned.itemIds,
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

  /// Fetch videos for the given addressable IDs.
  ///
  /// Uses [VideosRepository.getVideosByAddressableIds] which:
  /// 1. Queries Nostr relays for the videos
  /// 2. Falls back to Funnelcake API for videos not found on relays
  /// 3. Optionally saves fetched events to local storage
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first page loads
  /// to avoid bloating the cache.
  ///
  /// Returns videos in the same order as [addressableIds], excluding:
  /// - Videos not found in cache or relay
  /// - Unsupported video formats (WebM on iOS/macOS)
  Future<({List<VideoEvent> videos, int resolvedVideoCount})> _fetchVideos(
    List<String> addressableIds, {
    bool cacheResults = false,
  }) async {
    if (addressableIds.isEmpty) {
      return (videos: <VideoEvent>[], resolvedVideoCount: 0);
    }

    // VideosRepository handles relay + Funnelcake fallback internally
    final videos = await _videosRepository.getVideosByAddressableIds(
      addressableIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileRepostedVideosBloc: Fetched ${videos.length}/${addressableIds.length} '
      'videos (cacheResults: $cacheResults)',
      name: 'ProfileRepostedVideosBloc',
      category: LogCategory.video,
    );

    return (
      videos: videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
      resolvedVideoCount: videos.length,
    );
  }

  /// Compute the addressable ID for a video event.
  ///
  /// Format: `kind:pubkey:d-tag`
  /// Returns null if the video doesn't have a real d-tag.
  String? _computeAddressableId(VideoEvent video) {
    return video.addressableId;
  }

  @override
  Future<void> close() {
    _removedVideoIdsSubscription.cancel();
    return super.close();
  }
}
