// ABOUTME: Fullscreen video feed using the shared native feed player
// ABOUTME: Displays videos with swipe navigation and shared feed chrome
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/screens/feed/feed_tuning_snackbar.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/feed_tuning/feed_tuning_swipe_overlay.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/fullscreen_sponsor_disclosure.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';
import 'package:openvine/widgets/video_feed_item/reaction_overlay.dart';
import 'package:openvine/widgets/video_feed_item/reel_dm_reply_bar.dart';
import 'package:unified_logger/unified_logger.dart';

/// Always centers — including contain-fit (non-portrait) videos.
/// Returning [Alignment.topCenter] for non-portrait used to jam 1 × 1
/// classic Vine reposts against the AppBar; centering keeps them
/// symmetric with the bands the caller paints around them (see
/// [_MaybeRoundFeedBottom] / [_PooledFullscreenItemContent] for the
/// canvas and [_BlurredVideoBackdrop] for the blurred-thumbnail
/// layer). Portrait videos cover the whole viewport so alignment is
/// a no-op for them.
@visibleForTesting
Alignment fullscreenVideoMediaAlignment({required bool isPortrait}) {
  return Alignment.center;
}

/// Clears both the expanded leading slot and the scaled back-button target.
double _sponsorDisclosureStartInset(
  BuildContext context,
  DiVineAppBarStyle style,
) => math.max(
  style.leadingWidth,
  style.horizontalPadding + DivineIcon.scaleSize(context, 48),
);

/// Clears the scaled trailing action target plus its app-bar edge padding.
double _sponsorDisclosureEndInset(
  BuildContext context,
  DiVineAppBarStyle style,
) => style.horizontalPadding + DivineIcon.scaleSize(context, 48);

/// Arguments for navigating to PooledFullscreenVideoFeedScreen.
///
/// The feed is described by a [source] and resolved through a
/// [feedRepository]. The repository owns a lifecycle-stable, filtered stream
/// so the fullscreen surface no longer depends on a caller-owned
/// `StreamController` (see issue #3383).
class PooledFullscreenVideoFeedArgs {
  const PooledFullscreenVideoFeedArgs({
    required this.source,
    required this.feedRepository,
    required this.initialIndex,
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
    this.sponsorName,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.autoOpenComments = false,
    this.onPageChanged,
  });

  /// The feed to display, resolved via [feedRepository].
  final ViewSource source;

  /// Repository used to resolve [source] into a live, filtered feed.
  final FeedRepository feedRepository;

  /// Initial video index to start playback.
  final int initialIndex;

  /// Optional specific video identity to resolve against the first non-empty
  /// source list. This survives empty-first streams and source reordering.
  final String? initialVideoId;

  /// Optional stable id fallback for addressable videos whose event id may
  /// change after metadata updates.
  final String? initialStableId;

  /// Optional title for context display.
  final String? contextTitle;

  /// Already sanitized and clamped sponsor; null for non-sponsored feeds.
  final String? sponsorName;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  /// Whether to open the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Used by embedded surfaces to keep the URL in sync.
  final void Function(int index)? onPageChanged;
}

/// Profile-backed arguments for fullscreen playback.
///
/// Unlike [PooledFullscreenVideoFeedArgs], this keeps the fullscreen route
/// subscribed directly to the profile feed cubit so profile-specific metadata
/// updates (like loop counts) are not lost when the launching grid unmounts.
class ProfilePooledFullscreenVideoFeedArgs {
  const ProfilePooledFullscreenVideoFeedArgs({
    required this.userIdHex,
    required this.initialIndex,
    this.seedVideos = const [],
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
    this.onPageChanged,
  });

  final String userIdHex;
  final int initialIndex;
  final List<VideoEvent> seedVideos;
  final String? initialVideoId;
  final String? initialStableId;
  final String? contextTitle;
  final void Function(int index)? onPageChanged;
}

/// Fullscreen video feed screen using FeedVideos.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation.
///
/// Uses [FullscreenFeedBloc] for state management, receiving videos from
/// the source via a stream and delegating pagination back to the source.
class PooledFullscreenVideoFeedScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'pooled-video-feed';

  /// Path for this route.
  static const String path = RoutePaths.pooledFullscreenVideoFeed;

  /// Query parameter carrying the selected video's durable identity.
  static const videoQueryParameter = 'video';

  /// Builds a lifecycle-restorable route for a pooled feed.
  ///
  /// The feed repository still travels in GoRouter `extra`, but the selected
  /// video is also encoded in the URL so state restoration can fall back to the
  /// reconstructible single-video route if iOS discards the in-memory args.
  static String pathForVideoId(String videoId) => Uri(
    path: path,
    queryParameters: {videoQueryParameter: videoId},
  ).toString();

  const PooledFullscreenVideoFeedScreen({
    required this.source,
    required this.feedRepository,
    required this.initialIndex,
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
    this.sponsorName,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.autoOpenComments = false,
    this.onPageChanged,
    this.dmReplyContext,
    this.onBack,
    super.key,
  });

  /// The feed to display, resolved via [feedRepository].
  final ViewSource source;

  /// Repository used to resolve [source] into a live, filtered feed.
  final FeedRepository feedRepository;
  final int initialIndex;
  final String? initialVideoId;
  final String? initialStableId;
  final String? contextTitle;

  /// Already sanitized and clamped sponsor; null for non-sponsored feeds.
  final String? sponsorName;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  /// Present when the reel was opened from a DM thread — drives the in-player
  /// reply/reaction bar. Null on feed/profile opens.
  final DmReplyContext? dmReplyContext;

  /// When true, opens the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Receives the new feed index. Used by embedded surfaces (e.g. explore,
  /// search) to keep the URL in sync for deep-linking.
  final void Function(int index)? onPageChanged;

  /// Overrides the app-bar back action.
  ///
  /// When the fullscreen feed is embedded as a "video mode" of a parent screen
  /// (e.g. a curated list grid) rather than pushed as its own route, the parent
  /// passes this to return to its grid instead of popping the whole route — so
  /// the feed's own app-bar back button is the single back affordance the user
  /// sees.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCache = kIsWeb ? null : ref.read(mediaCacheProvider);
    final blossomAuthService = ref.read(blossomAuthServiceProvider);
    // Viewer-aware block predicate (blocks ∪ mutes ∪ blocked-us ∪ muted-us) —
    // the same `shouldFilterFromFeeds` every other feed surface filters with.
    // The bound method reads live blocklist state on each call, so capturing it
    // once in `create:` is safe: `contentBlocklistRepository` is keepAlive and
    // doesn't flip identity on a block action. The version listener in
    // [FullscreenFeedContent] re-runs the filter when the blocklist changes
    // broadly (account switch / external sync). See #5041.
    final hideFilter = ref.read(videoEventServiceProvider).shouldHideVideo;

    // The removal bus is wired internally (no longer a per-caller parameter):
    // deletion / block / mute emit a removed id here and the bloc drops it,
    // independent of whichever widget opened the route. See #3383.
    final removedIdsStream = ref
        .read(videoEventServiceProvider)
        .removedVideoIds;

    // Persist permanently-unavailable ids so the video stays filtered out of
    // every list surface (feed, profile, hashtag, grids) across restarts. The
    // bloc only fires this after DeadMediaFeedGuard confirms a
    // requester-independent, terminal moderation verdict explains the media
    // 404 (#6251). An API 404 is session-only.
    void persistConfirmedUnavailable(VideoEvent video) {
      ref.read(videoEventServiceProvider).removeVideoEventCompletely(video);
      unawaited(
        ref
            .read(brokenVideoTrackerProvider.future)
            .then(
              (tracker) => tracker.markVideoBroken(
                video.id,
                'Confirmed unavailable video in fullscreen feed',
              ),
            )
            .catchError((Object error) {
              Log.warning(
                'Failed to persist confirmed-unavailable video: $error',
                name: 'PooledFullscreenVideoFeedScreen',
                category: LogCategory.video,
              );
            }),
      );
    }

    // Filter persisted unavailable videos out of the fullscreen list at the
    // stream boundary. This covers static / by-id sources (liked, saved,
    // reposts, collabs, curated lists) whose repositories don't run the central
    // feed filters, so a video confirmed unavailable in a previous session
    // won't reappear when opened fullscreen. Reads live
    // tracker state on every call via the provider (rather than capturing a
    // snapshot in `create:`, which would stay `null` if the tracker's async
    // init hadn't resolved by first build and never recover): before init
    // resolves it filters nothing; once it resolves, every subsequent source
    // re-push is filtered. See #5237.
    bool unavailableFilter(String videoId) => ref
        .read(brokenVideoTrackerProvider)
        .maybeWhen(
          data: (tracker) => tracker.isVideoBroken(videoId),
          orElse: () => false,
        );

    Future<FeedUnavailability> confirmVideoUnavailable({
      required String videoId,
      required String? videoUrl,
      String? explicitSha256,
    }) async {
      final guard = ref.read(deadMediaFeedGuardProvider).asData?.value;
      if (guard == null) return FeedUnavailability.none;
      return guard.isConfirmedUnavailable(
        videoId: videoId,
        videoUrl: videoUrl,
        explicitSha256: explicitSha256,
      );
    }

    // Stable, keepAlive repository; reads `publicKey` live at publish time, so
    // capturing it once in `create:` stays correct across auth changes (no
    // ValueKey guard needed — see feedTuningRepositoryProvider).
    final feedTuningRepository = ref.watch(feedTuningRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => FullscreenFeedBloc(
            videosStream: feedRepository.watchView(source),
            initialIndex: initialIndex,
            initialVideoId: initialVideoId,
            initialStableId: initialStableId,
            hasMoreStream: feedRepository.watchHasMore(source),
            removedIdsStream: removedIdsStream,
            onLoadMore: () => unawaited(feedRepository.loadMore(source)),
            onRemoveVideo: (videoId) {
              ref
                  .read(videoEventServiceProvider)
                  .removeVideoCompletely(videoId);
            },
            onVideoConfirmedUnavailable: persistConfirmedUnavailable,
            confirmVideoUnavailable: confirmVideoUnavailable,
            mediaCache: mediaCache,
            blossomAuthService: blossomAuthService,
            hideFilter: hideFilter,
            unavailableFilter: unavailableFilter,
            feedTuningRepository: feedTuningRepository,
          )..add(const FullscreenFeedStarted()),
        ),
        BlocProvider(
          create: (_) => VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () => ref
                .read(mediaAuthInterceptorProvider)
                .canAutoAuthorizeAdultMedia(),
          ),
        ),
      ],
      child: FullscreenFeedContent(
        contextTitle: contextTitle,
        sponsorName: sponsorName,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        autoOpenComments: autoOpenComments,
        onPageChanged: onPageChanged,
        dmReplyContext: dmReplyContext,
        onBack: onBack,
      ),
    );
  }
}

/// Content widget for the fullscreen video feed.
///
/// Wires feed playback hooks to dispatch BLoC events for caching and loop
/// enforcement.
@visibleForTesting
class FullscreenFeedContent extends ConsumerStatefulWidget {
  /// Creates fullscreen feed content.
  @visibleForTesting
  const FullscreenFeedContent({
    this.contextTitle,
    this.sponsorName,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.autoOpenComments = false,
    this.onPageChanged,
    this.dmReplyContext,
    this.onBack,
    super.key,
  });

  /// Optional title for context display.
  final String? contextTitle;

  /// Already sanitized and clamped sponsor; null for non-sponsored feeds.
  final String? sponsorName;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  /// When true, opens the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Used by embedded surfaces to keep the URL in sync.
  final void Function(int index)? onPageChanged;

  /// Present when the reel was opened from a DM thread — drives the in-player
  /// reply/reaction bar in the body footer.
  final DmReplyContext? dmReplyContext;

  /// Overrides the app-bar back action when the feed is embedded as a parent
  /// screen's video mode (see [PooledFullscreenVideoFeedScreen.onBack]).
  final VoidCallback? onBack;

  @override
  ConsumerState<FullscreenFeedContent> createState() =>
      _FullscreenFeedContentState();
}

class _FullscreenFeedContentState extends ConsumerState<FullscreenFeedContent>
    with WidgetsBindingObserver {
  late final ValueNotifier<double> _pagePosition;
  final _feedVideosKey = GlobalKey<FeedVideosState>();

  /// Whether the in-player DM reply composer is focused. When true the reel
  /// pauses so the user can type without the video playing under the keyboard.
  bool _replyComposerFocused = false;

  /// Whether the inline comment composer is focused.
  bool _inlineComposerFocused = false;

  /// Whether one of THIS screen's own bottom composers (inline comment or DM
  /// reply) currently holds focus. Drives `resizeToAvoidBottomInset`: we only
  /// want the reel to shrink for a keyboard we opened. A keyboard opened by a
  /// modal on top — the share sheet's message field lives on the ROOT
  /// navigator while this feed sits on a nested one, so `ModalRoute.isCurrent`
  /// never flips — must NOT resize the reel, which re-lays-out the full-screen
  /// video + overlay and janks badly on older devices (Galaxy S10, #5758).
  bool get _ownComposerFocused =>
      _replyComposerFocused || _inlineComposerFocused;

  /// Emoji currently being animated by the full-screen reaction overlay (null
  /// when idle). [_reactionNonce] remounts the overlay so repeated taps replay.
  String? _reactionEmoji;
  int _reactionNonce = 0;

  /// Feed-scoped Auto playback state; exposed to descendants via
  /// `BlocProvider.value` in [build].
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();

  /// Feed-scoped immersive (hold-to-peek) state. Owned here so it sits above
  /// both [FeedVideos] — which raises it on a long press — and this screen's
  /// app bar, which fades out against it.
  final FeedImmersiveCubit _immersiveCubit = FeedImmersiveCubit();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialIndex = context.read<FullscreenFeedBloc>().state.currentIndex;
    _pagePosition = ValueNotifier<double>(initialIndex.toDouble());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pagePosition.dispose();
    unawaited(_autoAdvanceCubit.close());
    unawaited(_immersiveCubit.close());
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    // safePop: a /video/:id deep link renders this screen with a one-entry
    // stack and no onBack, and the old `go('/')` fallback matched no route.
    context.safePop();
  }

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  void _animateToPage(int index) {
    // New native player path.
    final feedVideosState = _feedVideosKey.currentState;
    if (feedVideosState != null) {
      unawaited(feedVideosState.animateToPage(index));
      return;
    }
  }

  FeedAutoAdvanceSnapshot _autoAdvanceSnapshot(FullscreenFeedState state) {
    return FeedAutoAdvanceSnapshot(
      currentIndex: state.currentIndex,
      itemCount: state.videos.length,
      hasMore: state.canLoadMore,
      isLoadingMore: state.isLoadingMore,
    );
  }

  /// Dispatch a [FullscreenFeedVideoUnavailable] event for the active video
  /// when the cubit reports [PlaybackStatus.notFound]. Replaces the prior
  /// per-item post-frame callback that violated the "no business logic in
  /// widgets" rule.
  void _dispatchVideoUnavailableIfActive(VideoPlaybackStatusState state) {
    final bloc = context.read<FullscreenFeedBloc>();
    final activeVideo = bloc.state.currentVideo;
    if (activeVideo == null) return;
    if (state.statusFor(activeVideo.id) != PlaybackStatus.notFound) return;
    if (bloc.state.removedVideoIds.contains(activeVideo.id)) return;
    bloc.add(FullscreenFeedVideoUnavailable(activeVideo.id));
  }

  /// React to a pending skip target emitted by the BLoC after a confirmed
  /// 404. Animates the active feed (pooled on native, page controller on
  /// web) and acknowledges the signal so the BLoC clears it.
  Future<void> _handlePendingSkip(int nextIndex) async {
    try {
      _animateToPage(nextIndex);
    } on Exception catch (error, stackTrace) {
      Log.error(
        'FullscreenFeedContent: animateToPage failed during skip',
        name: 'FullscreenFeedContent',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedSkipAcknowledged(),
    );
  }

  void _continuePendingAutoAdvance(FullscreenFeedState state) {
    continueFeedAutoAdvanceAfterPagination(
      cubit: _autoAdvanceCubit,
      snapshot: _autoAdvanceSnapshot(state),
      animateToPage: _animateToPage,
    );
  }

  void _triggerLoadMore() {
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedLoadMoreRequested(),
    );
  }

  /// Publish a feed-tuning signal for the active video and page forward.
  void _onTuned(FeedTuningDirection direction) {
    final bloc = context.read<FullscreenFeedBloc>();
    final video = bloc.state.currentVideo;
    if (video == null) return;
    bloc.add(
      FullscreenFeedTuningSwipeCommitted(
        videoId: video.id,
        direction: direction,
      ),
    );
    final nextIndex = bloc.state.currentIndex + 1;
    if (nextIndex < bloc.state.videos.length) {
      _animateToPage(nextIndex);
    }
  }

  void _showTuningSnackbar(FullscreenFeedTuningAction action) {
    final eventId = action.publishedEventId;
    showFeedTuningSnackbar(
      context,
      direction: action.direction,
      onUndo: eventId == null
          ? null
          : () => _undoTuning(eventId, action.videoId),
    );
  }

  void _undoTuning(String feedTuningEventId, String videoId) {
    // The Undo receipt lives in the app-level ScaffoldMessenger, so it can
    // fire after this screen was popped and its State unmounted — touching
    // `context` then throws a null-check on the dead element. Bail if gone.
    if (!mounted) return;
    final bloc = context.read<FullscreenFeedBloc>()
      ..add(FullscreenFeedTuningUndoRequested(feedTuningEventId));
    final videos = bloc.state.videos;
    for (var i = 0; i < videos.length; i++) {
      if (videos[i].id == videoId) {
        _animateToPage(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refilter the open feed when the blocklist changes broadly (block / mute
    // / account switch / identity adoption / external relay sync). This listen
    // lives in the fullscreen's OWN state — which is mounted whenever the feed
    // is visible — so it survives the launching widget unmounting on a
    // shell-route push (the same reason the `removedIdsStream` bus exists).
    // Broad changes bump `blocklistVersionProvider` but emit no granular
    // removal, so the static-snapshot routes (curated list / liked videos)
    // would otherwise keep showing a blocked author until reopened. See #5041.
    ref.listen<int>(blocklistVersionProvider, (previous, next) {
      if (previous != null && next > previous) {
        context.read<FullscreenFeedBloc>().add(
          const FullscreenFeedBlocklistChanged(),
        );
      }
    });

    // Owned at the screen level so the inline comment composer bar at the
    // bottom of the Scaffold has a single cubit shared across page swipes —
    // re-creating it per-item would lose any in-flight publish during a
    // swipe. Keyed on the comments repository so an auth flip / account
    // switch closes the cubit and a fresh one captures the new repo
    // identity (see `rules/state_management.md`).
    final commentsRepository = ref.watch(commentsRepositoryProvider);

    // Swipe-to-tune is off by default; flip the flag on once the relay
    // allow-lists the kind and the recommendation backend ships.
    final feedTuningEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedTuning),
    );

    return BlocProvider<InlineCommentComposerCubit>(
      key: ValueKey(commentsRepository),
      create: (_) =>
          InlineCommentComposerCubit(commentsRepository: commentsRepository),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _autoAdvanceCubit),
          BlocProvider.value(value: _immersiveCubit),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
              listenWhen: (prev, curr) =>
                  prev.videos.length != curr.videos.length ||
                  prev.isLoadingMore != curr.isLoadingMore ||
                  prev.canLoadMore != curr.canLoadMore,
              listener: (context, state) => _continuePendingAutoAdvance(state),
            ),
            // Open comments sheet once the first video is ready (notification deep-link)
            if (widget.autoOpenComments)
              BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
                listenWhen: (prev, curr) =>
                    prev.currentVideo == null && curr.currentVideo != null,
                listener: (context, state) {
                  final video = state.currentVideo;
                  if (video != null) CommentsScreen.show(context, video);
                },
              ),
            // Dispatch FullscreenFeedVideoUnavailable when the active video's
            // playback status becomes notFound. The BLoC owns the confirm,
            // removal, and dedupe logic — this listener is the screen-level
            // bridge that replaces the per-item post-frame callback.
            BlocListener<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
              listener: (context, state) =>
                  _dispatchVideoUnavailableIfActive(state),
            ),
            // Animate the feed when the BLoC signals a pending skip after a
            // confirmed 404 removal.
            BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
              listenWhen: (prev, curr) =>
                  prev.pendingSkipTarget != curr.pendingSkipTarget &&
                  curr.pendingSkipTarget != null,
              listener: (context, state) {
                final target = state.pendingSkipTarget;
                if (target != null) unawaited(_handlePendingSkip(target));
              },
            ),
            // Pop the route when the last visible video has been removed
            // by deletion (or, soon, block / mute). When `maybePop`
            // returns false (cold deep-link into the fullscreen with no
            // parent route in the stack), the BlocBuilder below renders
            // an explicit `emptyAfterRemoval` branch so the user is not
            // left looking at a perpetual loading spinner.
            BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
              listenWhen: (prev, curr) =>
                  prev.status != curr.status &&
                  curr.status == FullscreenFeedStatus.emptyAfterRemoval,
              listener: (context, _) {
                // Embedded video mode: hand back to the parent (grid) instead
                // of popping the whole route, matching the app-bar back button.
                final onBack = widget.onBack;
                if (onBack != null) {
                  onBack();
                  return;
                }
                Navigator.of(context).maybePop();
              },
            ),
            // Show an Undo snackbar after a feed-tuning swipe commits.
            BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
              listenWhen: (prev, curr) =>
                  prev.lastTuningAction != curr.lastTuningAction &&
                  curr.lastTuningAction != null,
              listener: (context, state) {
                final action = state.lastTuningAction;
                if (action != null) _showTuningSnackbar(action);
              },
            ),
          ],
          child: BlocBuilder<FullscreenFeedBloc, FullscreenFeedState>(
            builder: (context, state) {
              // The BlocListener above tries to pop on this status; when
              // it can (parent route exists) the route is gone before this
              // branch renders. When `maybePop` is a no-op, we land here
              // and show an explicit empty-state with a back button rather
              // than the loading spinner below.
              if (state.status == FullscreenFeedStatus.emptyAfterRemoval) {
                return Scaffold(
                  backgroundColor: context.vineColors.background,
                  appBar: DiVineAppBar(
                    title: widget.contextTitle ?? '',
                    showBackButton: true,
                    // The BlocListener above already tried `maybePop` and
                    // failed (otherwise we wouldn't be rendering this
                    // branch), so this back button is the only way out.
                    onBackPressed: () => _handleBack(context),
                    backgroundMode: DiVineAppBarBackgroundMode.transparent,
                    forceMaterialTransparency: true,
                  ),
                  body: Center(
                    child: Text(
                      context.l10n.fullscreenFeedRemovedMessage,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ),
                );
              }

              // The feed drained after having had videos, so no further
              // emit is coming. Rendering the loading placeholder here left
              // the route stuck on a spinner with no video, no action
              // buttons and no explanation — see #6949.
              if (state.status == FullscreenFeedStatus.empty) {
                return Scaffold(
                  backgroundColor: context.vineColors.background,
                  appBar: DiVineAppBar(
                    title: widget.contextTitle ?? '',
                    showBackButton: true,
                    onBackPressed: () => _handleBack(context),
                    backgroundMode: DiVineAppBarBackgroundMode.transparent,
                    forceMaterialTransparency: true,
                  ),
                  body: Center(
                    child: Semantics(
                      identifier: SemanticIds.fullscreenFeedEmpty,
                      child: Text(
                        context.l10n.fullscreenFeedEmptyMessage,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (state.status == FullscreenFeedStatus.initial ||
                  !state.hasVideos) {
                return Scaffold(
                  backgroundColor: context.vineColors.background,
                  appBar: DiVineAppBar(
                    title: widget.contextTitle ?? '',
                    showBackButton: true,
                    onBackPressed: () => _handleBack(context),
                    backgroundMode: DiVineAppBarBackgroundMode.transparent,
                    forceMaterialTransparency: true,
                  ),
                  body: Semantics(
                    identifier: SemanticIds.fullscreenFeedLoading,
                    child: const Center(
                      child: BrandedLoadingIndicator(size: 60),
                    ),
                  ),
                );
              }

              final authService = ref.watch(authServiceProvider);
              final currentUserPubkey = authService.currentPublicKeyHex;

              // The inline comment composer bar sits at the bottom of the
              // Scaffold body (inside a Column with `Expanded(child:
              // feed)`) whenever there's an active video AND a signed-in
              // user. The bar lives in the body — NOT in
              // `Scaffold.bottomNavigationBar` — because Scaffold pins
              // bottomNavigationBar to `size.height - barHeight` and does
              // not push it above the keyboard. Putting the bar inside the
              // body lets `resizeToAvoidBottomInset` shrink the body when the
              // keyboard opens, which slides the bar up with it — which is
              // why that flag is gated on [_ownComposerFocused] (true while
              // this bar or the DM reply bar is focused). The feed's
              // MediaQuery is intentionally
              // left untouched: the home feed's overlays sit at
              // `bottom: 20 + viewPadding.bottom (= 34) = 54` above the
              // nav bar, and the fullscreen overlays use the same formula
              // so the action column / author info land at the same gap
              // above the comment bar. The bar's own `SafeArea`-style
              // padding handles the home-indicator visually.
              // When the reel is opened FROM a DM, only the private DM reply
              // bar is shown — the public comment composer is suppressed so a
              // private-context reply can't be mistaken for (or accidentally
              // posted as) a public comment. Public commenting is still one
              // tap away via the right-rail comment button. Matches TikTok/IG.
              final showCommentBar =
                  widget.dmReplyContext == null &&
                  currentUserPubkey != null &&
                  state.currentVideo != null;

              final showDmReplyBar =
                  widget.dmReplyContext != null &&
                  currentUserPubkey != null &&
                  state.currentVideo != null;

              final appBarStyle = DiVineAppBarStyle.overMediaStyle.copyWith(
                horizontalPadding: 12,
                // With the default 48 px icon button and 12 px
                // [horizontalPadding], a 72 px leading slot leaves
                // 12 px between the back button's right edge and
                // the title text (72 − 12 − 48 = 12).
                leadingWidth: 72,
                // Figma `title/medium` token (Bricolage Grotesque
                // 800, 16 / 24 / 0.15) — overrides the default
                // [VineTheme.titleLargeFont] (22) used by the
                // shared app bar.
                titleStyle: VineTheme.titleMediumFont(
                  color: VineTheme.whiteText,
                ),
              );
              final appBar = DiVineAppBar(
                title: widget.contextTitle ?? '',
                showBackButton: true,
                onBackPressed: () => _handleBack(context),
                backgroundMode: DiVineAppBarBackgroundMode.transparent,
                forceMaterialTransparency: true,
                // This bar really does sit on the player, unlike the
                // transparent bars over themed pages, so it opts into the
                // fixed white treatment and light status-bar icons.
                systemOverlayStyle: VineTheme.statusBarStyle,
                // Stretch the back-button tap target to the full
                // leading slot. The fullscreen feed sits over playing
                // video so a small icon hit-target is easy to miss.
                expandLeadingHitArea: true,
                customActions: [FeedSettingsMenu(video: state.currentVideo)],
                style: appBarStyle,
              );

              return Scaffold(
                // Only resize for a keyboard that one of OUR OWN bottom
                // composers opened (inline comment bar, DM reply bar). A
                // keyboard owned by a modal on top — most importantly the
                // share sheet's message field — must NOT shrink this Scaffold,
                // because that re-lays-out the full-screen reel + overlay every
                // keyboard frame and janks on older devices (#5758). See
                // [_ownComposerFocused].
                resizeToAvoidBottomInset: _ownComposerFocused,
                // Paint the Scaffold with [VineTheme.surfaceBackground]
                // (`#00150D`, the same green the comment bar uses).
                // This is what shows wherever the Scaffold body leaks
                // around its content — most importantly the strip
                // below the soft keyboard (above the home indicator)
                // and the device's curved-corner cutouts at the
                // bottom edges. Keeping it green continues the comment
                // bar's surface visually around the keyboard. The
                // video item's own [ColoredBox] paints
                // [VineTheme.surfaceContainerHigh] on top of this so
                // the video area itself reads as a darker canvas.
                backgroundColor: context.vineColors.surface,
                // Always edge-to-edge: the video fills the screen and the
                // (transparent) AppBar overlays it, matching the home feed.
                // 1 × 1 / landscape / dimensions-less videos are rendered
                // with `BoxFit.contain`, so their letterbox bars sit on
                // the [VineTheme.surfaceContainerHigh] above — the
                // transparent AppBar reads cleanly against that surface
                // colour, no carve-out needed.
                extendBodyBehindAppBar: true,
                // Wrap the AppBar in a [TextFieldTapRegion] so taps on
                // the back button / title / [FeedSettingsMenu] popover
                // trigger don't dismiss the inline composer's keyboard.
                // That lets users toggle playback (mute, captions, ...)
                // mid-comment without losing what they're typing.
                // [TapRegion] is independent of the gesture arena, so
                // the back button and the More popover still fire their
                // own handlers — only the "tap outside" unfocus
                // callback is suppressed for taps inside this region.
                // The popover's pill content is wrapped in its own
                // [TextFieldTapRegion] inside [_FeedSettingsOverlay] so
                // taps on the playback controls (which render outside
                // this widget tree via [OverlayPortal]) are covered too.
                // [FeedImmersiveChrome] fades the bar out while the viewer
                // holds the video, matching the per-item overlay below. The
                // slot keeps its height either way, which is what the
                // already-`extendBodyBehindAppBar` body expects.
                appBar: PreferredSize(
                  preferredSize: appBar.preferredSize,
                  child: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: FeedImmersiveChrome(
                      child: TextFieldTapRegion(child: appBar),
                    ),
                  ),
                ),
                body: Stack(
                  children: [
                    Semantics(
                      sortKey: const OrdinalSortKey(2),
                      child: Column(
                        children: [
                          Expanded(
                            // Match the home feed: when the comment bar is on
                            // screen, the video carries the same rounded
                            // bottom corners as `video_feed_page.dart`, so
                            // the corners reveal the semantic nav surface (the
                            // outer color [NavRoundedShell] paints). It
                            // shares its hex (`#00150D`) with the comment
                            // bar's [VineTheme.surfaceBackground], so the
                            // rounded cutouts seam continuously into the bar.
                            child: Stack(
                              children: [
                                FeedTuningSwipeGate(
                                  enabled: feedTuningEnabled,
                                  onTuned: _onTuned,
                                  child: VideoTapShield(
                                    child: _MaybeRoundFeedBottom(
                                      roundCorners: showCommentBar,
                                      child: MediaQuery.removePadding(
                                        context: context,
                                        removeBottom: true,
                                        child: FeedVideos(
                                          key: _feedVideosKey,
                                          // Pause the reel while the DM reply composer
                                          // is focused so it doesn't play under the
                                          // keyboard.
                                          isActive: !_replyComposerFocused,
                                          videos: state.videos,
                                          contextTitle: widget.contextTitle,
                                          currentIndex: state.currentIndex,
                                          hasMore: state.canLoadMore,
                                          isLoadingMore: state.isLoadingMore,
                                          trafficSource: widget.trafficSource,
                                          sourceDetail: widget.sourceDetail,
                                          onActiveVideoChanged: (video, index) {
                                            ref
                                                .read(
                                                  foregroundFeedActivityGateProvider,
                                                )
                                                .markActive();
                                            _resumeAutoAdvanceAfterSwipe();
                                            ref
                                                .read(
                                                  feedPerformanceTrackerProvider,
                                                )
                                                .startVideoSwipeTracking(
                                                  video.id,
                                                );
                                            context
                                                .read<FullscreenFeedBloc>()
                                                .add(
                                                  FullscreenFeedIndexChanged(
                                                    index,
                                                  ),
                                                );
                                            widget.onPageChanged?.call(index);
                                          },
                                          onNearEnd: () {
                                            if (state.canLoadMore) {
                                              _triggerLoadMore();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 16,
                                  child: LoadingMorePill(
                                    isVisible:
                                        state.isLoadingMore &&
                                        state.currentIndex >=
                                            state.videos.length - 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showCommentBar)
                            InlineCommentComposerBar(
                              onFocusChanged: (focused) {
                                if (mounted &&
                                    focused != _inlineComposerFocused) {
                                  setState(
                                    () => _inlineComposerFocused = focused,
                                  );
                                }
                              },
                            ),
                          if (showDmReplyBar)
                            ReelReplyBridge(
                              setComposerFocused: (focused) {
                                if (mounted &&
                                    focused != _replyComposerFocused) {
                                  setState(
                                    () => _replyComposerFocused = focused,
                                  );
                                }
                              },
                              playReaction: (emoji) {
                                if (mounted) {
                                  setState(() {
                                    _reactionEmoji = emoji;
                                    _reactionNonce++;
                                  });
                                }
                              },
                              child: ReelDmReplyBarHost(
                                dmReplyContext: widget.dmReplyContext!,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Deliberately not wrapped in [FeedImmersiveChrome]: every
                    // other chrome layer fades while the viewer holds the
                    // video, but a commercial disclosure has to stay up for
                    // the whole reel. It keeps the app bar's slot height as
                    // its offset even once that bar has faded, so the pill
                    // does not jump when immersive mode toggles.
                    if (widget.sponsorName case final sponsorName?)
                      PositionedDirectional(
                        top:
                            MediaQuery.paddingOf(context).top +
                            (appBar.preferredSize.height -
                                    FullscreenSponsorDisclosure.singleLineHeight(
                                      context,
                                    )) /
                                2,
                        start: _sponsorDisclosureStartInset(
                          context,
                          appBarStyle,
                        ),
                        end: _sponsorDisclosureEndInset(context, appBarStyle),
                        child: IgnorePointer(
                          child: Semantics(
                            sortKey: const OrdinalSortKey(1),
                            child: FullscreenSponsorDisclosure(
                              sponsorName: sponsorName,
                            ),
                          ),
                        ),
                      ),
                    // Full-screen TikTok/IG-style reaction pop, centered over
                    // the reel.
                    if (_reactionEmoji != null)
                      Positioned.fill(
                        child: ReactionOverlay(
                          key: ValueKey(_reactionNonce),
                          emoji: _reactionEmoji!,
                          onComplete: () {
                            if (mounted) {
                              setState(() => _reactionEmoji = null);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wraps the fullscreen video feed in a [NavRoundedShell] when the
/// inline comment composer bar is on screen, so the bottom of the
/// video carries the same rounded-corner treatment as the home feed.
/// Without the bar there's nothing to seam into, so the shell is
/// skipped and the feed renders edge-to-edge.
class _MaybeRoundFeedBottom extends StatelessWidget {
  const _MaybeRoundFeedBottom({
    required this.roundCorners,
    required this.child,
  });

  final bool roundCorners;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!roundCorners) return child;
    // Inside the rounded shell, paint
    // [VineTheme.surfaceContainerHigh] (`#000A06`) — a near-black with
    // a faint green tint. That's the canvas around contain-fit videos
    // (1 × 1 classics, landscape, anything without dimensions
    // metadata) which leave letterbox bands the user can see. The
    // shell's outer colour is the semantic nav surface (the color
    // [NavRoundedShell] paints by construction); it shares its hex
    // (`#00150D`) with the comment bar's [VineTheme.surfaceBackground],
    // so the rounded bottom corners reveal a colour that seams
    // continuously into the bar.
    return NavRoundedShell(
      innerColor: context.vineColors.surfaceContainerHigh,
      child: child,
    );
  }
}

/// Bottom-center pill shown while the fullscreen feed is fetching the
/// next page of videos and the user is already on the last item.
/// Hidden (with a short fade) otherwise so it doesn't sit on top of
/// the video chrome during normal scrolling.
@visibleForTesting
class LoadingMorePill extends StatelessWidget {
  @visibleForTesting
  const LoadingMorePill({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1 : 0,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.surfaceBackground.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  // The label beside it already announces the wait.
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: ExcludeSemantics(
                      child: BrandedLoadingIndicator(size: 16),
                    ),
                  ),
                  Text(
                    context.l10n.feedLoadingMore,
                    style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps the video feed so that taps on the video are *consumed*
/// while a text input on this screen has primary focus.
///
/// Without this shield, tapping outside the inline comment composer's
/// text field while the keyboard is up both (a) dismisses the
/// keyboard — the intended effect — and (b) reaches the video's
/// play / pause gesture recognizer underneath, toggling playback as
/// a side-effect of typing.
///
/// The fix is layered:
///
/// * The shield's `GestureDetector(behavior: opaque)` claims the tap
///   in the gesture arena, so the video's recognizer never sees it.
/// * Keyboard dismissal still happens because [TextField.onTapOutside]
///   is wired through [TapRegion] / `TapRegionSurface`, which reads
///   pointer events at the surface level *independent* of the
///   gesture arena — so the claim above does not prevent the
///   onTapOutside callback from firing on the inline composer.
///
/// The shield only mounts the overlay while a text input has primary
/// focus, so it's a passthrough on the steady-state feed.
@visibleForTesting
class VideoTapShield extends StatefulWidget {
  @visibleForTesting
  const VideoTapShield({required this.child, super.key});

  final Widget child;

  @override
  State<VideoTapShield> createState() => _VideoTapShieldState();
}

class _VideoTapShieldState extends State<VideoTapShield> {
  bool _textInputFocused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    // Sync initial state in case a text input is already focused
    // when this widget mounts (rare — e.g. screen recreated mid-
    // composition).
    _onFocusChanged();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final focused = _primaryFocusIsTextInput();
    if (focused == _textInputFocused) return;
    setState(() => _textInputFocused = focused);
  }

  /// Mirror the check used by [KeyboardAwareTopFade] /
  /// `_primaryFocusIsTextInput` over in this file's other helpers:
  /// the primary focus is "text input" iff its FocusNode's context
  /// has an [EditableText] ancestor (the widget that actually owns
  /// the platform TextInput connection).
  static bool _primaryFocusIsTextInput() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_textInputFocused)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Empty handler — see class docstring. The GD's job
              // is to claim the tap so the video's play / pause
              // recognizer never sees it; keyboard dismissal is
              // delivered by the composer's onTapOutside via
              // TapRegionSurface.
              onTap: () {},
            ),
          ),
      ],
    );
  }
}

/// Wraps the right-side action column so that its top fades to
/// transparent while the soft keyboard is on screen.
///
/// When the inline comment composer pulls the keyboard up,
/// [Scaffold.resizeToAvoidBottomInset] shrinks the body and the action
/// column slides up toward the transparent app bar — the Like button
/// can end up sitting under the More popover and the back button. The
/// [ShaderMask] erases the top of the column with a [BlendMode.dstIn]
/// gradient: fully transparent through the top 20 %, then a linear
/// fade to fully opaque at the bottom edge. The mask snaps on when
/// the keyboard begins to show, and fades out linearly over 100 ms
/// the moment the keyboard begins to hide, then drops the ShaderMask
/// wrapper entirely so the steady-state feed doesn't carry a save
/// layer.
///
/// The trigger is the *direction* of `viewInsets.bottom`, not whether
/// it's zero. On iOS and Android the platform animates the keyboard
/// inset over the OS's own animation curve (~250 ms) and Flutter
/// fires [WidgetsBindingObserver.didChangeMetrics] each frame.
/// "First decrease after a steady non-zero" is the start of the hide
/// animation, "first rise from zero" is the start of the show
/// animation — that lines the column fade up with the platform
/// keyboard animation in parallel rather than running it sequentially
/// after the keyboard is already gone.
///
/// Focus alone isn't a usable signal: on macOS / desktop a text
/// input can take focus by click without the platform keyboard ever
/// appearing, so a focus-driven mask would activate when the column
/// hasn't actually slid up.
///
/// We read the inset off the [FlutterView] rather than `MediaQuery`
/// because Scaffold's `resizeToAvoidBottomInset: true` strips
/// `viewInsets.bottom` from the body's MediaQuery (the body has
/// already shrunk to avoid the keyboard, so "the body shouldn't need
/// to know").
@visibleForTesting
class KeyboardAwareTopFade extends StatefulWidget {
  @visibleForTesting
  const KeyboardAwareTopFade({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardAwareTopFade> createState() => _KeyboardAwareTopFadeState();
}

class _KeyboardAwareTopFadeState extends State<KeyboardAwareTopFade>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Linear fade-out applied to the mask when the keyboard begins to
  /// hide. Picked to overlap the platform keyboard's dismiss
  /// animation (~250 ms) — the column is fully unmasked well before
  /// the keyboard finishes sliding off-screen. The fade-in is
  /// instantaneous because the AppBar collision happens immediately
  /// as the column slides up.
  static const Duration _fadeOutDuration = Duration(milliseconds: 100);

  /// Last sampled keyboard inset, used to infer the direction of
  /// change between [didChangeMetrics] frames.
  double _lastInset = 0;

  /// Whether the keyboard is currently visible (or animating in).
  /// Flips back to `false` the moment the inset starts decreasing
  /// from a non-zero value.
  bool _keyboardVisible = false;

  late final AnimationController _maskStrength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maskStrength = AnimationController(
      vsync: this,
      duration: _fadeOutDuration,
      value: 0,
    )..addStatusListener(_onMaskStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync initial state in case the keyboard is already up when
    // this widget mounts (rare — screen recreated mid-animation).
    final inset = View.of(context).viewInsets.bottom;
    if (inset > 0 && !_keyboardVisible) {
      _lastInset = inset;
      _keyboardVisible = true;
      _maskStrength.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maskStrength
      ..removeStatusListener(_onMaskStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    final previous = _lastInset;
    _lastInset = inset;

    if (_keyboardVisible) {
      // Already up — only react to the first decrease, which is the
      // start of the hide animation. Subsequent decreasing frames
      // during the same animation no-op.
      if (inset < previous) {
        setState(() => _keyboardVisible = false);
        _maskStrength.reverse();
      }
    } else {
      // Hidden — any rise from a lower value into the positive range
      // is the start of the show animation. Snap the mask on so the
      // column is masked by the time it finishes sliding up.
      if (inset > previous && inset > 0) {
        setState(() => _keyboardVisible = true);
        _maskStrength.value = 1;
      }
    }
  }

  void _onMaskStatusChanged(AnimationStatus status) {
    // Drop the ShaderMask wrapper once the fade-out completes so the
    // steady-state feed isn't paying for an idle save layer.
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_maskStrength.value == 0) return widget.child;

    return AnimatedBuilder(
      animation: _maskStrength,
      child: widget.child,
      builder: (context, child) {
        // Only the alpha matters with BlendMode.dstIn. Interpolating the
        // top stop between opaque-white (no fade) and transparent
        // (full fade) lets a single animation value drive the strength
        // of the mask without changing the gradient shape.
        final topColor = Color.lerp(
          VineTheme.whiteText,
          Colors.transparent,
          _maskStrength.value,
        )!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, VineTheme.whiteText],
              stops: const [0.2, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
