// ABOUTME: BLoC for unified video feed with mode switching
// ABOUTME: Manages For You, Following, and New (latest) feeds
// ABOUTME: Uses VideosRepository for data fetching with cursor-based pagination

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/home_feed_resume_manager.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'feed_mode_preference_store.dart';
part 'video_feed_event.dart';
part 'video_feed_state.dart';

/// Default interval between auto-refreshes of the home feed.
const _defaultAutoRefreshMinInterval = Duration(minutes: 10);

/// Enriches REST-sourced videos with their full Nostr tag set.
///
/// Injected so [VideoFeedBloc] stays decoupled from relay clients while still
/// letting home feeds repair compact REST rows that omit ProofMode/C2PA tags.
typedef EnrichVideos = Future<List<VideoEvent>> Function(
  List<VideoEvent> videos,
);

/// BLoC for managing the unified video feed.
///
/// Handles:
/// - Multiple feed modes (forYou, following, latest)
/// - Pagination via cursor-based loading
/// - Following list changes for home feed
/// - Pull-to-refresh functionality
class VideoFeedBloc extends Bloc<VideoFeedEvent, VideoFeedBlocState> {
  VideoFeedBloc({
    required VideosRepository videosRepository,
    required FollowRepository followRepository,
    required CuratedListRepository curatedListRepository,
    ProfileRepository? profileRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    String? userPubkey,
    SharedPreferences? sharedPreferences,
    bool serveCachedHomeFeed = true,
    Duration autoRefreshMinInterval = _defaultAutoRefreshMinInterval,
    FeedPerformanceTracker? feedTracker,
    HomeFeedCache? homeFeedCache,
    EnrichVideos? enrichVideos,
    FeedTuningRepository? feedTuningRepository,
  }) : _videosRepository = videosRepository,
       _followRepository = followRepository,
       _curatedListRepository = curatedListRepository,
       _profileRepository = profileRepository,
       _blocklistRepository = contentBlocklistRepository,
       _userPubkey = userPubkey,
       _sharedPreferences = sharedPreferences,
       _serveCachedHomeFeed = serveCachedHomeFeed,
       _autoRefreshMinInterval = autoRefreshMinInterval,
       _feedTracker = feedTracker,
       _enrichVideos = enrichVideos,
       _feedTuningRepository = feedTuningRepository,
       _resumeManager = HomeFeedResumeManager(
         cache: homeFeedCache ?? const HomeFeedCache(),
         videosRepository: videosRepository,
       ),
       _modePreferences = FeedModePreferenceStore(
         sharedPreferences: sharedPreferences,
         userPubkey: userPubkey,
         followRepository: followRepository,
         curatedListRepository: curatedListRepository,
       ),
       super(const VideoFeedBlocState()) {
    on<VideoFeedStarted>(_onStarted);
    on<VideoFeedModeChanged>(_onModeChanged);
    on<VideoFeedSourceChanged>(_onSourceChanged);
    on<VideoFeedLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<VideoFeedRefreshRequested>(_onRefreshRequested);
    on<VideoFeedAutoRefreshRequested>(_onAutoRefreshRequested);
    on<VideoFeedFollowingListChanged>(_onFollowingListChanged);
    on<VideoFeedCuratedListsChanged>(_onCuratedListsChanged);
    on<VideoFeedBlocklistChanged>(_onBlocklistChanged);
    on<VideoFeedActiveIndexChanged>(_onActiveIndexChanged);
    on<VideoFeedEnrichmentReady>(_onEnrichmentReady);
    on<VideoFeedTuningSwipeCommitted>(_onTuningSwipeCommitted);
    on<VideoFeedTuningUndoRequested>(_onTuningUndoRequested);
  }

  final VideosRepository _videosRepository;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;
  final ProfileRepository? _profileRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  final String? _userPubkey;
  final SharedPreferences? _sharedPreferences;
  final bool _serveCachedHomeFeed;
  final Duration _autoRefreshMinInterval;
  final FeedPerformanceTracker? _feedTracker;
  final EnrichVideos? _enrichVideos;
  final FeedTuningRepository? _feedTuningRepository;

  /// Owns the cross-restart cache serve / splice / resume-persist logic.
  final HomeFeedResumeManager _resumeManager;

  /// Owns reading/writing the persisted feed-mode/source selection.
  final FeedModePreferenceStore _modePreferences;
  StreamSubscription<List<String>>? _followingSubscription;
  StreamSubscription<List<CuratedList>>? _curatedListsSubscription;

  /// Tracks when the last successful load completed, used by
  /// [_onAutoRefreshRequested] to skip refreshes when data is fresh.
  DateTime? _lastRefreshedAt;

  /// Whether [source] participates in the cross-restart [HomeFeedCache].
  ///
  /// All four home modes (For You, Following, New, Classics) are served from
  /// and written to the cache so cold start shows the last feed instantly. The
  /// `forYou` staleness concern from #3861 is handled differently now: the
  /// cached feed is positioned at the user's last index and everything past
  /// the active video is replaced with fresh server data on every load
  /// (via [HomeFeedResumeManager]), so the feed is never stale beyond the
  /// current video. Subscribed curated lists are excluded — they are derived
  /// from locally held list IDs, not a server feed.
  bool _usesHomeFeedCache(VideoFeedSource source) =>
      source.type == VideoFeedSourceType.forYou ||
      source.type == VideoFeedSourceType.following ||
      source.type == VideoFeedSourceType.newVideos ||
      source.type == VideoFeedSourceType.classic;

  /// Whether [source] paginates via an opaque server cursor (recommendation
  /// and popular feeds) rather than a `createdAt` "until" timestamp.
  ///
  /// Cursor-backed feeds arrive in server-ranked order, so pages must be
  /// appended as-is (no `createdAt` re-sort) and exhaustion is signalled by a
  /// null [HomeFeedResult.paginationCursor] rather than an empty page.
  bool _usesCursorPagination(VideoFeedSource source) =>
      source.type == VideoFeedSourceType.forYou ||
      source.type == VideoFeedSourceType.classic;

  bool _canEmitForSource(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit,
  ) => !emit.isDone && state.source == source;

  bool _shouldEnrichSource(VideoFeedSource source) =>
      // Subscribed-list rows are loaded from locally held event IDs and are
      // already resolved as full events rather than compact server feed rows.
      source.type != VideoFeedSourceType.subscribedList;

  /// Publish a feed-tuning signal for the swiped home-feed video and record it
  /// for the UI's Undo snackbar. Does not mutate the video list.
  Future<void> _onTuningSwipeCommitted(
    VideoFeedTuningSwipeCommitted event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final repository = _feedTuningRepository;
    if (repository == null) return;

    VideoEvent? target;
    for (final video in state.videos) {
      if (video.id == event.videoId) {
        target = video;
        break;
      }
    }
    if (target == null) return;

    final publishedEventId = await repository.tune(
      video: target,
      direction: event.direction,
    );
    final sequence = state.tuningActionSequence + 1;

    emit(
      state.copyWith(
        tuningActionSequence: sequence,
        lastTuningAction: VideoFeedTuningAction(
          videoId: event.videoId,
          direction: event.direction,
          sequence: sequence,
          publishedEventId: publishedEventId,
        ),
      ),
    );
  }

  /// Retract a previously-published feed-tuning signal.
  Future<void> _onTuningUndoRequested(
    VideoFeedTuningUndoRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    await _feedTuningRepository?.undo(event.feedTuningEventId);
  }

  /// Handle feed started event.
  ///
  /// Fires [_loadVideos] immediately without waiting for the follow list to
  /// initialize. When `userPubkey` is available, the Funnelcake API is
  /// attempted first (fast path).
  ///
  /// After the initial load, subscribes to [FollowRepository.followingStream]
  /// and ignores only the first replay when it exactly matches the follow
  /// list already used for that load. This avoids a redundant second API
  /// call on startup while still allowing late [FollowRepository.initialize]
  /// completions to trigger a corrective refresh or "no follows" CTA.
  ///
  /// Also subscribes to [CuratedListRepository.subscribedListsStream]
  /// (skipping the first replay) so curated list changes refresh the feed.
  ///
  /// If a feed mode was previously saved to SharedPreferences, that mode is
  /// restored. Otherwise [event.mode] is used.
  Future<void> _onStarted(
    VideoFeedStarted event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final source = _modePreferences.restoreSource(event.mode);
    if (_sharedPreferences?.getString(_modePreferences.key) !=
        source.persistenceValue) {
      await _modePreferences.persist(source);
    }

    final subscribedLists = _curatedListRepository.getSubscribedLists();

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        subscribedLists: subscribedLists,
        isLoadingMore: false,
        clearPaginationCursor: true,
      ),
    );

    _feedTracker?.startFeedLoad(source.mode.name);

    final initialFollowingPubkeys = List<String>.unmodifiable(
      _followRepository.followingPubkeys,
    );

    await _loadVideos(source, emit, revalidate: true);
    if (emit.isDone) return;

    // After the initial load, check for the "no follows" CTA. Needed for
    // BLoC re-creation (e.g. navigating back to home) when the follow repo
    // is already initialized — .skip(1) would skip the only replay.
    if (state.source == source &&
        source.type == VideoFeedSourceType.following) {
      final currentFollowing = _followRepository.followingPubkeys;
      if (currentFollowing.isEmpty && state.videos.isEmpty) {
        emit(
          state.copyWith(
            status: VideoFeedStatus.success,
            videos: [],
            hasMore: false,
            error: VideoFeedError.noFollowedUsers,
            videoListSources: const {},
            listOnlyVideoIds: const {},
          ),
        );
      }
    }

    if (emit.isDone) return;

    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();

    // Subscribe to following list changes.
    //
    // The first replay can mean one of two things:
    // - the initial load already used this exact follow list and a refresh
    //   would be redundant
    // - initialize() completed after the first load and this replay is the
    //   corrective signal that the feed should refresh or show the CTA
    //
    // Distinguish those cases by comparing the first replay with the list
    // used for the initial fetch instead of relying on isInitialized.
    var isFirstFollowingEmission = true;
    _followingSubscription = _followRepository.followingStream.listen((
      pubkeys,
    ) {
      if (isFirstFollowingEmission) {
        isFirstFollowingEmission = false;
        if (_listsEqual(pubkeys, initialFollowingPubkeys)) {
          return;
        }
      }

      addIfOpen(VideoFeedFollowingListChanged(pubkeys));
    });

    // Subscribe to curated list changes.
    _curatedListsSubscription = _curatedListRepository.subscribedListsStream
        .skip(1)
        .listen((lists) {
          addIfOpen(VideoFeedCuratedListsChanged(lists));
        });
  }

  @override
  Future<void> close() async {
    // Flush any swipe still inside the debounce window before tearing down, so
    // the last move isn't lost on dispose.
    _resumeManager.dispose();
    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();
    _followingSubscription = null;
    _curatedListsSubscription = null;
    return super.close();
  }

  /// Handle mode changed event.
  Future<void> _onModeChanged(
    VideoFeedModeChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    await _selectSource(VideoFeedSource.fromMode(event.mode), emit);
  }

  /// Handle source changed event.
  Future<void> _onSourceChanged(
    VideoFeedSourceChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    await _selectSource(event.source, emit);
  }

  Future<void> _selectSource(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Skip if already on this source.
    if (state.source == source && state.status == VideoFeedStatus.success) {
      return;
    }

    await _modePreferences.persist(source);

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        videos: [],
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        clearPaginationCursor: true,
        currentIndex: 0,
      ),
    );

    await _loadVideos(source, emit, revalidate: true);
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Handle load more request (pagination).
  Future<void> _onLoadMoreRequested(
    VideoFeedLoadMoreRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Skip if not in success state, already loading more, or no more content
    if (state.status != VideoFeedStatus.success ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.videos.isEmpty) {
      return;
    }

    if (_usesCursorPagination(state.source) && state.paginationCursor == null) {
      emit(state.copyWith(hasMore: false));
      return;
    }

    final source = state.source;
    emit(state.copyWith(isLoadingMore: true));

    try {
      // Find the oldest createdAt among all loaded videos for the cursor.
      // For popular feed (sorted by engagement), state.videos.last is the
      // lowest-engagement video, not the oldest — using its createdAt would
      // skip older popular videos.
      final oldestCreatedAt = state.videos
          .map((v) => v.createdAt)
          .reduce((a, b) => a < b ? a : b);
      final until = oldestCreatedAt;

      final usesCursor = _usesCursorPagination(source);
      final result = await _fetchVideosForSource(
        source,
        until: usesCursor ? null : until,
        paginationCursor: usesCursor ? state.paginationCursor : null,
      );
      if (!_canEmitForSource(source, emit)) return;

      // Filter out videos without valid URLs
      final validNewVideos = result.videos
          .where((v) => v.videoUrl != null)
          .toList();

      // Deduplicate by logical video identity. Addressable videos can be
      // republished with fresh event IDs, and bare d-tags can collide across
      // authors, so the key is the full addressable coordinate when present.
      final seenVideoKeys = <String>{};
      final updatedVideos = <VideoEvent>[];
      for (final video in [...state.videos, ...validNewVideos]) {
        if (seenVideoKeys.add(video.feedDedupKey)) {
          updatedVideos.add(video);
        }
      }

      // Cursor-backed feeds (For You, Classics) arrive in server-ranked
      // order; re-sorting by createdAt would shuffle new videos around the
      // current play index and resurface already-seen ones.
      if (!usesCursor) {
        updatedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      final addedUniqueVideos = updatedVideos.length > state.videos.length;

      // Merge attribution metadata from pagination with existing state.
      final mergedSources = Map.of(state.videoListSources);
      for (final entry in result.videoListSources.entries) {
        mergedSources
            .putIfAbsent(entry.key, () => <String>{})
            .addAll(entry.value);
      }

      final mergedListOnly = {...state.listOnlyVideoIds}
        ..addAll(result.listOnlyVideoIds);

      emit(
        state.copyWith(
          videos: updatedVideos,
          // Only stop pagination when the server returns nothing.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: _hasMoreForSource(
            source,
            result,
            fallbackHasMore: addedUniqueVideos,
          ),
          isLoadingMore: false,
          videoListSources: mergedSources,
          listOnlyVideoIds: mergedListOnly,
          paginationCursor: result.paginationCursor,
          clearPaginationCursor: result.paginationCursor == null,
        ),
      );

      _scheduleNostrEnrichment(source: source, videos: updatedVideos);

      // Batch-fetch profiles for new creators only.
      await _fetchCreatorProfiles(validNewVideos, source, emit);

      // The cross-restart cache is written only on a genuine swipe
      // (_onActiveIndexChanged); pagination alone does not move the resume
      // position, so nothing is persisted here.
    } catch (e) {
      if (!_canEmitForSource(source, emit)) return;

      Log.error(
        'VideoFeedBloc: Failed to load more videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle refresh request.
  Future<void> _onRefreshRequested(
    VideoFeedRefreshRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        clearPaginationCursor: true,
        currentIndex: 0,
      ),
    );

    await _loadVideos(state.source, emit, skipCache: true);
  }

  /// Handle auto-refresh request (dispatched by UI on app resume).
  ///
  /// Only refreshes when:
  /// - The current feed source type is [VideoFeedSourceType.following],
  ///   [VideoFeedSourceType.forYou], or [VideoFeedSourceType.newVideos]
  /// - The data is stale (last refresh was longer ago than
  ///   [_autoRefreshMinInterval])
  ///
  /// For You is included so the feed picks up fresh recommendations on
  /// resume, addressing the "feed stays the same after reopening the app"
  /// report (issue #3861).
  Future<void> _onAutoRefreshRequested(
    VideoFeedAutoRefreshRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (state.source.type != VideoFeedSourceType.following &&
        state.source.type != VideoFeedSourceType.forYou &&
        state.source.type != VideoFeedSourceType.newVideos) {
      return;
    }

    final lastRefresh = _lastRefreshedAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _autoRefreshMinInterval) {
      return;
    }

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        clearPaginationCursor: true,
        currentIndex: 0,
      ),
    );

    await _loadVideos(
      state.source,
      emit,
      skipCache: state.source.type != VideoFeedSourceType.newVideos,
      revalidate: state.source.type == VideoFeedSourceType.newVideos,
    );
  }

  /// Handle following list changes from [FollowRepository].
  ///
  /// Only receives runtime changes (the initial BehaviorSubject replay is
  /// skipped). Performs a silent refresh — keeps current videos visible and
  /// replaces when done.
  ///
  /// - **Empty list** → show `noFollowedUsers` CTA immediately.
  /// - **Non-empty list** → silent refresh via [_loadVideos]. Old content
  ///   stays visible briefly, then replaced with updated feed (no loading
  ///   flash).
  Future<void> _onFollowingListChanged(
    VideoFeedFollowingListChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (state.source.type != VideoFeedSourceType.following) return;
    if (state.status == VideoFeedStatus.loading) return;

    // Empty follow list → show "follow someone" CTA.
    if (event.followingPubkeys.isEmpty) {
      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: [],
          hasMore: false,
          error: VideoFeedError.noFollowedUsers,
          videoListSources: const {},
          listOnlyVideoIds: const {},
        ),
      );
      return;
    }

    // Silent refresh — keep current videos visible, replace when done.
    await _loadVideos(state.source, emit, skipCache: true);
  }

  /// Handle curated list subscription changes from [CuratedListRepository].
  ///
  /// Only refreshes when the current mode is [FeedMode.following] and the
  /// feed has already been loaded (avoids double-loading on startup).
  Future<void> _onCuratedListsChanged(
    VideoFeedCuratedListsChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final subscribedLists = event.subscribedLists;
    if (state.status == VideoFeedStatus.loading) {
      if (subscribedLists.isNotEmpty) {
        emit(state.copyWith(subscribedLists: subscribedLists));
      }
      return;
    }

    if (!state.isSubscribedListSelected) {
      emit(state.copyWith(subscribedLists: subscribedLists));
      return;
    }

    // Mirror restoreSource: if the currently selected subscribed list is no
    // longer in the subscription set (user unsubscribed, list was deleted),
    // fall back to forYou instead of reloading an empty list source.
    final selectedId = state.source.listId;
    final stillSubscribed = subscribedLists.any((l) => l.id == selectedId);
    final nextSource = stillSubscribed
        ? state.source
        : const VideoFeedSource.forYou();

    if (!stillSubscribed) {
      await _modePreferences.persist(nextSource);
    }

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: nextSource,
        videos: [],
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
        subscribedLists: subscribedLists,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        clearPaginationCursor: true,
        currentIndex: 0,
      ),
    );

    await _loadVideos(nextSource, emit, skipCache: true);
  }

  /// Handle blocklist changes.
  ///
  /// When [event.blockedPubkey] is provided, removes that user's videos
  /// from the current state instantly (no network call). When null,
  /// filters the current videos against the full blocklist in-memory.
  void _onBlocklistChanged(
    VideoFeedBlocklistChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) {
    final pubkey = event.blockedPubkey;
    if (pubkey != null) {
      final filtered = state.videos.where((v) => v.pubkey != pubkey).toList();
      if (filtered.length != state.videos.length) {
        emit(state.copyWith(videos: filtered));
      }
      return;
    }

    // General blocklist change — filter current videos in-memory.
    final service = _blocklistRepository;
    if (service == null) return;

    final filtered = service.filterContent<VideoEvent>(
      state.videos,
      (v) => v.pubkey,
    );
    if (filtered.length != state.videos.length) {
      emit(state.copyWith(videos: filtered));
    }
  }

  /// Load videos for the specified mode.
  ///
  /// On a cache-eligible load ([skipCache] false), serves the persisted home
  /// feed for the mode instantly — positioned at the user's last-viewed index
  /// — while fresh data loads in the background. When the fresh result
  /// arrives it is spliced in *after* the active video so the playing video
  /// and its next never jump (via [HomeFeedResumeManager]).
  ///
  /// For the home feed, does NOT wait for the follow list to initialize.
  /// Instead, the follow-list stream subscription (set up in [_onStarted])
  /// drives recovery: when the follow list arrives via
  /// [VideoFeedFollowingListChanged], the handler decides whether to show
  /// the `noFollowedUsers` CTA or refresh the feed.
  Future<void> _loadVideos(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit, {
    bool skipCache = false,
    bool revalidate = false,
  }) async {
    final servedCache = await _maybeServeCachedFeed(source, emit, skipCache);
    if (!_canEmitForSource(source, emit)) return;

    try {
      // `revalidate` serves the cached window *and* forces a fresh fetch.
      // `skipCache` alone cannot express that: it also suppresses the served
      // window, which would blank the screen, and at the repository layer it
      // reseeds For You recommendations and triggers the New feed's
      // pull-to-refresh relay merge — neither belongs on a session start.
      // Without `revalidate` a warm start reads the repository's in-memory
      // feed cache — which carries no TTL for the home, latest, and
      // recommended first-page entries — so the follow-up fetch answers
      // from the same entry it is meant to refresh.
      final result = await _fetchVideosForSource(
        source,
        skipCache: skipCache,
        revalidate: revalidate,
      );
      if (!_canEmitForSource(source, emit)) return;

      // Filter out videos without valid URLs
      final validVideos = result.videos
          .where((v) => v.videoUrl != null)
          .toList();

      _lastRefreshedAt = DateTime.now();

      // Keep the active video + one lookahead from the served cache and
      // replace the rest with fresh results, so fresh content appears right
      // after the current video. The active controller is preserved by
      // InfiniteVideoFeed's common-prefix handling, so it does not restart.
      final displayedVideos = servedCache
          ? _resumeManager.splice(
              existing: state.videos,
              fresh: validVideos,
              currentIndex: state.currentIndex,
            )
          : validVideos;

      _feedTracker?.markFirstVideosReceived(
        source.mode.name,
        displayedVideos.length,
      );

      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: displayedVideos,
          // Only stop pagination when no results at all.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: _hasMoreForSource(
            source,
            result,
            fallbackHasMore:
                source.type != VideoFeedSourceType.subscribedList &&
                validVideos.isNotEmpty,
          ),
          clearError: true,
          videoListSources: result.videoListSources,
          listOnlyVideoIds: result.listOnlyVideoIds,
          paginationCursor: result.paginationCursor,
          clearPaginationCursor: result.paginationCursor == null,
        ),
      );

      _scheduleNostrEnrichment(source: source, videos: displayedVideos);

      _feedTracker?.markFeedDisplayed(source.mode.name, displayedVideos.length);

      // Batch-fetch creator profiles to warm the Drift cache.
      await _fetchCreatorProfiles(validVideos, source, emit);

      // Advance the resume window past the active position so the next cold
      // start opens on the next unseen video — even when the user just
      // reopens without scrolling. Uses the spliced list so freshly loaded
      // videos replenish the window.
      if (_usesHomeFeedCache(source)) {
        _resumeManager.persistNow(
          pubkey: _userPubkey,
          mode: source.mode.name,
          videos: displayedVideos,
          activeIndex: state.currentIndex,
        );
      }
    } catch (e) {
      if (!_canEmitForSource(source, emit)) return;

      Log.error(
        'VideoFeedBloc: Failed to load videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );

      _feedTracker?.trackFeedError(
        source.mode.name,
        errorType: 'load_failed',
        errorMessage: e.toString(),
      );

      // Only show failure if we don't have cached data already displayed.
      if (state.status != VideoFeedStatus.success || state.videos.isEmpty) {
        emit(
          state.copyWith(
            status: VideoFeedStatus.failure,
            error: VideoFeedError.loadFailed,
          ),
        );
      }
    }
  }

  /// Serves the persisted feed for [source] at the last-viewed index when a
  /// cache-eligible (non-[skipCache]) load is requested.
  ///
  /// Returns whether a cached feed was emitted, so the caller knows to splice
  /// the fresh result in rather than replace wholesale.
  Future<bool> _maybeServeCachedFeed(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit,
    bool skipCache,
  ) async {
    if (skipCache || !_serveCachedHomeFeed || !_usesHomeFeedCache(source)) {
      return false;
    }

    final mode = source.mode.name;
    final cachedValid = await _resumeManager.readServeableWindow(
      pubkey: _userPubkey,
      mode: mode,
    );
    if (cachedValid.isEmpty) return false;
    if (!_canEmitForSource(source, emit)) return false;

    // The cached window already starts at the resume position (already-watched
    // videos were dropped on write), so it is served at index 0.
    _feedTracker?.markFirstVideosReceived(mode, cachedValid.length);
    emit(
      state.copyWith(
        status: VideoFeedStatus.success,
        videos: cachedValid,
        currentIndex: 0,
        hasMore: true,
        clearPaginationCursor: true,
        clearError: true,
      ),
    );
    _feedTracker?.markFeedDisplayed(mode, cachedValid.length);

    // Advance the resume point immediately so a quick reopen (before the fresh
    // fetch lands and the load-time write runs) still opens on the next video
    // rather than this one again.
    _resumeManager.persistNow(
      pubkey: _userPubkey,
      mode: mode,
      videos: cachedValid,
      activeIndex: 0,
    );
    return true;
  }

  /// Records the active video index and advances the resume window.
  ///
  /// Only persists on a genuine index change, so the index-0 echo emitted when
  /// the feed first mounts (or after a cold-start serve) doesn't double-write
  /// (the load already persisted the window).
  void _onActiveIndexChanged(
    VideoFeedActiveIndexChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) {
    final index = event.index < 0 ? 0 : event.index;
    if (state.currentIndex == index) return;
    emit(state.copyWith(currentIndex: index));

    if (_usesHomeFeedCache(state.source)) {
      // The index emit above stays immediate so the splice and resume-restore
      // listener react without delay; the disk write is debounced.
      _resumeManager.schedulePersist(
        pubkey: _userPubkey,
        mode: state.source.mode.name,
        videos: state.videos,
        activeIndex: index,
      );
    }
  }

  bool _hasMoreForSource(
    VideoFeedSource source,
    HomeFeedResult result, {
    required bool fallbackHasMore,
  }) {
    final upstreamHasMore = result.hasMore ?? fallbackHasMore;
    if (!_usesCursorPagination(source)) {
      return upstreamHasMore;
    }

    return upstreamHasMore && result.paginationCursor != null;
  }

  /// Fetch videos for a specific mode from the repository.
  ///
  /// Returns [HomeFeedResult] for all modes. For home/forYou, includes
  /// curated list attribution metadata. For other modes, returns a
  /// result with empty attribution.
  ///
  /// When [skipCache] is `false` (default), the repository may return
  /// a previously cached result from the [InMemoryFeedCache] without
  /// a network round-trip. Pass `true` for refresh and auto-refresh
  /// flows that must hit the network.
  ///
  /// [revalidate] bypasses the in-memory cache read only, for session-start
  /// revalidation: it does not reseed For You recommendations and does not
  /// trigger the New feed's pull-to-refresh relay merge. Classics ignores
  /// it — that source keeps its deliberate 15-minute cache so re-entry
  /// resumes the same stable opening.
  Future<HomeFeedResult> _fetchVideosForSource(
    VideoFeedSource source, {
    int? until,
    String? paginationCursor,
    bool skipCache = false,
    bool revalidate = false,
  }) => switch (source.type) {
    VideoFeedSourceType.forYou =>
      paginationCursor == null
          ? _videosRepository.getRecommendedVideos(
              userPubkey: _userPubkey,
              until: until,
              skipCache: skipCache,
              revalidate: revalidate,
            )
          : _videosRepository.getRecommendedVideos(
              userPubkey: _userPubkey,
              cursor: paginationCursor,
              skipCache: skipCache,
              revalidate: revalidate,
            ),
    VideoFeedSourceType.following => _videosRepository.getHomeFeedVideos(
      authors: _followRepository.followingPubkeys,
      userPubkey: _userPubkey,
      until: until,
    ),
    VideoFeedSourceType.subscribedList =>
      _videosRepository
          .getVideosForList(
            _curatedListRepository.getOrderedVideoIds(source.listId!),
          )
          .then((videos) => HomeFeedResult(videos: videos)),
    VideoFeedSourceType.newVideos => _videosRepository.getNewVideos(
      until: until,
      skipCache: skipCache,
      revalidate: revalidate,
    ),
    // Classics is offset-paginated behind an opaque cursor and has no
    // time-window pagination, so `until` does not apply. `revalidate` does
    // not apply either: the source's 15-minute first-page cache exists so
    // re-entry resumes the same opening, and bypassing it would re-shuffle.
    VideoFeedSourceType.classic => _videosRepository.getClassicVideos(
      cursor: paginationCursor,
      skipCache: skipCache,
    ),
  };

  void _scheduleNostrEnrichment({
    required VideoFeedSource source,
    required List<VideoEvent> videos,
  }) {
    final enrichVideos = _enrichVideos;
    if (enrichVideos == null ||
        videos.isEmpty ||
        !_shouldEnrichSource(source)) {
      return;
    }

    final snapshot = List<VideoEvent>.unmodifiable(videos);
    final sourceIds = {for (final video in snapshot) video.id.toLowerCase()};

    unawaited(
      enrichVideos(snapshot)
          .then((enrichedVideos) {
            if (isClosed || identical(enrichedVideos, snapshot)) return;
            add(
              VideoFeedEnrichmentReady(
                source: source,
                enrichedVideos: enrichedVideos,
                sourceIds: sourceIds,
              ),
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!isClosed) {
              addError(
                Reportable(error, context: '_scheduleNostrEnrichment'),
                stackTrace,
              );
            }
          }),
    );
  }

  void _onEnrichmentReady(
    VideoFeedEnrichmentReady event,
    Emitter<VideoFeedBlocState> emit,
  ) {
    if (state.source != event.source || state.videos.isEmpty) return;

    final enrichedById = {
      for (final video in event.enrichedVideos) video.id.toLowerCase(): video,
    };

    var changed = false;
    final mergedVideos = state.videos.map((video) {
      final key = video.id.toLowerCase();
      if (!event.sourceIds.contains(key)) return video;

      final enriched = enrichedById[key];
      if (enriched == null || identical(enriched, video)) return video;

      changed = true;
      return enriched;
    }).toList();

    if (!changed) return;

    emit(
      state.copyWith(
        videos: mergedVideos,
        enrichmentRevision: state.enrichmentRevision + 1,
      ),
    );

    if (_usesHomeFeedCache(state.source)) {
      _resumeManager.persistNow(
        pubkey: _userPubkey,
        mode: state.source.mode.name,
        videos: mergedVideos,
        activeIndex: state.currentIndex,
      );
    }
  }

  /// Batch-fetch creator profiles for the given videos.
  ///
  /// Only fetches profiles for pubkeys not already in
  /// [state.creatorProfiles]. Does not block video display — called
  /// after videos are already emitted.
  Future<void> _fetchCreatorProfiles(
    List<VideoEvent> videos,
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (_profileRepository == null || videos.isEmpty) return;

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .toSet()
        .difference(state.creatorProfiles.keys.toSet())
        .toList();

    if (newPubkeys.isEmpty) return;

    try {
      final profiles = await _profileRepository.fetchBatchProfiles(
        pubkeys: newPubkeys,
      );

      if (!_canEmitForSource(source, emit)) return;

      if (profiles.isNotEmpty) {
        emit(
          state.copyWith(
            creatorProfiles: {...state.creatorProfiles, ...profiles},
          ),
        );
      }
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to batch-fetch creator profiles - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
    }
  }
}
