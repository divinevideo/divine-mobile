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
/// - [BookmarksRepository]: Provides the videos in the viewer's NIP-51 global
///   bookmarks (kind 10003) as references — a video's `kind:pubkey:d-tag`
///   address where known, else its event id.
/// - [VideosRepository]: Fetches the latest revision at each address, and the
///   video of each event id, checking SQLite local storage before the relays.
///
/// An edit republishes a video at the same address under a new event id, so
/// only the address keeps a saved video current (#7135).
///
/// Bookmarks are the current viewer's own list, so this BLoC is only wired for
/// the current user's own profile.
class ProfileSavedVideosBloc
    extends Bloc<ProfileSavedVideosEvent, ProfileSavedVideosState> {
  ProfileSavedVideosBloc({
    required BookmarksRepository bookmarksRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    required Stream<String> removedVideoIds,
    required bool Function(VideoEvent video) deletedVideoFilter,
  }) : _bookmarksRepository = bookmarksRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _deletedVideoFilter = deletedVideoFilter,
       super(const ProfileSavedVideosState()) {
    // One queue owns all grid and snapshot mutations. Separate per-event
    // queues let a slow sync overwrite a newer bookmark notification.
    // Queue rather than drop syncs so every refresh completer is released.
    on<ProfileSavedVideosEvent>(_onEvent, transformer: sequential());
    _removedVideoIdsSubscription = removedVideoIds.listen((videoId) {
      if (isClosed) return;
      add(ProfileSavedVideosVideoRemoved(videoId));
    });
    // The share sheet saves through the same repository instance, so this is
    // how a grid that is already mounted learns about it.
    _bookmarksSubscription = bookmarksRepository
        .watchBookmarkedVideoReferences()
        .listen((references) {
          if (isClosed) return;
          add(
            ProfileSavedVideosReconcileRequested(
              _newestFirst(references),
              privateBookmarksLocked:
                  bookmarksRepository.hasUnreadablePrivateItems,
            ),
          );
        });
  }

  final BookmarksRepository _bookmarksRepository;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;
  late final StreamSubscription<String> _removedVideoIdsSubscription;
  late final StreamSubscription<List<String>> _bookmarksSubscription;
  final bool Function(VideoEvent video) _deletedVideoFilter;
  bool _loadMorePending = false;

  @override
  void add(ProfileSavedVideosEvent event) {
    if (event is! ProfileSavedVideosLoadMoreRequested || isClosed) {
      super.add(event);
      return;
    }
    // Coalesce scroll ticks at admission, including while another mutation
    // owns the queue. A handler-only guard runs too late for queued requests.
    if (_loadMorePending) return;
    _loadMorePending = true;
    try {
      super.add(event);
    } on Object {
      _loadMorePending = false;
      rethrow;
    }
  }

  /// Cache key for the saved-videos snapshot. The key is scoped to the signed-
  /// in user because this is the viewer's own list and must be cleared on
  /// sign-out.
  ///
  /// `_v3` because the snapshot's item ids are now bookmark references — a
  /// video's address where known, else its event id — and a v2 snapshot holds
  /// event ids only, along with the revisions they named, which may predate an
  /// edit (#7135). Starting cold loads one page.
  String get _cacheKey => '$_currentUserPubkey:profile_saved_videos_v3';

  /// Video references in reverse repository order: private entries first,
  /// then public entries, with each group reversed. The source contains no
  /// per-bookmark timestamps for a chronological merge across the groups.
  static List<String> _newestFirst(List<String> references) =>
      references.reversed.toList();

  /// Whether [reference] is a video's address rather than its event id.
  static bool _isAddress(String reference) => reference.contains(':');

  /// The references [video] can be saved under: its event id, and its
  /// address when it has one.
  static List<String> _referencesTo(VideoEvent video) => [
    video.id,
    ?video.addressableId,
  ];

  /// [videos] with one tile per video, the first of each kept: references are
  /// newest first, so that is the most recently saved one.
  static List<VideoEvent> _oneTilePerVideo(Iterable<VideoEvent> videos) {
    final shown = <String>{};
    return [
      for (final video in videos)
        if (shown.add(video.feedDedupKey)) video,
    ];
  }

  Future<void> _onEvent(
    ProfileSavedVideosEvent event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    switch (event) {
      case ProfileSavedVideosSyncRequested():
        await _onSyncRequested(event, emit);
      case ProfileSavedVideosLoadMoreRequested():
        try {
          await _onLoadMoreRequested(event, emit);
        } finally {
          _loadMorePending = false;
        }
      case ProfileSavedVideosReconcileRequested():
        await _onReconcileRequested(event, emit);
      case ProfileSavedVideosVideoRemoved():
        await _onVideoRemoved(event, emit);
    }
  }

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
      final (:ids, :privateBookmarksLocked) = await _resolveSavedIds();
      if (isClosed) return;

      if (state.videos.isEmpty) {
        await _coldLoad(
          ids,
          emit,
          privateBookmarksLocked: privateBookmarksLocked,
        );
      } else {
        await _warmRevalidate(
          ids,
          emit,
          privateBookmarksLocked: privateBookmarksLocked,
        );
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

  /// Reconciles the bookmark list against the relay, then reads its video
  /// references.
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
  ///
  /// The lock flag is read with the ids: when the private section stayed
  /// encrypted, the ids are only the public part of the viewer's list.
  Future<({List<String> ids, bool privateBookmarksLocked})>
  _resolveSavedIds() async {
    await _bookmarksRepository.syncGlobalBookmarks();
    return (
      ids: _newestFirst(_bookmarksRepository.bookmarkedVideoReferences),
      privateBookmarksLocked: _bookmarksRepository.hasUnreadablePrivateItems,
    );
  }

  /// Cold path: nothing cached. Fetch the first page for [savedEventIds].
  Future<void> _coldLoad(
    List<String> savedEventIds,
    Emitter<ProfileSavedVideosState> emit, {
    required bool privateBookmarksLocked,
  }) async {
    if (savedEventIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: [],
          savedEventIds: [],
          nextPageOffset: 0,
          hasMoreContent: false,
          isRefreshing: false,
          privateBookmarksLocked: privateBookmarksLocked,
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
        privateBookmarksLocked: privateBookmarksLocked,
        clearError: true,
      ),
    );
    await _persistSnapshot(snapshot);
  }

  /// Warm path: cached videos are already on screen. Reconcile against the
  /// fresh bookmark list (drop unsaved, fetch newly-saved in the window, and
  /// re-read every address in it, which an edit may have moved on).
  Future<void> _warmRevalidate(
    List<String> freshIds,
    Emitter<ProfileSavedVideosState> emit, {
    required bool privateBookmarksLocked,
  }) async {
    if (listEquals(freshIds, state.savedEventIds) &&
        !_isWindowUnderfilled(freshIds) &&
        !state.videos.any(_deletedVideoFilter) &&
        !_reconcileWindow(freshIds).any(_isAddress)) {
      emit(
        state.copyWith(
          isRefreshing: false,
          privateBookmarksLocked: privateBookmarksLocked,
        ),
      );
      return;
    }

    final reconciled = await _reconcile(freshIds, refreshAddresses: true);
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
        privateBookmarksLocked: privateBookmarksLocked,
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

  /// Lands a bookmark change made while the grid is already showing — a save
  /// or an unsave from the share sheet — without waiting for the next sync.
  Future<void> _onReconcileRequested(
    ProfileSavedVideosReconcileRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    // Ignore the initial subscription replay before the first sync request.
    // Notifications received during a sync wait in the shared event queue.
    if (state.status == ProfileSavedVideosStatus.initial) {
      return;
    }
    final freshIds = event.savedEventIds;
    if (listEquals(freshIds, state.savedEventIds)) {
      // The private section can lock or unlock without moving a video id.
      emit(
        state.copyWith(privateBookmarksLocked: event.privateBookmarksLocked),
      );
      return;
    }

    try {
      final reconciled = await _reconcile(freshIds);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: reconciled.videos,
          savedEventIds: freshIds,
          nextPageOffset: reconciled.nextPageOffset,
          hasMoreContent: reconciled.hasMoreContent,
          lastFetchResolvedVideoCount: reconciled.resolvedVideoCount,
          privateBookmarksLocked: event.privateBookmarksLocked,
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
        'ProfileSavedVideosBloc: Failed to reconcile saved videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
    }
  }

  /// Reconciles displayed videos against a fresh [freshIds] list: keeps saved
  /// videos still present, drops the rest, and fetches only the newly-saved
  /// IDs in the loaded window. Bounded so it never bulk-fetches.
  ///
  /// With [refreshAddresses], every address in the window is fetched again
  /// too, since an edit republishes a video at its address (#7135). A tile
  /// whose address comes back empty keeps the revision already shown.
  Future<
    ({
      List<VideoEvent> videos,
      int nextPageOffset,
      bool hasMoreContent,
      int resolvedVideoCount,
    })
  >
  _reconcile(List<String> freshIds, {bool refreshAddresses = false}) async {
    final byReference = <String, VideoEvent>{
      for (final video in state.videos)
        if (!_deletedVideoFilter(video))
          for (final reference in _referencesTo(video)) reference: video,
    };
    final windowIds = _reconcileWindow(freshIds);

    final idsToFetch = windowIds
        .where(
          (id) =>
              !byReference.containsKey(id) ||
              (refreshAddresses && _isAddress(id)),
        )
        .toList();
    // Counts this window's fetch only. A video carried over in [byReference]
    // but absent from [windowIds] is no longer saved, so it is no evidence
    // that the window resolved — seeding the count with it would send an
    // all-unresolved window back to the empty state this fix exists to avoid.
    var resolvedVideoCount = 0;
    if (idsToFetch.isNotEmpty) {
      final fetched = await _resolveReferences(idsToFetch, cacheResults: true);
      resolvedVideoCount = fetched.length;
      for (final MapEntry(key: reference, value: video) in fetched.entries) {
        if (video.isSupportedOnCurrentPlatform) byReference[reference] = video;
      }
    }

    final videos = _oneTilePerVideo([
      for (final id in windowIds) ?byReference[id],
    ]);
    return (
      videos: videos,
      nextPageOffset: windowIds.length,
      hasMoreContent: windowIds.length < freshIds.length,
      resolvedVideoCount: videos.isEmpty ? resolvedVideoCount : 0,
    );
  }

  /// The leading [freshIds] that [_reconcile] resolves.
  List<String> _reconcileWindow(List<String> freshIds) {
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
    return freshIds.take(windowSize).toList();
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
      // Expired snapshots are served too; the sync revalidates right after.
      final entry = await CacheSync.readEntry<ProfileVideoListSnapshot>(
        key: _cacheKey,
        fromJson: ProfileVideoListSnapshot.fromJson,
      );
      return entry == null ? null : _filterDeletedSnapshot(entry.data);
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
    final deletedReferences = <String>{};
    final videos = <VideoEvent>[];
    for (final video in snapshot.videos) {
      if (_deletedVideoFilter(video)) {
        deletedReferences.addAll(_referencesTo(video));
      } else {
        videos.add(video);
      }
    }
    if (deletedReferences.isEmpty) return snapshot;

    final pruned = pruneProfileVideoListIds(
      itemIds: snapshot.itemIds,
      removedIds: deletedReferences,
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

      // A video saved under two references can land on two pages.
      final shownVideos = state.videos.map((v) => v.feedDedupKey).toSet();
      final uniqueNewVideos = newVideos
          .where((v) => !shownVideos.contains(v.feedDedupKey))
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
    final removedReferences = <String>{event.videoId};
    final videos = <VideoEvent>[];
    for (final video in state.videos) {
      final isRemoved = video.id == event.videoId || _deletedVideoFilter(video);
      if (isRemoved) {
        removedReferences.addAll(_referencesTo(video));
      } else {
        videos.add(video);
      }
    }

    final pruned = pruneProfileVideoListIds(
      itemIds: state.savedEventIds,
      removedIds: removedReferences,
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

  /// Fetch the videos [references] name, one tile per video.
  ///
  /// Returns videos in the same order as [references], excluding references
  /// not found in cache or relay and videos whose format is unsupported on
  /// the current platform. `resolvedVideoCount` counts them before that
  /// platform filter.
  Future<({List<VideoEvent> videos, int resolvedVideoCount})> _fetchVideos(
    List<String> references, {
    bool cacheResults = false,
  }) async {
    if (references.isEmpty) {
      return (videos: <VideoEvent>[], resolvedVideoCount: 0);
    }

    final byReference = await _resolveReferences(
      references,
      cacheResults: cacheResults,
    );
    final videos = _oneTilePerVideo([
      for (final reference in references) ?byReference[reference],
    ]);
    return (
      videos: videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
      resolvedVideoCount: videos.length,
    );
  }

  /// The videos [references] resolve to, keyed by reference, via
  /// [VideosRepository], which checks local storage before the relays. An
  /// address resolves to its latest revision, an event id to that event.
  /// References that resolve to nothing are absent.
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits.
  Future<Map<String, VideoEvent>> _resolveReferences(
    List<String> references, {
    required bool cacheResults,
  }) async {
    final addresses = references.where(_isAddress).toList();
    final eventIds = references.where((r) => !_isAddress(r)).toList();
    final [videosByEventId, videosByAddress] = await Future.wait([
      if (eventIds.isEmpty)
        Future.value(const <VideoEvent>[])
      else
        _videosRepository.getVideosByIds(eventIds, cacheResults: cacheResults),
      if (addresses.isEmpty)
        Future.value(const <VideoEvent>[])
      else
        _videosRepository.getVideosByAddressableIds(
          addresses,
          cacheResults: cacheResults,
        ),
    ]);
    final byReference = <String, VideoEvent>{
      for (final video in videosByEventId) video.id: video,
      for (final video in videosByAddress) ?video.addressableId: video,
    };

    Log.debug(
      'ProfileSavedVideosBloc: Fetched ${byReference.length}/'
      '${references.length} videos (cacheResults: $cacheResults)',
      name: 'ProfileSavedVideosBloc',
      category: LogCategory.video,
    );

    return byReference;
  }

  @override
  Future<void> close() async {
    final removedVideoIdsCancelled = _removedVideoIdsSubscription.cancel();
    final bookmarksCancelled = _bookmarksSubscription.cancel();
    await super.close();
    await removedVideoIdsCancelled;
    await bookmarksCancelled;
  }
}
