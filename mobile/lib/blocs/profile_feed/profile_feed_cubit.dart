// ABOUTME: Bloc backing a single author's profile/video feed.
// ABOUTME: Composes REST via videos_repository.getAuthorFeed and subscribes to
// ABOUTME: VideoEventService for the realtime/optimistic half (the repo is
// ABOUTME: Flutter/VES-free). Replaces the legacy profile_feed_provider.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_enrichment_merge.dart';
import 'package:openvine/blocs/profile_feed/profile_video_metadata_cache.dart';
import 'package:openvine/blocs/profile_feed/profile_video_snapshot_cache.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_sync_completion.dart';
import 'package:openvine/blocs/profile_shared/profile_video_offset_snapshot.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_feed_event.dart';
part 'profile_feed_state.dart';

/// Audits an event stream, then processes the survivors sequentially.
///
/// Used for [ProfileFeedRelaySnapshotChanged]: the cubit listens to the
/// app-wide [VideoEventService], so a single profile pays a snapshot
/// reconciliation for *every* global relay event — even ones for other
/// feeds. Auditing collapses those bursts so a high-video-count author's
/// profile recomputes its (O(videos)) snapshot at most once per window
/// rather than hundreds of times during streaming. Unlike `debounce`,
/// `audit` cannot be starved by sustained sub-window traffic from other
/// feeds — it still emits the latest snapshot once per window.
EventTransformer<E> _auditSequential<E>(Duration duration) {
  return (events, mapper) =>
      sequential<E>().call(events.audit(duration), mapper);
}

/// Enriches REST-sourced videos with their full Nostr tag set. Injected so the
/// cubit stays decoupled from `NostrClient` / the enrichment util and testable.
typedef EnrichVideos = Future<List<VideoEvent>> Function(
  List<VideoEvent> videos,
);

/// Bloc backing a single author's profile feed.
///
/// Cold load + pagination come from `videos_repository.getAuthorFeed` (REST-
/// source composition); the relay/realtime half (snapshot, optimistic add,
/// tombstones, live updates) is owned here over [VideoEventService]. Filtering
/// is applied on **every** emit so a block/unblock reflects without a re-fetch
/// (#4782).
///
/// It extends [Bloc] (not [Cubit]) only so `droppable()` can guard pagination.
class ProfileFeedCubit extends Bloc<ProfileFeedEvent, ProfileFeedState> {
  ProfileFeedCubit({
    required String authorPubkey,
    required VideosRepository videosRepository,
    required VideoEventService videoEventService,
    required ContentBlocklistRepository blocklistRepository,
    required EnrichVideos enrichVideos,
  }) : _authorPubkey = authorPubkey,
       _videosRepository = videosRepository,
       _videoEventService = videoEventService,
       _blocklistRepository = blocklistRepository,
       _enrichVideos = enrichVideos,
       super(const ProfileFeedState()) {
    on<ProfileFeedStarted>(_onStarted, transformer: sequential());
    on<ProfileFeedLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<ProfileFeedRefreshRequested>(_onRefresh, transformer: restartable());
    on<ProfileFeedFiltersChanged>(_onFiltersChanged, transformer: sequential());
    // Audited: the cubit listens to the app-wide [VideoEventService], so a
    // streaming relay — including this author's whole backlog, delivered as
    // individual live "new video" notifications — would otherwise reconcile
    // the O(videos) snapshot (and rebuild the grid) once per event. The audit
    // window coalesces bursts into a single reconciliation that reads the full
    // author set via [_relayVideosSnapshot], without starving under sustained
    // traffic. This is the sole realtime add path; there is no separate
    // per-video handler (the snapshot is always a superset of any single new
    // video, which is in the author bucket before the notification fires).
    on<ProfileFeedRelaySnapshotChanged>(
      _onRelaySnapshot,
      transformer: _auditSequential(relaySnapshotAudit),
    );
    on<ProfileFeedVideoUpdated>(_onVideoUpdated, transformer: restartable());
    on<ProfileFeedInitialLoadTimedOut>(
      _onInitialLoadTimedOut,
      transformer: sequential(),
    );
    on<ProfileFeedEnrichmentReady>(
      _onEnrichmentReady,
      transformer: sequential(),
    );

    _registerRealtimeListeners();
    add(const ProfileFeedStarted());
  }

  /// Hard ceiling on how long [ProfileFeedState.isInitialLoad] stays true if no
  /// source settles, so the loading spinner can't strand (#4164).
  @visibleForTesting
  static Duration initialLoadHardTimeout = const Duration(seconds: 10);

  /// Audit window for coalescing [ProfileFeedRelaySnapshotChanged] bursts. The
  /// cubit listens to the app-wide [VideoEventService], so unrelated feeds'
  /// relay traffic would otherwise trigger a full snapshot reconciliation per
  /// event — multi-second jank on profiles with many videos. See
  /// [_auditSequential].
  @visibleForTesting
  static Duration relaySnapshotAudit = const Duration(milliseconds: 250);

  /// Debounce window for persisting the Videos-tab snapshot. The snapshot
  /// contains full [VideoEvent] payloads, so serializing it on every emit during
  /// relay/enrichment bursts is unnecessary main-isolate work.
  @visibleForTesting
  static Duration snapshotPersistDebounce = const Duration(milliseconds: 250);

  final String _authorPubkey;
  final VideosRepository _videosRepository;
  final VideoEventService _videoEventService;
  final ContentBlocklistRepository _blocklistRepository;
  final EnrichVideos _enrichVideos;

  /// Best-effort stale-while-revalidate persistence for the Videos tab.
  late final ProfileVideoSnapshotCache _snapshotCache =
      ProfileVideoSnapshotCache(_authorPubkey);

  /// Accumulated **unfiltered** source list (REST + relay). Not UI state — it's
  /// the source [ProfileFeedFiltersChanged] re-filters in place without a
  /// re-fetch. Same source-cache category as the injected dependencies.
  List<VideoEvent> _unfilteredVideos = const [];

  /// Backfill cache for engagement counts, used on the Nostr-fallback loadMore
  /// branch where there is no REST hydration.
  final ProfileVideoMetadataCache _metadataCache = ProfileVideoMetadataCache();

  /// True while a cold-load fetch is in flight (timer-coupled lifecycle
  /// bookkeeping; the observable result is [ProfileFeedState.isInitialLoad]).
  bool _initialLoadPending = false;
  Timer? _initialLoadTimer;
  Timer? _snapshotPersistTimer;
  ProfileVideoOffsetSnapshot? _pendingSnapshot;

  VoidCallback? _removeChangeListener;
  VoidCallback? _unregisterUpdate;

  // ---------------------------------------------------------------------------
  // Realtime wiring
  // ---------------------------------------------------------------------------

  void _registerRealtimeListeners() {
    void onChanged() {
      if (!isClosed) add(const ProfileFeedRelaySnapshotChanged());
    }

    _videoEventService.addListener(onChanged);
    _removeChangeListener = () => _videoEventService.removeListener(onChanged);

    _unregisterUpdate = _videoEventService.addVideoUpdateListener((updated) {
      if (updated.pubkey == _authorPubkey && !isClosed) {
        add(const ProfileFeedVideoUpdated());
      }
    });
  }

  Future<void> _subscribe() async {
    try {
      await _videoEventService.subscribeToUserVideos(_authorPubkey);
    } on Object {
      // Non-fatal: the realtime listeners and REST still populate the feed.
    }
  }

  // ---------------------------------------------------------------------------
  // Cold load + refresh
  // ---------------------------------------------------------------------------

  Future<void> _onStarted(
    ProfileFeedStarted event,
    Emitter<ProfileFeedState> emit,
  ) async {
    emit(state.copyWith(status: ProfileFeedStatus.loading));

    final relaySeed = _relayVideosSnapshot();

    // Stale-while-revalidate: a persisted snapshot restores the full
    // scrolled-through window + REST cursor instantly, so reopening a profile
    // does not re-paginate from the relay (#5279 extended to the Videos tab).
    final cached = await _snapshotCache.read();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      await _restoreFromCache(emit, cached: cached, relaySeed: relaySeed);
      return;
    }

    // Cold open — no cache to serve.
    if (relaySeed.isEmpty) {
      _beginInitialLoadTracking();
    }
    _unfilteredVideos = relaySeed;
    unawaited(_subscribe());

    emit(
      state.copyWith(
        status: ProfileFeedStatus.ready,
        videos: _applyFeedFilters(relaySeed),
        hasMoreContent:
            relaySeed.length >= AppConstants.hasMoreContentThreshold,
        isInitialLoad: relaySeed.isEmpty,
        isFetchingTotalCount: true,
        lastUpdated: DateTime.now(),
      ),
    );

    // Persist before the network is consulted. Waiting for a successful REST
    // load means a user whose loads keep failing never accumulates a snapshot,
    // so the cache is empty for exactly the connections that need it most.
    if (relaySeed.isNotEmpty) _persistSnapshot();

    final result = await _loadFromRest(
      emit,
      relaySeed: relaySeed,
      mergeWithCurrent: false,
      skipCache: false,
    );

    if (!isClosed && result?.isFromCache == true) {
      await _doRefresh(emit, backfillInitialPage: true);
    } else if (!isClosed && result != null) {
      await _backfillInitialRestPage(emit);
    }
  }

  /// Serves the persisted snapshot immediately (full window + cursor), then
  /// revalidates the head in the background.
  ///
  /// The cached videos are merged with the current [relaySeed] so any realtime
  /// data already in [VideoEventService] (e.g. a just-published clip) shows on
  /// top of the restored window. [ProfileFeedState.nextOffset] /
  /// [ProfileFeedState.hasMoreContent] come straight from the snapshot so
  /// scrolling resumes where the user left off.
  Future<void> _restoreFromCache(
    Emitter<ProfileFeedState> emit, {
    required ProfileVideoOffsetSnapshot cached,
    required List<VideoEvent> relaySeed,
  }) async {
    final merged = _withoutTombstones(
      mergeProfileFeedVideoLists(relaySeed, cached.videos),
    );
    _unfilteredVideos = merged;
    _metadataCache.cache(merged);
    unawaited(_subscribe());

    emit(
      state.copyWith(
        status: ProfileFeedStatus.ready,
        videos: _applyFeedFilters(merged),
        nextOffset: cached.nextOffset,
        totalVideoCount: cached.totalVideoCount,
        hasMoreContent: cached.hasMoreContent,
        isInitialLoad: false,
        isRefreshing: true,
        isFetchingTotalCount: cached.totalVideoCount == null,
        lastUpdated: DateTime.now(),
      ),
    );
    _persistSnapshot();

    await _revalidateHead(emit, relaySeed: relaySeed);
  }

  /// Refreshes the head of a cache-restored feed: re-fetches the first REST
  /// page and merges it into the restored window, **preserving** the restored
  /// pagination cursor so the scrolled-through tail is not dropped and the user
  /// does not re-paginate from the start. Stale cursors self-heal on the next
  /// load-more (an over-shot offset returns empty → `hasMoreContent` flips off).
  ///
  /// A `null` restored cursor (Nostr-fallback) is preserved too: even if this
  /// REST refresh succeeds, pagination stays on the relay `until` path until a
  /// full refresh re-resolves the offset. That keeps the restored tail intact
  /// at the cost of one stale-mode pagination, and self-heals on pull-to-refresh.
  Future<void> _revalidateHead(
    Emitter<ProfileFeedState> emit, {
    required List<VideoEvent> relaySeed,
  }) async {
    try {
      final result = await _videosRepository.getAuthorFeed(
        authorPubkey: _authorPubkey,
        relaySeed: relaySeed,
        skipCache: true,
      );
      if (isClosed) return;
      final merged = _withoutTombstones(
        mergeProfileFeedVideoLists(_unfilteredVideos, result.videos),
      );
      _unfilteredVideos = merged;
      _metadataCache.cache(merged);
      emit(
        state.copyWith(
          videos: _applyFeedFilters(merged),
          totalVideoCount: result.totalCount ?? state.totalVideoCount,
          isRefreshing: false,
          isFetchingTotalCount: false,
          lastUpdated: DateTime.now(),
        ),
      );
      _enrichInBackground();
      _persistSnapshot();
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(state.copyWith(isRefreshing: false, isFetchingTotalCount: false));
    }
  }

  /// Refreshes the feed, completing
  /// [ProfileFeedRefreshRequested.completer] once the load has settled so the
  /// profile pull-to-refresh can release its indicator.
  ///
  /// Safe under `restartable()`: unlike `droppable()`, it invokes the handler
  /// for every event and only cancels the superseded one's emitter, so a
  /// refresh that loses the race still reaches this `finally`.
  Future<void> _onRefresh(
    ProfileFeedRefreshRequested event,
    Emitter<ProfileFeedState> emit,
  ) async {
    try {
      await _doRefresh(emit);
    } finally {
      completeProfileTabSync(event.completer);
    }
  }

  Future<void> _onVideoUpdated(
    ProfileFeedVideoUpdated event,
    Emitter<ProfileFeedState> emit,
  ) => _doRefresh(emit);

  Future<void> _doRefresh(
    Emitter<ProfileFeedState> emit, {
    bool backfillInitialPage = false,
  }) async {
    emit(
      state.copyWith(
        isRefreshing: true,
        isInitialLoad: false,
        isFetchingTotalCount: true,
      ),
    );
    final relaySeed = _relayVideosSnapshot();
    unawaited(_subscribe());
    await _loadFromRest(
      emit,
      relaySeed: relaySeed,
      mergeWithCurrent: false,
      skipCache: true,
    );
    if (backfillInitialPage && !isClosed) {
      await _backfillInitialRestPage(emit);
    }
  }

  Future<AuthorFeedResult?> _loadFromRest(
    Emitter<ProfileFeedState> emit, {
    required List<VideoEvent> relaySeed,
    required bool mergeWithCurrent,
    required bool skipCache,
  }) async {
    try {
      final result = await _videosRepository.getAuthorFeed(
        authorPubkey: _authorPubkey,
        relaySeed: relaySeed,
        skipCache: skipCache,
      );
      if (isClosed) return null;
      _applyRestPage(
        emit,
        pageVideos: result.videos,
        totalCount: result.totalCount,
        nextOffset: result.nextOffset,
        hasMore: result.hasMore,
        mergeWithCurrent: mergeWithCurrent,
      );
      _enrichInBackground();
      return result;
    } on Object catch (error, stackTrace) {
      if (isClosed) return null;
      addError(error, stackTrace);
      _completeInitialLoad();
      emit(
        state.copyWith(
          status: state.videos.isEmpty
              ? ProfileFeedStatus.failure
              : ProfileFeedStatus.ready,
          isRefreshing: false,
          isFetchingTotalCount: false,
        ),
      );
      return null;
    }
  }

  Future<void> _backfillInitialRestPage(Emitter<ProfileFeedState> emit) async {
    var targetCount = AppConstants.paginationBatchSize;
    final totalVideoCount = state.totalVideoCount;
    if (totalVideoCount != null && totalVideoCount < targetCount) {
      targetCount = totalVideoCount;
    }

    while (!isClosed &&
        state.hasMoreContent &&
        state.nextOffset != null &&
        state.videos.length < targetCount) {
      final offset = state.nextOffset;
      if (offset == null) return;

      final beforeCount = state.videos.length;
      final AuthorFeedResult result;
      try {
        result = await _videosRepository.getAuthorFeed(
          authorPubkey: _authorPubkey,
          offset: offset,
        );
        if (isClosed) return;
      } on Object catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        emit(state.copyWith(hasLoadMoreError: true));
        return;
      }

      if (result.videos.isEmpty) {
        if (_isAdvancingRestPage(result, offset)) {
          _applyRestPage(
            emit,
            pageVideos: const [],
            totalCount: result.totalCount,
            nextOffset: result.nextOffset,
            hasMore: result.hasMore,
            mergeWithCurrent: true,
          );
          continue;
        }
        emit(state.copyWith(hasMoreContent: false));
        return;
      }

      final enriched = await _enrichVideos(result.videos);
      if (isClosed) return;
      _applyRestPage(
        emit,
        pageVideos: enriched,
        totalCount: result.totalCount,
        nextOffset: result.nextOffset,
        hasMore: result.hasMore,
        mergeWithCurrent: true,
      );

      if (state.videos.length <= beforeCount && state.nextOffset == offset) {
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Load more (REST offset page or Nostr-fallback page)
  // ---------------------------------------------------------------------------

  Future<void> _onLoadMore(
    ProfileFeedLoadMoreRequested event,
    Emitter<ProfileFeedState> emit,
  ) async {
    if (!state.hasMoreContent) return;
    emit(state.copyWith(isLoadingMore: true, hasLoadMoreError: false));

    try {
      if (state.nextOffset != null) {
        final offset = state.nextOffset;
        final result = await _videosRepository.getAuthorFeed(
          authorPubkey: _authorPubkey,
          offset: offset,
        );
        if (isClosed) return;
        if (result.videos.isEmpty) {
          if (_isAdvancingRestPage(result, offset)) {
            _applyRestPage(
              emit,
              pageVideos: const [],
              totalCount: result.totalCount,
              nextOffset: result.nextOffset,
              hasMore: result.hasMore,
              mergeWithCurrent: true,
            );
            return;
          }
          emit(state.copyWith(hasMoreContent: false, isLoadingMore: false));
          return;
        }
        final enriched = await _enrichVideos(result.videos);
        if (isClosed) return;
        _applyRestPage(
          emit,
          pageVideos: enriched,
          totalCount: result.totalCount,
          nextOffset: result.nextOffset,
          hasMore: result.hasMore,
          mergeWithCurrent: true,
        );
      } else {
        // Nostr-fallback pagination (REST unavailable).
        final until = state.videos.isEmpty
            ? null
            : state.videos
                  .map((v) => v.createdAt)
                  .reduce((a, b) => a < b ? a : b);
        final before = _videoEventService.authorVideos(_authorPubkey).length;
        await _videoEventService.queryHistoricalUserVideos(
          _authorPubkey,
          until: until,
        );
        if (isClosed) return;
        final after = _videoEventService.authorVideos(_authorPubkey).length;

        _unfilteredVideos = _withoutTombstones(
          _metadataCache.apply(
            _videoEventService
                .authorVideos(_authorPubkey)
                .where((v) => !v.isRepost)
                .toList(),
          ),
        );
        // C5 fix: copyWith over the live state preserves totalVideoCount,
        // isInitialLoad, isFetchingTotalCount and nextOffset that the legacy
        // fresh-VideoFeedState() emit dropped.
        emit(
          state.copyWith(
            videos: _applyFeedFilters(_unfilteredVideos),
            hasMoreContent: (after - before) > 0,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
        _persistSnapshot();
      }
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(state.copyWith(isLoadingMore: false, hasLoadMoreError: true));
    }
  }

  bool _isAdvancingRestPage(AuthorFeedResult result, int? previousOffset) {
    final nextOffset = result.nextOffset;
    return result.hasMore == true &&
        nextOffset != null &&
        nextOffset != previousOffset;
  }

  void _applyRestPage(
    Emitter<ProfileFeedState> emit, {
    required List<VideoEvent> pageVideos,
    required int? totalCount,
    required int? nextOffset,
    required bool? hasMore,
    required bool mergeWithCurrent,
  }) {
    _completeInitialLoad();
    final merged = mergeWithCurrent
        ? mergeProfileFeedVideoLists(_unfilteredVideos, pageVideos)
        : pageVideos;
    _unfilteredVideos = _withoutTombstones(merged);
    _metadataCache.cache(_unfilteredVideos);
    final filtered = _applyFeedFilters(_unfilteredVideos);

    emit(
      state.copyWith(
        status: ProfileFeedStatus.ready,
        videos: filtered,
        hasMoreContent:
            hasMore ?? (pageVideos.length >= AppConstants.paginationBatchSize),
        totalVideoCount: totalCount ?? state.totalVideoCount,
        nextOffset: nextOffset,
        isLoadingMore: false,
        isRefreshing: false,
        isFetchingTotalCount: false,
        isInitialLoad: _shouldKeepInitialLoad(videosEmpty: filtered.isEmpty),
        lastUpdated: DateTime.now(),
      ),
    );
    _persistSnapshot();
  }

  // ---------------------------------------------------------------------------
  // Background Nostr enrichment of the REST page (#3705)
  // ---------------------------------------------------------------------------

  void _enrichInBackground() {
    final snapshot = _unfilteredVideos;
    if (snapshot.isEmpty) return;
    final sourceKeys = {
      for (final v in snapshot) canonicalProfileFeedVideoKey(v),
    };
    unawaited(
      _enrichVideos(snapshot)
          .then((enriched) {
            if (isClosed || identical(enriched, snapshot)) return;
            add(
              ProfileFeedEnrichmentReady(
                enriched: enriched,
                sourceKeys: sourceKeys,
              ),
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!isClosed) addError(error, stackTrace);
          }),
    );
  }

  void _onEnrichmentReady(
    ProfileFeedEnrichmentReady event,
    Emitter<ProfileFeedState> emit,
  ) {
    _unfilteredVideos = mergeProfileFeedEnrichment(
      current: _unfilteredVideos,
      sourceKeys: event.sourceKeys,
      incoming: event.enriched,
      removeTombstones: _withoutTombstones,
    );
    emit(
      state.copyWith(
        videos: _applyFeedFilters(_unfilteredVideos),
        lastUpdated: DateTime.now(),
      ),
    );
    _persistSnapshot();
  }

  // ---------------------------------------------------------------------------
  // Realtime handlers
  // ---------------------------------------------------------------------------

  void _onRelaySnapshot(
    ProfileFeedRelaySnapshotChanged event,
    Emitter<ProfileFeedState> emit,
  ) {
    final snapshot = _relayVideosSnapshot();
    final merged = _withoutTombstones(
      mergeProfileFeedVideoLists(_unfilteredVideos, snapshot),
    );
    final filtered = _applyFeedFilters(merged);
    if (_sameVideoSequence(state.videos, filtered)) return;

    if (merged.isNotEmpty) _completeInitialLoad();
    _unfilteredVideos = merged;
    emit(
      state.copyWith(
        videos: filtered,
        hasMoreContent: state.totalVideoCount != null
            ? state.hasMoreContent
            : merged.length >= AppConstants.hasMoreContentThreshold,
        isRefreshing: false,
        isInitialLoad: _shouldKeepInitialLoad(videosEmpty: filtered.isEmpty),
        lastUpdated: DateTime.now(),
      ),
    );
    _persistSnapshot();
  }

  void _onFiltersChanged(
    ProfileFeedFiltersChanged event,
    Emitter<ProfileFeedState> emit,
  ) {
    // Re-filter in place over the cached source — no re-fetch, no re-key
    // (#4782). Equatable suppresses the emit when the filtered list is
    // unchanged.
    emit(state.copyWith(videos: _applyFeedFilters(_unfilteredVideos)));
  }

  // ---------------------------------------------------------------------------
  // Initial-load spinner machine (#4164)
  // ---------------------------------------------------------------------------

  void _onInitialLoadTimedOut(
    ProfileFeedInitialLoadTimedOut event,
    Emitter<ProfileFeedState> emit,
  ) {
    if (!_initialLoadPending) return;
    _initialLoadPending = false;
    _initialLoadTimer = null;
    if (state.isInitialLoad) {
      emit(state.copyWith(isInitialLoad: false));
    }
  }

  void _beginInitialLoadTracking() {
    _initialLoadPending = true;
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(initialLoadHardTimeout, () {
      if (!isClosed) add(const ProfileFeedInitialLoadTimedOut());
    });
  }

  void _completeInitialLoad() {
    _initialLoadPending = false;
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
  }

  bool _shouldKeepInitialLoad({required bool videosEmpty}) =>
      _initialLoadPending && videosEmpty;

  // ---------------------------------------------------------------------------
  // Source helpers (ported from the provider)
  // ---------------------------------------------------------------------------

  List<VideoEvent> _relayVideosSnapshot() {
    var videos = _videoEventService
        .authorVideos(_authorPubkey)
        .where((v) => !v.isRepost)
        .toList();
    videos = _metadataCache.apply(videos);
    return _withoutTombstones(_videoEventService.filterVideoList(videos));
  }

  /// Blocked/muted-author filter on top of the content-preference filter, for
  /// the REST author endpoint (anonymous, applies no per-viewer block). Relay
  /// videos are already blocklist-filtered by [VideoEventService] at reception
  /// (#4782). Does NOT remove tombstones — those are handled in the merge paths.
  List<VideoEvent> _applyFeedFilters(List<VideoEvent> videos) {
    if (videos.isEmpty) return videos;
    final blockFiltered = videos
        .where((v) => !_blocklistRepository.shouldFilterFromFeeds(v.pubkey))
        .toList();
    return _videoEventService.filterVideoList(blockFiltered);
  }

  List<VideoEvent> _withoutTombstones(List<VideoEvent> videos) {
    if (videos.isEmpty) return videos;
    return videos
        .where((v) => !_videoEventService.isVideoEventKnownDeleted(v))
        .toList();
  }

  bool _sameVideoSequence(List<VideoEvent> left, List<VideoEvent> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      final l = left[i];
      final r = right[i];
      if (l.id != r.id) return false;
      if (l.originalLoops != r.originalLoops) return false;
      if (l.rawTags['views'] != r.rawTags['views']) return false;
      if (l.originalLikes != r.originalLikes) return false;
      if (l.originalComments != r.originalComments) return false;
      if (l.originalReposts != r.originalReposts) return false;
      if (l.nostrLikeCount != r.nostrLikeCount) return false;
    }
    return true;
  }

  /// Persists the current source window + cursor via [_snapshotCache] so a
  /// reopen restores it (stale-while-revalidate).
  void _persistSnapshot() {
    _pendingSnapshot = ProfileVideoOffsetSnapshot.capped(
      videos: _unfilteredVideos,
      nextOffset: state.nextOffset,
      totalVideoCount: state.totalVideoCount,
      hasMoreContent: state.hasMoreContent,
    );
    if (_snapshotPersistTimer?.isActive ?? false) return;
    _snapshotPersistTimer = Timer(snapshotPersistDebounce, _flushSnapshot);
  }

  void _flushSnapshot() {
    final snapshot = _pendingSnapshot;
    _pendingSnapshot = null;
    _snapshotPersistTimer?.cancel();
    _snapshotPersistTimer = null;
    if (snapshot == null || isClosed) return;
    _snapshotCache.writeSnapshot(snapshot);
  }

  @override
  Future<void> close() async {
    _removeChangeListener?.call();
    _unregisterUpdate?.call();
    _initialLoadTimer?.cancel();
    _flushSnapshot();
    try {
      await _videoEventService.unsubscribeFromUserVideos(_authorPubkey);
    } on Object {
      // Closing the Cubit must still complete; the service treats unsubscribe
      // as best-effort route cleanup.
    }
    return super.close();
  }
}
