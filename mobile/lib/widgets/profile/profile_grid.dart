// ABOUTME: Profile grid view with header, stats, action buttons, and tabbed content
// ABOUTME: Reusable between own profile and others' profile screens

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_tab_index_provider.dart';
import 'package:openvine/widgets/profile/profile_banner_layer.dart';
import 'package:openvine/widgets/profile/profile_collabs_grid.dart';
import 'package:openvine/widgets/profile/profile_comments_grid.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:openvine/widgets/profile/profile_lists_grid.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';
import 'package:openvine/widgets/profile/profile_tab_bar.dart';
import 'package:openvine/widgets/profile/profile_tab_kind.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';

/// Profile grid view showing header, stats, action buttons, and tabbed content.
class ProfileGridView extends ConsumerStatefulWidget {
  const ProfileGridView({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    this.profile,
    this.profileStats,
    this.displayName,
    this.onEditProfile,
    this.onBack,
    this.onMore,
    this.onOpenClips,
    this.onMessageUser,
    this.isMessageRestricted = false,
    this.onShareProfile,
    this.onBlockedTap,
    this.scrollController,
    this.displayNameHint,
    this.avatarUrlHint,
    this.refreshNotifier,
    this.isLoadingVideos = false,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (only used for other profiles).
  final String? displayName;

  /// List of videos to display in the videos tab.
  final List<VideoEvent> videos;

  /// Optional profile owned by the parent widget.
  final UserProfile? profile;

  /// Optional cached profile stats owned by the parent widget.
  final ProfileStats? profileStats;

  /// Callback when edit profile is tapped (own profile only).
  final VoidCallback? onEditProfile;

  /// Callback for back navigation (other profiles only).
  final VoidCallback? onBack;

  /// Callback for more options menu (other profiles only).
  final VoidCallback? onMore;

  /// Callback when "Clips" button is tapped (own profile only).
  final VoidCallback? onOpenClips;

  /// Callback when "Message" button is tapped (other profiles only).
  final VoidCallback? onMessageUser;

  /// Whether the Message affordance should be hidden for policy reasons.
  final bool isMessageRestricted;

  /// Callback when share button is tapped.
  final void Function(BuildContext context)? onShareProfile;

  /// Callback when the Blocked button is tapped (other profiles only).
  final VoidCallback? onBlockedTap;

  /// Optional scroll controller for the NestedScrollView.
  final ScrollController? scrollController;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  /// Notifier that triggers BLoC refresh when its value changes.
  /// Parent should call `notifier.value++` to trigger refresh.
  final ValueNotifier<int>? refreshNotifier;

  /// Whether videos are currently being loaded.
  /// When true and [videos] is empty, shows a loading indicator
  /// in the videos tab instead of the empty state.
  final bool isLoadingVideos;

  @override
  ConsumerState<ProfileGridView> createState() => _ProfileGridViewState();
}

class _ProfileGridViewState extends ConsumerState<ProfileGridView>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  @override
  int get tabCount => _tabKinds.length;

  /// Restores the previously selected tab so navigating back from a fullscreen
  /// video doesn't drop the user on Videos. The mixin clamps it.
  @override
  int get initialTabIndex =>
      ref.read(profileTabIndexProvider)[_tabIndexKey] ?? 0;

  /// Direct references to BLoCs for refresh capability.
  ProfileLikedVideosBloc? _likedVideosBloc;
  ProfileRepostedVideosBloc? _repostedVideosBloc;
  ProfileCollabVideosBloc? _collabVideosBloc;
  ProfileCommentsBloc? _commentsBloc;

  /// Mirrors each cached tab's `isRefreshing` so the pinned tab bar can show a
  /// sticky cache-revalidation bar directly under the tabs while that grid
  /// scrolls (a body overlay would be drawn behind the header).
  bool _likedRefreshing = false;
  StreamSubscription<ProfileLikedVideosState>? _likedRefreshSub;
  bool _repostsRefreshing = false;
  StreamSubscription<ProfileRepostedVideosState>? _repostsRefreshSub;
  bool _collabsRefreshing = false;
  StreamSubscription<ProfileCollabVideosState>? _collabsRefreshSub;

  /// Whether the currently-selected tab is revalidating cached content.
  ///
  /// Resolved by tab [ProfileTabKind] rather than raw index: the own profile's
  /// tab order differs from other profiles' (Collabs is inserted at index 1 on
  /// the own profile, per #5213), so a fixed index would track the wrong tab.
  /// Videos reads the [ProfileFeedCubit]'s refreshing flag, passed in from
  /// [build] because that cubit is provided by the ancestor `ProfileFeedScope`.
  bool _activeTabRefreshing(bool videosRefreshing) =>
      switch (_tabKinds[tabController.index]) {
        ProfileTabKind.videos => videosRefreshing,
        ProfileTabKind.liked => _likedRefreshing,
        ProfileTabKind.reposts => _repostsRefreshing,
        ProfileTabKind.collabs => _collabsRefreshing,
        ProfileTabKind.lists => false,
        ProfileTabKind.comments => false,
      };

  /// The dependency identities the tab BLoCs were last created for.
  ///
  /// The BLoCs capture these at construction (in [build]), so when any of
  /// them changes identity — profile switch, auth flip, account switch,
  /// sign-out, or an explicit provider invalidation — the BLoCs must be torn
  /// down and rebuilt, otherwise they keep operating on a stale signer /
  /// repository (see `rules/state_management.md`, captured-dependency trap).
  /// Strings/bools compare by value; repositories don't override `==` so they
  /// compare by identity, which is exactly the swap signal we need.
  /// [isOwnProfile] is tracked too: an own↔other flip on the same mounted
  /// profile changes the tab set and which BLoCs exist (#5213).
  ({
    String userIdHex,
    bool isOwnProfile,
    bool includeVideoReplies,
    String currentUserPubkey,
    Object likesRepository,
    Object repostsRepository,
    Object videosRepository,
    Object commentsRepository,
    Object contentBlocklistRepository,
  })?
  _blocsDeps;

  /// Track which tabs have been synced (lazy loading).
  final Set<ProfileTabKind> _syncedKinds = <ProfileTabKind>{};

  /// Ordered tabs for the current profile. The own profile adds a Collabs
  /// tab (between Videos and Liked) on top of its Lists tab (#5213); other
  /// profiles keep their existing order.
  List<ProfileTabKind> get _tabKinds =>
      profileTabKinds(isOwnProfile: widget.isOwnProfile);

  ProfileTabIndexKey get _tabIndexKey => (
    viewerPubkeyHex: ref.read(authServiceProvider).currentPublicKeyHex,
    targetPubkeyHex: widget.userIdHex,
  );

  /// Key attached to the ProfileHeaderWidget so we can measure its height
  /// and compute the tab bar top inset accordingly.
  final GlobalKey _headerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void didUpdateWidget(ProfileGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNotifier != widget.refreshNotifier) {
      oldWidget.refreshNotifier?.removeListener(_onRefreshRequested);
      widget.refreshNotifier?.addListener(_onRefreshRequested);
    }
    // An own↔other flip changes the tab set (#5213).
    syncTabController();
  }

  @override
  void onTabChanged() {
    // Trigger rebuild to update SVG icon colors
    if (mounted) setState(() {});

    // Persist the current index so a remount (triggered by navigation
    // transitions that briefly take the URL off the profile route) can
    // restore the user to the tab they were on.
    final notifier = ref.read(profileTabIndexProvider.notifier);
    notifier.state = {...notifier.state, _tabIndexKey: tabController.index};

    _syncCurrentTabIfNeeded();
  }

  /// Dispatch the lazy-load event for the currently selected tab, unless it
  /// has already been synced this session. Extracted so it can also be
  /// triggered after BLoCs are created on first build — [_onTabChanged]
  /// doesn't fire for the initial [TabController] index.
  void _syncCurrentTabIfNeeded() {
    final kind = _tabKinds[tabController.index];
    if (_syncedKinds.contains(kind)) return;
    switch (kind) {
      case ProfileTabKind.videos:
        // Videos render from [widget.videos]; no bloc sync needed.
        return;
      case ProfileTabKind.collabs:
        final bloc = _collabVideosBloc;
        if (bloc == null) return;
        bloc.add(const ProfileCollabVideosFetchRequested());
      case ProfileTabKind.liked:
        final bloc = _likedVideosBloc;
        if (bloc == null) return;
        bloc.add(const ProfileLikedVideosSyncRequested());
      case ProfileTabKind.reposts:
        final bloc = _repostedVideosBloc;
        if (bloc == null) return;
        bloc.add(const ProfileRepostedVideosSyncRequested());
      case ProfileTabKind.lists:
        // Lists render from [CuratedListService], which already synced during
        // its own initialization. Nothing to dispatch on first view, but the
        // tab still counts as synced so pull-to-refresh reaches it below.
        break;
      case ProfileTabKind.comments:
        final bloc = _commentsBloc;
        if (bloc == null) return;
        bloc.add(const ProfileCommentsSyncRequested());
    }
    _syncedKinds.add(kind);
  }

  void _onRefreshRequested() {
    unawaited(_refreshSyncedTabs());
  }

  /// Re-syncs every tab the user has viewed and resolves once all of them have
  /// finished.
  ///
  /// Each sync event carries its own [Completer], which its handler completes
  /// in a `finally`. Watching the state stream instead cannot express this: an
  /// unchanged re-sync emits a state equal to the current one and bloc
  /// suppresses it, and a handler stays busy past its terminal emit while it
  /// writes its snapshot to the cache — so a settled-looking tab could still be
  /// mid-handler. Holding the indicator until the completers fire also keeps
  /// the next pull from landing on a bloc that is still working.
  Future<void> _refreshSyncedTabs() async {
    // Re-dispatch sync only for tabs that have been viewed (lazy load still
    // applies).
    final refreshes = <Future<void>>[];
    for (final kind in _syncedKinds) {
      switch (kind) {
        case ProfileTabKind.videos:
          break;
        case ProfileTabKind.collabs:
          final bloc = _collabVideosBloc;
          if (bloc == null) break;
          final completer = Completer<void>();
          bloc.add(ProfileCollabVideosFetchRequested(completer: completer));
          refreshes.add(completer.future);
        case ProfileTabKind.liked:
          final bloc = _likedVideosBloc;
          if (bloc == null) break;
          final completer = Completer<void>();
          bloc.add(ProfileLikedVideosSyncRequested(completer: completer));
          refreshes.add(completer.future);
        case ProfileTabKind.reposts:
          final bloc = _repostedVideosBloc;
          if (bloc == null) break;
          final completer = Completer<void>();
          bloc.add(ProfileRepostedVideosSyncRequested(completer: completer));
          refreshes.add(completer.future);
        case ProfileTabKind.lists:
          final service = ref.read(curatedListsStateProvider.notifier).service;
          if (service == null) break;
          // Forced: the service syncs once per session, so an unforced call
          // returns without querying and a list made on another device would
          // stay invisible until the next cold start.
          refreshes.add(service.fetchUserListsFromRelays(force: true));
        case ProfileTabKind.comments:
          final bloc = _commentsBloc;
          if (bloc == null) break;
          final completer = Completer<void>();
          bloc.add(ProfileCommentsSyncRequested(completer: completer));
          refreshes.add(completer.future);
      }
    }
    await Future.wait(refreshes);
  }

  Future<void> _refreshProfileContent() async {
    final profileRefresh = Completer<void>();

    if (widget.isOwnProfile) {
      try {
        context.read<MyProfileBloc>().add(
          MyProfileRefreshRequested(completer: profileRefresh),
        );
      } on ProviderNotFoundException {
        profileRefresh.complete();
      }
    } else {
      profileRefresh.complete();
    }

    // The Videos tab uses the same completer handshake as the other tabs, for
    // the same reason: its terminal emit is not the end of the handler, and a
    // refresh that changes nothing would emit a suppressed state.
    final feedRefresh = Completer<void>();
    context.read<ProfileFeedCubit>().add(
      ProfileFeedRefreshRequested(completer: feedRefresh),
    );

    final tabRefresh = _refreshSyncedTabs();

    await Future.wait([profileRefresh.future, feedRefresh.future, tabRefresh]);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    _likedRefreshSub?.cancel();
    _repostsRefreshSub?.cancel();
    _collabsRefreshSub?.cancel();
    // Close the BLoCs we created
    _likedVideosBloc?.close();
    _repostedVideosBloc?.close();
    _collabVideosBloc?.close();
    _commentsBloc?.close();
    super.dispose();
  }

  /// The grid widget for a given tab [kind].
  Widget _gridForKind(ProfileTabKind kind) {
    switch (kind) {
      case ProfileTabKind.videos:
        return ProfileVideosGrid(
          videos: widget.videos,
          userIdHex: widget.userIdHex,
          isLoading: widget.isLoadingVideos,
        );
      case ProfileTabKind.collabs:
        return ProfileCollabsGrid(
          isOwnProfile: widget.isOwnProfile,
          userIdHex: widget.userIdHex,
        );
      case ProfileTabKind.liked:
        return ProfileLikedGrid(
          isOwnProfile: widget.isOwnProfile,
          userIdHex: widget.userIdHex,
        );
      case ProfileTabKind.reposts:
        return ProfileRepostsGrid(
          isOwnProfile: widget.isOwnProfile,
          userIdHex: widget.userIdHex,
        );
      case ProfileTabKind.lists:
        return const ProfileListsGrid();
      case ProfileTabKind.comments:
        return ProfileCommentsGrid(isOwnProfile: widget.isOwnProfile);
    }
  }

  /// The tab-bar anchor, localized name and icon for a given tab [kind].
  ProfileTab _tabPresentationFor(ProfileTabKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      ProfileTabKind.videos => (
        semanticId: SemanticIds.profileVideosTab,
        label: l10n.profileVideosLabel,
        icon: DivineIconName.play,
      ),
      ProfileTabKind.collabs => (
        semanticId: SemanticIds.profileCollabsTab,
        label: l10n.profileCollabsLabel,
        icon: DivineIconName.users,
      ),
      ProfileTabKind.liked => (
        semanticId: SemanticIds.profileLikedTab,
        label: l10n.profileLikedLabel,
        icon: DivineIconName.heart,
      ),
      ProfileTabKind.reposts => (
        semanticId: SemanticIds.profileRepostsTab,
        label: l10n.profileRepostsLabel,
        icon: DivineIconName.repeat,
      ),
      ProfileTabKind.lists => (
        semanticId: SemanticIds.profileListsTab,
        label: l10n.profileListsLabel,
        icon: DivineIconName.squaresFour,
      ),
      ProfileTabKind.comments => (
        semanticId: SemanticIds.profileCommentsTab,
        label: l10n.profileCommentsLabel,
        icon: DivineIconName.chatCircle,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final followRepository = ref.watch(followRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final includeVideoReplies = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.videoReplies),
    );
    final nostrService = ref.watch(nostrServiceProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final currentUserPubkey = nostrService.publicKey;

    // The Videos tab's BLoC is provided by the ancestor `ProfileFeedScope`, so
    // its revalidation flag is read here (rather than via a stored stream
    // subscription like the tabs created below) to drive the sticky bar.
    final videosRefreshing = context.select<ProfileFeedCubit, bool>(
      (cubit) => cubit.state.isRefreshing,
    );

    final blocsDeps = (
      userIdHex: widget.userIdHex,
      isOwnProfile: widget.isOwnProfile,
      includeVideoReplies: includeVideoReplies,
      currentUserPubkey: currentUserPubkey,
      likesRepository: likesRepository as Object,
      repostsRepository: repostsRepository as Object,
      videosRepository: videosRepository as Object,
      commentsRepository: commentsRepository as Object,
      contentBlocklistRepository: contentBlocklistRepository as Object,
    );

    // Create the tab BLoCs on first build, and recreate them whenever any
    // captured dependency changes identity (profile switch, auth flip,
    // account switch, sign-out, own↔other flip). Store references for
    // refresh capability.
    if (_blocsDeps != blocsDeps) {
      _likedVideosBloc?.close();
      _repostedVideosBloc?.close();
      _collabVideosBloc?.close();
      _commentsBloc?.close();

      // Reset lazy load flags when switching profiles
      _syncedKinds.clear();

      // Create BLoCs but DON'T sync yet - lazy load when tab is viewed
      // VideosRepository handles cache-first lookups via SQLite localStorage
      _likedVideosBloc = ProfileLikedVideosBloc(
        likesRepository: likesRepository,
        videosRepository: videosRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        currentUserPubkey: currentUserPubkey,
        targetUserPubkey: widget.userIdHex,
        removedVideoIds: videosRepository.removedVideoIds,
        deletedVideoFilter: videosRepository.isVideoKnownDeleted,
      )..add(const ProfileLikedVideosSubscriptionRequested());
      // Sync deferred until user views Liked tab

      // Mirror the Liked bloc's refreshing flag so the pinned tab bar can
      // render the sticky revalidation bar.
      _likedRefreshSub?.cancel();
      _likedRefreshing = false;
      _likedRefreshSub = _likedVideosBloc!.stream.listen((likedState) {
        if (likedState.isRefreshing != _likedRefreshing && mounted) {
          setState(() => _likedRefreshing = likedState.isRefreshing);
        }
      });

      _repostedVideosBloc = ProfileRepostedVideosBloc(
        repostsRepository: repostsRepository,
        videosRepository: videosRepository,
        currentUserPubkey: currentUserPubkey,
        targetUserPubkey: widget.userIdHex,
        removedVideoIds: videosRepository.removedVideoIds,
        deletedVideoFilter: videosRepository.isVideoKnownDeleted,
      )..add(const ProfileRepostedVideosSubscriptionRequested());
      // Sync deferred until user views Reposts tab

      _repostsRefreshSub?.cancel();
      _repostsRefreshing = false;
      _repostsRefreshSub = _repostedVideosBloc!.stream.listen((repostsState) {
        if (repostsState.isRefreshing != _repostsRefreshing && mounted) {
          setState(() => _repostsRefreshing = repostsState.isRefreshing);
        }
      });

      // Collabs render on every profile (#5213); Lists is own-profile only.
      _collabVideosBloc = ProfileCollabVideosBloc(
        videosRepository: videosRepository,
        targetUserPubkey: widget.userIdHex,
        removedVideoIds: videosRepository.removedVideoIds,
        deletedVideoFilter: videosRepository.isVideoKnownDeleted,
      );
      _collabsRefreshSub?.cancel();
      _collabsRefreshing = false;
      _collabsRefreshSub = _collabVideosBloc!.stream.listen((collabsState) {
        if (collabsState.isRefreshing != _collabsRefreshing && mounted) {
          setState(() => _collabsRefreshing = collabsState.isRefreshing);
        }
      });

      // Sync deferred until the user views the Collabs tab.

      _commentsBloc = ProfileCommentsBloc(
        commentsRepository: commentsRepository,
        targetUserPubkey: widget.userIdHex,
        includeVideoReplies: includeVideoReplies,
      );
      // Sync deferred until user views Comments tab

      _blocsDeps = blocsDeps;

      // Kick off the lazy sync for the currently selected tab. On a fresh
      // mount this will no-op for tab 0 (videos use [widget.videos] and
      // don't need a bloc sync) and fire the correct sync event for any
      // other restored tab. Deferred to a post-frame callback so we don't
      // emit new BLoC states during this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncCurrentTabIfNeeded();
      });
    }

    // Build the base widget with the tab BLoCs using .value() to provide
    // our managed instances. Collabs is provided on every profile. The tab
    // order is resolved from
    // [_tabKinds].
    final tabContent = MultiBlocProvider(
      providers: [
        BlocProvider<ProfileLikedVideosBloc>.value(value: _likedVideosBloc!),
        BlocProvider<ProfileRepostedVideosBloc>.value(
          value: _repostedVideosBloc!,
        ),
        BlocProvider<ProfileCollabVideosBloc>.value(value: _collabVideosBloc!),
        BlocProvider<ProfileCommentsBloc>.value(value: _commentsBloc!),
      ],
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: TabBarView(
          controller: tabController,
          children: [for (final kind in _tabKinds) _gridForKind(kind)],
        ),
      ),
    );

    final content = RefreshIndicator(
      color: context.vineColors.accentPositive,
      backgroundColor: context.vineColors.surfaceContainer,
      notificationPredicate: (_) => true,
      onRefresh: _refreshProfileContent,
      child: ClipRRect(
        borderRadius: const .vertical(bottom: .circular(30)),
        child: ColoredBox(
          color: context.vineColors.surface,
          child: DefaultTabController(
            length: _tabKinds.length,
            child: NestedScrollView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Profile Header (GlobalKey for measuring height)
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      ProfileBannerLayer(
                        userIdHex: widget.userIdHex,
                        isOwnProfile: widget.isOwnProfile,
                        profile: widget.profile,
                      ),
                      ProfileHeaderWidget(
                        key: _headerKey,
                        userIdHex: widget.userIdHex,
                        isOwnProfile: widget.isOwnProfile,
                        videoCount: widget.videos.length,
                        profile: widget.profile,
                        profileStats: widget.profileStats,
                        onEditProfile: widget.onEditProfile,
                        onBack: widget.onBack,
                        onMore: widget.onMore,
                        displayNameHint: widget.displayNameHint,
                        avatarUrlHint: widget.avatarUrlHint,
                        displayName: widget.displayName,
                        onOpenClips: widget.onOpenClips,
                        onMessageUser: widget.onMessageUser,
                        isMessageRestricted: widget.isMessageRestricted,
                        onShareProfile: widget.onShareProfile,
                        onBlockedTap: widget.onBlockedTap,
                      ),
                    ],
                  ),
                ),

                // Sticky Tab Bar
                ProfileTabBar(
                  controller: tabController,
                  scrollController: widget.scrollController,
                  tabs: [
                    for (final kind in _tabKinds) _tabPresentationFor(kind),
                  ],
                  headerKey: _headerKey,
                  // Sticky cache-revalidation bar for the active cached tab.
                  isRefreshing: _activeTabRefreshing(videosRefreshing),
                ),
              ],
              body: tabContent,
            ),
          ),
        ),
      ),
    );

    // Provide OthersFollowersBloc only for other profiles so the follow
    // button can optimistically update the followers count after a
    // follow/unfollow action.
    if (!widget.isOwnProfile) {
      return BlocProvider<OthersFollowersBloc>(
        key: ValueKey((
          followRepository,
          contentBlocklistRepository,
          currentUserPubkey,
          widget.userIdHex,
        )),
        create: (_) => OthersFollowersBloc(
          followRepository: followRepository,
          contentBlocklistRepository: contentBlocklistRepository,
          currentUserPubkey: currentUserPubkey,
        )..add(OthersFollowersListLoadRequested(widget.userIdHex)),
        child: content,
      );
    }

    return content;
  }
}
