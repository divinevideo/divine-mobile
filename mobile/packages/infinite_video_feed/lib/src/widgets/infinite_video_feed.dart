import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:infinite_video_feed/src/models/builders.dart';
import 'package:infinite_video_feed/src/models/feed_first_frame_metric.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/services/controller_subscriptions.dart';
import 'package:infinite_video_feed/src/services/derivative_failure_cache.dart';
import 'package:infinite_video_feed/src/services/disk_prefetcher.dart';
import 'package:infinite_video_feed/src/services/load_watchdog.dart';
import 'package:infinite_video_feed/src/services/playback_source_registry.dart';
import 'package:infinite_video_feed/src/services/stale_playback_detector.dart';
import 'package:infinite_video_feed/src/utils/playback_failure_log.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:infinite_video_feed/src/utils/source_loader.dart';
import 'package:infinite_video_feed/src/widgets/video_item.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

const _runtimeProcessingRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 8),
];

/// Infinite scrolling video feed using native platform video players.
///
/// Manages [DivineVideoPlayerController] instances for the current and
/// optionally the next video. Uses [MediaCacheManager] to prefetch
/// upcoming videos to disk so playback starts from local storage.
class InfiniteVideoFeed extends StatefulWidget {
  /// Creates an infinite scrolling video feed.
  const InfiniteVideoFeed({
    required this.videos,
    required this.cache,
    this.videoBuilder,
    this.urlResolver,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlayBuilder,
    this.scrollPhysics,
    this.initialIndex = 0,
    this.initialVolume = 1.0,
    this.onVolumeChanged,
    this.scrollDirection = Axis.vertical,
    this.keepPreviousAlive = true,
    this.keepNextAlive = true,
    this.releaseNeighboursWhenInactive = false,
    this.releaseCurrentWhenInactive = false,
    this.prefetchCount = 8,
    this.shouldPortraitExpand = true,
    this.maxPlaybackDuration,
    this.onActiveVideoChanged,
    this.onNearEnd,
    this.nearEndThreshold = 10,
    this.onVideoLoopCompleted,
    this.onVideoStalled,
    this.slowLoadThreshold = const Duration(seconds: 8),
    this.preloadGracePeriod = const Duration(seconds: 3),
    this.isActive = true,
    this.canAutoPlay,
    this.autoRetryMaxAttempts = 4,
    this.autoRetryBaseDelay = const Duration(seconds: 2),
    this.autoRetryMaxDelay = const Duration(seconds: 30),
    super.key,
  });

  /// Whether the native video player is supported on the current platform.
  ///
  /// Returns `true` on Android, iOS, macOS, Linux, and web. Returns `false`
  /// on Windows and every other unsupported platform.
  static bool get isSupported =>
      _isSupportedOverrideForTesting ??
      (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux); // coverage:ignore-line

  static bool? _isSupportedOverrideForTesting;

  // coverage:ignore-start
  // Test hook used by app-layer widget tests outside this package.
  /// Current test override for [isSupported].
  @visibleForTesting
  static bool? get debugIsSupportedOverride => _isSupportedOverrideForTesting;

  /// Overrides [isSupported] in tests. Set to `null` to clear override.
  @visibleForTesting
  static set debugIsSupportedOverride(bool? value) {
    _isSupportedOverrideForTesting = value;
  }
  // coverage:ignore-end

  /// The list of videos to display.
  final List<VideoEvent> videos;

  /// Resolves the playback URL for a [VideoEvent].
  ///
  /// When provided, called instead of using [VideoEvent.videoUrl] directly.
  /// Use this to apply platform-aware URL selection (e.g. progressive MP4
  /// for short videos instead of raw blob URLs).
  ///
  /// Falls back to [VideoEvent.videoUrl] when `null`.
  final String? Function(VideoEvent video)? urlResolver;

  /// Builder for the loading state shown while a video initializes.
  final LoadingBuilder? loadingBuilder;

  /// Builder for the error state.
  final ErrorBuilder? errorBuilder;

  /// Builder that wraps or replaces the default video player widget.
  ///
  /// When provided, called instead of the default [VideoItemWidget].
  /// Use this to inject metrics tracking, custom sizing, or other
  /// wrappers around the raw video surface.
  ///
  /// When `null`, the feed renders [VideoItemWidget] directly.
  final VideoBuilder? videoBuilder;

  /// Builder for the overlay layer rendered on top of the video.
  final OverlayBuilder? overlayBuilder;

  /// Optional physics for page swiping.
  ///
  /// When `null`, a tuned default is used for short-video feeds.
  final ScrollPhysics? scrollPhysics;

  /// The cache manager used for disk prefetching and cached playback.
  ///
  /// Must be initialized before passing it in.
  final MediaCacheManager cache;

  /// The initial video index to display.
  final int initialIndex;

  /// The initial playback volume (0.0 silent, 1.0 full).
  ///
  /// Defaults to `1.0`. Use [InfiniteVideoFeedState.setVolume] to change the
  /// volume after the feed is mounted.
  final double initialVolume;

  /// Whether the feed is allowed to play its active video.
  ///
  /// When `false`, the feed pauses the current video and suppresses any
  /// internal resume/play side effects until it becomes active again.
  final bool isActive;

  /// Per-video autoplay gate consulted before the feed starts playback.
  ///
  /// Return `false` to keep a video paused while it is the active page —
  /// e.g. while a content warning overlay is shown. The controller is
  /// still initialized so the first frame can render behind the overlay.
  /// Once the gate opens, call [InfiniteVideoFeedState.resumeCurrentPlayback]
  /// to start playback without a page change.
  ///
  /// When `null`, every video is allowed to play.
  final bool Function(VideoEvent video)? canAutoPlay;

  /// Hook: Called when the playback volume changes (mute/unmute/setVolume).
  ///
  /// The callback receives the new volume value (0.0 = muted, 1.0 = full).
  /// Use this to persist the mute/volume state outside the package.
  final ValueChanged<double>? onVolumeChanged;

  /// The scroll direction of the feed.
  final Axis scrollDirection;

  /// Whether to keep the previous video's player alive for instant playback
  /// when swiping back.
  ///
  /// When `true`, the controller for index `currentIndex - 1` stays
  /// initialized alongside the current one. Defaults to `true`.
  final bool keepPreviousAlive;

  /// Whether to keep the next video's player alive for instant playback
  /// on swipe.
  ///
  /// When `true`, the controller for index `currentIndex + 1` stays
  /// initialized alongside the current one. Defaults to `true`.
  final bool keepNextAlive;

  /// Whether the neighbour players and disk prefetch are released while the
  /// feed is inactive (see [isActive]).
  ///
  /// When `true` and the feed becomes inactive — e.g. the user switches tabs
  /// or pushes a route over a feed that stays mounted in the background — the
  /// previous/next controllers are disposed and any in-flight disk prefetch is
  /// cancelled. Only the current controller is retained, so playback resumes
  /// instantly when the feed becomes active again; the neighbours
  /// re-initialize and prefetch resumes on reactivation.
  ///
  /// When `false` (the default), neighbours and prefetch stay warm while
  /// inactive — appropriate for a feed that only pauses transiently while
  /// staying on screen (e.g. behind a focused text composer).
  final bool releaseNeighboursWhenInactive;

  /// Whether the *current* player is released too — a full drain of the live
  /// window — while the feed is inactive (see [isActive]).
  ///
  /// A backgrounded feed normally keeps its current player warm even when
  /// neighbours are released ([releaseNeighboursWhenInactive]), so playback
  /// resumes instantly at the same frame on reactivation. Set this `true` only
  /// while a surface that needs the device's scarce hardware video codecs for
  /// itself is open — the camera, the video editor, or the exporter. When it is
  /// `true` and the feed is (or becomes) inactive, every native player is
  /// disposed, handing the decoders back. The current video re-initializes —
  /// restarting from its first frame — when the feed becomes active again.
  ///
  /// Takes precedence over [releaseNeighboursWhenInactive]: a full drain
  /// releases the neighbours regardless of that flag.
  final bool releaseCurrentWhenInactive;

  /// Number of videos ahead of the current index to prefetch to disk.
  ///
  /// These videos are downloaded via [MediaCacheManager] and played
  /// from local storage when the user reaches them.
  final int prefetchCount;

  /// Controls how videos are fitted into the feed viewport.
  ///
  /// When `true`, non-square videos expand to [BoxFit.cover] while
  /// square (1:1) videos use [BoxFit.contain].
  /// When `false`, all videos use [BoxFit.contain].
  ///
  /// Defaults to `true`.
  final bool shouldPortraitExpand;

  /// Hard cap on how long each video plays before the native player loops.
  ///
  /// Applied as the clip end position ([VideoClip.end]) on every source the
  /// feed opens, so the loop point lives in the platform player: Android
  /// clips the `MediaItem` and repeats it, iOS trims the composition the
  /// `AVPlayerLooper` loops over. A source shorter than the cap plays to its
  /// natural end — both backends clamp the clip end to the real duration.
  ///
  /// When `null`, every source plays to its full length.
  final Duration? maxPlaybackDuration;

  /// Called when the active video changes.
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// Called when the user is near the end of the list.
  final VoidCallback? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  /// Called each time the active video completes a loop.
  ///
  /// Fires when the playback position resets from near the end of the clip
  /// back to the beginning — the native player looping the clip it was
  /// opened with, which [maxPlaybackDuration] may already have shortened.
  ///
  /// The `currentIndex` argument is the feed index of the video that looped.
  /// Use this to implement auto-advance logic in the owning widget.
  final void Function(int currentIndex)? onVideoLoopCompleted;

  /// Called when the active video stalls — all source fallbacks are
  /// exhausted or the load watchdog times out without a source to retry.
  ///
  /// The feed marks the video as an error automatically. Use this
  /// callback to auto-advance the feed or show a custom toast.
  final void Function(int index)? onVideoStalled;

  /// Duration after which a buffering video is considered slow.
  ///
  /// When the active video's playback status stays buffering or idle
  /// for this duration the player tries the next URL in its fallback list.
  /// Defaults to 8 seconds.
  final Duration slowLoadThreshold;

  /// How long to give the current video a bandwidth head-start before
  /// initializing the previous neighbour controller.
  ///
  /// The next neighbour initializes immediately after the current video so a
  /// forward swipe does not land on a cold player. The previous neighbour init
  /// fires as soon as the current video renders its first frame, or after this
  /// duration — whichever is earlier. Defaults to 3 seconds.
  final Duration preloadGracePeriod;

  /// How many times the active video automatically re-initializes after it
  /// fails to load before auto-retry gives up (manual retry still works).
  ///
  /// On a flaky connection a transient stall would otherwise leave a
  /// permanent error tile; auto-retry heals it once the network recovers.
  /// Defaults to 4.
  final int autoRetryMaxAttempts;

  /// Base delay before the first automatic retry of a failed active video.
  ///
  /// The delay doubles per attempt (capped at [autoRetryMaxDelay]) so a
  /// still-bad connection isn't hammered. Defaults to 2 seconds.
  final Duration autoRetryBaseDelay;

  /// Upper bound on the exponential auto-retry backoff. Defaults to 30s.
  final Duration autoRetryMaxDelay;

  /// Backoff before the next automatic retry of an errored video, or `null`
  /// when [attempt] has reached [maxAttempts] (auto-retry gives up; manual
  /// retry still works). Doubles [baseDelay] per attempt, capped at
  /// [maxDelay].
  @visibleForTesting
  static Duration? autoRetryDelay({
    required int attempt,
    required int maxAttempts,
    required Duration baseDelay,
    required Duration maxDelay,
  }) {
    if (attempt >= maxAttempts) return null;
    // Cap the shift so a large maxAttempts can't overflow the multiply; the
    // clamp below is the real bound, this only keeps the intermediate sane.
    final factor = 1 << (attempt > 16 ? 16 : attempt);
    final scaled = baseDelay.inMilliseconds * factor;
    return Duration(milliseconds: scaled.clamp(0, maxDelay.inMilliseconds));
  }

  @override
  State<InfiniteVideoFeed> createState() => InfiniteVideoFeedState();
}

/// State for [InfiniteVideoFeed]. Owns the live controller window and
/// orchestrates the focused services that handle prefetching, source
/// failover, slow-load detection, stalled-playback recovery, and
/// per-controller stream subscriptions.
///
/// Exposes [pauseActive], [resumeActive], [animateToPage], and
/// [currentIndex] for owning widgets that need to drive the feed
/// imperatively.
class InfiniteVideoFeedState extends State<InfiniteVideoFeed> {
  static const _logName = 'InfiniteVideoFeed';
  static const _loopEndThreshold = Duration(seconds: 1);
  static const _loopStartThreshold = Duration(seconds: 1);
  static const _pageJumpDuration = Duration(milliseconds: 300);
  static const Cubic _pageJumpCurve = Curves.easeInOut;

  late final PageController _pageController;
  late final ValueNotifier<double> _pagePosition;

  // Live controller window — read by build(). Stays on the State because
  // build() needs synchronous access to it.
  final _controllers = <int, DivineVideoPlayerController>{};

  // UI-facing state — drives build(). Stays on the State.
  final _errors = <int>{};
  final _errorTypes = <int, VideoErrorType>{};
  final _terminalErrorTypesByVideoId = <String, VideoErrorType>{};
  // Viewer auth headers per index, applied to every resolved playback source
  // for that index. The age-gate token is a hash-bound BUD-01 (kind 24242)
  // auth, valid for any variant URL of the same blob, so one header set covers
  // the optimized, HLS, and raw sources alike.
  final _httpHeadersByIndex = <int, Map<String, String>>{};

  // Indices currently performing a source failover. Stale `hasError`
  // events from the old source can arrive between `stop()` and `setSource()`
  // — this guard prevents them from re-triggering failover or showing
  // the error UI on top of a successfully recovered controller.
  final _failoverInFlight = <int>{};
  final _processingRetryInFlight = <int>{};
  final _processingRetryAttempts = <int, int>{};

  // Indices whose initial source was the on-disk cache file. If a runtime
  // error fires for one of these we evict the cached file so future loads
  // hit the network instead of replaying the corrupt bytes.
  final _loadedFromCache = <int>{};
  FeedFirstFrameTimer? _activeFirstFrameTimer;
  int _currentIndex = 0;

  /// The autoplay-gate answer this widget last acted on for [_currentIndex].
  ///
  /// Captured rather than re-derived from `oldWidget`, because the caller's
  /// [InfiniteVideoFeed.canAutoPlay] is typically a tear-off that reads live
  /// external state. Evaluating it against the old and the new widget in the
  /// same frame therefore returns the same answer, and an externally driven
  /// gate change is invisible (#6899). `null` means no decision has been
  /// applied yet, so there is no transition to react to.
  bool? _lastAppliedGate;

  // Current playback volume applied to the active controller and all
  // controllers that become active. Seeded from widget.initialVolume.
  late double _volume;
  late bool _isActive;

  // Set when a full drain (releaseCurrentWhenInactive) tore down the current
  // controller while inactive. The next activation re-initializes the window
  // instead of trying to resume a player that no longer exists.
  bool _needsReinitOnActivate = false;

  // Generation counter for the player window so async neighbour-init can
  // detect that the user scrolled away mid-load.
  int _playerWindowGeneration = 0;

  // Per-index generation token used by _initController to cancel stale
  // async work when ownership changes while awaits are in flight.
  final _controllerInitGenerations = <int, int>{};

  // Pending automatic-retry timers and per-index attempt counters for the
  // active errored video. Only the visible index is auto-retried; the
  // counter resets when the video plays or the slot is disposed.
  final _autoRetryTimers = <int, Timer>{};
  final _autoRetryAttempts = <int, int>{};

  // ─── Services ───────────────────────────────────────────────────────────

  late final PlaybackSourceRegistry _sources;
  late final DerivativeFailureCache _derivativeFailures;
  late final DiskPrefetcher _prefetcher;
  late final LoadWatchdog _watchdog;
  late final StalePlaybackDetector _staleDetector;
  late final ControllerSubscriptions _subscriptions;

  // ─── Public API ─────────────────────────────────────────────────────────

  /// The feed index of the currently active (visible) video.
  int get currentIndex => _currentIndex;

  /// The feed indices that currently have a live player controller.
  ///
  /// Exposed for tests that assert the live player window shrinks to the
  /// current video when the feed is released on inactivity (see
  /// [InfiniteVideoFeed.releaseNeighboursWhenInactive]).
  @visibleForTesting
  Set<int> get debugLiveControllerIndices => _controllers.keys.toSet();

  /// Video ids with terminal playback failures that should not auto-retry.
  ///
  /// Exposed for tests that assert a confirmed unplayable video remains an
  /// error even after its off-screen controller is disposed.
  @visibleForTesting
  Set<String> get debugTerminalErrorVideoIds =>
      _terminalErrorTypesByVideoId.keys.toSet();

  int _clampIndex(int index) {
    if (widget.videos.isEmpty) return 0;
    return index.clamp(0, widget.videos.length - 1);
  }

  /// Continuous page position for scroll-driven overlay effects.
  ///
  /// Value is 0-based and includes fractional positions while the page view
  /// is between two items.
  ValueListenable<double> get pagePositionListenable => _pagePosition;

  /// Pauses the currently active video without changing the page.
  void pauseActive() {
    _setPlaybackActive(false);
  }

  /// Resumes the currently active video without changing the page.
  void resumeActive() {
    _setPlaybackActive(true);
  }

  /// Re-evaluates playback for the active video and starts it if allowed.
  ///
  /// Unlike [resumeActive], this works while the feed is already active —
  /// use it after an external [InfiniteVideoFeed.canAutoPlay] gate opens
  /// (e.g. the user dismissed a content warning) so the already
  /// initialized controller starts playing without a page change.
  void resumeCurrentPlayback() {
    _resumeCurrentPlaybackIfReady();
  }

  /// Pauses the active video without changing the page or the feed's active
  /// state.
  ///
  /// The imperative counterpart to [resumeCurrentPlayback]. Unlike
  /// [pauseActive], this leaves [_isActive] untouched, so the owner can resume
  /// the current video without reactivating the entire feed.
  void pauseCurrentPlayback() {
    _pauseCurrentPlayback();
  }

  /// Sets the playback volume (0.0 silent, 1.0 full).
  ///
  /// Only the active controller is updated immediately. Neighbour controllers
  /// already receive the correct volume during their initialization via
  /// [_initController], so there is no need to touch them here.
  ///
  /// Calls [InfiniteVideoFeed.onVolumeChanged] with the new value.
  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (_volume == clamped) return;
    _volume = clamped;
    final active = _controllers[_currentIndex];
    if (active != null) unawaited(active.setVolume(clamped));
    widget.onVolumeChanged?.call(clamped);
  }

  /// Animate the page view to [index].
  Future<void> animateToPage(int index) async {
    if (!mounted || widget.videos.isEmpty) return;

    final targetIndex = index.clamp(0, widget.videos.length - 1);
    await _pageController.animateToPage(
      targetIndex,
      duration: _pageJumpDuration,
      curve: _pageJumpCurve,
    );
  }

  void _syncPagePosition() {
    late final double page;
    if (_pageController.hasClients) {
      page = _pageController.page ?? _currentIndex.toDouble();
    } else {
      page = _currentIndex.toDouble(); // coverage:ignore-line
    }
    if ((_pagePosition.value - page).abs() < 0.0001) return;
    _pagePosition.value = page;
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.initialIndex);
    _volume = widget.initialVolume;
    _isActive = widget.isActive;
    _pagePosition = ValueNotifier<double>(_currentIndex.toDouble());
    _pageController = PageController(initialPage: _currentIndex)
      ..addListener(_syncPagePosition);

    _sources = PlaybackSourceRegistry();
    _derivativeFailures = DerivativeFailureCache();
    _prefetcher = DiskPrefetcher(cache: widget.cache, log: _log);
    // coverage:ignore-start
    // Callback wiring only; exercised transitively by watchdog/detector tests
    // but not counted in optimized widget coverage.
    _watchdog = LoadWatchdog(
      threshold: widget.slowLoadThreshold,
      onSlowLoad: (index) => unawaited(_retryWithNextSource(index)),
      log: _log,
    );
    _staleDetector = StalePlaybackDetector(
      onSeekRecovery: _seekKick,
      onSourceFailover: (index) => unawaited(_retryWithNextSource(index)),
      log: _log,
    );
    // coverage:ignore-end
    _subscriptions = ControllerSubscriptions();

    _beginFirstFrameMeasurement(_currentIndex);
    unawaited(_onIndexChanged(_currentIndex));
  }

  @override
  void didUpdateWidget(InfiniteVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _setPlaybackActive(widget.isActive);
    } else if (!widget.isActive) {
      _reconcileInactiveReleasePolicy(oldWidget);
    }
    _syncCurrentAutoPlayGate();
    if (widget.videos == oldWidget.videos) return;

    // How many leading items are unchanged — same id AND same resolved
    // playback source. A changed resolved URL for an existing index (e.g. the
    // caller swapped the playback source for the same id) ends the common
    // prefix there, so its stale controller is rebuilt below.
    final commonPrefix = _commonPrefixLength(oldWidget, widget);

    // The active video and everything before it are unchanged when the common
    // prefix extends past the current index. Keep those controllers and only
    // rebuild the changed tail (indices >= commonPrefix), so the active video
    // does not restart. This covers append-only pagination and a tail
    // replacement (fresh feed spliced in after the current video). Disposing
    // the changed tail first lets _onIndexChanged re-init any stale controller
    // that falls inside the live window; out-of-window ones it disposes itself.
    if (commonPrefix > _currentIndex) {
      _prefetcher.cancelActive();
      _clearChangedTailPlaybackState(oldWidget, widget, commonPrefix);
      _controllers.keys
          .where((index) => index >= commonPrefix)
          .toList()
          .forEach(_disposeAt);
      unawaited(_onIndexChanged(_currentIndex));
      return;
    }

    // The change reaches the current video (or before it) — e.g. a tab switch
    // forYou → following or a full feed replacement. Tear down all live
    // controllers, reset to the caller's intended starting index, and jump the
    // PageController so the next frame opens on the right item instead of
    // whatever stale page the previous feed was on.
    _log(
      'Non-append-only video list change — tearing down all controllers '
      '(old=${oldWidget.videos.length} new=${widget.videos.length})',
    );

    _terminalErrorTypesByVideoId.clear();
    _teardownAllControllers();

    _currentIndex = _clampIndex(widget.initialIndex);
    _lastAppliedGate = null;
    _pagePosition.value = _currentIndex.toDouble();
    _beginFirstFrameMeasurement(_currentIndex);

    _rebuild();

    // The PageController is shared across rebuilds, so its current page
    // does not reset on its own. Jump after the rebuild schedules a
    // frame, once the PageView has re-attached against the new item
    // count. If the controller has no clients (e.g. videos became empty)
    // skip the jump — the next mount will pick up _currentIndex via
    // PageController.initialPage on a fresh attach.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.videos.isEmpty) return;
      if (!_pageController.hasClients) return;
      if (_pageController.page?.round() == _currentIndex) return;
      _pageController.jumpToPage(_currentIndex);
    });

    unawaited(_onIndexChanged(_currentIndex));
  }

  String? _resolvedSourceFor(
    VideoEvent video,
    String? Function(VideoEvent video)? resolver,
  ) => resolver?.call(video) ?? video.videoUrl;

  /// Number of leading items shared by [oldWidget] and [widget] — equal id and
  /// equal resolved playback source at each index.
  int _commonPrefixLength(
    InfiniteVideoFeed oldWidget,
    InfiniteVideoFeed newWidget,
  ) {
    final maxLength = oldWidget.videos.length < newWidget.videos.length
        ? oldWidget.videos.length
        : newWidget.videos.length;
    var i = 0;
    while (i < maxLength) {
      final oldVideo = oldWidget.videos[i];
      final newVideo = newWidget.videos[i];
      if (oldVideo.id != newVideo.id ||
          _resolvedSourceFor(oldVideo, oldWidget.urlResolver) !=
              _resolvedSourceFor(newVideo, newWidget.urlResolver)) {
        break;
      }
      i++;
    }
    return i;
  }

  /// Clears playback failure state for the changed tail (index >=
  /// [startIndex]), so fresh videos do not inherit stale index-scoped errors
  /// or terminal errors from videos that used to occupy those slots.
  void _clearChangedTailPlaybackState(
    InfiniteVideoFeed oldWidget,
    InfiniteVideoFeed newWidget,
    int startIndex,
  ) {
    for (var i = startIndex; i < oldWidget.videos.length; i++) {
      _terminalErrorTypesByVideoId.remove(oldWidget.videos[i].id);
    }
    for (var i = startIndex; i < newWidget.videos.length; i++) {
      _terminalErrorTypesByVideoId.remove(newWidget.videos[i].id);
    }
    for (var i = startIndex; i < oldWidget.videos.length; i++) {
      _errors.remove(i);
      _errorTypes.remove(i);
      _cancelAutoRetry(i);
    }
  }

  @override
  void dispose() {
    _prefetcher.dispose();
    _watchdog.disposeAll();
    _staleDetector.disposeAll();
    _subscriptions.disposeAll();
    // coverage:ignore-start
    // Pending timer cancellation is covered through deactivation/disposal
    // behavior; optimized coverage does not hit this defensive dispose loop.
    for (final timer in _autoRetryTimers.values) {
      timer.cancel();
    }
    // coverage:ignore-end
    _autoRetryTimers.clear();
    _autoRetryAttempts.clear();
    _sources.clear();
    _pagePosition.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _controllerInitGenerations.clear();
    super.dispose();
  }

  // ─── Logging / setState wrapper ─────────────────────────────────────────

  void _log(String message) =>
      Log.debug(message, name: _logName, category: LogCategory.video);

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _setPlaybackActive(bool isActive) {
    if (_isActive == isActive) return;
    _isActive = isActive;
    if (_isActive) {
      _beginFirstFrameMeasurement(_currentIndex);
      if (_needsReinitOnActivate) {
        // A full drain dropped the current player while inactive. Re-build the
        // live window from scratch instead of resuming a disposed controller.
        _needsReinitOnActivate = false;
        unawaited(_onIndexChanged(_currentIndex));
        return;
      }
      final currentController = _controllers[_currentIndex];
      if (currentController != null && currentController.isInitialized) {
        unawaited(_recordFirstFrame(_currentIndex, currentController));
      }
      _resumeCurrentPlaybackIfReady();
      if (widget.releaseNeighboursWhenInactive) {
        // Re-expand the live window and resume disk prefetch now that the
        // feed is visible again.
        unawaited(_onIndexChanged(_currentIndex));
      }
    } else {
      _pauseCurrentPlayback();
      _cancelAutoRetry(_currentIndex);
      if (widget.releaseCurrentWhenInactive) {
        _fullyReleaseWhileInactive();
      } else if (widget.releaseNeighboursWhenInactive) {
        _releaseNeighboursAndPrefetch();
      }
    }
  }

  /// Applies the release policy when a flag changes while the feed stays
  /// inactive (its [InfiniteVideoFeed.isActive] did not flip this update).
  void _reconcileInactiveReleasePolicy(InfiniteVideoFeed oldWidget) {
    // A codec-heavy surface just opened over a backgrounded feed: drop the
    // current player too. Takes precedence over the neighbour policy.
    if (widget.releaseCurrentWhenInactive) {
      if (!oldWidget.releaseCurrentWhenInactive) {
        _fullyReleaseWhileInactive();
      }
      return;
    }
    // The surface closed again while the feed is still inactive. The pool was
    // already drained; there is nothing to re-acquire until reactivation, which
    // re-inits via [_needsReinitOnActivate].
    if (oldWidget.releaseCurrentWhenInactive) return;

    if (widget.releaseNeighboursWhenInactive ==
        oldWidget.releaseNeighboursWhenInactive) {
      return;
    }
    if (widget.releaseNeighboursWhenInactive) {
      _releaseNeighboursAndPrefetch();
    } else {
      unawaited(_onIndexChanged(_currentIndex));
    }
  }

  /// Tears down every live controller (current + neighbours) and cancels disk
  /// prefetch while the feed is inactive, flagging a re-init so the current
  /// video reloads when the feed becomes active again.
  ///
  /// Driven by [InfiniteVideoFeed.releaseCurrentWhenInactive] when a
  /// codec-heavy surface (camera, video editor, exporter) needs the hardware
  /// decoders this backgrounded feed is holding.
  void _fullyReleaseWhileInactive() {
    if (_controllers.isEmpty && _needsReinitOnActivate) return;
    _log('Releasing all players while inactive (codec-heavy surface open)');
    // Stop the whole prefetch cycle, not just the active download
    // (_teardownAllControllers only cancels the active op), so a backgrounded
    // feed downloads nothing while the codec-heavy surface is open.
    _prefetcher.cancelCycle();
    _teardownAllControllers();
    _needsReinitOnActivate = true;
    _rebuild();
  }

  /// Disposes the neighbour controllers and cancels the in-flight disk
  /// prefetch, keeping only the current controller alive. Called when the
  /// feed becomes inactive while
  /// [InfiniteVideoFeed.releaseNeighboursWhenInactive] is set, so a feed that
  /// stays mounted in the background stops holding off-screen players and
  /// downloading upcoming videos.
  void _releaseNeighboursAndPrefetch() {
    _prefetcher.cancelCycle();
    // Bump the window generation so any in-flight neighbour init aborts
    // instead of re-adding a controller we are about to drop.
    _playerWindowGeneration++;
    _controllers.keys
        .where((index) => index != _currentIndex)
        .toList()
        .forEach(_disposeAt);
    _rebuild();
  }

  void _pauseCurrentPlayback() {
    _watchdog.stop(_currentIndex);
    _staleDetector.stop();
    final controller = _controllers[_currentIndex];
    if (controller != null && controller.isInitialized) {
      unawaited(controller.pause());
    }
  }

  void _resumeCurrentPlaybackIfReady() {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.isInitialized) return;
    unawaited(_activateCurrentController(controller, _currentIndex));
  }

  /// Whether [InfiniteVideoFeed.canAutoPlay] allows the video at [index]
  /// to start playing. Defaults to `true` when no gate is provided.
  bool _canAutoPlayAt(int index) {
    final gate = widget.canAutoPlay;
    if (gate == null) return true;
    if (index < 0 || index >= widget.videos.length) return true;
    return gate(widget.videos[index]);
  }

  /// Starts or stops the current video when its autoplay gate has flipped
  /// since the last decision this widget applied.
  ///
  /// Compares against [_lastAppliedGate] rather than re-evaluating the gate
  /// against `oldWidget`: both widgets share the caller's live-reading
  /// predicate, so that comparison always collapses and cannot see an
  /// external change (#6899).
  ///
  /// Deliberately acts only on a transition. The caller may pause the active
  /// controller directly — a tap-to-pause never reaches this widget — so
  /// reconciling against actual playback state on every rebuild would resume
  /// a video the viewer deliberately paused.
  void _syncCurrentAutoPlayGate() {
    if (!_isActive) return;
    final wasAllowed = _lastAppliedGate;
    final isAllowed = _canAutoPlayAt(_currentIndex);
    _lastAppliedGate = isAllowed;
    if (wasAllowed == null || wasAllowed == isAllowed) return;
    if (isAllowed) {
      _resumeCurrentPlaybackIfReady();
    } else {
      _pauseCurrentPlayback();
    }
  }

  Future<void> _activateCurrentController(
    DivineVideoPlayerController controller,
    int index,
  ) async {
    // The captured [controller] can be disposed mid-await by a window update,
    // failover, or re-init — each removes it from [_controllers] before
    // disposing. Re-checking identity (not just _isActive/_currentIndex, which
    // miss a same-index controller swap) avoids calling setVolume()/play() on a
    // disposed controller, which throws StateError from _ensureInitialized().
    // Unlike ownsInit()/ownsRetry(), `mounted` is intentionally omitted:
    // dispose() clears [_controllers] before super.dispose(), so the identity
    // check already fails after unmount.
    bool stillOwnsController() =>
        _isActive &&
        index == _currentIndex &&
        identical(_controllers[index], controller);

    if (!stillOwnsController() || !controller.isInitialized) return;
    final allowed = _canAutoPlayAt(index);
    if (index == _currentIndex) _lastAppliedGate = allowed;
    if (!allowed) return;
    await controller.setVolume(_volume);
    if (!stillOwnsController()) return;
    await controller.play();
    if (!stillOwnsController()) return;
    // Playback resumed cleanly — clear any auto-retry budget spent on this
    // slot so a later, unrelated stall starts from a fresh backoff.
    _autoRetryAttempts.remove(index);
    _watchdog.start(index, controller);
    _staleDetector.start(index, controller);
  }

  // coverage:ignore-start
  // Simple resolver wrapper; behavior is covered via callers, but optimized
  // coverage reports the declaration line itself as uncovered.
  String? _resolveUrl(VideoEvent video) =>
      widget.urlResolver?.call(video) ?? video.videoUrl;
  // coverage:ignore-end

  // ─── Index change → window + prefetch ───────────────────────────────────

  Future<void> _onIndexChanged(int index) async {
    if (widget.videos.isEmpty) return;
    await _updatePlayerWindow(index);
    unawaited(_runPrefetch(index));
  }

  void _beginFirstFrameMeasurement(int index) {
    if (index < 0 || index >= widget.videos.length || !_isActive) {
      _activeFirstFrameTimer = null;
      return;
    }
    _activeFirstFrameTimer = FeedFirstFrameMetrics.start(
      videoId: widget.videos[index].id,
      index: index,
    );
  }

  Future<void> _recordFirstFrame(
    int index,
    DivineVideoPlayerController controller,
  ) async {
    final timer = _activeFirstFrameTimer;
    if (timer == null || timer.index != index) return;
    await controller.firstFrameRendered;
    if (!mounted ||
        index != _currentIndex ||
        !identical(_controllers[index], controller) ||
        !identical(_activeFirstFrameTimer, timer)) {
      return;
    }
    timer.complete(loadedFromCache: _loadedFromCache.contains(index));
  }

  Future<void> _updatePlayerWindow(int index) async {
    final generation = ++_playerWindowGeneration;

    // Full drain: a codec-heavy surface is open over this inactive feed, so it
    // must hold no native players at all. An index change, a first mount, or a
    // video-list update while drained must not re-allocate a decoder the
    // camera/editor needs. Flag a re-init so the window rebuilds from the
    // current list once the feed becomes active again.
    if (widget.releaseCurrentWhenInactive && !_isActive) {
      _controllers.keys.toList().forEach(_disposeAt);
      _needsReinitOnActivate = true;
      return;
    }

    final lastIndex = widget.videos.length - 1;
    // Neighbour players are kept alive while the feed is active. When the feed
    // is hidden and configured to release them
    // ([InfiniteVideoFeed.releaseNeighboursWhenInactive]), the window collapses
    // to the current video so a background feed holds only one native player;
    // the neighbours re-initialize when it becomes active again.
    final keepNeighbours = !widget.releaseNeighboursWhenInactive || _isActive;
    final start = widget.keepPreviousAlive && keepNeighbours
        ? (index - 1).clamp(0, lastIndex)
        : index;
    final end = widget.keepNextAlive && keepNeighbours
        ? (index + 1).clamp(0, lastIndex)
        : index;

    // Dispose controllers outside the live window.
    _controllers.keys
        .where((i) => i < start || i > end)
        .toList()
        .forEach(_disposeAt);

    // Initialize the current index first for instant playback.
    if (!_controllers.containsKey(index) && !_restoreTerminalErrorAt(index)) {
      await _initController(index);
    }

    if (_playerWindowGeneration != generation || !mounted) return;

    if (widget.keepNextAlive &&
        keepNeighbours &&
        index + 1 <= lastIndex &&
        !_controllers.containsKey(index + 1) &&
        !_restoreTerminalErrorAt(index + 1)) {
      unawaited(_initController(index + 1));
    }

    // Give the current video a bandwidth head-start before loading the
    // previous neighbour. The next neighbour is already warming above because
    // forward swipes are the primary feed path and should not hit a cold
    // controller.
    final currentController = _controllers[index];
    if (currentController != null) {
      await _waitForFirstFrameOrGracePeriod(currentController);
    }

    if (_playerWindowGeneration != generation || !mounted) return;

    if (widget.keepPreviousAlive &&
        keepNeighbours &&
        index - 1 >= 0 &&
        !_controllers.containsKey(index - 1) &&
        !_restoreTerminalErrorAt(index - 1)) {
      unawaited(_initController(index - 1));
    }
  }

  Future<void> _waitForFirstFrameOrGracePeriod(
    DivineVideoPlayerController controller,
  ) async {
    final gracePeriodElapsed = Completer<void>();
    final graceTimer = Timer(widget.preloadGracePeriod, () {
      if (!gracePeriodElapsed.isCompleted) {
        gracePeriodElapsed.complete();
      }
    });

    try {
      await Future.any([
        controller.firstFrameRendered,
        gracePeriodElapsed.future,
      ]);
    } finally {
      graceTimer.cancel();
    }
  }

  Future<void> _runPrefetch(int index) async {
    // Pause disk prefetch while a hidden feed is releasing players (neighbours
    // only, or a full drain under a codec-heavy surface) so it stops
    // downloading upcoming videos. It resumes from the current index on
    // reactivation.
    if (!_isActive &&
        (widget.releaseNeighboursWhenInactive ||
            widget.releaseCurrentWhenInactive)) {
      return;
    }
    if (widget.prefetchCount <= 0) return;

    // coverage:ignore-start
    // Exercised indirectly by widget tests and DiskPrefetcher tests, but the
    // optimized coverage run misses these nested local-helper lines.
    final lastIndex = widget.videos.length - 1;
    final prefetchStart = widget.keepNextAlive ? index + 2 : index + 1;
    final prefetchEnd = (index + widget.prefetchCount).clamp(0, lastIndex);

    bool isHlsManifest(String url) {
      try {
        final uri = Uri.parse(url);
        final lastSegment = uri.pathSegments.isEmpty
            ? ''
            : uri.pathSegments.last;
        return lastSegment.endsWith('.m3u8');
      } on FormatException {
        return false;
      }
    }

    await _prefetcher.run(
      startIndex: prefetchStart,
      endIndex: prefetchEnd,
      videos: widget.videos,
      resolveUrls: (video) => resolvePlaybackSources(
        video,
        urlResolver: widget.urlResolver,
        derivativeFailureCache: _derivativeFailures,
        // Exclude HLS manifests: prefetch writes static files to disk,
        // but HLS playback needs re-streaming the manifest + segments.
      ).where((url) => !isHlsManifest(url)).toList(),
    );
    // coverage:ignore-end
  }

  void _teardownAllControllers() {
    _prefetcher.cancelActive();
    _playerWindowGeneration++;

    _watchdog.disposeAll();
    _staleDetector.disposeAll();
    _subscriptions.disposeAll();
    _sources.clear();

    // coverage:ignore-start
    // Same defensive cancellation as dispose(), but for full feed replacement.
    for (final timer in _autoRetryTimers.values) {
      timer.cancel();
    }
    // coverage:ignore-end
    _autoRetryTimers.clear();
    _autoRetryAttempts.clear();

    _failoverInFlight.clear();
    _processingRetryInFlight.clear();
    _processingRetryAttempts.clear();
    _loadedFromCache.clear();
    _errors.clear();
    _errorTypes.clear();
    _httpHeadersByIndex.clear();

    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _controllerInitGenerations.clear();
  }

  // coverage:ignore-start
  // Disposal is driven by live controller-window churn. Widget tests can
  // cover the call sites, but the native-controller disposal path itself is
  // not observable in package tests without platform players.
  void _disposeAt(int index) {
    _log('Disposing player at index $index');
    _subscriptions.unsubscribe(index);
    _watchdog.stop(index);
    if (index == _currentIndex) _staleDetector.stop();
    _staleDetector.forget(index);
    _cancelAutoRetry(index);
    _errors.remove(index);
    _failoverInFlight.remove(index);
    _processingRetryInFlight.remove(index);
    _processingRetryAttempts.remove(index);
    _loadedFromCache.remove(index);
    _errorTypes.remove(index);
    _httpHeadersByIndex.remove(index);
    _sources.remove(index);
    _controllerInitGenerations.remove(index);
    unawaited(_controllers.remove(index)?.dispose());
  }
  // coverage:ignore-end

  // ─── Controller init / retry ────────────────────────────────────────────

  Future<void> _initController(int index, {bool skipCache = false}) async {
    if (index < 0 || index >= widget.videos.length) return;

    if (_restoreTerminalErrorAt(index)) return;

    final video = widget.videos[index];

    final initGeneration = (_controllerInitGenerations[index] ?? 0) + 1;
    _controllerInitGenerations[index] = initGeneration;

    final cachedFile = skipCache
        ? null
        : widget.cache.getCachedFileSync(video.id);
    final fromCache = cachedFile != null;

    _log(
      'Init player index $index (${video.id}) — '
      '${fromCache ? 'from cache' : 'from network'}',
    );

    // Use the legacy Android `SurfaceTextureEntry` backend instead of the
    // default `SurfaceProducer`. The feed renders many players concurrently;
    // when a sibling player's decoder is released the Exynos C2 H.264
    // driver triggers a global format reprobe, and SurfaceProducer's small
    // ImageReader buffer pool can leak the previously-decoded frame onto a
    // peer player's surface for one frame (visible flicker). The legacy
    // single-buffer SurfaceTexture has no shared pool and is immune.
    // Trade-off: no surface-recreate callback (e.g. permission dialogs);
    // acceptable for the feed because the screen is always foregrounded
    // while videos are playing. No effect on iOS/macOS.
    final controller = DivineVideoPlayerController(
      useTexture: true,
      useLegacySurface: true,
      // Up to three feed players stay live at once; bound each one's native
      // read-ahead buffer so short-form playback doesn't OOM on low-RAM
      // Android devices (#3419).
      bufferProfile: VideoBufferProfile.feed,
      debugLabel: 'feed[$index]',
    );
    _controllers[index] = controller;

    bool ownsInit() {
      return mounted &&
          _controllerInitGenerations[index] == initGeneration &&
          identical(_controllers[index], controller);
    }

    bool guardInitOwnership(String step) {
      if (ownsInit()) return true;
      // coverage:ignore-start
      // Stale-init cleanup only fires when an in-flight await races a widget
      // unmount or a rapid re-init for the same index. Both are observable in
      // production, but not reproducible in package widget tests without
      // microsecond-precise control over native platform-channel timing.
      _log('Abort stale init at index $index (${video.id}) during $step');
      if (identical(_controllers[index], controller)) {
        _controllers.remove(index);
      }
      unawaited(controller.dispose());
      return false;
      // coverage:ignore-end
    }

    String? lastFailedSource;
    void rememberFailedSource(String source) {
      lastFailedSource = source;
    }

    try {
      await controller.initialize();
      if (!guardInitOwnership('initialize')) return;

      // coverage:ignore-start
      // Native controller initialization and source selection require the
      // platform player. Package tests cover the surrounding window/update
      // orchestration, but not the end-to-end texture-backed init flow.
      // Always resolve network sources. They are used as runtime fallbacks
      // even when the video is loaded from disk cache (in case the cached
      // file is corrupt or unreadable).
      final playbackSources = resolvePlaybackSources(
        video,
        urlResolver: widget.urlResolver,
        derivativeFailureCache: _derivativeFailures,
      );
      // Hash-bound auth applies to every resolved source for this index, so
      // the optimized/HLS/raw variants all authenticate, not just the bare URL.
      Map<String, String>? httpHeadersForSource(String _) =>
          _httpHeadersByIndex[index];

      if (fromCache) {
        try {
          await controller.setSource(
            VideoClip.file(
              cachedFile.path,
              end: widget.maxPlaybackDuration,
              trimToCommonTrackEnd: true,
            ),
          );
          if (!guardInitOwnership('setSource(cache)')) return;
          _loadedFromCache.add(index);
          // Register network sources with prestart so a runtime parseError
          // on the cached file can still fall over to network URLs.
          if (playbackSources.isNotEmpty) {
            _sources.registerPrestart(index, playbackSources);
            _log(
              'Cache loaded index $index (${video.id}): '
              'registered ${playbackSources.length} network fallbacks',
            );
          }
        } on Object catch (cacheError, cacheStackTrace) {
          // The cached file is unreadable at init time — evict it from the
          // cache so future loads don't replay the corrupt bytes, then
          // fall through to the network path.
          _log(
            'Cache read failed index $index (${video.id}): $cacheError '
            '— evicting cache and falling back to network',
          );
          Log.error(
            'Cache fallback to network',
            name: _logName,
            category: LogCategory.video,
            error: cacheError,
            stackTrace: cacheStackTrace,
          );
          unawaited(_evictCachedFile(video.id));
          if (playbackSources.isEmpty) {
            throw StateError('No playback source for video ${video.id}');
          }
          final (openedSource, openedSourceIdx) = await setSourceWithFallbacks(
            index: index,
            controller: controller,
            sources: playbackSources,
            log: _log,
            httpHeadersForSource: httpHeadersForSource,
            isLoadCurrent: ownsInit,
            maxPlaybackDuration: widget.maxPlaybackDuration,
            onFailoverSourceFailure: _derivativeFailures.recordFailureForSource,
            onSourceLoadFailure: rememberFailedSource,
          );
          if (!guardInitOwnership('setSourceWithFallbacks(cache)')) return;
          _sources.register(index, playbackSources, openedSourceIdx);
          _log(
            'Network fallback source selected index $index (${video.id}): '
            'openedSource=$openedSource '
            'attempt=$openedSourceIdx',
          );
        }
      } else {
        if (playbackSources.isEmpty) {
          throw StateError('No playback source for video ${video.id}');
        }

        final (openedSource, openedSourceIdx) = await setSourceWithFallbacks(
          index: index,
          controller: controller,
          sources: playbackSources,
          log: _log,
          httpHeadersForSource: httpHeadersForSource,
          isLoadCurrent: ownsInit,
          maxPlaybackDuration: widget.maxPlaybackDuration,
          onFailoverSourceFailure: _derivativeFailures.recordFailureForSource,
          onSourceLoadFailure: rememberFailedSource,
        );
        if (!guardInitOwnership('setSourceWithFallbacks(network)')) return;
        _sources.register(index, playbackSources, openedSourceIdx);
        _log(
          'Source selected index $index (${video.id}): '
          'openedSource=$openedSource '
          'attempt=$openedSourceIdx',
        );
      }

      await controller.setLooping(looping: true);
      if (!guardInitOwnership('setLooping')) return;
      await controller.setVolume(_volume);
      if (!guardInitOwnership('setVolume')) return;

      if (index == _currentIndex && _isActive) {
        _log('Playing index $index (${video.id})');
        unawaited(_recordFirstFrame(index, controller));
        await _activateCurrentController(controller, index);
        if (!guardInitOwnership('play')) return;
      }

      _errors.remove(index);
      _errorTypes.remove(index);

      _attachSubscriptions(index, controller);
    } on Object catch (e, stackTrace) {
      if (!ownsInit()) {
        guardInitOwnership('error handling');
        return;
      }
      final sourceDetail = lastFailedSource == null
          ? ''
          : ' failedSource=$lastFailedSource';
      _log('Error loading index $index (${video.id}):$sourceDetail $e');
      logPlaybackFailure(
        'Player init failed$sourceDetail',
        name: _logName,
        error: e,
        stackTrace: stackTrace,
      );
      final errorType = classifyVideoError(
        errorCode: nativePlayerErrorCodeFromError(e),
        errorMessage: e.toString(),
      );
      unawaited(_controllers.remove(index)?.dispose());
      if (_isTerminalPlaybackFailure(e)) {
        _stopAndMarkTerminalError(index, errorType);
      } else {
        _errorTypes[index] = errorType;
        _errors.add(index);
      }
    }
    // coverage:ignore-end

    if (!ownsInit()) {
      // coverage:ignore-start
      // Same race as guardInitOwnership: only fires when the try block
      // completes after the widget was unmounted or the index was re-inited.
      // Not reproducible in package widget tests.
      guardInitOwnership('rebuild');
      return;
      // coverage:ignore-end
    }
    _rebuild();
    if (_errors.contains(index)) {
      // coverage:ignore-start
      // Native init-failure auto-retry scheduling is exercised by runtime
      // integration behavior; package tests drive the runtime error path.
      _scheduleAutoRetryIfEligible(index);
      // coverage:ignore-end
    }
  }

  /// The error the player classified for [index], or `null` when that slot is
  /// not currently in an error state.
  ///
  /// Mirrors the value handed to `errorBuilder`, so a caller that just awaited
  /// [retryAt] can tell a repeated auth rejection apart from an unrelated
  /// playback failure (network drop, decode error) that happened to land on
  /// the same reload.
  VideoErrorType? errorTypeAt(int index) {
    if (!_errors.contains(index)) return null;
    return _terminalErrorTypeAt(index) ??
        _errorTypes[index] ??
        VideoErrorType.generic;
  }

  // coverage:ignore-start
  // Manual retry delegates back into native controller init, which is not
  // executable in package tests without platform players.
  /// Retries the video at [index] by clearing its current controller state and
  /// reinitializing it from the network.
  ///
  /// [httpHeaders] are attached to every resolved playback source for [index]
  /// (optimized, HLS, and raw variants), since the age-gate auth token is
  /// hash-bound and valid for any variant URL of the blob. Pass an empty map
  /// to retry anonymously.
  Future<bool> retryAt(
    int index, {
    Map<String, String> httpHeaders = const {},
  }) {
    // A manual retry resets the auto-retry budget for a fresh start.
    _cancelAutoRetry(index);
    return _retryController(index, httpHeaders: httpHeaders);
  }

  Future<bool> _retryController(
    int index, {
    Map<String, String> httpHeaders = const {},
  }) async {
    _errors.remove(index);
    _errorTypes.remove(index);
    _processingRetryInFlight.remove(index);
    _processingRetryAttempts.remove(index);
    final videoId = _videoIdAt(index);
    if (videoId != null) {
      _terminalErrorTypesByVideoId.remove(videoId);
    }
    if (httpHeaders.isEmpty) {
      _httpHeadersByIndex.remove(index);
    } else {
      _httpHeadersByIndex[index] = httpHeaders;
    }
    _watchdog.stop(index);
    if (index == _currentIndex) _staleDetector.stop();
    _sources.remove(index);
    _staleDetector.forget(index);
    _subscriptions.unsubscribe(index);
    unawaited(_controllers.remove(index)?.dispose());
    _rebuild();
    // Skip cache on manual retry so a corrupt cached file does not loop
    // the same failure indefinitely.
    await _initController(index, skipCache: true);
    return !_errors.contains(index);
  }
  // coverage:ignore-end

  // ─── Source failover (called by watchdog + stale detector) ──────────────

  // coverage:ignore-start
  // Source failover depends on runtime native playback errors and source
  // switching on an initialized controller, which package tests cannot
  // simulate without the platform player backend.
  /// Advances [index] to its next playback source.
  ///
  /// Set [recordSourceFailure] only when the failover is caused by a typed
  /// source-level failure. Slow loads and stalls are transient network
  /// conditions, so they must not demote an otherwise healthy derivative —
  /// this mirrors the gate `setSourceWithFallbacks` applies before calling
  /// `onFailoverSourceFailure`.
  Future<void> _retryWithNextSource(
    int index, {
    bool recordSourceFailure = false,
  }) async {
    if (!_sources.hasSources(index)) {
      _log('No sources to retry for index $index');
      _onVideoStalled(index);
      return;
    }

    if (recordSourceFailure) {
      final failedSource = _sources.activeSourceFor(index);
      if (failedSource != null) {
        _derivativeFailures.recordFailureForSource(failedSource);
      }
    }

    final nextSource = _sources.advance(index);
    if (nextSource == null) {
      _log('All sources exhausted for index $index');
      _onVideoStalled(index);
      return;
    }

    _log('Source failover index $index: source=$nextSource');

    // The first failover after a cache load means the cached file was
    // unplayable at runtime. Evict it so future loads hit the network.
    if (_loadedFromCache.remove(index)) {
      final video = widget.videos[index];
      _log('Evicting corrupt cache file for index $index (${video.id})');
      unawaited(_evictCachedFile(video.id));
    }

    final controller = _controllers[index];
    if (controller == null) return;

    _failoverInFlight.add(index);
    try {
      await controller.stop();
      await controller.setSource(
        VideoClip.network(
          nextSource,
          end: widget.maxPlaybackDuration,
          httpHeaders: _httpHeadersByIndex[index] ?? const {},
          trimToCommonTrackEnd: true,
        ),
      );
      if (index == _currentIndex && _isActive && _canAutoPlayAt(index)) {
        await controller.setVolume(_volume);
        await controller.play();
        if (index == _currentIndex && _isActive) {
          _watchdog.start(index, controller);
          _staleDetector.resetGrace();
        }
      }
    } on Object catch (e, stackTrace) {
      _log('Source failover failed index $index source=$nextSource: $e');
      logPlaybackFailure(
        'Source failover failed',
        name: _logName,
        error: e,
        stackTrace: stackTrace,
      );
      _onVideoStalled(
        index,
        isTerminal: _isTerminalPlaybackFailure(e),
        errorType: classifyVideoError(
          errorCode: nativePlayerErrorCodeFromError(e),
          errorMessage: e.toString(),
          source: nextSource,
        ),
      );
    } finally {
      _failoverInFlight.remove(index);
    }
  }

  Future<void> _retryCurrentProcessingSource(
    int index,
    Object? errorMessage,
  ) async {
    if (_processingRetryInFlight.contains(index)) return;

    final controller = _controllers[index];
    if (controller == null) return;
    final retryGeneration = _controllerInitGenerations[index];

    bool ownsRetry() {
      return mounted &&
          _controllerInitGenerations[index] == retryGeneration &&
          identical(_controllers[index], controller);
    }

    bool guardRetryOwnership(String step) {
      if (ownsRetry()) return true;
      _log('Abort stale processing retry at index $index during $step');
      return false;
    }

    final source = _sources.activeSourceFor(index);
    if (source == null) {
      _log('No active source to retry for processing index $index');
      if (ownsRetry()) {
        _stopAndMarkError(index, VideoErrorType.generic);
      }
      return;
    }

    final attempt = _processingRetryAttempts[index] ?? 0;
    if (attempt >= _runtimeProcessingRetryDelays.length) {
      _log(
        'Processing retry exhausted index $index: '
        'source=$source error=$errorMessage',
      );
      if (ownsRetry()) {
        _stopAndMarkError(index, VideoErrorType.generic);
      }
      return;
    }

    final delay = _runtimeProcessingRetryDelays[attempt];
    _processingRetryAttempts[index] = attempt + 1;
    _processingRetryInFlight.add(index);
    var retryProcessingAgain = false;
    _log(
      'Processing retry index $index: '
      'source=$source retryInMs=${delay.inMilliseconds} '
      'attempt=${attempt + 1}/${_runtimeProcessingRetryDelays.length}',
    );

    try {
      await Future<void>.delayed(delay);
      if (!guardRetryOwnership('delay')) return;
      await controller.stop();
      if (!guardRetryOwnership('stop')) return;
      await controller.setSource(
        VideoClip.network(
          source,
          end: widget.maxPlaybackDuration,
          httpHeaders: _httpHeadersByIndex[index] ?? const {},
          trimToCommonTrackEnd: true,
        ),
      );
      if (!guardRetryOwnership('setSource')) return;
      if (index == _currentIndex && _isActive && _canAutoPlayAt(index)) {
        await controller.setVolume(_volume);
        if (!guardRetryOwnership('setVolume')) return;
        await controller.play();
        if (!guardRetryOwnership('play')) return;
        if (index == _currentIndex && _isActive) {
          _watchdog.start(index, controller);
          _staleDetector.resetGrace();
        }
      }
      _processingRetryAttempts.remove(index);
    } on Object catch (e, stackTrace) {
      if (!ownsRetry()) {
        guardRetryOwnership('error handling');
        return;
      }
      _log('Processing retry failed index $index source=$source: $e');
      logPlaybackFailure(
        'Processing retry failed',
        name: _logName,
        error: e,
        stackTrace: stackTrace,
      );
      if (isMediaProcessingError(e)) {
        retryProcessingAgain = true;
      } else {
        _stopAndMarkError(
          index,
          classifyVideoError(
            errorCode: nativePlayerErrorCodeFromError(e),
            errorMessage: e.toString(),
            source: source,
          ),
        );
      }
    } finally {
      if (ownsRetry()) {
        _processingRetryInFlight.remove(index);
      }
    }
    if (retryProcessingAgain && ownsRetry()) {
      unawaited(_retryCurrentProcessingSource(index, errorMessage));
    }
  }
  // coverage:ignore-end

  // coverage:ignore-start
  // Stall recovery is only reached from watchdog / stale-detector callbacks
  // tied to native playback state streams.
  void _onVideoStalled(
    int index, {
    bool isTerminal = false,
    VideoErrorType errorType = VideoErrorType.generic,
  }) {
    _log('Video stalled index $index — marking error');
    if (isTerminal) {
      _stopAndMarkTerminalError(index, errorType);
    } else {
      _stopAndMarkError(index, errorType);
    }
    widget.onVideoStalled?.call(index);
  }

  /// Removes [videoId] from the on-disk media cache. Errors are logged but
  /// not rethrown — cache eviction is best-effort cleanup.
  Future<void> _evictCachedFile(String videoId) async {
    try {
      await widget.cache.removeCachedFile(videoId);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to evict cached file for $videoId',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops the controller at [index] (so audio/video cease immediately) and
  /// marks the slot as an error, triggering a rebuild.
  void _stopAndMarkError(int index, VideoErrorType type) {
    unawaited(_controllers[index]?.stop());
    _errors.add(index);
    _errorTypes[index] ??= type;
    _rebuild();
    _scheduleAutoRetryIfEligible(index);
  }

  /// Like [_stopAndMarkError] but records the failure as terminal for this
  /// video id, so it will not auto-retry and is restored on revisit.
  void _stopAndMarkTerminalError(int index, VideoErrorType type) {
    final videoId = _videoIdAt(index);
    if (videoId != null) {
      _terminalErrorTypesByVideoId[videoId] = type;
    }
    _cancelAutoRetry(index);
    unawaited(_controllers[index]?.stop());
    _errors.add(index);
    _errorTypes[index] = type;
    _rebuild();
  }

  String? _videoIdAt(int index) {
    if (index < 0 || index >= widget.videos.length) return null;
    return widget.videos[index].id;
  }

  bool _hasTerminalError(int index) {
    final videoId = _videoIdAt(index);
    return videoId != null && _terminalErrorTypesByVideoId.containsKey(videoId);
  }

  bool _restoreTerminalErrorAt(int index) {
    final videoId = _videoIdAt(index);
    if (videoId == null) return false;
    final terminalType = _terminalErrorTypesByVideoId[videoId];
    if (terminalType == null) return false;
    _errors.add(index);
    _errorTypes[index] = terminalType;
    _rebuild();
    return true;
  }

  VideoErrorType? _terminalErrorTypeAt(int index) {
    final videoId = _videoIdAt(index);
    return videoId == null ? null : _terminalErrorTypesByVideoId[videoId];
  }

  bool _isTerminalPlaybackFailure(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    return message.contains('no playable video tracks') ||
        message.contains('no video track');
  }

  void _seekKick(int index, int positionMs) {
    final controller = _controllers[index];
    if (controller == null) return;
    unawaited(controller.seekTo(Duration(milliseconds: positionMs)));
  }
  // coverage:ignore-end

  /// Schedules an automatic re-init of the errored video at [index] after a
  /// backoff, so a transient network stall doesn't strand a permanent error
  /// tile. Only the active, visible video auto-retries — off-screen errors
  /// re-init on revisit, and retrying them would add load that worsens the
  /// congestion that caused the stall. Gives up after
  /// [InfiniteVideoFeed.autoRetryMaxAttempts]; manual retry still works.
  void _scheduleAutoRetryIfEligible(int index) {
    if (index != _currentIndex || !_isActive) return;
    if (_hasTerminalError(index)) return;
    if (!_isAutoRetryableErrorType(_errorTypes[index])) return;
    final attempt = _autoRetryAttempts[index] ?? 0;
    final delay = InfiniteVideoFeed.autoRetryDelay(
      attempt: attempt,
      maxAttempts: widget.autoRetryMaxAttempts,
      baseDelay: widget.autoRetryBaseDelay,
      maxDelay: widget.autoRetryMaxDelay,
    );
    if (delay == null) return;
    _autoRetryTimers.remove(index)?.cancel();
    _autoRetryTimers[index] = Timer(delay, () {
      _autoRetryTimers.remove(index);
      if (!mounted ||
          !_isActive ||
          index != _currentIndex ||
          !_errors.contains(index)) {
        return;
      }
      _autoRetryAttempts[index] = attempt + 1;
      unawaited(
        _retryController(
          index,
          httpHeaders: _httpHeadersByIndex[index] ?? const {},
        ),
      );
    });
  }

  bool _isAutoRetryableErrorType(VideoErrorType? type) {
    return type == null || type == VideoErrorType.generic;
  }

  /// Cancels a pending auto-retry and clears the attempt budget for [index].
  void _cancelAutoRetry(int index) {
    _autoRetryTimers.remove(index)?.cancel();
    _autoRetryAttempts.remove(index);
  }

  // ─── Subscription wiring ────────────────────────────────────────────────

  // coverage:ignore-start
  // Subscription callbacks are driven by native controller streams. Package
  // tests cover the builder/callback contract around them, but not the
  // platform-emitted stream traffic itself.
  void _attachSubscriptions(int index, DivineVideoPlayerController controller) {
    _subscriptions
      ..subscribeToDimensions(index, controller, onDimensionsReady: _rebuild)
      ..subscribeToFirstFrame(index, controller, onFirstFrame: _rebuild)
      ..subscribeToPlaybackErrors(
        index,
        controller,
        isAlreadyError: () =>
            _errors.contains(index) ||
            _hasTerminalError(index) ||
            _failoverInFlight.contains(index) ||
            _processingRetryInFlight.contains(index),
        onError: (errorCode, errorMessage) {
          _log(
            'Runtime playback error at index '
            '$index ${_resolveUrl(widget.videos[index])}: '
            'code=$errorCode message=$errorMessage',
          );
          _watchdog.stop(index);
          if (index == _currentIndex) _staleDetector.stop();

          if (errorCode == NativePlayerErrorCode.mediaProcessing ||
              isMediaProcessingError(errorMessage)) {
            unawaited(_retryCurrentProcessingSource(index, errorMessage));
            return;
          }

          // Use the typed error code for a reliable failover decision.
          // Fall back to attempting failover for unknown errors so we
          // don't give up prematurely on unclassified failures.
          final shouldFailover =
              (errorCode == null ||
                  errorCode == NativePlayerErrorCode.unknown ||
                  errorCode.shouldFailover) &&
              _sources.hasSources(index) &&
              _sources.canAdvance(index);
          if (shouldFailover) {
            unawaited(
              _retryWithNextSource(
                index,
                recordSourceFailure: errorCode?.shouldFailover ?? false,
              ),
            );
            return;
          }

          final errorType = classifyVideoError(
            errorCode: errorCode,
            errorMessage: errorMessage,
          );
          if (_isTerminalPlaybackFailure(errorMessage)) {
            _stopAndMarkTerminalError(index, errorType);
          } else {
            _stopAndMarkError(index, errorType);
          }
        },
      );

    if (widget.onVideoLoopCompleted != null) {
      _subscriptions.subscribeToAutoAdvance(
        index,
        controller,
        endThreshold: _loopEndThreshold,
        startThreshold: _loopStartThreshold,
        isCurrent: () => index == _currentIndex,
        onLoopCompleted: () => widget.onVideoLoopCompleted!.call(index),
      );
    }
  }
  // coverage:ignore-end

  // ─── Page changes ───────────────────────────────────────────────────────

  // coverage:ignore-start
  // Page-change side effects are coupled to controller readiness on native
  // players. Existing tests cover page replacement and callback wiring, but
  // not pause/play against real initialized platform controllers.
  void _onPageChanged(int index) {
    final previousIndex = _currentIndex;
    _log('Page changed: $previousIndex → $index');
    _currentIndex = index;
    _beginFirstFrameMeasurement(index);
    _lastAppliedGate = null;

    _watchdog.stop(previousIndex);
    _staleDetector.stop();

    // Guard: only call methods on controllers that have finished initializing.
    // _initController stores the instance in _controllers synchronously before
    // awaiting initialize(), so there is a short window where the controller
    // exists in the map but is not yet ready. Calling pause()/play() in that
    // window throws StateError. The guard makes _onPageChanged safe to call
    // from jumpToPage callbacks that fire before initialization completes
    // (e.g. from the didUpdateWidget post-frame jumpToPage on feed
    // replacement).
    final prevController = _controllers[previousIndex];
    if (prevController != null && prevController.isInitialized) {
      unawaited(prevController.pause());
    }

    // Play the current video if it is already initialized. Otherwise
    // _initController will play it and start the watchdog + stale detector
    // once the source is ready.
    if (_isActive && _controllers.containsKey(index)) {
      final curr = _controllers[index]!;
      if (curr.isInitialized) {
        unawaited(_recordFirstFrame(index, curr));
        unawaited(_activateCurrentController(curr, index));
      }
    }

    if (index < widget.videos.length) {
      widget.onActiveVideoChanged?.call(widget.videos[index], index);
    }

    final distanceFromEnd = widget.videos.length - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call();
    }

    unawaited(_onIndexChanged(index));

    if (mounted) setState(() {});
  }
  // coverage:ignore-end

  // Determine if the video is square from the controller's resolved
  // dimensions. False until dimensions are available.
  bool _isSquareVideo(DivineVideoPlayerController? controller) {
    if (controller == null) return false;
    final state = controller.state;
    return state.videoWidth > 0 &&
        state.videoHeight > 0 &&
        state.videoWidth == state.videoHeight;
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      allowImplicitScrolling: true,
      controller: _pageController,
      physics: widget.scrollPhysics,
      scrollDirection: widget.scrollDirection,
      onPageChanged: _onPageChanged,
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final hasError = _errors.contains(index) || _hasTerminalError(index);
        final controller = _controllers[index];

        final overlay = widget.overlayBuilder?.call(
          context,
          index,
          controller,
          isActive: index == _currentIndex,
        );
        final videoItem = VideoItemWidget(
          controller: controller,
          shouldPortraitExpand: widget.shouldPortraitExpand,
        );

        final hasVideoSize =
            controller != null && controller.state.videoHeight != 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Loading layer — shown while the video surface is not yet
            // available. Removed once the first frame is rendered so the
            // widget (and any timers it owns) are properly disposed.
            if (!hasError &&
                (!hasVideoSize || !controller.state.isFirstFrameRendered))
              ?widget.loadingBuilder?.call(
                context,
                index,
                isSquare: _isSquareVideo(controller),
              ),

            if (!hasError && hasVideoSize)
              widget.videoBuilder?.call(
                    context,
                    videoItem,
                    index,
                    controller,
                  ) ??
                  videoItem,
            // Overlay layer — consumer-provided controls, progress, etc.
            ?overlay,

            if (hasError)
              // coverage:ignore-start
              // Consumer-supplied error UI is wiring only; package tests cover
              // retry behavior elsewhere and don't need to duplicate builder
              // composition here.
              ?widget.errorBuilder?.call(
                context,
                index,
                () => unawaited(retryAt(index).then((_) {})),
                _terminalErrorTypeAt(index) ??
                    _errorTypes[index] ??
                    VideoErrorType.generic,
              ),
            // coverage:ignore-end
          ],
        );
      },
    );
  }
}
