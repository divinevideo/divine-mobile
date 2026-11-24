// ABOUTME: Owns one independent Classics queue and its request-only context.
// ABOUTME: Adapts unseen videos while keeping reached history and next stable.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/src/home_feed_result.dart';
import 'package:videos_repository/src/recommendation_session_seed.dart';
import 'package:videos_repository/src/video_merge_helpers.dart';

/// Most recent outcomes a request carries as context.
const _maxRecentInteractions = 20;

/// Most recently reached videos a request carries as context.
const _maxRecentVideoIds = 10;

/// Videos past the furthest reached one that adaptation keeps, so the video
/// queued next does not change under the viewer.
const _stableVideosAhead = 1;

/// Reads a private Classics page.
///
/// Transport and fallback belong to the repository.
typedef ClassicRecommendationsLoader =
    Future<HomeFeedResult> Function(
      ClassicRecommendationsRequest request,
    );

/// Immutable queue snapshot consumed by Home and route-scoped playback blocs.
class ClassicFeedSessionState extends Equatable {
  /// Creates a queue snapshot.
  const ClassicFeedSessionState({
    this.videos = const [],
    this.currentIndex = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.cursor,
  });

  /// Playback order, including reached history.
  final List<VideoEvent> videos;

  /// Current position in [videos].
  final int currentIndex;

  /// Whether the repository can read another page.
  final bool hasMore;

  /// Whether one request is in flight.
  final bool isLoading;

  /// Continuation for the current session.
  final String? cursor;

  @override
  List<Object?> get props => [videos, currentIndex, hasMore, isLoading, cursor];
}

/// A single feed's domain session, independent of any widget or global grid.
///
/// Every request passes only bounded recent context.
/// This helper never publishes
/// or stores feedback. Its stream can be consumed by a BLoC or a Cubit without
/// coupling those presentation controllers to one another.
class ClassicFeedSession {
  /// Creates an independent feed, optionally anchored on a selected classic.
  ClassicFeedSession({
    required ClassicRecommendationsLoader loadPage,
    List<VideoEvent> initialVideos = const [],
    bool Function()? canPersonalize,
    Stream<ClassicFeedFeedback>? feedback,
    Stream<void>? privacyChanges,
    Stream<String>? removedVideoIds,
    List<VideoEvent> Function(List<VideoEvent>)? filter,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) : _loadPage = loadPage,
       _canPersonalize = canPersonalize ?? _allowed,
       _filter = filter,
       _preferredLanguages = preferredLanguages,
       _viewerCountry = viewerCountry,
       _updates = BehaviorSubject.seeded(
         ClassicFeedSessionState(videos: List.unmodifiable(initialVideos)),
       ) {
    _feedbackSubscription = feedback?.listen((event) {
      switch (event) {
        case ClassicFeedInteraction():
          recordInteraction(event);
        case ClassicFeedInteractionRetracted():
          forgetInteraction(event.videoId);
      }
    });
    _privacySubscription = privacyChanges?.listen((_) => resetContext());
    _removedSubscription = removedVideoIds?.listen((id) {
      _removedIds.add(id);
      reapplyFilters();
    });
    if (initialVideos.isNotEmpty) _reach(initialVideos.first.id);
  }

  static bool _allowed() => true;

  final ClassicRecommendationsLoader _loadPage;
  final bool Function() _canPersonalize;
  final List<VideoEvent> Function(List<VideoEvent>)? _filter;
  final List<String> _preferredLanguages;
  final String? _viewerCountry;
  final BehaviorSubject<ClassicFeedSessionState> _updates;
  final LinkedHashMap<String, ClassicFeedInteraction> _interactions =
      LinkedHashMap();
  final List<String> _recentIds = [];
  StreamSubscription<ClassicFeedFeedback>? _feedbackSubscription;
  StreamSubscription<void>? _privacySubscription;
  StreamSubscription<String>? _removedSubscription;
  final Set<String> _removedIds = {};
  String _seed = generateRecommendationSessionSeed();
  Future<HomeFeedResult>? _pending;
  int _generation = 0;
  int _furthestIndex = 0;
  bool _started = false;
  bool _adaptiveAvailable = true;
  bool _active = true;
  bool _refreshRequested = false;
  bool _retryOnResume = false;
  bool _disposed = false;

  /// Latest queue, available synchronously for a selected tile.
  ClassicFeedSessionState get state => _updates.value;

  /// Replays the current queue before later updates.
  Stream<ClassicFeedSessionState> get stream => _updates.stream;

  /// Completes after the in-flight read and coalesced feedback have settled.
  Future<void> get settled async {
    while (_pending != null) {
      await _pending;
    }
  }

  /// Home pauses its session when another feed source is selected.
  void setActive({required bool active}) {
    if (_disposed || _active == active) return;
    _active = active;
    if (!active) {
      _retryOnResume = _pending != null;
      _generation++;
      _refreshRequested = false;
    } else if (_retryOnResume) {
      _retryOnResume = false;
      _requestAdaptation();
    }
  }

  /// Reads the first page, or resumes the same independent queue.
  ///
  /// Never throws: a failed read is logged and resolves to an empty page.
  Future<HomeFeedResult> loadInitial({bool refresh = false}) async {
    if (_disposed) return const HomeFeedResult(videos: [], hasMore: false);
    reapplyFilters();
    setActive(active: true);
    if (refresh) {
      _started = true;
      _generation++;
      _seed = generateRecommendationSessionSeed();
      _interactions.clear();
      _recentIds.clear();
      _furthestIndex = 0;
      _refreshRequested = false;
      await settled;
      return _start(replaceAll: true);
    }
    if (_started && state.videos.isNotEmpty) return _result(state.videos);
    _started = true;
    final pending = _pending;
    return pending ?? _start();
  }

  /// Appends a page; serializes behind any in-flight tail adaptation.
  ///
  /// Never throws: a failed read is logged and resolves to an empty page.
  Future<HomeFeedResult> loadMore() async {
    if (!_started) return loadInitial();
    await settled;
    if (_disposed || !_active || !state.hasMore) {
      return _result(const []);
    }
    // Another caller may have started this page while this one waited.
    return _pending ?? _start();
  }

  /// Records navigation immediately; no network request delays playback.
  void activate(int index) {
    if (_disposed || !_active || index < 0 || index >= state.videos.length) {
      return;
    }
    final changed = index != state.currentIndex;
    _furthestIndex = max(_furthestIndex, index);
    if (changed) _reach(state.videos[index].id);
    _emit(currentIndex: index);
    if (changed) _requestAdaptation();
  }

  /// Resolves the actual visible video after a player-side removal or filter.
  void activateVideo(VideoEvent video) {
    reapplyFilters();
    final index = state.videos.indexWhere(
      (v) => v.feedDedupKey == video.feedDedupKey,
    );
    if (index >= 0) activate(index);
  }

  /// Incorporates an observed outcome for a video in this active queue.
  void recordInteraction(ClassicFeedInteraction interaction) {
    if (_disposed ||
        !_active ||
        !_canPersonalize() ||
        !state.videos.any((video) => video.id == interaction.videoId)) {
      return;
    }
    final previous = _interactions[interaction.videoId];
    // A trailing partial playback segment must not undo a deliberate action or
    // a replay already observed in the same viewing run.
    if (previous != null &&
        interaction.signal != ClassicFeedSignal.positive &&
        interaction.signal != ClassicFeedSignal.less &&
        _strength(previous.signal) >= _strength(interaction.signal)) {
      return;
    }
    _interactions
      ..remove(interaction.videoId)
      ..[interaction.videoId] = interaction;
    while (_interactions.length > _maxRecentInteractions) {
      _interactions.remove(_interactions.keys.first);
    }
    _requestAdaptation();
  }

  /// Reapplies live content/block preferences while preserving active identity.
  ///
  /// [keep] applies only to the current queue, so a reversible sweep does not
  /// permanently exclude a video from a later read.
  void reapplyFilters({bool Function(VideoEvent video)? keep}) {
    if (_disposed || state.videos.isEmpty) return;
    _applyQueueFilters(state.videos, keep: keep);
  }

  /// Updates an existing slot when its owner republishes a newer revision.
  void replaceVideoRevision(VideoEvent republished) {
    final address = republished.addressableId;
    if (_disposed || address == null) return;
    final index = state.videos.indexWhere(
      (video) =>
          video.addressableId == address &&
          isNewerVideoRevision(republished, video),
    );
    if (index == -1) return;
    final videos = [...state.videos];
    videos[index] = mergeRepublishedVideo(videos[index], republished);
    _applyQueueFilters(videos);
  }

  void _applyQueueFilters(
    List<VideoEvent> candidates, {
    bool Function(VideoEvent video)? keep,
  }) {
    final previous = state.videos;
    final currentKey = previous[state.currentIndex].feedDedupKey;
    final reachedKeys = previous
        .take(_furthestIndex + 1)
        .map((v) => v.feedDedupKey)
        .toSet();
    final videos = _filterVideos(
      candidates,
    ).where((video) => keep?.call(video) ?? true).toList();
    final current = videos.indexWhere((v) => v.feedDedupKey == currentKey);
    _furthestIndex = max(
      0,
      videos.lastIndexWhere((v) => reachedKeys.contains(v.feedDedupKey)),
    );
    _emit(
      videos: videos,
      currentIndex: current < 0
          ? min(state.currentIndex, max(0, videos.length - 1))
          : current,
    );
  }

  /// Removes retracted explicit intent without publishing another event.
  void forgetInteraction(String videoId) {
    if (_interactions.remove(videoId) != null) _requestAdaptation();
  }

  /// Rotates the request context at account or consent boundaries.
  void resetContext() {
    if (_disposed) return;
    _generation++;
    _adaptiveAvailable = true;
    _seed = generateRecommendationSessionSeed();
    _interactions.clear();
    _recentIds.clear();
    _emit(clearCursor: true, hasMore: true);
    if (_started && _active) _requestAdaptation();
  }

  void _reach(String id) {
    _recentIds
      ..remove(id)
      ..add(id);
    if (_recentIds.length > _maxRecentVideoIds) _recentIds.removeAt(0);
  }

  int _strength(ClassicFeedSignal signal) => switch (signal) {
    ClassicFeedSignal.skip => 0,
    ClassicFeedSignal.completed => 1,
    ClassicFeedSignal.replay => 2,
    ClassicFeedSignal.positive || ClassicFeedSignal.less => 3,
  };

  void _requestAdaptation() {
    if (_disposed || !_active || !_started || !_adaptiveAvailable) return;
    if (_pending != null) {
      _refreshRequested = true;
      return;
    }
    unawaited(_start(replaceTail: true));
  }

  Future<HomeFeedResult> _start({
    bool replaceTail = false,
    bool replaceAll = false,
  }) {
    final generation = _generation;
    final allowed = _canPersonalize();
    final videos = state.videos;
    final anchor = videos.isEmpty ? null : videos[state.currentIndex].id;
    final request = ClassicRecommendationsRequest(
      seed: _seed,
      cursor: replaceAll ? null : state.cursor,
      recentInteractions: allowed
          ? List.unmodifiable(_interactions.values)
          : const [],
      recentVideoIds: allowed ? List.unmodifiable(_recentIds) : const [],
      anchorVideoId: allowed ? anchor : null,
      preferredLanguages: _preferredLanguages,
      viewerCountry: _viewerCountry,
    );
    _emit(isLoading: true);
    final completion = Completer<HomeFeedResult>();
    final pending = _pending = completion.future;
    unawaited(
      _read(
        request,
        generation,
        pending: pending,
        replaceTail: replaceTail,
        replaceAll: replaceAll,
      ).then(completion.complete),
    );
    return pending;
  }

  Future<HomeFeedResult> _read(
    ClassicRecommendationsRequest request,
    int generation, {
    required Future<HomeFeedResult> pending,
    required bool replaceTail,
    required bool replaceAll,
  }) async {
    try {
      final result = await _loadPage(request);
      if (_disposed || !_active || generation != _generation) {
        return _result(const []);
      }
      _adaptiveAvailable = result.recommendationPageCount > 0;
      reapplyFilters();
      final existing = state.videos;
      final protectedCount = replaceAll
          ? 0
          : replaceTail && result.videos.isNotEmpty
          ? min(existing.length, _furthestIndex + 1 + _stableVideosAhead)
          : existing.length;
      final preserved = existing.take(protectedCount);
      final keys = <String>{};
      final merged = <VideoEvent>[
        for (final video in [...preserved, ...result.videos])
          if (keys.add(video.feedDedupKey)) video,
      ];
      final filtered = _filterVideos(merged);
      final currentId = replaceAll || existing.isEmpty
          ? null
          : existing[state.currentIndex].feedDedupKey;
      final newIndex = currentId == null
          ? 0
          : filtered.indexWhere((video) => video.feedDedupKey == currentId);
      _emit(
        videos: filtered,
        currentIndex: max(0, newIndex),
        hasMore: result.hasMore ?? result.paginationCursor != null,
        cursor: result.paginationCursor,
        clearCursor: result.paginationCursor == null,
      );
      if (filtered.isNotEmpty && _recentIds.isEmpty) {
        _reach(filtered.first.id);
      }
      return result;
    } on Object catch (error, stackTrace) {
      if (!_disposed && generation == _generation) {
        Log.warning(
          'Could not update Classics recommendations: $error',
          name: 'ClassicFeedSession',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
      return _result(const []);
    } finally {
      // A refresh can start its own read while this one is in flight.
      if (identical(_pending, pending)) _pending = null;
      if (!_disposed) {
        _emit(isLoading: _pending != null);
        if (_refreshRequested && _active) {
          _refreshRequested = false;
          _requestAdaptation();
        }
      }
    }
  }

  List<VideoEvent> _filterVideos(List<VideoEvent> videos) =>
      (_filter?.call(videos) ?? videos)
          .where((video) => !_removedIds.contains(video.id))
          .toList();

  HomeFeedResult _result(List<VideoEvent> videos) => HomeFeedResult(
    videos: videos,
    paginationCursor: state.cursor,
    hasMore: state.hasMore,
  );

  void _emit({
    List<VideoEvent>? videos,
    int? currentIndex,
    bool? hasMore,
    bool? isLoading,
    String? cursor,
    bool clearCursor = false,
  }) {
    if (_disposed) return;
    _updates.add(
      ClassicFeedSessionState(
        videos: List.unmodifiable(videos ?? state.videos),
        currentIndex: currentIndex ?? state.currentIndex,
        hasMore: hasMore ?? state.hasMore,
        isLoading: isLoading ?? state.isLoading,
        cursor: clearCursor ? null : cursor ?? state.cursor,
      ),
    );
  }

  /// Stops subscriptions and prevents in-flight reads from modifying the queue.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await _feedbackSubscription?.cancel();
    await _privacySubscription?.cancel();
    await _removedSubscription?.cancel();
    await _updates.close();
  }
}
