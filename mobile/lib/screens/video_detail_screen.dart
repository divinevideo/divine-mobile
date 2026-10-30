// ABOUTME: Screen for viewing a specific video by ID (from deep links)
// ABOUTME: Fetches video from Nostr and displays it in full-screen player

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_detail/video_detail_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_viewer_preference_hints.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/single_video_feed_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/takeover_close_button.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';

class VideoDetailRouteExtra {
  const VideoDetailRouteExtra({
    this.autoOpenComments = false,
    this.fallbackVideoIds = const [],
    this.initialVideo,
    this.dmReplyContext,
    this.focusCommentId,
  });

  final bool autoOpenComments;
  final List<String> fallbackVideoIds;
  final VideoEvent? initialVideo;

  /// The comment the comments sheet [autoOpenComments] opens scrolls to,
  /// such as the one a tapped reply sticker replies to.
  final String? focusCommentId;

  /// Present when the reel was opened from a DM thread — drives the in-player
  /// reply/reaction bar. Null for feed/profile opens.
  final DmReplyContext? dmReplyContext;
}

class VideoDetailScreen extends ConsumerWidget {
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
    this.focusCommentId,
    super.key,
  });

  final String videoId;
  final bool autoOpenComments;
  final List<String> fallbackVideoIds;
  final VideoEvent? initialVideo;
  final Widget Function(VideoEvent video)? videoFeedBuilder;

  /// The comment the comments sheet [autoOpenComments] opens scrolls to.
  final String? focusCommentId;

  /// Present when opened from a DM thread — forwarded to the player for the
  /// in-player reply/reaction bar.
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => VideoDetailCubit(
        // Read at lookup time, not in create: the repository can change after
        // age verification or a filter toggle without resetting playback.
        videosRepository: () => ref.read(videosRepositoryProvider),
        isRelayReady: () {
          final client = ref.read(nostrServiceProvider);
          return client.isInitialized && client.connectedRelayCount > 0;
        },
        relayReadyStream: () => ref
            .read(nostrServiceProvider)
            .relayStatusStream
            .map(
              (statuses) => statuses.values.any((status) => status.isConnected),
            ),
      ),
      child: _VideoDetailView(screen: this),
    );
  }
}

class _VideoDetailView extends ConsumerStatefulWidget {
  const _VideoDetailView({required this.screen});

  final VideoDetailScreen screen;

  @override
  ConsumerState<_VideoDetailView> createState() => _VideoDetailViewState();
}

class _VideoDetailViewState extends ConsumerState<_VideoDetailView> {
  SingleVideoFeedRepository? _discoveryRepository;
  String? _discoveryVideoId;
  String? _discoveryUserPubkey;

  @override
  void initState() {
    super.initState();
    _search();
    if (widget.screen.initialVideo != null) {
      ref.read(screenAnalyticsServiceProvider).markDataLoaded('video_detail');
    }
  }

  @override
  void didUpdateWidget(covariant _VideoDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.screen;
    final current = widget.screen;
    if (previous.videoId != current.videoId ||
        !listEquals(previous.fallbackVideoIds, current.fallbackVideoIds) ||
        previous.initialVideo != current.initialVideo) {
      _disposeDiscoveryRepository();
      _search();
    }
  }

  @override
  void dispose() {
    _disposeDiscoveryRepository();
    super.dispose();
  }

  void _disposeDiscoveryRepository() {
    final repository = _discoveryRepository;
    _discoveryRepository = null;
    _discoveryVideoId = null;
    _discoveryUserPubkey = null;
    if (repository != null) {
      runDetached(
        repository.dispose(),
        'dispose single-video discovery feed',
        logName: 'VideoDetailScreen',
        category: LogCategory.video,
      );
    }
  }

  SingleVideoFeedRepository _repositoryFor(VideoEvent video) {
    final pubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    if (_discoveryVideoId != video.id || _discoveryUserPubkey != pubkey) {
      _disposeDiscoveryRepository();
      // Page loading can outlive this widget, so callbacks retain the app
      // container rather than WidgetRef and read current services after recovery.
      final container = ProviderScope.containerOf(context, listen: false);
      _discoveryRepository = SingleVideoFeedRepository(
        video: video,
        loadPage: ({cursor}) async {
          final hints = await readFeedViewerPreferenceHints(container.read);
          return container
              .read(videosRepositoryProvider)
              .getVideoDiscoveryPage(
                userPubkey: pubkey,
                cursor: cursor,
                preferredLanguages: hints.preferredLanguages,
                viewerCountry: hints.viewerCountry,
              );
        },
        filter: (videos) => container
            .read(videoEventServiceProvider)
            .filterVideoList(
              videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
            ),
      );
      _discoveryVideoId = video.id;
      _discoveryUserPubkey = pubkey;
    }
    return _discoveryRepository!..refreshFilters();
  }

  void _search() {
    final screen = widget.screen;
    context.read<VideoDetailCubit>().search(
      routeId: screen.videoId,
      fallbackRouteIds: screen.fallbackVideoIds,
      initialVideo: screen.initialVideo,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    ref.watch(currentAuthStateProvider);
    ref.watch(blocklistVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(contentFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final screen = widget.screen;

    return BlocConsumer<VideoDetailCubit, VideoDetailState>(
      listenWhen: (previous, current) =>
          current.status == VideoDetailStatus.ready &&
          (previous.status != current.status ||
              previous.video != current.video),
      listener: (_, _) {
        ref.read(screenAnalyticsServiceProvider).markDataLoaded('video_detail');
      },
      builder: (context, state) {
        switch (state.status) {
          case VideoDetailStatus.searching:
            return _LoadingScreen(onClose: () => _handleExit(context));
          case VideoDetailStatus.hiddenBySettings:
            return _HiddenBySettingsScreen(
              video: state.video!,
              reason: _hiddenReason(state.video!),
              onShowAnyway: context
                  .read<VideoDetailCubit>()
                  .showHiddenVideoAnyway,
              onClose: () => _handleExit(context),
            );
          case VideoDetailStatus.loadFailed:
            return TvStaticMessageScreen(
              sticker: .alert,
              title: context.l10n.videoDetailLoadError,
              description: context.l10n.videoDetailLoadErrorBody,
              actionLabel: context.l10n.videoErrorRetry,
              onAction: context.read<VideoDetailCubit>().retry,
              onClose: () => _handleExit(context),
              closeSemanticLabel: context.l10n.videoDetailCloseSemanticLabel,
            );
          case VideoDetailStatus.ready:
            final video = state.video!;
            if (videoEventService.shouldHideVideo(video) ||
                videoEventService.isVideoEventKnownDeleted(video)) {
              return _NotFoundScreen(onClose: () => _handleExit(context));
            }
            final builder = screen.videoFeedBuilder;
            if (builder != null) return builder(video);
            final repository = _repositoryFor(video);
            return PooledFullscreenVideoFeedScreen(
              key: ValueKey(repository),
              source: SingleVideoViewSource(video),
              feedRepository: repository,
              initialIndex: 0,
              contextTitle: context.l10n.videoDetailContextTitle,
              trafficSource: ViewTrafficSource.share,
              autoOpenComments: screen.autoOpenComments,
              focusCommentId: screen.focusCommentId,
              dmReplyContext: screen.dmReplyContext,
            );
        }
      },
    );
  }

  void _handleExit(BuildContext context) {
    context.read<VideoDetailCubit>().cancelSearch();
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

/// Shown when an already-resolved video is hidden or known to be deleted.
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
