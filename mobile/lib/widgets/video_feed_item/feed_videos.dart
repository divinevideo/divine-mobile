import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart'
    hide PlaybackStatus;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/codec_heavy_surface/codec_heavy_surface_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/community_content_label_service.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/divine_video_metrics_tracker.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_like_helpers.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_overlay.dart';
import 'package:openvine/widgets/video_feed_item/player_gesture_surface.dart';
import 'package:openvine/widgets/video_feed_item/player_tap_helpers.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/verifying_aware_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_bloc_key.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_restriction_listener.dart';
import 'package:openvine/widgets/video_feed_item/video_loading_placeholder.dart';

class FeedVideos extends ConsumerStatefulWidget {
  const FeedVideos({
    required this.videos,
    required this.onNearEnd,
    this.contextTitle,
    this.currentIndex = 0,
    this.shouldPortraitExpand = true,
    this.isActive = true,
    this.releaseNeighboursWhenInactive = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onActiveVideoChanged,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    super.key,
  });

  final List<VideoEvent> videos;
  final VoidCallback onNearEnd;
  final int currentIndex;
  final String? contextTitle;
  final bool shouldPortraitExpand;

  /// Whether this feed should be playing. Set to `false` when the owning
  /// screen is obscured (tab switch, overlay open) to pause the active video
  /// without tearing down the widget tree.
  final bool isActive;

  /// See [InfiniteVideoFeed.releaseNeighboursWhenInactive].
  ///
  /// Set this for feeds that stay mounted in the background (e.g. the home
  /// feed inside a `StatefulShellRoute`) so the off-screen neighbour players
  /// and disk prefetch are released while [isActive] is `false`.
  final bool releaseNeighboursWhenInactive;

  /// Whether more videos can be loaded from the source.
  ///
  /// Used to build the [FeedAutoAdvanceSnapshot] passed to
  /// [handleFeedAutoAdvanceCompleted] and
  /// [continueFeedAutoAdvanceAfterPagination].
  final bool hasMore;

  /// Whether a pagination load is currently in progress.
  ///
  /// Used together with [hasMore] to decide whether auto-advance should
  /// wait for more content before advancing.
  final bool isLoadingMore;

  /// Called when the active (visible) video changes.
  final void Function(VideoEvent video, int index)? onActiveVideoChanged;

  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  @override
  ConsumerState<FeedVideos> createState() => FeedVideosState();
}

class FeedVideosState extends ConsumerState<FeedVideos> with RouteAware {
  /// Reads the page-scoped [FeedAutoAdvanceCubit] from context.
  ///
  /// The cubit is owned and provided by the enclosing page surface
  /// ([VideoFeedPage] / [PooledFullscreenVideoFeedScreen]) so the home
  /// feed's top-bar [FeedSettingsMenu] and this widget's internal
  /// auto-advance flow share a single instance. Creating a second cubit
  /// here would silently shadow the page-scoped one for the inner subtree
  /// and make the popover toggle a no-op.
  FeedAutoAdvanceCubit get _autoAdvanceCubit =>
      context.read<FeedAutoAdvanceCubit>();
  final _feedKey = GlobalKey<InfiniteVideoFeedState>();
  bool _routeAllowsPlayback = true;

  /// Last error type reported per video.id to
  /// [VideoPlaybackStatusCubit]. Used to dedupe at the call site so
  /// `errorBuilder` rebuilds (orientation change, parent rebuild) don't
  /// schedule a post-frame callback every frame. The cubit also dedupes
  /// internally, but skipping the callback entirely avoids the per-frame
  /// scheduler churn.
  final Map<String, VideoErrorType> _lastReportedError = {};

  /// Video ids whose content warning the user dismissed via "View Anyway".
  ///
  /// Lives at the feed level (not in the per-item overlay state) because
  /// [InfiniteVideoFeed.canAutoPlay] must consult it before starting
  /// playback — a warned video must stay paused until revealed.
  final Set<String> _revealedContentWarningVideoIds = <String>{};
  String? _activeSubtitleVideoId;
  final Object _subtitleVisibilityOwner = Object();
  late final SubtitleVisibilityOverrideNotifier _subtitleVisibilityOverrides;

  @override
  void initState() {
    super.initState();
    _subtitleVisibilityOverrides = ref.read(
      subtitleVisibilityOverrideProvider.notifier,
    );
  }

  void _syncScopedSubtitleVisibility(String videoId, {bool defer = false}) {
    if (_activeSubtitleVideoId == videoId) return;
    _activeSubtitleVideoId = videoId;
    // didUpdateWidget/dispose may run while Riverpod is building dependents, so
    // those callers defer Notifier mutation until the current build unwinds.
    if (defer) {
      scheduleMicrotask(
        () => _subtitleVisibilityOverrides.syncOwnerToVideo(
          _subtitleVisibilityOwner,
          videoId,
        ),
      );
      return;
    }
    _subtitleVisibilityOverrides.syncOwnerToVideo(
      _subtitleVisibilityOwner,
      videoId,
    );
  }

  void _clearOwnedScopedSubtitleVisibility({bool defer = false}) {
    _activeSubtitleVideoId = null;
    // didUpdateWidget/dispose may run while Riverpod is building dependents, so
    // those callers defer Notifier mutation until the current build unwinds.
    if (defer) {
      scheduleMicrotask(
        () => _subtitleVisibilityOverrides.clearOwner(_subtitleVisibilityOwner),
      );
      return;
    }
    _subtitleVisibilityOverrides.clearOwner(_subtitleVisibilityOwner);
  }

  /// Warn labels for [video] merging creator/trusted labels with any
  /// crossed-threshold community labels (#4771), so the autoplay gate and
  /// the blur overlay always agree on whether the video is warned.
  ///
  /// The community half is gated on the kill-switch: with the flag off, only
  /// the creator/trusted labels apply, so already-cached community warnings
  /// stop blurring and gating the moment the flag flips off (the read path is
  /// gated, not just prefetch). `build` watches the same flag so a flip
  /// re-evaluates the gate without a restart.
  List<String> _effectiveWarnLabels(VideoEvent video) {
    if (!ref.read(
      isFeatureEnabledProvider(FeatureFlag.communityContentWarnings),
    )) {
      return video.warnLabels;
    }
    return <String>{
      ...video.warnLabels,
      ...ref.read(communityContentLabelServiceProvider).warnLabelsFor(video),
    }.toList();
  }

  /// Whether [video] may start playing: either it has no content-warning
  /// gate, or the user already chose "View Anyway" for it.
  bool _canAutoPlayVideo(VideoEvent video) =>
      !shouldShowContentWarningOverlay(
        contentWarningLabels: video.contentWarningLabels,
        warnLabels: _effectiveWarnLabels(video),
      ) ||
      _revealedContentWarningVideoIds.contains(video.id);

  /// Marks [videoId] as revealed and starts playback of the active video.
  void _revealContentWarning(String videoId) {
    setState(() {
      _revealedContentWarningVideoIds.add(videoId);
    });
    _feedKey.currentState?.resumeCurrentPlayback();
  }

  /// Animates the underlying feed to [index].
  ///
  /// Used by parent screens that hold a [GlobalKey<FeedVideosState>] to
  /// programmatically skip to a specific video (e.g. after a 404 removal).
  Future<void> animateToPage(int index) =>
      _feedKey.currentState?.animateToPage(index) ?? Future.value();

  Future<PooledRetryOutcome> _retryPooledVideoAt(
    int index,
    Map<String, String> httpHeaders,
  ) => _retryFeedItem(_feedKey.currentState, index, httpHeaders);

  void _skipPooledVideoAt(int index) {
    unawaited(_feedKey.currentState?.animateToPage(index + 1));
  }

  @override
  void didUpdateWidget(covariant FeedVideos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      final currentIndex =
          _feedKey.currentState?.currentIndex ?? widget.currentIndex;
      if (currentIndex >= 0 && currentIndex < widget.videos.length) {
        _syncScopedSubtitleVisibility(
          widget.videos[currentIndex].id,
          defer: true,
        );
      } else {
        _clearOwnedScopedSubtitleVisibility(defer: true);
      }
    }
    // Overlays, pushed routes, and tab switches make the feed temporarily
    // inactive. Keep a same-video override through those pauses; the next
    // active-video sync or dispose path owns clearing it.
    // When pagination settles (hasMore / isLoadingMore changed), flush any
    // pending auto-advance that was waiting on more content.
    if (widget.hasMore != oldWidget.hasMore ||
        widget.isLoadingMore != oldWidget.isLoadingMore) {
      final currentIndex = _feedKey.currentState?.currentIndex ?? 0;
      continueFeedAutoAdvanceAfterPagination(
        cubit: _autoAdvanceCubit,
        snapshot: FeedAutoAdvanceSnapshot(
          currentIndex: currentIndex,
          itemCount: widget.videos.length,
          hasMore: widget.hasMore,
          isLoadingMore: widget.isLoadingMore,
        ),
        animateToPage: (index) =>
            unawaited(_feedKey.currentState?.animateToPage(index)),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _clearOwnedScopedSubtitleVisibility(defer: true);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_routeAllowsPlayback) return;
    setState(() => _routeAllowsPlayback = false);
  }

  @override
  void didPopNext() {
    if (_routeAllowsPlayback) return;
    setState(() => _routeAllowsPlayback = true);
  }

  void _suppressAutoAdvance() => _autoAdvanceCubit.suppressForInteraction();

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  void _handleAutoAdvanceCompleted(int currentIndex) {
    handleFeedAutoAdvanceCompleted(
      cubit: _autoAdvanceCubit,
      snapshot: FeedAutoAdvanceSnapshot(
        currentIndex: currentIndex,
        itemCount: widget.videos.length,
        hasMore: widget.hasMore,
        isLoadingMore: widget.isLoadingMore,
      ),
      animateToPage: (index) =>
          unawaited(_feedKey.currentState?.animateToPage(index)),
      requestLoadMore: widget.onNearEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appForeground = ref.watch(appForegroundProvider);
    final isFeedActive =
        widget.isActive && _routeAllowsPlayback && appForeground;
    // Rebuild when a community-label prefetch resolves, and when the
    // kill-switch flips, so InfiniteVideoFeed re-syncs the autoplay gate from
    // didUpdateWidget. The package captures the gate answer per rebuild
    // (#6899), so both directions follow from these watches: a newly crossed
    // warning pauses the current video, and a warning that lapses resumes it.
    ref.watch(communityContentLabelServiceProvider);
    ref.watch(isFeatureEnabledProvider(FeatureFlag.communityContentWarnings));
    // While a codec-heavy surface (camera, video editor, exporter) is open, a
    // backgrounded feed must release even its warm current player so the editor
    // can claim the device's scarce hardware decoders/encoder. Selected so the
    // feed re-evaluates the moment the surface opens or closes. Nullable lookup:
    // the signal is an optimization, so a feed mounted without the cubit (tests,
    // isolated previews) simply never force-drains rather than crashing.
    final codecHeavySurfaceActive = context
        .select<CodecHeavySurfaceCubit?, bool>(
          (cubit) => cubit?.state.isActive ?? false,
        );
    return MultiBlocListener(
      listeners: [
        BlocListener<VideoVolumeCubit, VideoVolumeState>(
          // Sync volume when hardware buttons change system volume.
          listener: (_, state) {
            _feedKey.currentState?.setVolume(state.volume);
          },
        ),
        BlocListener<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
          listenWhen: (previous, current) => previous != current,
          // Once a video recovers to `ready` (e.g. after age verification),
          // forget its last reported error so a later re-error re-surfaces
          // through the errorBuilder dedupe instead of being suppressed.
          listener: (_, state) {
            _lastReportedError.removeWhere(
              (videoId, _) => state.statusFor(videoId) == PlaybackStatus.ready,
            );
          },
        ),
        // Turning Auto on is a request to keep watching: resume the current
        // video so playback — and the loop that drives the advance — actually
        // starts, instead of leaving it paused until the viewer taps to play.
        BlocListener<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
          listenWhen: (previous, current) =>
              !previous.enabled && current.enabled,
          listener: (_, _) {
            _feedKey.currentState?.resumeCurrentPlayback();
          },
        ),
      ],
      child: InfiniteVideoFeed(
        key: _feedKey,
        videos: widget.videos,
        isActive: isFeedActive,
        releaseNeighboursWhenInactive: widget.releaseNeighboursWhenInactive,
        releaseCurrentWhenInactive: codecHeavySurfaceActive,
        // mediaCacheProvider is a keepAlive singleton; identity is stable for
        // the app lifetime, so ref.read is safe here. See
        // .claude/rules/state_management.md → "Bridging Riverpod-provided
        // dependencies into BlocProvider" → exception #1.
        cache: ref.read(mediaCacheProvider),
        urlResolver: (video) => video.getOptimalVideoUrlForPlatform(),
        initialIndex: widget.currentIndex,
        onNearEnd: widget.onNearEnd,
        initialVolume: context.read<VideoVolumeCubit>().state.volume,
        onVolumeChanged: context
            .read<VideoVolumeCubit>()
            .onPlaybackVolumeChanged,
        onActiveVideoChanged: (video, index) {
          _syncScopedSubtitleVisibility(video.id);
          _resumeAutoAdvanceAfterSwipe();
          widget.onActiveVideoChanged?.call(video, index);
        },
        // Nothing in the feed plays longer than a Vine, not even a 60s file a
        // foreign Nostr client points at. The cap is a native clip end, so the
        // loop point stays in the platform player and the join stays seamless
        // (#5544, #6421).
        maxPlaybackDuration: AppConstants.maxFeedPlaybackDuration,
        onVideoLoopCompleted: _handleAutoAdvanceCompleted,
        shouldPortraitExpand: widget.shouldPortraitExpand,
        canAutoPlay: _canAutoPlayVideo,
        videoBuilder: (context, child, index, controller) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];

          final thumbnailUrl = video.thumbnailUrl;
          final blurhash = video.blurhash;
          // Metadata (dim-tag) ratio, expected to match the player's decoded
          // ratio. A wrong dim mis-sizes the bars, or — when it flips the
          // square/non-square split the cover gate below keys off — drops the
          // backdrop entirely; no publisher emits such a dim (PR #5965 review).
          // A missing dim falls back to a fullscreen fill.
          final aspectRatio = backdropAspectRatio(video.width, video.height);
          // The player covers (fills) the screen for every non-square video
          // when shouldPortraitExpand is set (see VideoItemWidget._resolveBoxFit),
          // fully occluding the backdrop — so only mount it for the
          // contain-fit (letterboxed) case where it is actually visible.
          final coversScreen = videoCoversFeedViewport(
            aspectRatio: aspectRatio,
            shouldPortraitExpand: widget.shouldPortraitExpand,
          );
          // Either source can carry the backdrop: the blurhash path needs
          // no poster URL (PR #5957 review). The backdrop paints only in the
          // letterbox bars (each bar in its own RepaintBoundary), so no outer
          // boundary here — a fullscreen boundary would be composited whole
          // every frame and undo the per-bar isolation (PR #5957).
          final showBlurBackdrop =
              !video.isPortrait &&
              !coversScreen &&
              ((thumbnailUrl != null && thumbnailUrl.isNotEmpty) ||
                  (blurhash != null && blurhash.isNotEmpty));
          return Stack(
            fit: StackFit.expand,
            children: [
              if (showBlurBackdrop)
                Positioned.fill(
                  child: BlurredVideoBackdrop(
                    url: thumbnailUrl,
                    blurhash: blurhash,
                    videoAspectRatio: aspectRatio,
                  ),
                ),
              child,
            ],
          );
        },
        loadingBuilder: (context, index, {required bool isSquare}) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];
          return _FeedLoadingOrRestrictedOverlay(
            video: video,
            index: index,
            feedMode: widget.contextTitle,
            isSquare: isSquare,
            shouldPortraitExpand: widget.shouldPortraitExpand,
          );
        },
        errorBuilder: (context, index, onRetry, errorType) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];
          final cubit = context.read<VideoPlaybackStatusCubit>();

          // Dedupe at the call site so `errorBuilder` rebuilds don't
          // schedule a post-frame callback every frame. See
          // _lastReportedError doc above.
          if (_lastReportedError[video.id] != errorType) {
            _lastReportedError[video.id] = errorType;
            // Capture the status eagerly so the post-frame callback doesn't
            // walk the ancestor tree on a potentially-deactivated element.
            final playbackStatus = playbackStatusFromError(
              errorType,
              isModerationSource:
                  VideoModerationStatusService.shouldCheckModeration(
                    video.videoUrl,
                  ),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              cubit.report(video.id, playbackStatus);
            });
          }
          // Mirror the BoxFit logic of VideoLoadingPlaceholder /
          // VideoItemWidget so the error thumbnail respects the same
          // square / portrait-expand rules as the live video.
          final width = video.width;
          final height = video.height;
          final isSquare = width != null && height != null && width == height;
          return VerifyingAwareVideoErrorOverlay(
            video: video,
            index: index,
            resolveSha256: VideoModerationStatusService.resolveSha256,
            onRetry: () {
              _lastReportedError.remove(video.id);
              cubit.report(video.id, PlaybackStatus.ready);
              onRetry();
            },
            onSkip: () => _skipPooledVideoAt(index),
            retryPlayback: (httpHeaders) =>
                _retryPooledVideoAt(index, httpHeaders),
            errorType: errorType,
            shouldPortraitExpand: widget.shouldPortraitExpand,
            isSquare: isSquare,
          );
        },
        overlayBuilder: (context, index, controller, {required bool isActive}) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];
          return DivineVideoMetricsTracker(
            video: video,
            controller: controller,
            isActive: isActive,
            isFeedVisible: isFeedActive,
            position: index,
            trafficSource: widget.trafficSource,
            sourceDetail: widget.sourceDetail,
            child: _Overlay(
              controller: controller,
              video: video,
              index: index,
              isActive: isActive,
              isFeedActive: isFeedActive,
              contextTitle: widget.contextTitle,
              contentWarningRevealed: _revealedContentWarningVideoIds.contains(
                video.id,
              ),
              onContentWarningRevealed: () => _revealContentWarning(video.id),
              onSuppressAutoAdvance: _suppressAutoAdvance,
              onResumeAutoAdvance: _resumeAutoAdvanceAfterSwipe,
            ),
          );
        },
      ),
    );
  }
}

class _Overlay extends ConsumerStatefulWidget {
  const _Overlay({
    required this.contextTitle,
    required this.controller,
    required this.video,
    required this.index,
    required this.isActive,
    required this.isFeedActive,
    required this.contentWarningRevealed,
    required this.onContentWarningRevealed,
    this.onSuppressAutoAdvance,
    this.onResumeAutoAdvance,
  });

  final String? contextTitle;
  final DivineVideoPlayerController? controller;
  final VideoEvent video;
  final int index;

  /// Whether this item is the current page of the feed.
  final bool isActive;

  /// Whether the feed itself may play: the home tab is current, no route or
  /// overlay covers it, and the app is foregrounded. A paused player while
  /// this is `false` is a temporary pause that resumes on its own, so the
  /// paused affordance stays hidden.
  final bool isFeedActive;

  /// Whether the user already dismissed this video's content warning.
  /// Owned by [FeedVideosState] so the autoplay gate can read it too.
  final bool contentWarningRevealed;

  /// Called when the user taps "View Anyway" on the content warning.
  final VoidCallback onContentWarningRevealed;

  final VoidCallback? onSuppressAutoAdvance;

  /// Called when a tap resumes playback, so Auto can be lifted out of the
  /// suppression a preceding pause applied.
  final VoidCallback? onResumeAutoAdvance;

  @override
  ConsumerState<_Overlay> createState() => __OverlayState();
}

sealed class _OverlayMode {
  const _OverlayMode();
}

class _OverlayForbiddenMode extends _OverlayMode {
  const _OverlayForbiddenMode();
}

class _OverlayAgeRestrictedMode extends _OverlayMode {
  const _OverlayAgeRestrictedMode();
}

class _OverlayUnavailableMode extends _OverlayMode {
  const _OverlayUnavailableMode();
}

/// Retries [index] on [feedState] and reports the error the player classified
/// afterwards, so the age-gate retry can tell a repeated auth rejection apart
/// from an unrelated playback failure. #6253
Future<PooledRetryOutcome> _retryFeedItem(
  InfiniteVideoFeedState? feedState,
  int index,
  Map<String, String> httpHeaders,
) async {
  if (feedState == null) {
    return (status: VideoRetryResult.notAttempted, errorType: null);
  }
  final status = await feedState.retryAt(index, httpHeaders: httpHeaders);
  return (
    status: status,
    errorType: status == VideoRetryResult.failed
        ? feedState.errorTypeAt(index)
        : null,
  );
}

class _OverlayContentWarningMode extends _OverlayMode {
  const _OverlayContentWarningMode(this.labels);

  final List<String> labels;
}

class _OverlayInteractiveMode extends _OverlayMode {
  const _OverlayInteractiveMode({required this.isReady});

  final bool isReady;
}

class __OverlayState extends ConsumerState<_Overlay> {
  final _heartTrigger = ValueNotifier<HeartTrigger?>(null);
  int _heartTriggerId = 0;
  InfiniteVideoFeedState? _feedState;
  ValueListenable<double>? _pagePositionListenable;

  /// Page-scoped immersive state, cached so [dispose] can lower the flag
  /// without reaching through a deactivated [BuildContext].
  FeedImmersiveCubit? _immersiveCubit;

  /// Whether *this* item raised the immersive flag. Guards enter/exit so an
  /// unrelated pointer can't clear a hold we never started.
  bool _isHoldingForImmersive = false;

  /// Pointers currently down over this item. The peek ends only when the last
  /// one lifts, so an incidental second finger (a resting thumb, a pinch
  /// attempt) can't restore the chrome while the hold finger is still down.
  final Set<int> _immersivePointers = <int>{};

  /// Latest local position of each down pointer, used to measure a pinch.
  final Map<int, Offset> _immersivePointerPositions = <int, Offset>{};

  /// Separation between the two pinch fingers when the second one landed, in
  /// logical pixels. `null` until at least two pointers are down; a pinch is
  /// measured against this so only a real spread or squeeze toggles the pin,
  /// not the incidental placement of two fingers.
  double? _pinchBaselineDistance;

  /// Whether the current multi-pointer gesture has already toggled the pin, so
  /// one continuous pinch cannot fire repeatedly.
  bool _pinchTriggeredForGesture = false;

  /// Whether *this* item pinned the chrome. Mirrors
  /// [_isHoldingForImmersive] so a pin can be cleared without un-pinning a
  /// state another item owns.
  bool _isPinnedForImmersive = false;

  /// Whether the touch in progress, or the one that just ended, ever had two
  /// fingers down. A tap recognizer follows its first finger through a second
  /// one landing, so a pinch whose first finger stayed inside touch slop still
  /// ends as a tap; that tap must not act on the pin, playback or a like.
  bool _touchWasMultiTouch = false;

  /// How far the pinch fingers must spread or squeeze from their landing
  /// separation before the pin toggles. Large enough to ignore a two-finger
  /// scroll settling, small enough to feel deliberate.
  static const double _pinchToggleDistance = 64;

  @override
  void initState() {
    super.initState();
    _prefetchCommunityLabels();
  }

  @override
  void didUpdateWidget(covariant _Overlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _prefetchCommunityLabels();
    }
    // Swiping away from this item must not leave the next video's chrome
    // pinned hidden — the cubit is shared across the feed page, so the pin is
    // released by the item that owns it as that item deactivates.
    if (oldWidget.isActive && !widget.isActive) {
      _clearPinnedImmersive();
    }
  }

  // Bounded to feed items that actually mount, so this only queries community
  // labels for videos the viewer is near. Idempotent inside the service.
  // Gated on the kill-switch: with the flag off nothing is fetched, so the
  // cache stays empty and neither the overlay nor the autoplay gate react.
  void _prefetchCommunityLabels() {
    final flagEnabled = ref.read(
      isFeatureEnabledProvider(FeatureFlag.communityContentWarnings),
    );
    if (!flagEnabled) return;
    unawaited(
      ref.read(communityContentLabelServiceProvider).prefetch(widget.video),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedState = context.findAncestorStateOfType<InfiniteVideoFeedState>();
    _pagePositionListenable = _feedState?.pagePositionListenable;
    _immersiveCubit = context.read<FeedImmersiveCubit?>();
  }

  @override
  void dispose() {
    // An item can be torn down mid-hold (feed rebuild, route replacement).
    // The cubit outlives this overlay, so the flag has to come down here or
    // the surface would be left with permanently hidden chrome. The pin has
    // the same failure mode — a pinned item disposed without clearing would
    // pin every later video too.
    _clearPinnedImmersive();
    _exitImmersive();
    // [didUpdateWidget] re-points this State at a different video, so the
    // pointer set must not outlive the item that filled it.
    _immersivePointers.clear();
    _immersivePointerPositions.clear();
    _heartTrigger.dispose();
    super.dispose();
  }

  /// Hides the chrome for as long as the viewer keeps their finger down.
  void _enterImmersive() {
    final cubit = _immersiveCubit;
    if (cubit == null || cubit.isClosed || _isHoldingForImmersive) return;
    _isHoldingForImmersive = true;
    // Confirms the hold registered — the gesture has no other affordance.
    unawaited(HapticService.immersiveModeFeedback());
    cubit.enter();
  }

  /// Drops a lifted/cancelled pointer, resets any in-progress pinch once the
  /// gesture is no longer multi-touch, and, with none left, brings the chrome
  /// back.
  ///
  /// Driven off the raw [Listener] rather than the gesture callbacks.
  /// `LongPressGestureRecognizer` does not report `onLongPressEnd` for a
  /// pointer cancelled after the press was accepted (`onLongPressCancel`
  /// does fire), and neither callback can distinguish an incidental second
  /// finger lifting from the hold finger lifting — only counting pointers
  /// can. Flutter still delivers the terminal event to the down-time hit
  /// path even after the [Listener] has unmounted (a mode flip mid-hold),
  /// so this stays the reliable exit.
  void _handleImmersivePointerEnd(int pointer) {
    _immersivePointers.remove(pointer);
    _immersivePointerPositions.remove(pointer);
    if (_immersivePointerPositions.length < 2) {
      _resetPinchGesture();
    } else if (_pinchBaselineDistance != null) {
      // A third finger was down, so the measured pair may now be a different
      // one. Re-measure from here rather than compare against the old pair.
      _pinchBaselineDistance = _pinchDistance();
    }
    if (_immersivePointers.isEmpty) _exitImmersive();
  }

  /// Records a down pointer and seeds the pinch baseline once two are down.
  void _handleImmersivePointerDown(PointerDownEvent event) {
    // An empty set means nothing is down, so any hold this item still believes
    // it owns is stale — its terminal event was lost (a touch dropped on
    // backgrounding, a platform view taking over). Without this the item could
    // never peek again.
    if (_immersivePointers.isEmpty) {
      _touchWasMultiTouch = false;
      _exitImmersive();
    }
    _immersivePointers.add(event.pointer);
    if (_immersivePointers.length > 1) _touchWasMultiTouch = true;
    _immersivePointerPositions[event.pointer] = event.localPosition;
    if (_immersivePointerPositions.length == 2) {
      _pinchBaselineDistance = _pinchDistance();
      _pinchTriggeredForGesture = false;
    }
  }

  /// Tracks pointer movement and toggles the pin when a two-finger pinch
  /// spreads or squeezes past [_pinchToggleDistance].
  ///
  /// Measured from the landing separation, not an absolute distance, so a
  /// two-finger scroll whose fingers drift keeps roughly the same separation
  /// and never trips it. Only the first crossing per gesture toggles; the
  /// flag resets when the fingers lift.
  void _handleImmersivePointerMove(PointerMoveEvent event) {
    if (!_immersivePointerPositions.containsKey(event.pointer)) return;
    _immersivePointerPositions[event.pointer] = event.localPosition;
    final baseline = _pinchBaselineDistance;
    if (baseline == null || _pinchTriggeredForGesture) return;
    if (_immersivePointerPositions.length < 2) return;
    if ((_pinchDistance() - baseline).abs() >= _pinchToggleDistance) {
      _pinchTriggeredForGesture = true;
      _togglePinnedImmersive();
    }
  }

  /// Separation between the first two down pointers, in logical pixels.
  double _pinchDistance() {
    final points = _immersivePointerPositions.values.toList(growable: false);
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  /// Forgets the pinch baseline so the next multi-touch gesture is measured
  /// afresh.
  void _resetPinchGesture() {
    _pinchBaselineDistance = null;
    _pinchTriggeredForGesture = false;
  }

  /// Toggles the persistent pin. A second pinch restores the chrome, as does
  /// tapping the video.
  void _togglePinnedImmersive() {
    final cubit = _immersiveCubit;
    if (cubit == null || cubit.isClosed) return;
    if (_isPinnedForImmersive) {
      _isPinnedForImmersive = false;
      cubit.unpin();
      return;
    }
    _isPinnedForImmersive = true;
    // Confirms the pinch registered — the gesture has no other affordance.
    unawaited(HapticService.immersiveModeFeedback());
    cubit.pin();
  }

  /// Clears a pin this item owns. Idempotent, so [dispose], the swipe-away
  /// path, and tap-to-restore can all call it unconditionally.
  void _clearPinnedImmersive() {
    if (!_isPinnedForImmersive) return;
    _isPinnedForImmersive = false;
    final cubit = _immersiveCubit;
    if (cubit == null || cubit.isClosed) return;
    cubit.unpin();
  }

  /// Brings the chrome back. Idempotent — the no-op guard lets [dispose] and
  /// the last-pointer-up path both call it unconditionally.
  void _exitImmersive() {
    if (!_isHoldingForImmersive) return;
    _isHoldingForImmersive = false;
    final cubit = _immersiveCubit;
    if (cubit == null || cubit.isClosed) return;
    cubit.exit();
  }

  // Single definition of "what counts as warned" for this overlay: the
  // video's own warn labels plus crossed-threshold community labels. Call
  // sites pass the service via ref.watch (build) or ref.read (handlers).
  // The community half is gated on the kill-switch so a cached warning stops
  // blurring the moment the flag flips off (build watches the same flag).
  List<String> _effectiveWarnLabels(CommunityContentLabelService service) {
    if (!ref.read(
      isFeatureEnabledProvider(FeatureFlag.communityContentWarnings),
    )) {
      return widget.video.warnLabels;
    }
    return <String>{
      ...widget.video.warnLabels,
      ...service.warnLabelsFor(widget.video),
    }.toList();
  }

  void _handleDoubleTapLike(
    BuildContext context,
    TapDownDetails details, {
    required bool isOwnVideo,
  }) {
    // Fires while the previous touch's flag is still set, so a tap that lands
    // within the double-tap window of a pinch cannot read as a double tap.
    if (_touchWasMultiTouch) return;
    final contentWarningBlocking =
        shouldShowContentWarningOverlay(
          contentWarningLabels: widget.video.contentWarningLabels,
          warnLabels: _effectiveWarnLabels(
            ref.read(communityContentLabelServiceProvider),
          ),
        ) &&
        !widget.contentWarningRevealed;

    final bloc = context.read<VideoInteractionsBloc>();
    final action = resolveDoubleTapLikeAction(
      isOwnVideo: isOwnVideo,
      contentWarningBlocking: contentWarningBlocking,
      alreadyLiked: bloc.state.isLiked,
    );

    if (action == DoubleTapLikeAction.ignore) return;

    if (action == DoubleTapLikeAction.likeAndAnimate) {
      bloc.add(const VideoInteractionsLikeToggled());
    }

    // Show heart animation at tap position (also when already liked).
    _heartTrigger.value = (
      offset: details.localPosition,
      id: ++_heartTriggerId,
    );
  }

  /// Restores pinned chrome on a tap while the player cannot yet play or pause.
  void _handleRestoreTap() {
    if (_touchWasMultiTouch) return;
    _clearPinnedImmersive();
  }

  void _handlePlayerTap() {
    if (_touchWasMultiTouch) return;
    // A tap while pinned restores the chrome instead of toggling playback.
    // Otherwise the first tap after a pinch both un-hid the controls and
    // paused the video, so the viewer could not bring the UI back without
    // also changing playback — the exit gesture has to be the tap alone.
    if (_isPinnedForImmersive) {
      _clearPinnedImmersive();
      return;
    }
    final controller = widget.controller;
    if (controller == null) return;
    switch (resolvePlayerTapAction(controller.state.status)) {
      // Pausing suppresses Auto so it cannot advance out from under a paused
      // frame; resuming lifts that suppression, because a tap to play is a
      // request to keep watching. Suppressing on both taps latched Auto off
      // after a pause and nothing lifted it until the next swipe.
      case PlayerTapAction.play:
        widget.onResumeAutoAdvance?.call();
        runDetached(
          controller.play(),
          'resume video playback',
          logName: 'FeedVideos',
          category: LogCategory.ui,
        );
      case PlayerTapAction.pause:
        widget.onSuppressAutoAdvance?.call();
        runDetached(
          controller.pause(),
          'pause video playback',
          logName: 'FeedVideos',
          category: LogCategory.ui,
        );
    }
  }

  /// Advances the feed to the next page via the cached
  /// [InfiniteVideoFeedState] reference.
  void _skipToNextVideo() {
    final feedState = _feedState;
    assert(
      feedState != null,
      'ModeratedContentOverlay must be mounted inside InfiniteVideoFeed',
    );
    if (feedState == null) return;
    unawaited(feedState.animateToPage(widget.index + 1));
  }

  /// Triggers age verification and retries playback with viewer auth.
  Future<void> _verifyAgeForVideo() async {
    await retryAgeRestrictedPooledVideo(
      context: context,
      ref: ref,
      video: widget.video,
      index: widget.index,
      resolveSha256: VideoModerationStatusService.resolveSha256,
      retryPlayback: (httpHeaders) =>
          _retryFeedItem(_feedState, widget.index, httpHeaders),
    );
  }

  _OverlayMode _resolveOverlayMode({
    required PlaybackStatus playbackStatus,
    required List<String> overlayLabels,
    required bool showContentWarningOverlay,
    required bool isReady,
  }) {
    return switch (playbackStatus) {
      PlaybackStatus.forbidden => const _OverlayForbiddenMode(),
      PlaybackStatus.ageRestricted => const _OverlayAgeRestrictedMode(),
      PlaybackStatus.unavailable => const _OverlayUnavailableMode(),
      _ =>
        showContentWarningOverlay && !widget.contentWarningRevealed
            ? _OverlayContentWarningMode(overlayLabels)
            : _OverlayInteractiveMode(isReady: isReady),
    };
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final pagePositionListenable = _pagePositionListenable;

    // Keep the BlocProvider keyed by repository identities. #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final addressableId = video.addressableId;

    final currentUserPubkey = ref.watch(
      authServiceProvider.select((service) => service.currentPublicKeyHex),
    );
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == widget.video.pubkey;

    // Subscribe only to `isEffectivelyActive` — the single Auto flag this
    // overlay reads — so unrelated cubit changes don't rebuild every visible
    // feed item while scrolling.
    final autoEffectivelyActive = context.select(
      (FeedAutoAdvanceCubit cubit) => cubit.state.isEffectivelyActive,
    );

    // Gate the runtime on the user's reduced-motion preference. When Auto is
    // unavailable, force it "off" at the view layer regardless of cubit state.
    final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(context);

    // Watch the kill-switch so the blur re-evaluates on a flip, and start
    // prefetching if it flips on for an already-mounted overlay (initState's
    // prefetch is a no-op while the flag is off). #5720 M3.
    ref.watch(isFeatureEnabledProvider(FeatureFlag.communityContentWarnings));
    ref.listen(isFeatureEnabledProvider(FeatureFlag.communityContentWarnings), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        _prefetchCommunityLabels();
      }
    });

    // Merge community-suggested warnings (#4771) into the creator/trusted
    // warn labels so a crossed-threshold community label drives the same
    // blur overlay. Advisory only; the service returns an empty set until
    // its background prefetch resolves.
    final effectiveWarnLabels = _effectiveWarnLabels(
      ref.watch(communityContentLabelServiceProvider),
    );

    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: effectiveWarnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: effectiveWarnLabels,
    );

    final effectiveAutoActive = autoAdvanceAvailable && autoEffectivelyActive;

    // Guard that HEAD-confirms a 404 and requires a terminal moderation verdict
    // before marking the item broken so the home feed can skip past + prune
    // dead imported-Vine media. Null until its one-time tracker init resolves.
    // See #5953 / #6251.
    final deadMediaGuard = ref.watch(deadMediaFeedGuardProvider).asData?.value;

    final playbackStatus = context.select(
      (VideoPlaybackStatusCubit cubit) => cubit.state.statusFor(video.id),
    );
    final isVerifyingAge = context.select(
      (VideoPlaybackStatusCubit cubit) => cubit.state.isVerifying(video.id),
    );
    // Watched, not read from the local flag: pinning does not call setState,
    // so the gesture surface must rebuild off the cubit to learn that a tap
    // should now restore the chrome.
    final isChromePinned = context.select<FeedImmersiveCubit?, bool>(
      (cubit) => cubit?.state.isPinned ?? false,
    );

    final isReady =
        widget.controller != null &&
        widget.controller?.state.isFirstFrameRendered == true &&
        widget.controller?.state.hasError == false;
    final mode = _resolveOverlayMode(
      playbackStatus: playbackStatus,
      overlayLabels: overlayLabels,
      showContentWarningOverlay: showContentWarningOverlay,
      isReady: isReady,
    );

    switch (mode) {
      case _OverlayForbiddenMode():
        return ModeratedContentOverlay(
          status: playbackStatus,
          onSkip: _skipToNextVideo,
        );
      case _OverlayAgeRestrictedMode():
        return ModeratedContentOverlay(
          status: playbackStatus,
          onSkip: _skipToNextVideo,
          onVerifyAge: _verifyAgeForVideo,
          isVerifying: isVerifyingAge,
        );
      case _OverlayUnavailableMode():
        return ModeratedContentOverlay(
          status: playbackStatus,
          onSkip: _skipToNextVideo,
        );
      case _OverlayContentWarningMode(:final labels):
        return ContentWarningBlurOverlay(
          // Display uses the merged (creator + community) labels so the blur
          // names every warning. Hide-similar must persist ONLY the
          // creator/trusted labels: an unverified community-only warning
          // must never become a persisted global hide (#4771 warn-only v1).
          labels: labels,
          onReveal: widget.onContentWarningRevealed,
          onHideSimilar: () {
            runDetached(
              hideContentWarningsLikeThese(
                context: context,
                ref: ref,
                labels: contentWarningOverlayLabels(
                  contentWarningLabels: video.contentWarningLabels,
                  warnLabels: video.warnLabels,
                ),
              ),
              'hide similar content warnings',
              logName: 'FeedVideos',
              category: LogCategory.ui,
            );
          },
        );
      case _OverlayInteractiveMode(isReady: final interactiveReady):
        return FeedAutoAdvancePastErrorListener(
          videoId: video.id,
          isActive: widget.isActive,
          isAutoAdvanceActive: effectiveAutoActive,
          onSkipBrokenVideo: _skipToNextVideo,
          confirmAndMarkMissing: deadMediaGuard == null
              ? null
              : () => deadMediaGuard.confirmAndMarkMissing(
                  videoId: video.id,
                  videoUrl: video.videoUrl,
                  explicitSha256: video.sha256,
                ),
          child: BlocProvider<VideoInteractionsBloc>(
            key: videoInteractionsBlocKey(
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              video: video,
            ),
            create: (_) =>
                VideoInteractionsBloc(
                    eventId: video.id,
                    authorPubkey: video.pubkey,
                    likesRepository: likesRepository,
                    commentsRepository: commentsRepository,
                    repostsRepository: repostsRepository,
                    addressableId: addressableId,
                    initialLikeCount: liveLikeCountSeed(video),
                    archivedLikeCount: video.originalLikes,
                    initialCommentCount: liveCommentCountSeed(video),
                    initialRepostCount: liveRepostCountSeed(video),
                  )
                  ..add(const VideoInteractionsSubscriptionRequested())
                  ..add(const VideoInteractionsFetchRequested()),
            child: VideoInteractionsRestrictionListener(
              child: Builder(
                builder: (context) {
                  // The chrome layers are SIBLINGS above the gesture surface,
                  // never descendants of it. As descendants, any press held
                  // past `kLongPressTimeout` anywhere on the action rail was
                  // claimed by the video's long-press: the rail's own tap
                  // recognizer only accepts on pointer-up, so it lost the
                  // arena, and Report/More/Share swallowed the tap and faded
                  // out under the viewer's finger. Keeping them siblings lets
                  // an opaque button win the hit test outright, so the peek
                  // never sees that pointer.
                  //
                  // The player's label and hint live on the gesture surface
                  // below, not on a wrapper here: a node with no tap action
                  // cannot name the one a screen reader activates.
                  return Stack(
                    children: [
                      // The raw [Listener] owns immersive mode's release: it
                      // counts the pointers over the item and exits once the
                      // last lifts. `onLongPressEnd` alone would not do —
                      // it does not fire for a pointer cancelled after the
                      // press was accepted (`onLongPressCancel` does), and
                      // neither callback can tell an incidental second finger
                      // lifting from the hold finger lifting. A Listener also
                      // sits outside the gesture arena, so it can't steal the
                      // press.
                      Positioned.fill(
                        child: Listener(
                          // Must match the translucent child below: with
                          // `deferToChild` a press on empty video area never
                          // adds this Listener to the hit-test path (the
                          // translucent GestureDetector adds itself but still
                          // reports a miss), so the pointer events would never
                          // arrive.
                          behavior: HitTestBehavior.translucent,
                          // The raw pointer stream also owns the pinch that
                          // toggles the persistent pin. A ScaleGestureRecognizer
                          // would join the gesture arena and compete with the
                          // PageView's vertical drag, breaking feed swiping;
                          // measuring the raw pointers never enters the arena.
                          onPointerDown: _handleImmersivePointerDown,
                          onPointerMove: _handleImmersivePointerMove,
                          onPointerUp: (event) =>
                              _handleImmersivePointerEnd(event.pointer),
                          onPointerCancel: (event) =>
                              _handleImmersivePointerEnd(event.pointer),
                          child: PlayerGestureSurface(
                            interactiveReady: interactiveReady,
                            isOwnVideo: isOwnVideo,
                            onTap: _handlePlayerTap,
                            onDoubleTapDown: (details) => _handleDoubleTapLike(
                              context,
                              details,
                              isOwnVideo: isOwnVideo,
                            ),
                            onLongPressStart: _enterImmersive,
                            onRestoreChrome: isChromePinned
                                ? _handleRestoreTap
                                : null,
                          ),
                        ),
                      ),
                      if (widget.controller != null)
                        // The paused play indicator is chrome too — it
                        // covers the frame the peek is meant to reveal,
                        // and holding never resumes playback, so leaving
                        // it up would contradict the gesture.
                        FeedImmersiveChrome(
                          child: PausedVideoOverlay(
                            controller: widget.controller!,
                            videoId: video.id,
                            // Only a pause the user can undo gets the
                            // affordance. A comments/share sheet, a pushed
                            // route or a backgrounded app pauses the player
                            // too, but resumes it on its own — showing a play
                            // button behind the sheet just reads as broken.
                            isVisible: widget.isActive && widget.isFeedActive,
                          ),
                        ),
                      FeedImmersiveChrome(
                        child: _FeedItemActions(
                          video: video,
                          index: widget.index,
                          contextTitle: widget.contextTitle,
                          isOwnVideo: isOwnVideo,
                          onSuppressAutoAdvance: widget.onSuppressAutoAdvance,
                          // Captions fade with the rest of the chrome, by
                          // design: the hold reveals the frame the UI covers,
                          // and the caption is an overlay over that same frame,
                          // so keeping it up would re-cover exactly what the
                          // peek exposes. It is gone only while the viewer
                          // holds, and returns the instant they release.
                          subtitleLayer:
                              video.hasSubtitles && widget.controller != null
                              ? _SubtitleLayer(
                                  video: video,
                                  controller: widget.controller!,
                                )
                              : null,
                          pagePositionListenable: pagePositionListenable,
                        ),
                      ),
                      Positioned.fill(
                        child: DoubleTapHeartOverlay(trigger: _heartTrigger),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
    }
  }
}

class _FeedItemActions extends StatelessWidget {
  const _FeedItemActions({
    required this.video,
    required this.index,
    required this.contextTitle,
    required this.isOwnVideo,
    required this.onSuppressAutoAdvance,
    this.subtitleLayer,
    this.pagePositionListenable,
  });

  final VideoEvent video;
  final int index;
  final String? contextTitle;
  final bool isOwnVideo;
  final VoidCallback? onSuppressAutoAdvance;
  final Widget? subtitleLayer;
  final ValueListenable<double>? pagePositionListenable;

  @override
  Widget build(BuildContext context) {
    final listenable = pagePositionListenable;
    if (listenable == null) {
      return _FeedItemOverlayActions(
        video: video,
        contextTitle: contextTitle,
        isOwnVideo: isOwnVideo,
        onSuppressAutoAdvance: onSuppressAutoAdvance,
        subtitleLayer: subtitleLayer,
      );
    }

    // The overlay content (author row, every action button, caption) does
    // not depend on the scroll-driven opacity, so it is built once and
    // reused. Only [ScrollFadeOverlay]'s Opacity / IgnorePointer rebuild as
    // the page position ticks, instead of the whole overlay — the dominant
    // feed rebuild in profiling (~150 overlay rebuilds fanning out into ~900
    // action-button rebuilds).
    return ScrollFadeOverlay(
      pagePosition: listenable,
      index: index,
      child: _FeedItemOverlayActions(
        video: video,
        contextTitle: contextTitle,
        isOwnVideo: isOwnVideo,
        onSuppressAutoAdvance: onSuppressAutoAdvance,
        subtitleLayer: subtitleLayer,
      ),
    );
  }
}

/// Applies the scroll-driven fade to a feed item's overlay without rebuilding
/// it on every page-position tick.
///
/// [child] — the overlay content — is built once by the caller and reused;
/// only the wrapping [Opacity] / [IgnorePointer] rebuild as [pagePosition]
/// changes. This keeps a scroll frame from fanning out into a full overlay
/// (author row + all action buttons + caption) rebuild.
class ScrollFadeOverlay extends StatelessWidget {
  const ScrollFadeOverlay({
    required this.pagePosition,
    required this.index,
    required this.child,
    super.key,
  });

  /// Current fractional page offset of the enclosing [PageView].
  final ValueListenable<double> pagePosition;

  /// This item's page index; the fade is driven by the distance between
  /// [pagePosition] and [index].
  final int index;

  /// Overlay content, built once and shared across page-position ticks.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: pagePosition,
      child: child,
      builder: (context, page, child) {
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final opacity = scrollDrivenOpacity(distance);
        return Opacity(
          opacity: opacity,
          child: IgnorePointer(ignoring: opacity < 0.01, child: child),
        );
      },
    );
  }
}

class _FeedItemOverlayActions extends StatelessWidget {
  const _FeedItemOverlayActions({
    required this.video,
    required this.contextTitle,
    required this.isOwnVideo,
    required this.onSuppressAutoAdvance,
    this.subtitleLayer,
  });

  final VideoEvent video;
  final String? contextTitle;
  final bool isOwnVideo;
  final VoidCallback? onSuppressAutoAdvance;
  final Widget? subtitleLayer;

  @override
  Widget build(BuildContext context) {
    // Rendered at full opacity; the scroll-driven fade is applied by the
    // enclosing ValueListenableBuilder so this subtree stays stable across
    // page-position ticks.
    return VideoOverlayActions(
      video: video,
      isVisible: true,
      isActive: true,
      hasBottomNavigation: false,
      contextTitle: contextTitle,
      isFullscreen: true,
      topOffset: isOwnVideo ? 64 : 8,
      onInteracted: onSuppressAutoAdvance,
      subtitleLayer: subtitleLayer,
    );
  }
}

/// Streams player position and renders subtitle text for fullscreen feed.
class _SubtitleLayer extends StatefulWidget {
  const _SubtitleLayer({required this.video, required this.controller});

  final VideoEvent video;
  final DivineVideoPlayerController controller;

  @override
  State<_SubtitleLayer> createState() => _SubtitleLayerState();
}

class _SubtitleLayerState extends State<_SubtitleLayer> {
  late Stream<Duration> _positionStream;

  @override
  void initState() {
    super.initState();
    _positionStream = _createPositionStream(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _SubtitleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _positionStream = _createPositionStream(widget.controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SubtitleCueStreamPill(
        video: widget.video,
        positionStream: _positionStream,
        initialPosition: widget.controller.state.position,
      ),
    );
  }

  Stream<Duration> _createPositionStream(
    DivineVideoPlayerController controller,
  ) {
    return controller.stateStream.map((s) => s.position).distinct();
  }
}

/// Shows [VideoLoadingPlaceholder] initially.
///
/// If the video is still loading after the moderation-check delay, the
/// moderation API is queried via [FeedLoadingModerationCubit]. Cached
/// videos load immediately and never reach the delay, so no unnecessary
/// API calls are made. Once the moderation check returns a restricted
/// status the view switches to [VerifyingAwareVideoErrorOverlay] without
/// waiting for the native player to time out with a 404.
class _FeedLoadingOrRestrictedOverlay extends ConsumerWidget {
  const _FeedLoadingOrRestrictedOverlay({
    required this.video,
    required this.index,
    required this.feedMode,
    required this.isSquare,
    required this.shouldPortraitExpand,
  });

  final VideoEvent video;
  final int index;
  final String? feedMode;
  final bool isSquare;
  final bool shouldPortraitExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the moderation service so the BlocProvider rebuilds (and the
    // captured cubit is closed and re-created) if the provider's identity
    // ever flips. The ValueKey gates the BlocProvider lifecycle on the
    // service identity. See .claude/rules/state_management.md → "Bridging
    // Riverpod-provided dependencies into BlocProvider".
    final service = ref.watch(videoModerationStatusServiceProvider);
    return BlocProvider<FeedLoadingModerationCubit>(
      key: ValueKey(service),
      create: (_) => FeedLoadingModerationCubit(
        service: service,
        explicitSha256: video.sha256,
        videoUrl: video.videoUrl,
      )..start(),
      child: _FeedLoadingOrRestrictedOverlayView(
        video: video,
        index: index,
        feedMode: feedMode,
        isSquare: isSquare,
        shouldPortraitExpand: shouldPortraitExpand,
      ),
    );
  }
}

class _FeedLoadingOrRestrictedOverlayView extends ConsumerWidget {
  const _FeedLoadingOrRestrictedOverlayView({
    required this.video,
    required this.index,
    required this.feedMode,
    required this.isSquare,
    required this.shouldPortraitExpand,
  });

  final VideoEvent video;
  final int index;
  final String? feedMode;
  final bool isSquare;
  final bool shouldPortraitExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocListener<FeedLoadingModerationCubit, FeedLoadingModerationState>(
      listenWhen: (previous, current) =>
          previous.status != current.status && current.isAgeRestricted,
      listener: (context, state) {
        unawaited(
          autoRetryAgeRestrictedPooledVideo(
            context: context,
            ref: ref,
            video: video,
            index: index,
            resolveSha256: VideoModerationStatusService.resolveSha256,
            retryPlayback: (httpHeaders) => _retryFeedItem(
              context.findAncestorStateOfType<InfiniteVideoFeedState>(),
              index,
              httpHeaders,
            ),
          ),
        );
      },
      child:
          BlocBuilder<FeedLoadingModerationCubit, FeedLoadingModerationState>(
            builder: (context, state) {
              if (state.isRestricted) {
                return VerifyingAwareVideoErrorOverlay(
                  video: video,
                  index: index,
                  resolveSha256: VideoModerationStatusService.resolveSha256,
                  // Retry is hidden for moderation-restricted content.
                  onRetry: () {},
                  onSkip: () {
                    unawaited(
                      context
                          .findAncestorStateOfType<InfiniteVideoFeedState>()
                          ?.animateToPage(index + 1),
                    );
                  },
                  retryPlayback: (httpHeaders) => _retryFeedItem(
                    context.findAncestorStateOfType<InfiniteVideoFeedState>(),
                    index,
                    httpHeaders,
                  ),
                  errorType: VideoErrorType.forbidden,
                  shouldPortraitExpand: shouldPortraitExpand,
                  isSquare: isSquare,
                );
              }

              if (state.isAgeRestricted) {
                return VerifyingAwareVideoErrorOverlay(
                  video: video,
                  index: index,
                  resolveSha256: VideoModerationStatusService.resolveSha256,
                  // Retry is hidden while age-gated playback uses Verify age.
                  onRetry: () {},
                  onSkip: () {
                    unawaited(
                      context
                          .findAncestorStateOfType<InfiniteVideoFeedState>()
                          ?.animateToPage(index + 1),
                    );
                  },
                  retryPlayback: (httpHeaders) => _retryFeedItem(
                    context.findAncestorStateOfType<InfiniteVideoFeedState>(),
                    index,
                    httpHeaders,
                  ),
                  errorType: VideoErrorType.ageRestricted,
                  shouldPortraitExpand: shouldPortraitExpand,
                  isSquare: isSquare,
                );
              }

              return VideoLoadingPlaceholder(
                videoId: video.id,
                index: index,
                feedMode: feedMode,
                thumbnailUrl: video.thumbnailUrl,
                isSquare: isSquare,
                shouldPortraitExpand: shouldPortraitExpand,
              );
            },
          ),
    );
  }
}
