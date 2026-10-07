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
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

export 'package:openvine/services/feed_mode_persistence.dart';

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
    PeopleListsRepository? peopleListsRepository,
    ProfileRepository? profileRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    String? userPubkey,
    SharedPreferences? sharedPreferences,
    // Retain this account scope above replaceable blocs; omission creates an
    // isolated scope suitable for a single bloc, with no hidden global state.
    FeedModePersistenceCoordinator? persistenceCoordinator,
    bool serveCachedHomeFeed = true,
    Duration autoRefreshMinInterval = _defaultAutoRefreshMinInterval,
    FeedPerformanceTracker? feedTracker,
    HomeFeedCache? homeFeedCache,
    EnrichVideos? enrichVideos,
    FeedTuningRepository? feedTuningRepository,
  }) : _videosRepository = videosRepository,
       _followRepository = followRepository,
       _curatedListRepository = curatedListRepository,
       _peopleListsRepository = peopleListsRepository,
       _profileRepository = profileRepository,
       _blocklistRepository = contentBlocklistRepository,
       _userPubkey = userPubkey,
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
         persistenceCoordinator: persistenceCoordinator,
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
    on<VideoFeedCuratedListsChanged>(
      _onCuratedListsChanged,
      transformer: sequential(),
    );
    on<VideoFeedFollowedPeopleListsChanged>(
      _onFollowedPeopleListsChanged,
      transformer: concurrent(),
    );
    on<VideoFeedBlocklistChanged>(_onBlocklistChanged);
    on<VideoFeedActiveIndexChanged>(_onActiveIndexChanged);
    on<VideoFeedEnrichmentReady>(_onEnrichmentReady);
    on<VideoFeedTuningSwipeCommitted>(_onTuningSwipeCommitted);
    on<VideoFeedTuningUndoRequested>(_onTuningUndoRequested);
  }

  final VideosRepository _videosRepository;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;

  /// Where the people lists the viewer follows live. `null` leaves Home
  /// without people-list feeds.
  final PeopleListsRepository? _peopleListsRepository;
  final ProfileRepository? _profileRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  final String? _userPubkey;
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
  StreamSubscription<CuratedListSubscriptionSnapshot>?
  _curatedListsSubscription;
  StreamSubscription<List<PeopleListSearchResult>>?
  _followedPeopleListsSubscription;
  int _sourceSelectionSequence = 0;
  int? _activeSourceSelection;
  VideoFeedCuratedListsChanged? _deferredCuratedSnapshot;
  int _followedListsSequence = 0;
  bool _isClosing = false;
  FollowedPeopleListRef? _pendingRestoredPeopleList;
  String? _pendingRestoredCuratedList;

  /// Tracks when the last successful load completed, used by
  /// [_onAutoRefreshRequested] to skip refreshes when data is fresh.
  DateTime? _lastRefreshedAt;

  // Installing a fresh first page invalidates any continuation of the old
  // window, even when both requests belong to the same feed source.
  int _paginationGeneration = 0;

  // A refresh of the same source must invalidate its previous first page.
  int _loadGeneration = 0;

  /// Whether [source] participates in the cross-restart [HomeFeedCache].
  ///
  /// All four home modes (For You, Following, New, Classics) are served from
  /// and written to the cache so cold start shows the last feed instantly. The
  /// `forYou` staleness concern from #3861 is handled differently now: the
  /// cached feed is positioned at the user's last index and everything past
  /// the active video is replaced with fresh server data on every load
  /// (via [HomeFeedResumeManager]), so the feed is never stale beyond the
  /// current video. Subscribed curated lists are excluded — they are derived
  /// from locally held list IDs, not a server feed — and so are followed
  /// people lists, whose members can change between launches.
  bool _usesHomeFeedCache(VideoFeedSource source) =>
      source.type == VideoFeedSourceType.forYou ||
      source.type == VideoFeedSourceType.following ||
      source.type == VideoFeedSourceType.newVideos ||
      source.type == VideoFeedSourceType.classic;

  /// Whether [source] can paginate via an opaque server cursor rather than a
  /// `createdAt` "until" timestamp.
  ///
  /// Pages carrying a cursor arrive in server-ranked order and must be appended
  /// as-is (no `createdAt` re-sort). For You and Classics are cursor-only, so a
  /// null [HomeFeedResult.paginationCursor] signals exhaustion there. New
  /// Videos prefers the cursor but still pages on `until` when the repository
  /// returns no cursor (Funnelcake outage or a legacy bare-list response).
  bool _usesCursorPagination(VideoFeedSource source) =>
      source.type == VideoFeedSourceType.forYou ||
      source.type == VideoFeedSourceType.newVideos ||
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
  /// so curated list changes refresh the feed. The first replay can finish
  /// resolving a selection whose copy arrived while the initial feed loaded.
  ///
  /// If a feed mode was previously saved to SharedPreferences, that mode is
  /// restored. Otherwise [event.mode] is used. A forced start
  /// ([VideoFeedStarted.forceMode]) uses [event.mode] and leaves the stored
  /// preference untouched, so a campaign landing cannot rewrite the account's
  /// home source.
  Future<void> _onStarted(
    VideoFeedStarted event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final startupSelection = _sourceSelectionSequence;
    final initialFollowingPubkeys = List<String>.unmodifiable(
      _followRepository.followingPubkeys,
    );

    // Only a saved people list needs the follows resolved before the first
    // state. For anything else the watch below delivers them, so the first
    // frame does not wait on the copy box opening.
    final savedAtStart = _modePreferences._savedScopedValue;
    final restoresPeopleList =
        !event.forceMode &&
        savedAtStart != null &&
        VideoFeedSource.peopleListRefFromValue(savedAtStart) != null;
    final followedRead = restoresPeopleList
        ? await _readFollowedPeopleLists()
        : const <PeopleListSearchResult>[];
    if (_startupWasSuperseded(
      startupSelection,
      emit,
      initialFollowingPubkeys,
    )) {
      return;
    }
    final followedPeopleLists =
        followedRead ?? const <PeopleListSearchResult>[];
    late VideoFeedSource source;
    late bool mayPersist;
    while (true) {
      final stored = _modePreferences._savedScopedValue;
      final restoresCurated =
          !event.forceMode &&
          stored != null &&
          VideoFeedSource.isCuratedListPreference(stored);
      final snapshot = restoresCurated
          ? _curatedListRepository.subscriptionSnapshot
          : null;
      source = event.forceMode
          ? VideoFeedSource.fromMode(event.mode)
          : _modePreferences.restoreSource(
              event.mode,
              followedPeopleLists: followedPeopleLists,
            );
      mayPersist =
          !event.forceMode &&
          await _mayPersistRestoredSource(source, followedRead);
      if (_startupWasSuperseded(
        startupSelection,
        emit,
        initialFollowingPubkeys,
      )) {
        return;
      }
      if (restoresCurated &&
          !identical(snapshot, _curatedListRepository.subscriptionSnapshot)) {
        continue;
      }
      if (mayPersist) {
        if (restoresCurated) {
          final persisted = await _persistCuratedSource(
            VideoFeedCuratedListsChanged.snapshot(snapshot!),
            source,
            startupSelection,
            emit,
          );
          if (!persisted) {
            if (_startupWasSuperseded(
              startupSelection,
              emit,
              initialFollowingPubkeys,
            )) {
              return;
            }
            // Storage now contains the original unresolved preference. Retry
            // restoration against the newer snapshot before loading a source.
            continue;
          }
        } else {
          await _modePreferences.persist(source);
        }
      }
      if (_startupWasSuperseded(
        startupSelection,
        emit,
        initialFollowingPubkeys,
      )) {
        return;
      }
      break;
    }
    _pendingRestoredPeopleList =
        !event.forceMode &&
            !mayPersist &&
            source.type == VideoFeedSourceType.forYou
        ? VideoFeedSource.peopleListRefFromValue(
            _modePreferences._savedScopedValue ?? '',
          )
        : null;

    final storedSource = _modePreferences._savedScopedValue;
    _pendingRestoredCuratedList =
        !event.forceMode &&
            !mayPersist &&
            source.type == VideoFeedSourceType.forYou &&
            storedSource != null &&
            VideoFeedSource.isCuratedListPreference(storedSource)
        ? storedSource
        : null;

    final subscribedLists = _curatedListRepository.getSubscribedLists();

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        subscribedLists: subscribedLists,
        followedPeopleLists: followedPeopleLists,
        isLoadingMore: false,
        clearPaginationCursor: true,
      ),
    );

    final feedLoad = _feedTracker?.startFeedLoad(source.mode.name);

    await _followedPeopleListsSubscription?.cancel();
    if (emit.isDone || _isClosing) return;
    _followedPeopleListsSubscription = _watchFollowedPeopleLists();
    _refreshFollowedPeopleLists();
    await _loadVideos(source, emit, feedLoad: feedLoad, revalidate: true);
    if (emit.isDone || _isClosing) return;

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

    if (emit.isDone || _isClosing) return;

    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();
    if (emit.isDone || _isClosing) return;

    _followingSubscription = _watchFollowing(initialFollowingPubkeys);

    // Subscribe to curated list changes.
    _curatedListsSubscription = _watchCuratedLists();
  }

  /// A source chosen while startup reads storage still needs live feed updates.
  bool _startupWasSuperseded(
    int selection,
    Emitter<VideoFeedBlocState> emit,
    List<String> initialFollowingPubkeys,
  ) {
    if (emit.isDone || _isClosing) return true;
    if (selection == _sourceSelectionSequence) return false;
    if (_followedPeopleListsSubscription == null) {
      _followedPeopleListsSubscription = _watchFollowedPeopleLists();
      _refreshFollowedPeopleLists();
    }
    _followingSubscription ??= _watchFollowing(initialFollowingPubkeys);
    _curatedListsSubscription ??= _watchCuratedLists();
    return true;
  }

  StreamSubscription<CuratedListSubscriptionSnapshot> _watchCuratedLists() =>
      _curatedListRepository.subscriptionSnapshots.listen((snapshot) {
        addIfOpen(VideoFeedCuratedListsChanged.snapshot(snapshot));
      });

  StreamSubscription<List<String>> _watchFollowing(
    List<String> initialFollowingPubkeys,
  ) {
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
    return _followRepository.followingStream.listen((
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
  }

  /// The people lists the viewer follows: none when signed out or when Home
  /// was built without the repository, and `null` when the local read fails.
  /// A cache that cannot be read must not take the feed down with it, but
  /// its answer is unknown, not empty: [_mayPersistRestoredSource] keeps a
  /// stored selection on the strength of that difference.
  Future<List<PeopleListSearchResult>?> _readFollowedPeopleLists() async {
    final repository = _peopleListsRepository;
    final viewerPubkey = _userPubkey;
    if (repository == null || viewerPubkey == null) return const [];
    try {
      return await repository.readFollowedLists(viewerPubkey: viewerPubkey);
    } on Object catch (error, stackTrace) {
      Log.warning(
        'VideoFeedBloc: could not read followed people lists',
        name: 'VideoFeedBloc',
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
      // A box that will not open throws a `HiveError`, which is an `Error`,
      // not an `Exception`. Home still loads without the people-list feeds;
      // the observer reports the error only if it is a programming error.
      if (error is! Exception) addError(error, stackTrace);
      return null;
    }
  }

  /// Whether the [restored] source may replace the stored one.
  ///
  /// A stored people list that did not resolve is kept while the answer is
  /// unknown: the follows could not be read ([followed] is null), or the
  /// follow is still held and only its copy is missing until the next relay
  /// sync, as after "Reset app data". Persisting For You there would turn a
  /// transient failure into a lost selection; the feed shows For You for
  /// this session and the list is restored once its copy is back. A follow
  /// that is gone is replaced, as an unsubscribed video list's is.
  Future<bool> _mayPersistRestoredSource(
    VideoFeedSource restored,
    List<PeopleListSearchResult>? followed,
  ) async {
    final stored = _modePreferences._savedScopedValue;
    if (stored == FeedModePreferenceStore.storageValueFor(restored)) {
      return false;
    }
    if (stored != null &&
        VideoFeedSource.isCuratedListPreference(stored) &&
        !_curatedListRepository.hasCompleteSubscriptionSnapshot) {
      return false;
    }
    final ref = stored == null
        ? null
        : VideoFeedSource.peopleListRefFromValue(stored);
    if (ref == null) return true;
    if (followed == null) return false;
    return !await _isStillFollowed(ref);
  }

  /// Whether the viewer still follows [ref]. A follow that cannot be checked
  /// counts as held, so a failed check cannot lose the stored selection.
  Future<bool> _isStillFollowed(FollowedPeopleListRef ref) async {
    final repository = _peopleListsRepository;
    final viewerPubkey = _userPubkey;
    if (repository == null || viewerPubkey == null) return true;
    try {
      return await repository.isFollowingList(
        viewerPubkey: viewerPubkey,
        ownerPubkey: ref.ownerPubkey,
        listId: ref.listId,
      );
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'VideoFeedBloc: could not check whether a people list is followed',
        name: 'VideoFeedBloc',
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  /// Follows and unfollows made while Home is alive. The stream replays the
  /// current set first; the handler drops a set equal to the one in state.
  StreamSubscription<List<PeopleListSearchResult>>?
  _watchFollowedPeopleLists() {
    final repository = _peopleListsRepository;
    final viewerPubkey = _userPubkey;
    if (repository == null || viewerPubkey == null) return null;
    return repository
        .watchFollowedLists(viewerPubkey: viewerPubkey)
        .listen(
          (lists) => addIfOpen(VideoFeedFollowedPeopleListsChanged(lists)),
          onError: (Object error, StackTrace stackTrace) {
            Log.warning(
              'VideoFeedBloc: followed people lists stream failed',
              name: 'VideoFeedBloc',
              category: LogCategory.storage,
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
  }

  void _refreshFollowedPeopleLists() {
    final repository = _peopleListsRepository;
    final viewerPubkey = _userPubkey;
    if (_isClosing || repository == null || viewerPubkey == null) return;
    runDetached(
      repository.syncFollowedLists(
        viewerPubkey: viewerPubkey,
        isCancelled: () => _isClosing,
      ),
      'refresh Home followed people lists',
      logName: 'VideoFeedBloc',
      category: LogCategory.relay,
    );
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    _modePreferences._release();
    // Flush any swipe still inside the debounce window before tearing down, so
    // the last move isn't lost on dispose.
    _resumeManager.dispose();
    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();
    await _followedPeopleListsSubscription?.cancel();
    _followingSubscription = null;
    _curatedListsSubscription = null;
    _followedPeopleListsSubscription = null;
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
    _pendingRestoredPeopleList = null;
    _pendingRestoredCuratedList = null;
    final selectionSequence = ++_sourceSelectionSequence;
    _activeSourceSelection = selectionSequence;
    try {
      await _loadSelectedSource(source, selectionSequence, emit);
    } finally {
      if (_activeSourceSelection == selectionSequence) {
        _activeSourceSelection = null;
        final deferred = _deferredCuratedSnapshot;
        _deferredCuratedSnapshot = null;
        if (deferred != null && !emit.isDone && !_isClosing) {
          addIfOpen(deferred);
        }
      }
    }
  }

  Future<void> _loadSelectedSource(
    VideoFeedSource source,
    int selectionSequence,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Skip loading if already on this source. Showing a source is not the same
    // as having chosen it: a saved people list that did not resolve is kept
    // while Home shows For You, so picking For You has to be saved.
    if (state.source == source && state.status == VideoFeedStatus.success) {
      if (_modePreferences._savedScopedValue !=
          FeedModePreferenceStore.storageValueFor(source)) {
        await _modePreferences.persist(source);
      }
      return;
    }

    final feedLoad = _feedTracker?.startFeedLoad(
      source.mode.name,
      reason: FeedLoadReason.sourceSwitch,
    );

    final cachedVideos = await _readCachedFeed(source, skipCache: false);
    if (selectionSequence != _sourceSelectionSequence || emit.isDone) {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
      return;
    }

    await _modePreferences.persist(source);
    if (selectionSequence != _sourceSelectionSequence || emit.isDone) {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
      return;
    }

    final selectedState = state.copyWith(
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
    );
    final servedCache = _emitCachedFeed(
      source,
      cachedVideos,
      emit,
      baseState: selectedState,
      requireCurrentSource: false,
      feedLoad: feedLoad,
    );
    if (!servedCache) emit(selectedState);

    await _loadVideos(
      source,
      emit,
      feedLoad: feedLoad,
      revalidate: true,
      prefetchedCachedVideos: cachedVideos,
    );
  }

  bool _listsEqual<T>(List<T> a, List<T> b) {
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

    // For You and Classics are cursor-only: a missing cursor means the source
    // is exhausted. New Videos also prefers the cursor, but its repository can
    // answer without one (Funnelcake outage or a legacy bare-list response),
    // and that fallback still pages by `until`.
    if (_usesCursorPagination(state.source) &&
        state.paginationCursor == null &&
        state.source.type != VideoFeedSourceType.newVideos) {
      emit(state.copyWith(hasMore: false));
      return;
    }

    final source = state.source;
    final paginationGeneration = _paginationGeneration;
    final feedLoad = _feedTracker?.startFeedLoad(
      source.mode.name,
      reason: FeedLoadReason.pagination,
    );
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

      final usesCursor =
          _usesCursorPagination(source) && state.paginationCursor != null;
      final result = await _fetchVideosForSource(
        source,
        until: usesCursor ? null : until,
        paginationCursor: usesCursor ? state.paginationCursor : null,
      );
      if (!_canEmitForSource(source, emit) ||
          paginationGeneration != _paginationGeneration) {
        return;
      }

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

      // Cursor-backed pages (For You, Classics, and New Videos when the
      // repository supplied a cursor) arrive in server-ranked order;
      // re-sorting by createdAt would shuffle new videos around the current
      // play index and resurface already-seen ones.
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

      if (updatedVideos.isNotEmpty) {
        if (feedLoad != null) {
          _feedTracker?.markFirstVisibleContent(
            feedLoad,
            updatedVideos.length,
            servedFromCache: false,
          );
        }
      }
      if (feedLoad != null) {
        _feedTracker?.markFreshResultCompleted(
          feedLoad,
          updatedVideos.length,
          recommendationPageCount: result.recommendationPageCount,
          followingPageCount: result.followingPageCount,
        );
      }

      _scheduleNostrEnrichment(source: source, videos: updatedVideos);

      // Batch-fetch profiles for new creators only.
      await _fetchCreatorProfiles(validNewVideos, source, emit);

      // The cross-restart cache is written only on a genuine swipe
      // (_onActiveIndexChanged); pagination alone does not move the resume
      // position, so nothing is persisted here.
    } catch (e) {
      if (!_canEmitForSource(source, emit) ||
          paginationGeneration != _paginationGeneration) {
        return;
      }

      Log.error(
        'VideoFeedBloc: Failed to load more videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    } finally {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
    }
  }

  /// Handle refresh request.
  Future<void> _onRefreshRequested(
    VideoFeedRefreshRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    _refreshFollowedPeopleLists();
    final feedLoad = _feedTracker?.startFeedLoad(
      state.source.mode.name,
      reason: FeedLoadReason.refresh,
    );
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

    await _loadVideos(state.source, emit, feedLoad: feedLoad, skipCache: true);
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
    _refreshFollowedPeopleLists();
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

    final feedLoad = _feedTracker?.startFeedLoad(
      state.source.mode.name,
      reason: FeedLoadReason.refresh,
    );

    await _loadVideos(
      state.source,
      emit,
      feedLoad: feedLoad,
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
    // Starting the load discards the page a load-more is still fetching, and a
    // failed refresh emits nothing, so the flag that page holds is released
    // here as every other path that starts a load does.
    if (state.isLoadingMore) emit(state.copyWith(isLoadingMore: false));
    final feedLoad = _feedTracker?.startFeedLoad(
      state.source.mode.name,
      reason: FeedLoadReason.refresh,
    );
    await _loadVideos(state.source, emit, feedLoad: feedLoad, skipCache: true);
  }

  /// Handle curated list subscription changes from [CuratedListRepository].
  ///
  /// Only refreshes when the current mode is [FeedMode.following] and the
  /// feed has already been loaded (avoids double-loading on startup).
  Future<void> _onCuratedListsChanged(
    VideoFeedCuratedListsChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Stream delivery is asynchronous. A queued old snapshot must not remove
    // a source chosen from a newer snapshot or declare a partial copy set final.
    if (!_isCurrentCuratedSnapshot(event)) return;
    final selectionSequence = _sourceSelectionSequence;
    final subscribedLists = event.subscribedLists;
    if (_activeSourceSelection != null) {
      // The visible source can still be the old one while an explicit choice
      // awaits cache/storage. Reconcile only after that choice finishes, so an
      // automatic fallback cannot overwrite the newer intent using old state.
      _deferredCuratedSnapshot = event;
      emit(state.copyWith(subscribedLists: subscribedLists));
      return;
    }
    if (state.status == VideoFeedStatus.loading) {
      if (subscribedLists.isNotEmpty) {
        emit(state.copyWith(subscribedLists: subscribedLists));
      }
      return;
    }

    final pending = _pendingRestoredCuratedList;
    if (pending != null) {
      final restored = _modePreferences.sourceFromValue(pending);
      if (restored != null ||
          (event.isAuthoritative &&
              _curatedListRepository.hasCompleteSubscriptionSnapshot)) {
        final next = restored ?? const VideoFeedSource.forYou();
        final persisted = await _persistCuratedSource(
          event,
          next,
          selectionSequence,
          emit,
        );
        if (!persisted) return;
        _pendingRestoredCuratedList = null;
        await _restartFeed(next, emit, subscribedLists: subscribedLists);
        return;
      }
    }
    if (!state.isSubscribedListSelected) {
      emit(state.copyWith(subscribedLists: subscribedLists));
      return;
    }

    // Mirror restoreSource: if the currently selected subscribed list is no
    // longer in the subscription set (user unsubscribed, list was deleted),
    // fall back to forYou instead of reloading an empty list source.
    final selectedId = state.source.listId;
    final selected = subscribedLists
        .where(
          (list) => list.authorScopedId == selectedId,
        )
        .firstOrNull;
    final stillSubscribed = selected != null;
    if (!stillSubscribed && !event.isAuthoritative) {
      emit(state.copyWith(subscribedLists: subscribedLists));
      return;
    }
    if (stillSubscribed &&
        _listsEqual(subscribedLists, state.subscribedLists)) {
      return;
    }
    final nextSource = selected == null
        ? const VideoFeedSource.forYou()
        : VideoFeedSource.subscribedList(
            listId: selected.authorScopedId,
            listName: selected.name,
          );

    if (!stillSubscribed) {
      final persisted = await _persistCuratedSource(
        event,
        nextSource,
        selectionSequence,
        emit,
      );
      if (!persisted) return;
    }

    if (emit.isDone ||
        _isClosing ||
        selectionSequence != _sourceSelectionSequence) {
      return;
    }
    await _restartFeed(nextSource, emit, subscribedLists: subscribedLists);
  }

  bool _isCurrentCuratedSnapshot(VideoFeedCuratedListsChanged event) =>
      event.snapshot == null ||
      identical(event.snapshot, _curatedListRepository.subscriptionSnapshot);

  /// Automatic writes stay provisional until their exact snapshot and owner
  /// are still current. Discard repairs the latest shared choice even after
  /// this bloc closes or a replacement bloc claims the account's storage.
  ///
  /// A refused native write applies [source] for this session only, as
  /// [FeedModePreferenceStore.persist] does for explicit choices.
  Future<bool> _persistCuratedSource(
    VideoFeedCuratedListsChanged event,
    VideoFeedSource source,
    int selectionSequence,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    bool isCurrent() =>
        !emit.isDone &&
        !_isClosing &&
        selectionSequence == _sourceSelectionSequence &&
        _isCurrentCuratedSnapshot(event);
    final ProvisionalFeedModeWrite write;
    try {
      write = await _modePreferences._prepare(source);
      // The coordinator reports a refused native write as a StateError.
      // ignore: avoid_catching_errors
    } on StateError catch (error, stackTrace) {
      Log.warning(
        'Home could not save the restored feed source',
        name: 'VideoFeedBloc',
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
      return isCurrent();
    }
    if (isCurrent() && write.accept()) return true;
    await write.discard();
    return false;
  }

  /// Handle follows, unfollows and refreshed copies of followed people lists.
  ///
  /// The selected list going away falls back to For You, as an unsubscribed
  /// curated list does. Its members changing reloads it, since the feed is
  /// exactly those members' videos. Anything else only updates the menu.
  Future<void> _onFollowedPeopleListsChanged(
    VideoFeedFollowedPeopleListsChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final followed = event.followedPeopleLists;
    final pending = _pendingRestoredPeopleList;
    if (pending != null) {
      for (final result in followed) {
        if (result.ownerPubkey != pending.ownerPubkey ||
            result.list.id != pending.listId) {
          continue;
        }
        _pendingRestoredPeopleList = null;
        await _restartFeed(
          VideoFeedSource.peopleList(
            listId: result.list.id,
            listName: result.list.name,
            listOwnerPubkey: result.ownerPubkey,
          ),
          emit,
          followedPeopleLists: followed,
        );
        return;
      }
    }
    if (_listsEqual(followed, state.followedPeopleLists)) return;

    final sequence = ++_followedListsSequence;
    final updated = state.copyWith(followedPeopleLists: followed);
    final source = state.source;
    if (source.type != VideoFeedSourceType.peopleList) {
      emit(updated);
      return;
    }

    final before = state.selectedPeopleList;
    final after = updated.selectedPeopleList;
    if (after == null) {
      _loadGeneration++;
      _paginationGeneration++;
      emit(
        updated.copyWith(
          status: VideoFeedStatus.loading,
          videos: [],
          isLoadingMore: false,
        ),
      );
      final stillFollowed = await _isStillFollowed(
        FollowedPeopleListRef(
          ownerPubkey: source.listOwnerPubkey!,
          listId: source.listId!,
        ),
      );
      if (emit.isDone ||
          state.source != source ||
          sequence != _followedListsSequence) {
        return;
      }
      const fallback = VideoFeedSource.forYou();
      // A missing cached copy is not an unfollow; preserve the restart choice.
      if (stillFollowed) {
        _pendingRestoredPeopleList = FollowedPeopleListRef(
          ownerPubkey: source.listOwnerPubkey!,
          listId: source.listId!,
        );
      } else {
        await _modePreferences.persist(fallback);
      }
      if (emit.isDone ||
          state.source != source ||
          sequence != _followedListsSequence) {
        return;
      }
      await _restartFeed(fallback, emit, followedPeopleLists: followed);
      return;
    }
    if (before == null ||
        !_listsEqual(before.list.pubkeys, after.list.pubkeys)) {
      await _restartFeed(source, emit, followedPeopleLists: followed);
      return;
    }
    emit(updated);
  }

  /// Clears the feed and loads [source] from the network, carrying whichever
  /// list collection just changed into the loading state.
  Future<void> _restartFeed(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit, {
    List<CuratedList>? subscribedLists,
    List<PeopleListSearchResult>? followedPeopleLists,
  }) async {
    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        videos: [],
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
        subscribedLists: subscribedLists,
        followedPeopleLists: followedPeopleLists,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        clearPaginationCursor: true,
        currentIndex: 0,
      ),
    );

    final feedLoad = _feedTracker?.startFeedLoad(
      source.mode.name,
      reason: FeedLoadReason.refresh,
    );

    await _loadVideos(source, emit, feedLoad: feedLoad, skipCache: true);
  }

  /// Handle blocklist changes.
  ///
  /// When [event.blockedPubkey] is provided, removes that user's videos
  /// from the current state instantly (no network call). When null,
  /// filters the current videos against the full blocklist in-memory.
  ///
  /// Then reads the followed people lists again: a list whose owner is blocked
  /// is left out of what the repository returns, but blocking changes neither
  /// the follows nor the copies it watches, so nothing else would say so.
  Future<void> _onBlocklistChanged(
    VideoFeedBlocklistChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    _removeBlockedVideos(event.blockedPubkey, emit);

    // A set read before a newer one was applied must not overwrite it, so read
    // again until no other update landed while the read was in flight.
    List<PeopleListSearchResult>? followed;
    int appliedBeforeRead;
    do {
      appliedBeforeRead = _followedListsSequence;
      followed = await _readFollowedPeopleLists();
      if (followed == null || emit.isDone) return;
    } while (appliedBeforeRead != _followedListsSequence);
    await _onFollowedPeopleListsChanged(
      VideoFeedFollowedPeopleListsChanged(followed),
      emit,
    );
  }

  void _removeBlockedVideos(
    String? pubkey,
    Emitter<VideoFeedBlocState> emit,
  ) {
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
    FeedLoadHandle? feedLoad,
    bool skipCache = false,
    bool revalidate = false,
    List<VideoEvent>? prefetchedCachedVideos,
  }) async {
    final generation = ++_loadGeneration;
    _paginationGeneration++;
    bool canEmit() =>
        generation == _loadGeneration && _canEmitForSource(source, emit);
    try {
      final servedCache =
          prefetchedCachedVideos?.isNotEmpty ??
          await _maybeServeCachedFeed(
            source,
            emit,
            skipCache,
            feedLoad,
            generation: generation,
          );
      if (!canEmit()) return;

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
      if (!canEmit()) return;

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

      if (feedLoad != null) {
        _feedTracker?.markFirstVideosReceived(feedLoad, displayedVideos.length);
      }
      _paginationGeneration++;
      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: displayedVideos,
          isLoadingMore: false,
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

      if (!servedCache && displayedVideos.isNotEmpty) {
        if (feedLoad != null) {
          _feedTracker?.markFirstVisibleContent(
            feedLoad,
            displayedVideos.length,
            servedFromCache: false,
          );
        }
      }

      _scheduleNostrEnrichment(source: source, videos: displayedVideos);

      if (feedLoad != null) {
        _feedTracker?.markFreshResultCompleted(
          feedLoad,
          displayedVideos.length,
          recommendationPageCount: result.recommendationPageCount,
          followingPageCount: result.followingPageCount,
        );
      }

      // Batch-fetch creator profiles to warm the Drift cache.
      await _fetchCreatorProfiles(validVideos, source, emit);
      if (!canEmit()) return;

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
      if (!canEmit()) return;

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
    } finally {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
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
    FeedLoadHandle? feedLoad, {
    required int generation,
  }) async {
    final cachedValid = await _readCachedFeed(source, skipCache: skipCache);
    if (generation != _loadGeneration) return false;
    return _emitCachedFeed(source, cachedValid, emit, feedLoad: feedLoad);
  }

  Future<List<VideoEvent>> _readCachedFeed(
    VideoFeedSource source, {
    required bool skipCache,
  }) async {
    if (skipCache || !_serveCachedHomeFeed || !_usesHomeFeedCache(source)) {
      return const [];
    }

    final mode = source.mode.name;
    return _resumeManager.readServeableWindow(
      pubkey: _userPubkey,
      mode: mode,
    );
  }

  bool _emitCachedFeed(
    VideoFeedSource source,
    List<VideoEvent> cachedValid,
    Emitter<VideoFeedBlocState> emit, {
    VideoFeedBlocState? baseState,
    bool requireCurrentSource = true,
    FeedLoadHandle? feedLoad,
  }) {
    if (cachedValid.isEmpty || emit.isDone) return false;
    if (requireCurrentSource && state.source != source) return false;

    final mode = source.mode.name;

    // The cached window already starts at the resume position (already-watched
    // videos were dropped on write), so it is served at index 0.
    if (feedLoad != null) {
      _feedTracker?.markFirstVideosReceived(feedLoad, cachedValid.length);
    }
    emit(
      (baseState ?? state).copyWith(
        status: VideoFeedStatus.success,
        videos: cachedValid,
        currentIndex: 0,
        hasMore: true,
        clearPaginationCursor: true,
        clearError: true,
      ),
    );
    if (feedLoad != null) {
      _feedTracker?.markFirstVisibleContent(
        feedLoad,
        cachedValid.length,
        servedFromCache: true,
      );
    }
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

    // New Videos can fall back to the repository's `until` pagination when the
    // API returned no cursor; a cursor-less page there is not exhaustion.
    if (source.type == VideoFeedSourceType.newVideos) {
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
    VideoFeedSourceType.peopleList =>
      _videosRepository
          .getVideosByAuthors(
            authorPubkeys:
                state.followedPeopleListFor(source)?.list.pubkeys ?? const [],
            until: until,
          )
          .then((videos) => HomeFeedResult(videos: videos)),
    VideoFeedSourceType.newVideos =>
      paginationCursor == null
          ? _videosRepository.getNewVideos(
              until: until,
              skipCache: skipCache,
              revalidate: revalidate,
            )
          : _videosRepository.getNewVideos(
              cursor: paginationCursor,
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
