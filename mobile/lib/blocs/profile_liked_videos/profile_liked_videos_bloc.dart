// ABOUTME: BLoC for managing profile liked videos grid
// ABOUTME: Coordinates between LikesRepository (for IDs) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage)

import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_page_size.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_sync_completion.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_liked_videos_event.dart';
part 'profile_liked_videos_state.dart';

/// BLoC for managing profile liked videos.
///
/// Coordinates between:
/// - [LikesRepository]: Provides liked event IDs (sync for own, fetch for other)
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Handles:
/// - Syncing liked event IDs from LikesRepository
/// - Loading video data with cache-first pattern (SQLite → relay fallback)
/// - Filtering: excludes unsupported video formats
/// - Listening for like changes to update the list
/// - Pagination: loads videos in batches of [ProfileTabPagination.pageSize]
class ProfileLikedVideosBloc
    extends Bloc<ProfileLikedVideosEvent, ProfileLikedVideosState> {
  ProfileLikedVideosBloc({
    required LikesRepository likesRepository,
    required VideosRepository videosRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
    required String currentUserPubkey,
    required Stream<String> removedVideoIds,
    required bool Function(VideoEvent video) deletedVideoFilter,
    String? targetUserPubkey,
  }) : _likesRepository = likesRepository,
       _videosRepository = videosRepository,
       _blocklistRepository = contentBlocklistRepository,
       _currentUserPubkey = currentUserPubkey,
       _targetUserPubkey = targetUserPubkey,
       _deletedVideoFilter = deletedVideoFilter,
       super(const ProfileLikedVideosState()) {
    on<ProfileLikedVideosSyncRequested>(
      _onSyncRequested,
      // Sequential, not droppable: a dropped event never reaches the handler,
      // so nothing would complete its completer and pull-to-refresh would spin
      // forever. Rapid syncs queue instead of coalescing.
      transformer: sequential(),
    );
    on<ProfileLikedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileLikedVideosReconcileRequested>(
      _onReconcileRequested,
      transformer: sequential(),
    );
    on<ProfileLikedVideosLoadMoreRequested>(_onLoadMoreRequested);
    on<ProfileLikedVideosBlocklistChanged>(
      _onBlocklistChanged,
      transformer: droppable(),
    );
    on<ProfileLikedVideosVideoRemoved>(
      _onVideoRemoved,
      transformer: sequential(),
    );

    // Re-filter the loaded grid whenever the blocklist changes. Broad changes
    // (account switch / identity adoption, relay-synced blocked-by-others,
    // mute-list recovery) bump the version but emit no granular removed-id
    // signal, so the held list must be re-filtered here (#5104).
    _blocklistSubscription = _blocklistRepository.stateStream.listen((_) {
      if (isClosed) return;
      add(const ProfileLikedVideosBlocklistChanged());
    });
    _removedVideoIdsSubscription = removedVideoIds.listen((videoId) {
      if (isClosed) return;
      add(ProfileLikedVideosVideoRemoved(videoId));
    });
  }

  final LikesRepository _likesRepository;
  final VideosRepository _videosRepository;
  final ContentBlocklistRepository _blocklistRepository;
  final String _currentUserPubkey;

  /// Subscription to broad blocklist changes; cancelled in [close].
  late final StreamSubscription<ContentPolicyState> _blocklistSubscription;
  late final StreamSubscription<String> _removedVideoIdsSubscription;
  final bool Function(VideoEvent video) _deletedVideoFilter;

  /// The pubkey of the user whose likes to display.
  /// If null or same as current user, uses LikesRepository sync.
  /// If different, fetches likes directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _currentUserPubkey;

  /// Cache key for this profile's liked-videos snapshot.
  ///
  /// Follows the `${pubkey}:${operation}` convention (RFC #4244) so that
  /// `CacheSync.invalidatePrefix(currentPubkey)` at sign-out clears the
  /// signed-out user's own-profile entry.
  String get _cacheKey {
    // Scoped to the VIEWER (current user) as well as the target, because the
    // cached videos are blocklist-filtered per the signed-in user. A
    // target-only key would let another account on the same device reuse a
    // different viewer's filtered window. The current-user prefix also keeps
    // sign-out's `invalidatePrefix(currentPubkey)` clearing every entry.
    final target = _targetUserPubkey ?? _currentUserPubkey;
    return '$_currentUserPubkey:$target:profile_liked_videos';
  }

  /// Handle sync request using stale-while-revalidate backed by [CacheSync].
  ///
  /// On reopen the persisted snapshot is deserialized **once** and served
  /// immediately (full scrolled list, [ProfileLikedVideosState.isRefreshing]
  /// on). Revalidation then only refreshes the liked-ID list and reconciles
  /// it against the already-shown videos — it never re-fetches or
  /// re-serializes the whole window, which previously janked the UI thread
  /// when fresh data arrived. On a cold open the state stays loading until
  /// the first page resolves.
  ///
  /// [ProfileLikedVideosSyncRequested.completer] fires only once all of that
  /// is done, snapshot write included, so a refresh waiter is released exactly
  /// when the bloc is free to take the next sync.
  Future<void> _onSyncRequested(
    ProfileLikedVideosSyncRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    try {
      await _syncAndRevalidate(emit);
    } finally {
      completeProfileTabSync(event.completer);
    }
  }

  Future<void> _syncAndRevalidate(Emitter<ProfileLikedVideosState> emit) async {
    Log.info(
      'ProfileLikedVideosBloc: Starting sync for '
      '${_isOtherUserProfile ? "other user" : "own profile"}',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // Reopen / refresh: keep the settled grid on screen and surface the thin
    // progress bar straight away rather than flashing the full-screen spinner.
    // An empty settled grid needs the flag too: a re-sync that stays empty
    // emits a state equal to the current one, which bloc suppresses, so
    // without this transition the bar would never appear for an empty tab.
    if (state.status != ProfileLikedVideosStatus.initial &&
        !state.isRefreshing) {
      emit(state.copyWith(isRefreshing: true));
    }

    // 1. Serve the persisted snapshot instantly (single deserialize).
    final cached = await _readCachedSnapshot();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: cached.videos,
          likedEventIds: cached.itemIds,
          nextPageOffset: cached.nextPageOffset,
          hasMoreContent: cached.hasMoreContent,
          isRefreshing: true,
          clearError: true,
        ),
      );
    }

    // 2. Revalidate.
    try {
      if (state.videos.isEmpty) {
        await _coldLoad(emit);
      } else {
        await _warmRevalidate(emit);
      }
    } catch (e, stackTrace) {
      Log.error(
        'ProfileLikedVideosBloc: Sync failed - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      // Keep cached content on screen; only show the failure screen cold.
      if (state.videos.isNotEmpty) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          isRefreshing: false,
          error: _errorFor(e),
        ),
      );
    }
  }

  /// Cold path: nothing cached. Resolve the liked-ID list (own profile prefers
  /// the instant local list, falling back to the relay) and fetch just the
  /// first page.
  Future<void> _coldLoad(Emitter<ProfileLikedVideosState> emit) async {
    final List<String> likedEventIds;
    if (_isOtherUserProfile) {
      likedEventIds = await _likesRepository.fetchUserLikes(_targetUserPubkey!);
    } else {
      final localIds = await _likesRepository.getOrderedLikedEventIds();
      if (localIds.isNotEmpty) {
        _scheduleBackgroundRelaySync();
        likedEventIds = localIds;
      } else {
        likedEventIds =
            (await _likesRepository.syncUserReactions()).orderedEventIds;
      }
    }
    if (isClosed) return;

    if (likedEventIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: [],
          likedEventIds: [],
          nextPageOffset: 0,
          hasMoreContent: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
      await _persistSnapshot(_emptySnapshot);
      return;
    }

    // Fill a page through sparse IDs (some may not resolve to videos) and
    // apply the blocklist, so the first screen renders a full grid.
    final page = await _fetchVideoPage(
      likedEventIds,
      startOffset: 0,
      cacheFirstBatch: true,
    );
    if (isClosed) return;

    final snapshot = ProfileVideoListSnapshot(
      videos: page.videos,
      itemIds: likedEventIds,
      nextPageOffset: page.nextOffset,
      hasMoreContent: page.hasMoreContent,
    );
    emit(
      state.copyWith(
        status: ProfileLikedVideosStatus.success,
        videos: page.videos,
        likedEventIds: likedEventIds,
        nextPageOffset: page.nextOffset,
        hasMoreContent: page.hasMoreContent,
        isRefreshing: false,
        clearError: true,
      ),
    );
    await _persistSnapshot(snapshot);
  }

  /// Warm path: cached videos are already on screen. Refresh the liked-ID list
  /// against the relay and reconcile it against the shown videos.
  ///
  /// Deliberately does **not** re-resolve or re-serialize the whole loaded
  /// window: when the ID list is unchanged (the common reopen) this is just a
  /// flag flip; when it changed, [_reconcile] drops unliked videos and fetches
  /// only the newly-liked IDs in the window, so the UI thread never does bulk
  /// video work here. The one exception is an underfilled window
  /// ([_isWindowUnderfilled]), which reconciles even on an unchanged ID list
  /// because it can never recover otherwise.
  Future<void> _warmRevalidate(Emitter<ProfileLikedVideosState> emit) async {
    final List<String> freshIds;
    if (_isOtherUserProfile) {
      freshIds = await _likesRepository.fetchUserLikes(_targetUserPubkey!);
    } else {
      freshIds = (await _likesRepository.syncUserReactions()).orderedEventIds;
    }
    if (isClosed) return;

    if (listEquals(freshIds, state.likedEventIds) &&
        !_isWindowUnderfilled(freshIds) &&
        !state.videos.any(_deletedVideoFilter)) {
      // Nothing changed — just hide the bar. No re-fetch, no re-serialize.
      emit(state.copyWith(isRefreshing: false));
      return;
    }

    final reconciled = await _reconcile(freshIds);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileLikedVideosStatus.success,
        videos: reconciled.videos,
        likedEventIds: freshIds,
        nextPageOffset: reconciled.nextPageOffset,
        hasMoreContent: reconciled.hasMoreContent,
        isRefreshing: false,
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

  /// Reconciles the displayed videos against a fresh [freshIds] list.
  ///
  /// Keeps videos still liked (in fresh order), drops unliked ones, and
  /// fetches only the liked IDs in the loaded window that have no video yet —
  /// typically just the clip the user (or another device) liked at the top.
  /// Bounded to the loaded window (but never below one page) so it never
  /// bulk-fetches.
  Future<({List<VideoEvent> videos, int nextPageOffset, bool hasMoreContent})>
  _reconcile(List<String> freshIds) async {
    final byId = {
      for (final video in state.videos)
        if (!_deletedVideoFilter(video)) video.id: video,
    };
    // Count items newly prepended at the top by anchoring on the previous
    // top ID rather than on a length delta. A length delta breaks when the
    // persisted ID list was capped (its length no longer reflects the true
    // previous total), which would otherwise balloon the window to a full
    // re-fetch on reopen. Falls back to 0 (no growth) if the old top is gone.
    final newAtTop = _newItemsAtTop(freshIds);
    // Floored at one page. The window is otherwise bounded by what is already
    // loaded, so a first load that resolved fewer than a page — e.g. the cold
    // path ran against a local liked-ID list that had not finished syncing —
    // stays that size permanently: every reconcile re-derives the same short
    // window and persists it, and a grid shorter than the viewport never
    // scrolls, so scroll-driven pagination can never grow it either.
    final loadedWindow =
        max(state.nextPageOffset, state.videos.length) + newAtTop;
    final windowSize = max(
      loadedWindow,
      ProfileTabPagination.pageSize,
    ).clamp(0, freshIds.length);
    final windowIds = freshIds.take(windowSize).toList();

    final missingIds = windowIds.where((id) => !byId.containsKey(id)).toList();
    if (missingIds.isNotEmpty) {
      for (final video in await _fetchVideos(missingIds, cacheResults: true)) {
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
    );
  }

  /// Number of fresh IDs prepended above the previous top item, located by
  /// finding the old top ID in [freshIds]. Returns 0 when there is no prior
  /// list or the old top is gone, so a capped persisted list can never
  /// balloon the reconcile window into a full re-fetch.
  int _newItemsAtTop(List<String> freshIds) {
    if (state.likedEventIds.isEmpty) return 0;
    final index = freshIds.indexOf(state.likedEventIds.first);
    return index < 0 ? 0 : index;
  }

  /// Whether the loaded window holds less than a page while [ids] still has
  /// unconsumed entries.
  ///
  /// This is the state a short first load leaves behind, and it must be
  /// topped up even when the ID list itself is unchanged — otherwise the
  /// unchanged-IDs fast path in [_warmRevalidate] would keep the short window
  /// alive on every reopen for anyone whose ID list has settled.
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
        'ProfileLikedVideosBloc: Failed to read cached snapshot - $e',
        name: 'ProfileLikedVideosBloc',
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

  /// Persists [snapshot] under [_cacheKey] so reopening restores it. Cache
  /// failures are swallowed — they must never break an otherwise-fine load.
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
        'ProfileLikedVideosBloc: Failed to persist snapshot - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Fire-and-forget relay sync that keeps the in-memory liked list fresh for
  /// the live subscription after serving an instant local snapshot.
  void _scheduleBackgroundRelaySync() {
    unawaited(
      _likesRepository
          .syncUserReactions()
          .then((_) {
            Log.debug(
              'ProfileLikedVideosBloc: Background relay sync completed',
              name: 'ProfileLikedVideosBloc',
              category: LogCategory.video,
            );
          })
          .catchError((Object e) {
            Log.warning(
              'ProfileLikedVideosBloc: Background sync failed - $e',
              name: 'ProfileLikedVideosBloc',
              category: LogCategory.video,
            );
          }),
    );
  }

  ProfileLikedVideosError _errorFor(Object error) =>
      error is SyncFailedException || error is FetchLikesFailedException
      ? ProfileLikedVideosError.syncFailed
      : ProfileLikedVideosError.loadFailed;

  /// Subscribe to liked IDs changes and reconcile the video list reactively.
  ///
  /// Whenever the liked set changes (like or unlike), dispatches a
  /// [ProfileLikedVideosReconcileRequested] so the async handler can drop
  /// unliked videos and fetch a just-liked clip — `emit.forEach`'s callback is
  /// synchronous and cannot await the fetch itself.
  ///
  /// Note: This only works for the current user's own profile, as the
  /// LikesRepository only tracks the authenticated user's likes.
  /// For other users' profiles, this subscription has no effect.
  Future<void> _onSubscriptionRequested(
    ProfileLikedVideosSubscriptionRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Only subscribe for own profile - the repository only tracks current
    // user's likes, so watching it for other users would show wrong data.
    if (_isOtherUserProfile) return;

    await emit.forEach<List<String>>(
      _likesRepository.watchLikedEventIds(),
      onData: (newIds) {
        // Skip if IDs haven't changed, or before the initial sync completes.
        if (listEquals(newIds, state.likedEventIds) ||
            state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing) {
          return state;
        }

        // `close()` closes the event controller before it cancels this
        // emitter, so a delivery in that window would dispatch into a closed
        // bloc. There is nothing left to reconcile for at that point.
        if (isClosed) return state;

        Log.info(
          'ProfileLikedVideosBloc: Liked IDs changed, reconciling list',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );
        add(ProfileLikedVideosReconcileRequested(newIds));
        return state;
      },
    );
  }

  /// Reconcile the displayed videos against a fresh liked-ID list (dispatched
  /// from [_onSubscriptionRequested]). Drops unliked videos and fetches any
  /// newly-liked clip in the loaded window so it shows immediately.
  Future<void> _onReconcileRequested(
    ProfileLikedVideosReconcileRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    final freshIds = event.likedEventIds;
    if (listEquals(freshIds, state.likedEventIds)) return;

    try {
      final reconciled = await _reconcile(freshIds);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: reconciled.videos,
          likedEventIds: freshIds,
          nextPageOffset: reconciled.nextPageOffset,
          hasMoreContent: reconciled.hasMoreContent,
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
        'ProfileLikedVideosBloc: Failed to reconcile liked videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
    }
  }

  /// Handle load more request - fetches the next page of videos.
  ///
  /// Uses [state.nextPageOffset] to track the position in [state.likedEventIds]
  /// and fetches the next [ProfileTabPagination.pageSize] IDs. The offset
  /// advances by the number of IDs consumed, not the number of videos loaded
  /// (some IDs may not resolve to videos due to relay unavailability or
  /// format filtering).
  Future<void> _onLoadMoreRequested(
    ProfileLikedVideosLoadMoreRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Skip if not in success state, already loading, or no more content
    if (state.status != ProfileLikedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final offset = state.nextPageOffset;
    final totalCount = state.likedEventIds.length;

    // No more IDs to consume
    if (offset >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileLikedVideosBloc: Loading more videos '
      '(offset: $offset, total: $totalCount)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Fill a full page through sparse IDs, deduping against what's shown and
      // persisting the first batch so re-loading resolves from cache.
      final page = await _fetchVideoPage(
        state.likedEventIds,
        startOffset: offset,
        excludeVideoIds: state.videos.map((v) => v.id).toSet(),
        cacheFirstBatch: true,
      );

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${page.videos.length} more videos',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      final allVideos = [...state.videos, ...page.videos];
      final newOffset = page.nextOffset;
      final hasMore = page.hasMoreContent;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          nextPageOffset: newOffset,
        ),
      );

      // Grow the persisted snapshot so reopening restores the full scrolled
      // list (not just the first page) and the user does not re-paginate.
      await _persistSnapshot(
        ProfileVideoListSnapshot(
          videos: allVideos,
          itemIds: state.likedEventIds,
          nextPageOffset: newOffset,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Re-resolve the loaded window against the **current** blocklist.
  ///
  /// Re-fetching (rather than only filtering the held list down) is what lets a
  /// now-UNBLOCKED author's liked videos reappear — the cached snapshot stores
  /// the previously-filtered window, so dropping-only would never restore them.
  /// The videos are already in local storage, so
  /// [_fetchVideos] is a cache-first read, not a relay round-trip, and the
  /// re-resolved (re-filtered) window is persisted so a reopen stays correct.
  Future<void> _onBlocklistChanged(
    ProfileLikedVideosBlocklistChanged event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    if (state.likedEventIds.isEmpty || state.nextPageOffset == 0) {
      _dropBlockedFromCurrentList(emit);
      return;
    }

    final windowIds = state.likedEventIds.take(state.nextPageOffset).toList();
    final List<VideoEvent> videos;
    try {
      videos = await _fetchVideos(windowIds);
    } catch (e, stackTrace) {
      Log.warning(
        'ProfileLikedVideosBloc: Blocklist re-resolve failed - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (!isClosed) _dropBlockedFromCurrentList(emit);
      return;
    }
    if (isClosed) return;

    if (listEquals(
      videos.map((v) => v.id).toList(),
      state.videos.map((v) => v.id).toList(),
    )) {
      return;
    }

    emit(state.copyWith(videos: videos));
    await _persistSnapshot(
      ProfileVideoListSnapshot(
        videos: videos,
        itemIds: state.likedEventIds,
        nextPageOffset: state.nextPageOffset,
        hasMoreContent: state.hasMoreContent,
      ),
    );
  }

  /// Fallback when there is no window to re-resolve: drop newly-blocked authors
  /// from the held list (cannot restore unblocked ones without a window).
  void _dropBlockedFromCurrentList(Emitter<ProfileLikedVideosState> emit) {
    final filtered = _blocklistRepository.filterContent(
      state.videos,
      (video) => video.pubkey,
    );
    if (filtered.length != state.videos.length) {
      emit(state.copyWith(videos: filtered));
    }
  }

  Future<void> _onVideoRemoved(
    ProfileLikedVideosVideoRemoved event,
    Emitter<ProfileLikedVideosState> emit,
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
      itemIds: state.likedEventIds,
      removedIds: removedVideoIds,
      nextPageOffset: state.nextPageOffset,
    );
    if (videos.length == state.videos.length &&
        pruned.itemIds.length == state.likedEventIds.length &&
        pruned.nextPageOffset == state.nextPageOffset) {
      return;
    }

    final hasMoreContent = state.hasMoreContent;
    emit(
      state.copyWith(
        videos: videos,
        likedEventIds: pruned.itemIds,
        nextPageOffset: pruned.nextPageOffset,
        hasMoreContent: hasMoreContent,
      ),
    );
    await _persistSnapshot(
      ProfileVideoListSnapshot(
        videos: videos,
        itemIds: pruned.itemIds,
        nextPageOffset: pruned.nextPageOffset,
        hasMoreContent: hasMoreContent,
      ),
    );
  }

  /// Fetch videos for the given event IDs.
  ///
  /// Uses [VideosRepository.getVideosByIds] which implements cache-first:
  /// 1. Checks SQLite local storage for cached events
  /// 2. Queries Nostr relays only for missing events
  /// 3. Optionally saves fetched events to cache
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first page loads
  /// to avoid bloating the cache.
  ///
  /// Returns videos in the same order as [eventIds], excluding:
  /// - Videos not found in cache or relay
  /// - Unsupported video formats (WebM on iOS/macOS)
  Future<List<VideoEvent>> _fetchVideos(
    List<String> eventIds, {
    bool cacheResults = false,
  }) async {
    if (eventIds.isEmpty) return [];

    // VideosRepository handles cache-first lookup internally
    final videos = await _videosRepository.getVideosByIds(
      eventIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileLikedVideosBloc: Fetched ${videos.length}/${eventIds.length} videos '
      '(cacheResults: $cacheResults)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // Filter unsupported formats, then blocked authors.
    final supported = videos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    return _blocklistRepository.filterContent<VideoEvent>(
      supported,
      (video) => video.pubkey,
    );
  }

  /// Fetches videos until a full [ProfileTabPagination.pageSize] page is
  /// filled or the IDs run out, skipping over IDs that don't resolve (sparse
  /// likes) and deduping against [excludeVideoIds]. Returns the consumed-ID
  /// offset so pagination advances past dead IDs.
  Future<_LikedVideosPage> _fetchVideoPage(
    List<String> likedEventIds, {
    required int startOffset,
    Set<String> excludeVideoIds = const {},
    bool cacheFirstBatch = false,
  }) async {
    final totalCount = likedEventIds.length;
    var offset = startOffset;
    var isFirstBatch = true;
    final pageVideos = <VideoEvent>[];
    final seenIds = {...excludeVideoIds};

    while (offset < totalCount &&
        pageVideos.length < ProfileTabPagination.pageSize) {
      final batchIds = likedEventIds
          .skip(offset)
          .take(ProfileTabPagination.pageSize)
          .toList();
      if (batchIds.isEmpty) break;

      final videos = await _fetchVideos(
        batchIds,
        cacheResults: cacheFirstBatch && isFirstBatch,
      );
      final batchIndexById = {
        for (var index = 0; index < batchIds.length; index++)
          batchIds[index]: index,
      };
      var consumedIds = batchIds.length;

      for (final video in videos) {
        final batchIndex = batchIndexById[video.id];
        if (pageVideos.length >= ProfileTabPagination.pageSize) {
          if (batchIndex != null) consumedIds = batchIndex;
          break;
        }
        if (seenIds.add(video.id)) {
          pageVideos.add(video);
          if (pageVideos.length >= ProfileTabPagination.pageSize) {
            if (batchIndex != null) consumedIds = batchIndex + 1;
            break;
          }
        }
      }

      offset += consumedIds;
      isFirstBatch = false;
    }

    return _LikedVideosPage(
      videos: pageVideos,
      nextOffset: offset,
      hasMoreContent: offset < totalCount,
    );
  }

  @override
  Future<void> close() {
    _removedVideoIdsSubscription.cancel();
    _blocklistSubscription.cancel();
    return super.close();
  }
}

/// A page of liked videos resolved through possibly-sparse liked IDs.
final class _LikedVideosPage {
  const _LikedVideosPage({
    required this.videos,
    required this.nextOffset,
    required this.hasMoreContent,
  });

  final List<VideoEvent> videos;
  final int nextOffset;
  final bool hasMoreContent;
}
