import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_tuning_snackbar.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_empty_widget.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_error_widget.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/feed_tuning/feed_tuning_swipe_overlay.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';

class VideoFeedPage extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => RoutePaths.videoFeedForIndex(index);

  const VideoFeedPage({
    this.initialMode = FeedMode.forYou,
    this.initialIndex = 0,
    super.key,
  });

  /// The feed mode to start with. Defaults to [FeedMode.forYou].
  final FeedMode initialMode;

  /// The video index restored from the Home route or last-tab position.
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(divineHostFilterVersionProvider);
    final contentFilterVersion = ref.watch(contentFilterVersionProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final showDivineHostedOnly = ref
        .read(divineHostFilterServiceProvider)
        .showDivineHostedOnly;

    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final feedTuningRepository = ref.watch(feedTuningRepositoryProvider);
    final enrichmentAttemptTracker = NostrTagEnrichmentAttemptTracker();

    return MultiBlocProvider(
      key: ValueKey('video-feed-$showDivineHostedOnly-$contentFilterVersion'),
      providers: [
        BlocProvider(
          create: (_) => VideoFeedBloc(
            videosRepository: videosRepository,
            followRepository: followRepository,
            curatedListRepository: curatedListRepository,
            profileRepository: profileRepository,
            contentBlocklistRepository: blocklistRepository,
            userPubkey: authService.currentPublicKeyHex,
            sharedPreferences: sharedPreferences,
            // Cached-feed serving stays on (constructor default) regardless of
            // the Divine-hosted-only filter: applyContentPreferences re-filters
            // on read and the splice-on-refresh keeps the post-active tail
            // fresh, so the cached serve is never stale to the viewer.
            feedTracker: ref.read(feedPerformanceTrackerProvider),
            feedTuningRepository: feedTuningRepository,
            enrichVideos: (videos) => enrichVideosWithNostrTags(
              videos,
              nostrService: ref.read(nostrServiceProvider),
              callerName: 'VideoFeedBloc',
              attemptTracker: enrichmentAttemptTracker,
            ),
          )..add(VideoFeedStarted(mode: initialMode)),
        ),
        BlocProvider(
          create: (_) => VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () => ref
                .read(mediaAuthInterceptorProvider)
                .canAutoAuthorizeAdultMedia(),
          ),
        ),
      ],
      child: VideoFeedView(initialIndex: initialIndex),
    );
  }
}

@visibleForTesting
class VideoFeedView extends ConsumerStatefulWidget {
  const VideoFeedView({this.initialIndex = 0, super.key});

  /// The video index to show when the feed first mounts.
  final int initialIndex;

  @override
  ConsumerState<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<VideoFeedView>
    with WidgetsBindingObserver {
  /// Tracks whether the new native player feed should be active.
  ///
  /// Drives [FeedVideos] pause/resume on tab switches, route pushes, and
  /// overlay open/close. Kept in sync by [_syncFeedActive].
  bool _isNewFeedActive = true;

  /// Guards so startup milestones fire only once.
  bool _hasMarkedUIReady = false;
  bool _hasMarkedVideoReady = false;

  /// Whether the app has actually been backgrounded since the last resume.
  ///
  /// The launch `resumed` lifecycle event would otherwise trigger an
  /// auto-refresh that wipes the just-served cached feed and resets the
  /// resume index back to the first video. Only a genuine background →
  /// foreground transition should auto-refresh.
  bool _wasBackgrounded = false;

  /// Tracks the current fractional page position for scroll-driven overlay opacity.
  late final ValueNotifier<double> _pagePosition;

  /// Tracks the active Home video without forcing route updates while swiping.
  late int _currentIndex;

  final _feedVideosKey = GlobalKey<FeedVideosState>();
  int? _pendingTuningAutoAdvanceIndex;

  /// Feed-scoped Auto playback state. Owned by this state so tests can drive
  /// the screen without also wiring the cubit externally; exposed to children
  /// via `BlocProvider.value` in [build] so the rail control and feed items
  /// can observe/read it.
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();

  /// Feed-scoped immersive (hold-to-peek) state. Owned here so it sits above
  /// both [FeedVideos] — which raises it on a long press — and
  /// [FeedModeSwitch], which fades out against it.
  final FeedImmersiveCubit _immersiveCubit = FeedImmersiveCubit();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _pagePosition = ValueNotifier<double>(_currentIndex.toDouble());
    WidgetsBinding.instance.addObserver(this);
    // Seed playback from the current signals once mounted, in case this view is
    // first built on a non-home route (e.g. a deep link) where no later change
    // fires the [build] listeners. Deferred so the providers can resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFeedActive());
  }

  int _clampIndexForItemCount(int index, int itemCount) {
    if (itemCount == 0) return 0;
    return index.clamp(0, itemCount - 1);
  }

  @override
  void dispose() {
    _pagePosition.dispose();
    unawaited(_autoAdvanceCubit.close());
    unawaited(_immersiveCubit.close());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      // A hold in progress ends here whether or not the platform delivers a
      // pointer cancel. Without this, a touch lost to backgrounding leaves
      // the item's pointer set non-empty, and that item can never lower the
      // flag again — the header and app bar would stay hidden for the life
      // of the page.
      _immersiveCubit.exit();
      return;
    }
    // Only auto-refresh on a genuine background → foreground transition. The
    // spurious `resumed` event during cold start must not fire, or it would
    // wipe the just-served cached feed and reset the resume index.
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  void _animateToPage(int index) {
    final feedVideosState = _feedVideosKey.currentState;
    if (feedVideosState != null) {
      unawaited(feedVideosState.animateToPage(index));
    }
  }

  /// Publish a feed-tuning signal for the active home-feed video and page
  /// forward.
  void _onTuned(FeedTuningDirection direction) {
    final bloc = context.read<VideoFeedBloc>();
    final videos = bloc.state.videos;
    if (_currentIndex < 0 || _currentIndex >= videos.length) return;
    final video = videos[_currentIndex];

    bloc.add(
      VideoFeedTuningSwipeCommitted(videoId: video.id, direction: direction),
    );

    final nextIndex = _currentIndex + 1;
    if (nextIndex < videos.length) {
      _pendingTuningAutoAdvanceIndex = nextIndex;
      _animateToPage(nextIndex);
    }
  }

  void _showTuningSnackbar(VideoFeedTuningAction action) {
    final eventId = action.publishedEventId;
    showFeedTuningSnackbar(
      context,
      direction: action.direction,
      onUndo: eventId == null
          ? null
          : () => _undoTuning(eventId, action.videoId),
    );
  }

  void _dismissTuningSnackbar() {
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
  }

  void _undoTuning(String feedTuningEventId, String videoId) {
    // The Undo receipt lives in the app-level ScaffoldMessenger, so it can
    // fire after this screen was popped and its State unmounted — touching
    // `context` then throws a null-check on the dead element. Bail if gone.
    if (!mounted) return;
    final bloc = context.read<VideoFeedBloc>()
      ..add(VideoFeedTuningUndoRequested(feedTuningEventId));
    final videos = bloc.state.videos;
    for (var i = 0; i < videos.length; i++) {
      if (videos[i].id == videoId) {
        _animateToPage(i);
        return;
      }
    }
  }

  /// Recomputes whether the home feed should be playing and updates
  /// [_isNewFeedActive] if it changed. The feed is active only when the home
  /// route is current, nothing is pushed over the shell, and no overlay is
  /// open. See the listeners in [build] for the rationale.
  void _syncFeedActive() {
    if (!mounted) return;
    // Home is the first bottom-nav branch (index 0). Use the authoritative
    // active-branch index (set by AppShell from navigationShell) rather than
    // the URL-derived route: the latter can lag on web for StatefulShellRoute
    // branch switches, which left the feed playing on other tabs there.
    final isHomeRoute = ref.read(activeBranchIndexProvider) == 0;
    final isObscured = ref.read(shellObscuredProvider);
    final hasOverlay = ref.read(overlayVisibilityProvider).hasVisibleOverlay;

    final shouldBeActive = isHomeRoute && !isObscured && !hasOverlay;
    if (shouldBeActive == _isNewFeedActive) return;
    setState(() => _isNewFeedActive = shouldBeActive);
  }

  @override
  Widget build(BuildContext context) {
    // The home feed plays only while it is the visible top-level screen: the
    // home route is current, no full-screen route covers the shell, and no
    // overlay (page/bottom sheet) is open. Each signal lives in its own
    // provider, so re-evaluate playback whenever any of them changes. Some
    // pushed routes keep this widget mounted, so playback must follow these
    // signals instead of assuming disposal handles every transition.
    //
    // Uses activeBranchIndexProvider (the authoritative active tab from
    // navigationShell), NOT pageContextProvider: inside the StatefulShellRoute
    // home branch the latter is scoped to "home" and never flips when the tab
    // is backgrounded, and the URL-derived route can lag on web — both would
    // leave the feed playing on other tabs. [shellObscuredProvider] — driven by
    // AppShell's RouteAware subscription to the root navigator — covers the
    // orthogonal case where a full-screen route covers the shell (e.g. profile
    // → fullscreen video → pop back to profile), which the active tab alone
    // cannot detect.
    ref.listen(activeBranchIndexProvider, (_, _) => _syncFeedActive());
    ref.listen(shellObscuredProvider, (_, _) => _syncFeedActive());
    ref.listen(overlayVisibilityProvider, (_, _) => _syncFeedActive());

    // Refresh feed when blocklist changes (block from profile, DM, or relay).
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<VideoFeedBloc>().add(const VideoFeedBlocklistChanged());
      }
    });

    // Comments/Share bottom sheets pause the current player but keep the
    // neighbours and disk prefetch warm for instant resume
    // ([OverlayVisibilityState.shouldRetainPlayer]). Only a real backgrounding
    // — tab switch, pushed route, or a full-screen page overlay — releases the
    // off-screen players. Watched (not read) so the flag stays coherent with
    // the overlay state across rebuilds.
    final shouldRetainPlayer = ref
        .watch(overlayVisibilityProvider)
        .shouldRetainPlayer;
    final feedTuningEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedTuning),
    );
    final retapCubit = _maybeRetapCubit(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Video runs full-bleed under the status bar here, so its icons stay
      // light in both appearance modes — the app-level style in main.dart
      // follows the palette and would turn them dark on a light theme.
      value: VineTheme.statusBarStyle,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _autoAdvanceCubit),
          BlocProvider.value(value: _immersiveCubit),
        ],
        child: NavRoundedShell(
          innerColor: context.vineColors.background,
          child: MultiBlocListener(
            listeners: [
              // Refresh and scroll to top when the user re-taps the home tab
              // while already on it (TikTok-style). VineBottomNav flips the
              // cubit to refreshing; [_onHomeRetap] settles it again. Skipped
              // when no cubit is provided (direct construction in tests).
              if (retapCubit != null)
                BlocListener<HomeFeedRetapCubit, HomeFeedRetapState>(
                  bloc: retapCubit,
                  listenWhen: (previous, current) =>
                      !previous.isRefreshing && current.isRefreshing,
                  listener: (context, _) => _onHomeRetap(context, retapCubit),
                ),
              // Reset page position when mode changes.
              BlocListener<VideoFeedBloc, VideoFeedBlocState>(
                listenWhen: (previous, current) =>
                    previous.mode != current.mode,
                listener: (_, _) {
                  _currentIndex = 0;
                  _pagePosition.value = 0;
                  ref
                      .read(lastTabPositionProvider.notifier)
                      .recordPosition(RouteType.home, 0);
                },
              ),
              // Seed the page position from the BLoC's restored index (cold-start
              // resume / mode switch). Runs before the builder, so [FeedVideos]
              // mounts at the right page. Echoes of the user's own swipe are
              // ignored because [_currentIndex] already matches.
              BlocListener<VideoFeedBloc, VideoFeedBlocState>(
                listenWhen: (previous, current) =>
                    previous.currentIndex != current.currentIndex,
                listener: (_, state) {
                  if (state.currentIndex == _currentIndex) return;
                  _currentIndex = state.currentIndex;
                  _pagePosition.value = state.currentIndex.toDouble();
                },
              ),
              // Mark UI ready when videos first become available.
              BlocListener<VideoFeedBloc, VideoFeedBlocState>(
                listenWhen: (previous, current) =>
                    !previous.isLoaded &&
                    current.isLoaded &&
                    current.videos.isNotEmpty,
                listener: (_, _) {
                  if (!_hasMarkedUIReady) {
                    _hasMarkedUIReady = true;
                    ref.read(startupPerformanceServiceProvider).markUIReady();
                  }
                },
              ),
              BlocListener<VideoFeedBloc, VideoFeedBlocState>(
                listenWhen: (previous, current) =>
                    previous.lastTuningAction != current.lastTuningAction &&
                    current.lastTuningAction != null,
                listener: (context, state) {
                  final action = state.lastTuningAction;
                  if (action != null) _showTuningSnackbar(action);
                },
              ),
            ],
            child: BlocBuilder<VideoFeedBloc, VideoFeedBlocState>(
              // The builder renders from the widget's own [_currentIndex], never
              // [state.currentIndex], so a per-swipe index emit must not rebuild
              // the whole feed. Rebuild only when some other field changed.
              buildWhen: (previous, current) =>
                  current !=
                  previous.copyWith(currentIndex: current.currentIndex),
              builder: (context, state) {
                final itemCount = state.videos.length;
                final clampedIndex = _clampIndexForItemCount(
                  _currentIndex,
                  itemCount,
                );
                if (clampedIndex != _currentIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_currentIndex >= 0 && _currentIndex < itemCount) return;
                    final normalized = _clampIndexForItemCount(
                      _currentIndex,
                      itemCount,
                    );
                    if (_currentIndex == normalized) return;
                    _currentIndex = normalized;
                    _pagePosition.value = normalized.toDouble();
                    ref
                        .read(lastTabPositionProvider.notifier)
                        .recordPosition(RouteType.home, normalized);
                  });
                }

                // Loading state (including initial state before first load)
                if (state.isLoading) {
                  return const Center(child: BrandedLoadingIndicator());
                }

                // Error state
                if (state.status == VideoFeedStatus.failure) {
                  return FeedErrorWidget(onRetry: () => _refreshFeed(context));
                }

                // Empty state
                if (state.isEmpty) {
                  return Stack(
                    children: [
                      FeedEmptyWidget(state: state),
                      const FeedModeSwitch(),
                    ],
                  );
                }

                // Pull-to-refresh: a [RefreshIndicator] wraps the feed and
                // listens for overscroll notifications from the inner
                // [PageView]. The default predicate (depth == 0) restricts the
                // gesture to the outermost scrollable, so inner overlay
                // scrollables can't trigger a refresh.
                // The video overlay positions its author block and action
                // column against `viewPadding.bottom`.
                // [_KeyboardStableBottomInset] holds that inset steady while the
                // share sheet's keyboard is open, so the overlay does not slide
                // when the keyboard closes (#5758 follow-up).
                return RefreshIndicator(
                  color: VineTheme.onPrimary,
                  backgroundColor: VineTheme.vineGreen,
                  onRefresh: () => _refreshFeed(context),
                  child: _KeyboardStableBottomInset(
                    child: Stack(
                      children: [
                        FeedTuningSwipeGate(
                          enabled: feedTuningEnabled,
                          onTuned: _onTuned,
                          child: FeedVideos(
                            key: _feedVideosKey,
                            videos: state.videos,
                            contextTitle: state.feedContextTitle,
                            currentIndex: clampedIndex,
                            isActive: _isNewFeedActive,
                            // The home feed stays mounted across tab switches and
                            // pushed routes (StatefulShellRoute keep-alive), so
                            // release the off-screen neighbour players and pause
                            // disk prefetch while it is backgrounded. Bottom sheets
                            // (comments/share) only pause the current player — they
                            // keep neighbours and prefetch warm via
                            // shouldRetainPlayer.
                            releaseNeighboursWhenInactive: !shouldRetainPlayer,
                            hasMore: state.hasMore,
                            isLoadingMore: state.isLoadingMore,
                            trafficSource: ViewTrafficSource.home,
                            // Every feed mode renders through this one page and
                            // reports source=home, so without this detail the
                            // For You, following, list, new and classic feeds
                            // are indistinguishable in view_traffic_sources.
                            sourceDetail: state.source.type.analyticsTag,
                            onActiveVideoChanged: (video, index) {
                              final isTuningAutoAdvance =
                                  _pendingTuningAutoAdvanceIndex == index;
                              _pendingTuningAutoAdvanceIndex = null;
                              if (!isTuningAutoAdvance) {
                                _dismissTuningSnackbar();
                              }
                              ref
                                  .read(foregroundFeedActivityGateProvider)
                                  .markActive();
                              _currentIndex = index;
                              context.read<VideoFeedBloc>().add(
                                VideoFeedActiveIndexChanged(index),
                              );
                              ref
                                  .read(lastTabPositionProvider.notifier)
                                  .recordPosition(RouteType.home, index);
                              _resumeAutoAdvanceAfterSwipe();
                              ref
                                  .read(feedPerformanceTrackerProvider)
                                  .startVideoSwipeTracking(
                                    video.id,
                                  );
                              if (!_hasMarkedVideoReady && index == 0) {
                                _hasMarkedVideoReady = true;
                                ref
                                    .read(startupPerformanceServiceProvider)
                                    .markVideoReady();
                              }
                            },
                            onNearEnd: () {
                              if (state.hasMore) {
                                context.read<VideoFeedBloc>().add(
                                  const VideoFeedLoadMoreRequested(),
                                );
                              }
                            },
                          ),
                        ),
                        const FeedModeSwitch(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Nearest [HomeFeedRetapCubit], or null when the view is constructed
  /// without one (e.g. widget tests pumping [VideoFeedView] directly). In
  /// the app the cubit is provided above `AppShell` — see `shell.dart`.
  ///
  /// The nullable lookup returns null instead of throwing when no provider
  /// is found, so no try/catch is needed.
  HomeFeedRetapCubit? _maybeRetapCubit(BuildContext context) =>
      context.read<HomeFeedRetapCubit?>();

  /// Handles a home-tab retap: refreshes the feed, scrolls back to the top,
  /// and announces the result to screen readers.
  ///
  /// [HomeFeedRetapCubit.completeRefresh] runs in `finally` on the captured
  /// cubit — not through [BuildContext] — so the nav spinner always settles
  /// even when this view unmounts mid-refresh (the cubit outlives this view
  /// and would otherwise stay `refreshing` forever).
  Future<void> _onHomeRetap(
    BuildContext context,
    HomeFeedRetapCubit retapCubit,
  ) async {
    try {
      final status = await _refreshFeed(context);
      if (!context.mounted) return;
      await _feedVideosKey.currentState?.animateToPage(0);
      if (!context.mounted) return;
      // Only announce success. A failed refresh settles on
      // [VideoFeedStatus.failure] too, and announcing "Feed refreshed" then
      // would mislead screen-reader users — the visible failure state
      // already carries its own copy.
      if (status == VideoFeedStatus.success) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.feedRefreshed,
          Directionality.of(context),
        );
      }
    } finally {
      if (!retapCubit.isClosed) retapCubit.completeRefresh();
    }
  }

  /// Dispatches a refresh and resolves when the bloc settles.
  ///
  /// The [RefreshIndicator] keeps its spinner visible until the returned
  /// future completes, so we await the next non-loading state instead of
  /// resolving immediately on dispatch. If the bloc is disposed before
  /// settling (e.g. the user leaves the screen mid-refresh) the stream
  /// closes without matching and [Stream.firstWhere] returns the bloc's
  /// last known state via `orElse`.
  Future<VideoFeedStatus> _refreshFeed(BuildContext context) async {
    final bloc = context.read<VideoFeedBloc>();
    _currentIndex = 0;
    _pagePosition.value = 0;
    ref
        .read(lastTabPositionProvider.notifier)
        .recordPosition(RouteType.home, 0);
    bloc.add(const VideoFeedRefreshRequested());
    final settled = await bloc.stream.firstWhere(
      (s) =>
          s.status == VideoFeedStatus.success ||
          s.status == VideoFeedStatus.failure,
      orElse: () => bloc.state,
    );
    return settled.status;
  }
}

/// Holds the child subtree's bottom safe-area inset steady while a modal
/// keyboard is open over the home feed.
///
/// The shell [Scaffold] has a `bottomNavigationBar`, so it strips the body's
/// bottom padding: at rest the feed subtree reads `viewPadding.bottom == 0`.
/// While the share sheet's keyboard is up, the shell keeps its layout (it does
/// not resize for a modal route), so the window's keyboard inset zeroes the
/// shell's own `padding.bottom` — the strip then subtracts nothing and
/// `viewPadding.bottom` springs back up to the raw safe-area value, sliding the
/// overlay's action column up and then back down on keyboard close.
///
/// Latch the at-rest inset whenever the keyboard is down and hold it while the
/// keyboard is up, so the overlay positions against a stable inset. Holding the
/// real at-rest value (rather than a recomputed one) keeps the resting layout
/// pixel-identical. Scoped to the home feed; the fullscreen feed removes the
/// bottom padding outright and never springs.
class _KeyboardStableBottomInset extends StatefulWidget {
  const _KeyboardStableBottomInset({required this.child});

  final Widget child;

  @override
  State<_KeyboardStableBottomInset> createState() =>
      _KeyboardStableBottomInsetState();
}

class _KeyboardStableBottomInsetState
    extends State<_KeyboardStableBottomInset> {
  double? _restingBottom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Latch the at-rest inset whenever nothing is consuming the safe area, and
    // hold the last latched value while a keyboard is up. This fires on every
    // MediaQuery change, so `build` stays free of the caching side effect.
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.viewInsets.bottom == 0) {
      _restingBottom = mediaQuery.viewPadding.bottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final stableBottom = _restingBottom ?? mediaQuery.viewPadding.bottom;

    return MediaQuery(
      data: mediaQuery.copyWith(
        viewPadding: mediaQuery.viewPadding.copyWith(bottom: stableBottom),
      ),
      child: widget.child,
    );
  }
}
