// ABOUTME: Fullscreen video feed view for profile screens
// ABOUTME: Resolves the profile feed through a FeedRepository (#3383)

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/video_identity.dart';
import 'package:rxdart/rxdart.dart';
import 'package:videos_repository/videos_repository.dart';

/// Fullscreen video feed view for profile screens.
///
/// Wraps [PooledFullscreenVideoFeedScreen] with a [ProfileFeedScope] so the
/// fullscreen feed benefits from the pooled player, auto-advance and
/// prefetching machinery shared with the main feed. The feed is resolved
/// through a [StreamFeedRepository] bound to the scope's [ProfileFeedCubit],
/// so profile-specific metadata updates (like loop counts) survive the
/// launching grid unmounting. Keeps the URL in sync via [onPageChanged].
class ProfileVideoFeedView extends ConsumerWidget {
  const ProfileVideoFeedView({
    required this.npub,
    required this.userIdHex,
    required this.videoIndex,
    required this.onPageChanged,
    this.videos = const [],
    this.initialVideoId,
    this.initialStableId,
    this.contextTitleOverride,
    super.key,
  });

  /// The npub of the profile (carried for URL updates at the callsite).
  final String npub;

  /// The hex public key of the profile.
  final String userIdHex;

  /// Initial list of videos to seed the feed with before the cubit resolves.
  final List<VideoEvent> videos;

  /// Current video index from the URL.
  final int videoIndex;

  /// Optional specific tapped video identity for resolving the initial index
  /// against the live cubit-backed feed.
  final String? initialVideoId;
  final String? initialStableId;

  /// Optional title override when the caller already has context.
  final String? contextTitleOverride;

  /// Callback when the page changes (for URL updates).
  final void Function(int newIndex) onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextTitle =
        contextTitleOverride ??
        ref
            .watch(fetchUserProfileProvider(userIdHex))
            .value
            ?.betterDisplayName(context.l10n.profileTitle);

    return ProfileFeedScope(
      userIdHex: userIdHex,
      child: _ProfileFullscreenContent(
        userIdHex: userIdHex,
        seedVideos: videos,
        videoIndex: videoIndex,
        initialVideoId: initialVideoId,
        initialStableId: initialStableId,
        contextTitle: contextTitle,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

/// Inner content that binds a [StreamFeedRepository] to the scoped
/// [ProfileFeedCubit] exactly once, then hands it to the fullscreen screen.
class _ProfileFullscreenContent extends StatefulWidget {
  const _ProfileFullscreenContent({
    required this.userIdHex,
    required this.seedVideos,
    required this.videoIndex,
    required this.onPageChanged,
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
  });

  final String userIdHex;
  final List<VideoEvent> seedVideos;
  final int videoIndex;
  final String? initialVideoId;
  final String? initialStableId;
  final String? contextTitle;
  final void Function(int newIndex) onPageChanged;

  @override
  State<_ProfileFullscreenContent> createState() =>
      _ProfileFullscreenContentState();
}

class _ProfileFullscreenContentState extends State<_ProfileFullscreenContent> {
  late final ProfileFeedCubit _cubit;
  late final FeedRepository _feedRepository;
  late final int _initialIndex;
  late final bool _seedContainsInitialTarget;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProfileFeedCubit>();
    _seedContainsInitialTarget = _containsInitialTarget(widget.seedVideos);

    final initialState = _cubit.state;
    _initialIndex = _resolveInitialIndex(_effectiveVideos(initialState));

    _feedRepository = StreamFeedRepository(
      videos: _cubit.stream
          .map(_effectiveVideos)
          .startWith(_effectiveVideos(initialState)),
      hasMore: _cubit.stream
          .map((state) => state.hasMoreContent)
          .startWith(initialState.hasMoreContent),
      onLoadMore: () async => _cubit.add(const ProfileFeedLoadMoreRequested()),
    );
  }

  // Adapts the scoped live cubit feed to the launch seed while the new cubit
  // catches up to the tapped video from the profile grid.
  List<VideoEvent> _effectiveVideos(ProfileFeedState state) {
    final liveVideos = state.videos;
    final seedVideos = widget.seedVideos;
    if (liveVideos.isEmpty) return seedVideos;
    if (seedVideos.isEmpty || !_seedContainsInitialTarget) return liveVideos;

    // Once live paging reaches the tapped target, the cubit-owned list is
    // authoritative again; seed-only items can drop until live paging reaches
    // them through the normal profile feed path.
    if (_containsInitialTarget(liveVideos)) return liveVideos;

    return mergeProfileFeedVideoLists(liveVideos, seedVideos);
  }

  int _resolveInitialIndex(List<VideoEvent> videos) {
    if (videos.isEmpty) return 0;

    final resolved = _indexOfInitialTarget(videos);
    if (resolved >= 0) return resolved;

    return widget.videoIndex.clamp(0, videos.length - 1);
  }

  bool _containsInitialTarget(List<VideoEvent> videos) =>
      _indexOfInitialTarget(videos) >= 0;

  int _indexOfInitialTarget(List<VideoEvent> videos) {
    final initialVideoId = widget.initialVideoId;
    final initialStableId = widget.initialStableId;
    if (initialVideoId != null || initialStableId != null) {
      return indexOfVideoIdentity(
        videos,
        videoId: initialVideoId,
        stableId: initialStableId,
      );
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return PooledFullscreenVideoFeedScreen(
      source: ProfileViewSource(widget.userIdHex),
      feedRepository: _feedRepository,
      initialIndex: _initialIndex,
      initialVideoId: widget.initialVideoId,
      initialStableId: widget.initialStableId,
      trafficSource: ViewTrafficSource.profile,
      contextTitle: widget.contextTitle,
      onPageChanged: widget.onPageChanged,
    );
  }
}
