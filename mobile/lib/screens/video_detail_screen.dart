// ABOUTME: Screen for viewing a specific video by ID (from deep links)
// ABOUTME: Fetches video from Nostr and displays it in full-screen player

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart' show NostrClient;
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/takeover_close_button.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

class VideoDetailRouteExtra {
  const VideoDetailRouteExtra({
    this.autoOpenComments = false,
    this.fallbackVideoIds = const [],
    this.initialVideo,
    this.dmReplyContext,
  });

  final bool autoOpenComments;
  final List<String> fallbackVideoIds;
  final VideoEvent? initialVideo;

  /// Present when the reel was opened from a DM thread — drives the in-player
  /// reply/reaction bar. Null for feed/profile opens.
  final DmReplyContext? dmReplyContext;
}

class VideoDetailScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'video';

  /// Base path for video routes.
  static const String basePath = RoutePaths.videoDetailBase;

  /// Path pattern for this route.
  static const path = '/video/:id';

  /// Build path for a specific video route reference.
  ///
  /// The route segment may be a raw event ID, a stable ID / d-tag, or
  /// a NIP-19 reference such as `note1...`, `nevent1...`, or `naddr1...`.
  static String pathForId(String id) => RoutePaths.videoDetailForId(id);

  const VideoDetailScreen({
    required this.videoId,
    this.autoOpenComments = false,
    this.fallbackVideoIds = const [],
    this.initialVideo,
    this.videoFeedBuilder,
    this.dmReplyContext,
    super.key,
  });

  final String videoId;
  final bool autoOpenComments;
  final List<String> fallbackVideoIds;
  final VideoEvent? initialVideo;
  final Widget Function(VideoEvent video)? videoFeedBuilder;

  /// Present when opened from a DM thread — forwarded to the player for the
  /// in-player reply/reaction bar.
  final DmReplyContext? dmReplyContext;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  VideoEvent? _video;
  bool _isLoading = true;
  _VideoDetailError? _error;

  /// The video a content filter removed, kept so the viewer can override
  /// the filter for this one video without another round trip (#7892).
  VideoEvent? _hiddenVideo;
  StreamSubscription? _relayReadySubscription;
  bool _retryScheduled = false;
  bool _hasRetriedAfterRelayReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideo != null) {
      _video = widget.initialVideo;
      _isLoading = false;
      ref.read(screenAnalyticsServiceProvider).markDataLoaded('video_detail');
      return;
    }
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant VideoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId == widget.videoId &&
        listEquals(oldWidget.fallbackVideoIds, widget.fallbackVideoIds) &&
        oldWidget.initialVideo == widget.initialVideo) {
      return;
    }

    // Deep links can retarget an already-mounted video screen. Reset the
    // previous request state so the second shared link triggers a fresh load.
    _relayReadySubscription?.cancel();
    _relayReadySubscription = null;
    _retryScheduled = false;
    _hasRetriedAfterRelayReady = false;

    setState(() {
      _video = widget.initialVideo;
      _isLoading = widget.initialVideo == null;
      _error = null;
    });

    if (widget.initialVideo != null) {
      ref.read(screenAnalyticsServiceProvider).markDataLoaded('video_detail');
      return;
    }

    unawaited(_loadVideo());
  }

  @override
  void dispose() {
    _relayReadySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVideo({bool allowRelayReadyRetry = true}) async {
    try {
      Log.info(
        '📱 Loading video from route ref: ${widget.videoId}',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final nostrClient = ref.read(nostrServiceProvider);
      final canQueryRelays =
          nostrClient.isInitialized && nostrClient.connectedRelayCount > 0;

      // fetchVideoWithStats handles cache→relay lookup and bulk-stats
      // hydration in one call, matching what feed providers do.
      final videosRepository = ref.read(videosRepositoryProvider);
      final lookup = await videosRepository.lookupVideoForRouteId(
        widget.videoId,
        fallbackRouteIds: widget.fallbackVideoIds,
      );

      // A filtered video is not a missing one: it resolved and plays, and
      // reporting it as "not found" leaves the viewer with no way to act
      // on a setting they may never have chosen (#7892).
      if (lookup case VideoRouteHiddenByFilter(:final video)) {
        Log.info(
          'Video hidden by content filters: ${widget.videoId}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _hiddenVideo = video;
            _error = _VideoDetailError.hiddenBySettings;
            _isLoading = false;
          });
        }
        return;
      }

      final video = lookup is VideoRouteFound ? lookup.video : null;

      if (video != null) {
        Log.info(
          '✅ Loaded video: ${video.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = video;
            _isLoading = false;
            _error = null;
          });
          ref
              .read(screenAnalyticsServiceProvider)
              .markDataLoaded('video_detail');
        }
      } else {
        // A null result only establishes absence when relays were queryable
        // for the whole lookup. Checking that at the start alone misses the
        // resume case: a REQ can begin against a relay that is gone by the
        // time the per-query timeout fires, and an empty result from a lookup
        // that lost its relays is not a confirmed "not found". Check both
        // ends and defer to the relay-ready retry when either fails.
        final canQueryRelaysNow =
            nostrClient.isInitialized && nostrClient.connectedRelayCount > 0;
        if (allowRelayReadyRetry &&
            (!canQueryRelays || !canQueryRelaysNow) &&
            _scheduleRelayReadyRetry(nostrClient)) {
          Log.info(
            '⏳ Video lookup deferred until relay connection is ready',
            name: 'VideoDetailScreen',
            category: LogCategory.video,
          );
          return;
        }
        Log.warning(
          '❌ Video not found: ${widget.videoId}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _error = _VideoDetailError.notFound;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      final nostrClient = ref.read(nostrServiceProvider);
      final canQueryRelays =
          nostrClient.isInitialized && nostrClient.connectedRelayCount > 0;
      if (allowRelayReadyRetry &&
          !canQueryRelays &&
          _scheduleRelayReadyRetry(nostrClient)) {
        Log.warning(
          '⏳ Video lookup failed before relay readiness; waiting to retry: $e',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        return;
      }
      Log.error(
        'Error loading video: $e',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );
      if (mounted) {
        setState(() {
          _error = _VideoDetailError.loadFailed;
          _isLoading = false;
        });
      }
    }
  }

  /// Which source preference is responsible, so the panel names the setting
  /// the viewer actually has to change rather than guessing.
  ///
  /// Both can apply at once; hosting is reported first because it is on by
  /// default and is therefore the likelier surprise.
  _HiddenReason _hiddenReason(VideoEvent video) {
    if (!video.isFromDivineServer &&
        ref.read(divineHostFilterServiceProvider).showDivineHostedOnly) {
      return _HiddenReason.divineHostedOnly;
    }
    if (!video.hasProofMode &&
        !video.isOriginalVine &&
        ref.read(videoProvenanceFilterServiceProvider).showVerifiedOnly) {
      return _HiddenReason.verifiedOnly;
    }
    return _HiddenReason.otherContentFilter;
  }

  /// Renders the filtered video for this screen only.
  ///
  /// The lookup already parsed it, so the override is a state change rather
  /// than a refetch, and it deliberately does not touch the stored setting —
  /// overriding one video is not the same as turning the filter off.
  void _showHiddenVideoAnyway() {
    final video = _hiddenVideo;
    if (video == null) return;
    setState(() {
      _video = video;
      _error = null;
      _isLoading = false;
    });
  }

  bool _scheduleRelayReadyRetry(NostrClient nostrClient) {
    if (_retryScheduled || _hasRetriedAfterRelayReady) {
      return false;
    }

    _retryScheduled = true;
    _relayReadySubscription?.cancel();

    void retry() {
      _relayReadySubscription?.cancel();
      _relayReadySubscription = null;
      _retryScheduled = false;
      _hasRetriedAfterRelayReady = true;
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });
      unawaited(_loadVideo(allowRelayReadyRetry: false));
    }

    if (nostrClient.isInitialized && nostrClient.connectedRelayCount > 0) {
      retry();
      return true;
    }

    _relayReadySubscription = nostrClient.relayStatusStream.listen((statuses) {
      final hasConnectedRelay = statuses.values.any(
        (status) => status.isConnected,
      );
      if (hasConnectedRelay) {
        retry();
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(blocklistVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(contentFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);

    if (_isLoading) {
      return _LoadingScreen(onClose: () => _handleExit(context));
    }

    if (_error case final error?) {
      return switch (error) {
        _VideoDetailError.notFound => _NotFoundScreen(
          onClose: () => _handleExit(context),
        ),
        _VideoDetailError.hiddenBySettings => _HiddenBySettingsScreen(
          video: _hiddenVideo!,
          reason: _hiddenReason(_hiddenVideo!),
          onShowAnyway: _showHiddenVideoAnyway,
          onClose: () => _handleExit(context),
        ),
        _VideoDetailError.loadFailed => TvStaticMessageScreen(
          sticker: .alert,
          title: context.l10n.videoDetailLoadError,
          description: context.l10n.videoDetailLoadErrorBody,
          actionLabel: context.l10n.videoErrorRetry,
          onAction: _retry,
          onClose: () => _handleExit(context),
          closeSemanticLabel: context.l10n.videoDetailCloseSemanticLabel,
        ),
      };
    }

    if (_video == null ||
        videoEventService.shouldHideVideo(_video!) ||
        videoEventService.isVideoEventKnownDeleted(_video!)) {
      return _NotFoundScreen(onClose: () => _handleExit(context));
    }

    // Display video in full-screen pooled player
    return widget.videoFeedBuilder?.call(_video!) ??
        PooledFullscreenVideoFeedScreen(
          source: SingleVideoViewSource(_video!),
          feedRepository: StaticFeedRepository(),
          initialIndex: 0,
          contextTitle: context.l10n.videoDetailContextTitle,
          trafficSource: ViewTrafficSource.share,
          autoOpenComments: widget.autoOpenComments,
          dmReplyContext: widget.dmReplyContext,
        );
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // A user-initiated retry must end in a definite state. Deferring to the
    // relay-ready listener would swallow the failure and park the screen on an
    // unbounded spinner with the Retry button gone; the user can always tap
    // again once they are back online.
    unawaited(_loadVideo(allowRelayReadyRetry: false));
  }

  void _handleExit(BuildContext context) {
    // The loading state can now be dismissed mid-fetch. Without this, a relay
    // connecting during the pop transition would restart the lookup for a
    // screen the user has already left.
    _relayReadySubscription?.cancel();
    _relayReadySubscription = null;
    _retryScheduled = false;

    // safePop, not a hand-rolled canPop/go pair: `/video/:id` is a flat
    // top-level route, so a deep link lands here with a one-entry stack and
    // the fallback is the branch that actually runs.
    context.safePop();
  }
}

/// Shown while the route's video is still being resolved.
///
/// Carries the same top-left close affordance as the dead-end states, so a slow
/// or relay-stalled lookup never strands the user on a spinner with no way out.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Semantics(
              identifier: SemanticIds.videoDetailLoading,
              child: const BrandedLoadingIndicator(),
            ),
          ),
          SafeArea(
            child: TakeoverCloseButton(
              onPressed: onClose,
              semanticLabel: context.l10n.videoDetailCloseSemanticLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the route's video cannot be resolved, is hidden by a filter, or
/// was deleted — the three ways a shared link lands on nothing to play.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TvStaticMessageScreen(
      sticker: .alert,
      title: context.l10n.videoErrorNotFound,
      description: context.l10n.videoDetailNotFoundBody,
      onClose: onClose,
      closeSemanticLabel: context.l10n.videoDetailCloseSemanticLabel,
    );
  }
}

enum _VideoDetailError { notFound, loadFailed, hiddenBySettings }

/// Explains that a content filter — not a missing video — is why nothing
/// played, and offers both ways out: change the setting, or override it for
/// this one video.
/// Which source preference hid the video.
enum _HiddenReason { divineHostedOnly, verifiedOnly, otherContentFilter }

class _HiddenBySettingsScreen extends StatelessWidget {
  const _HiddenBySettingsScreen({
    required this.video,
    required this.reason,
    required this.onShowAnyway,
    required this.onClose,
  });

  final VideoEvent video;

  /// Drives which explanation is shown, so the copy never names a setting
  /// that is not the cause.
  final _HiddenReason reason;

  final VoidCallback onShowAnyway;
  final VoidCallback onClose;

  String _host() {
    final url = video.videoUrl;
    if (url == null || url.isEmpty) return '';
    return Uri.tryParse(url)?.host ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return TvStaticMessageScreen(
      sticker: .alert,
      title: context.l10n.videoDetailHiddenBySettingsTitle,
      description: switch (reason) {
        _HiddenReason.divineHostedOnly =>
          context.l10n.videoDetailHiddenByHostFilterBody(_host()),
        _HiddenReason.verifiedOnly =>
          context.l10n.videoDetailHiddenByProvenanceFilterBody,
        _HiddenReason.otherContentFilter =>
          context.l10n.videoDetailHiddenByContentFilterBody,
      },
      actionLabel: context.l10n.videoDetailHiddenShowAnyway,
      onAction: onShowAnyway,
      onClose: onClose,
      closeSemanticLabel: context.l10n.videoDetailCloseSemanticLabel,
      footer: DivineButton(
        label: context.l10n.videoDetailHiddenOpenSettings,
        type: DivineButtonType.secondary,
        onPressed: () => context.push(SafetySettingsScreen.path),
      ),
    );
  }
}
