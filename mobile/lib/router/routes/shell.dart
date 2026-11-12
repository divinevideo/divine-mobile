// ABOUTME: Bottom-nav StatefulShellRoute (home/explore/inbox/profile branches)
// ABOUTME: Typed with go_router_builder; owns per-branch pageContext scoping

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_tab_retap_cubit.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart' show FeedMode;
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/router_guards.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_unavailable_pins_screen.dart';
import 'package:openvine/startup/app_side_effects.dart';
import 'package:openvine/widgets/age_review_closure_launch_notice.dart';

part 'shell.g.dart';

/// The bottom-nav shell: the generated [AppShellRouteData] route, rebuilt with
/// `notifyRootObserver: false`.
///
/// go_router 18.0.1's `StatefulShellRouteData.$route` takes no
/// `notifyRootObserver` (flutter/packages#13323 adds it), and
/// go_router_builder 4.5.2 never reads
/// [TypedStatefulShellRoute.notifyRootObserver], so the generated route keeps
/// the default `true` and would forward branch navigation to the root
/// observers. The wrapper can go once both are fixed. Every other argument is
/// copied from the generated route.
List<RouteBase> shellRoutes() {
  final generated = $appRoutes.single as StatefulShellRoute;
  return [
    StatefulShellRoute(
      // Branch events are navigator lifecycle rather than reliable user
      // arrivals, so root analytics deliberately observes only the shell page
      // and routes above it; see docs/ANALYTICS_OBSERVABILITY.md.
      notifyRootObserver: false,
      branches: generated.branches,
      redirect: generated.redirect,
      builder: generated.builder,
      pageBuilder: generated.pageBuilder,
      navigatorContainerBuilder: generated.navigatorContainerBuilder,
      parentNavigatorKey: generated.parentNavigatorKey,
      restorationScopeId: generated.restorationScopeId,
      metadata: generated.metadata,
    ),
  ];
}

/// Bottom-nav tabs live in a StatefulShellRoute so every tab keeps its own
/// Navigator (and state) alive while inactive — that is what lets the tab
/// switch cross-fade between two live tabs (see [AppShellBranchContainer]).
///
/// Each branch screen reads the *globally-active* route via
/// pageContextProvider and renders a placeholder when it doesn't match.
/// Because all branches stay mounted, [branchPage] scopes pageContextProvider
/// per branch so each tab sees *its own* route context (not the active tab's)
/// and keeps rendering real content while inactive.
@TypedStatefulShellRoute<AppShellRouteData>(
  // Not read by go_router_builder 4.5.2; shellRoutes applies it.
  notifyRootObserver: false,
  branches: [
    TypedStatefulShellBranch<HomeBranchData>(
      routes: [
        TypedGoRoute<FollowingNewRouteData>(path: RoutePaths.followingNew),
        TypedGoRoute<HomeFeedRouteData>(
          path: VideoFeedPage.pathWithIndex,
          name: VideoFeedPage.routeName,
        ),
      ],
    ),
    TypedStatefulShellBranch<ExploreBranchData>(
      routes: [
        TypedGoRoute<ExploreRouteData>(
          path: ExploreScreen.path,
          name: ExploreScreen.routeName,
        ),
        TypedGoRoute<ExploreTabRouteData>(path: ExploreScreen.pathTabSubpath),
        TypedGoRoute<ExploreFeedRouteData>(path: ExploreScreen.pathWithIndex),
      ],
    ),
    TypedStatefulShellBranch<InboxBranchData>(
      routes: [
        TypedGoRoute<NotificationsRouteData>(
          path: NotificationsPage.pathWithIndex,
          name: NotificationsPage.routeName,
        ),
        TypedGoRoute<InboxRouteData>(
          path: InboxPage.path,
          name: InboxPage.routeName,
        ),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranchData>(
      routes: [
        // Ahead of /profile/:npub/:index, which would otherwise match this
        // location and read `unavailable-pins` as a video index.
        TypedGoRoute<ProfileUnavailablePinsRouteData>(
          path: RoutePaths.profileUnavailablePins,
        ),
        TypedGoRoute<ProfileRouteData>(
          path: ProfileScreenRouter.path,
          name: ProfileScreenRouter.routeName,
        ),
        TypedGoRoute<ProfileGridRouteData>(
          path: ProfileScreenRouter.pathWithNpub,
        ),
        TypedGoRoute<ProfileFeedRouteData>(
          path: ProfileScreenRouter.pathWithIndex,
        ),
      ],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  const AppShellRouteData();

  // Transition-free on purpose: the shell replaces `/welcome` on the root
  // navigator when the authenticated redirect lands (startup restore, login),
  // and the startup splash lifts at the *start* of that navigation. A default
  // MaterialPage here plays a ~400ms slide that shows the welcome screen
  // exiting — the "sign-in page glimpse" of #5242 in its post-splash form.
  // Pinned by shell_transition_test.
  @override
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => NoTransitionPage<void>(
    key: state.pageKey,
    name: goRouterPageName(state),
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    // The shell-tier app-wide side effects are activated here rather than
    // inside AppShell so the shell widget stays pure chrome — see
    // AppShellSideEffects for the membership rule.
    child: AppShellSideEffects(
      // Explains an age-review closure as soon as a closed account opens
      // the app, instead of waiting for a rejected post.
      child: AgeReviewClosureLaunchNotice(
        // Provided above AppShell so both consumers can reach the same
        // instance: VineBottomNav (inside AppShell) signals a home-tab or
        // profile-tab retap; the home branch refreshes its feed and the
        // profile branch retries a failed load.
        child: BlocProvider<HomeFeedRetapCubit>(
          create: (_) => HomeFeedRetapCubit(),
          child: BlocProvider<ProfileTabRetapCubit>(
            create: (_) => ProfileTabRetapCubit(),
            child: AppShell(
              currentIndex: navigationShell.currentIndex,
              child: navigationShell,
            ),
          ),
        ),
      ),
    ),
  );

  static Widget $navigatorContainerBuilder(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) => AppShellBranchContainer(
    currentIndex: navigationShell.currentIndex,
    children: children,
  );
}

/// The home tab: the feed, and the campaign landing on Following.
class HomeBranchData extends StatefulShellBranchData {
  const HomeBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = NavigatorKeys.home;
  static final String $initialLocation = VideoFeedPage.pathForIndex(0);
}

/// The explore tab: the grid, a tab chosen by name, and the feed.
class ExploreBranchData extends StatefulShellBranchData {
  const ExploreBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = NavigatorKeys.explore;
  static const String $initialLocation = ExploreScreen.path;
}

/// The inbox tab, which notifications share.
class InboxBranchData extends StatefulShellBranchData {
  const InboxBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = NavigatorKeys.inbox;
  static const String $initialLocation = InboxPage.path;
}

/// The own-profile tab: the grid and the feed.
class ProfileBranchData extends StatefulShellBranchData {
  const ProfileBranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = NavigatorKeys.profile;
  static const String $initialLocation = ProfileScreenRouter.path;
}

/// The campaign landing, rendered as the home branch's Following feed.
///
/// This contract location intentionally parses as RouteType.following while
/// rendering the home branch's Following feed. Keep the exact literal ahead of
/// /following/:pubkey so `new` is never treated as an account identifier.
class FollowingNewRouteData extends GoRouteData with $FollowingNewRouteData {
  const FollowingNewRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => branchPage(
    state,
    const VideoFeedPage(
      initialMode: FeedMode.following,
      // A campaign tap must land on Following whatever the account's saved
      // home source is; the forced start is not persisted back (see
      // VideoFeedStarted.forceMode).
      forceInitialMode: true,
    ),
  );
}

/// The home feed at a video index.
class HomeFeedRouteData extends GoRouteData with $HomeFeedRouteData {
  const HomeFeedRouteData({required this.index});

  /// The video index as written in the URL; [buildPage] parses it with
  /// [homeInitialIndexFromPathParameters], which starts a malformed or
  /// negative index at the first video.
  final String index;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => branchPage(
    state,
    VideoFeedPage(
      initialIndex: homeInitialIndexFromPathParameters(state.pathParameters),
    ),
  );
}

/// The explore grid on its default tab.
class ExploreRouteData extends GoRouteData with $ExploreRouteData {
  const ExploreRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const ExploreScreen());
}

/// An explore tab chosen by its URL slug.
class ExploreTabRouteData extends GoRouteData with $ExploreTabRouteData {
  const ExploreTabRouteData({required this.name});

  /// The tab's URL slug. An unknown or currently unconfigured slug opens the
  /// default tab rather than an error, and is kept for a featured tab whose
  /// configuration arrives later.
  final String name;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => branchPage(
    state,
    ExploreScreen(
      initialTabName: ExploreScreen.tabNameFromPathParameter(name),
      initialTabSlug: name,
    ),
  );
}

/// The explore feed at a video index.
///
/// The screen reads the index from its branch's route context ([branchPage]),
/// not from [index].
class ExploreFeedRouteData extends GoRouteData with $ExploreFeedRouteData {
  const ExploreFeedRouteData({required this.index});

  final String index;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const ExploreScreen());
}

/// Notifications, in the inbox tab. The page does not read [index].
class NotificationsRouteData extends GoRouteData with $NotificationsRouteData {
  const NotificationsRouteData({required this.index});

  final String index;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const NotificationsPage());
}

/// The inbox.
class InboxRouteData extends GoRouteData with $InboxRouteData {
  const InboxRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const InboxPage());
}

/// The owner's recovery page for pinned videos that no longer resolve; the
/// page itself turns away anyone but the owner of [npub].
class ProfileUnavailablePinsRouteData extends GoRouteData
    with $ProfileUnavailablePinsRouteData {
  const ProfileUnavailablePinsRouteData({required this.npub});

  final String npub;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, ProfileUnavailablePinsPage(npub: npub));
}

/// The profile tab's root.
class ProfileRouteData extends GoRouteData with $ProfileRouteData {
  const ProfileRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const ProfileScreenRouter());
}

/// A profile's grid.
///
/// The screen reads the npub from its branch's route context ([branchPage]),
/// not from [npub].
class ProfileGridRouteData extends GoRouteData with $ProfileGridRouteData {
  const ProfileGridRouteData({required this.npub});

  final String npub;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const ProfileScreenRouter());
}

/// A profile's feed at a video index.
///
/// The screen reads the npub and index from its branch's route context
/// ([branchPage]), not from [npub] and [index].
class ProfileFeedRouteData extends GoRouteData with $ProfileFeedRouteData {
  const ProfileFeedRouteData({required this.npub, required this.index});

  final String npub;
  final String index;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      branchPage(state, const ProfileScreenRouter());
}

/// Builds a [StatefulShellBranch] page whose subtree sees its *own* route's
/// [RouteContext] via a scoped [pageContextProvider], rather than the
/// globally-active route's.
///
/// `StatefulShellRoute` keeps every branch mounted, but the tab screens gate
/// their content on the global [pageContextProvider] (they render a
/// placeholder when its type doesn't match). Without this scope an inactive
/// branch would see the active tab's context and blank out — breaking both
/// state preservation and the live cross-fade. Scoping per branch makes each
/// tab keep rendering its real content while inactive. [NoTransitionPage]
/// keeps within-branch navigation (e.g. grid → feed) instant; the *between
/// tab* cross-fade is done by [AppShellBranchContainer].
///
/// Scoping caveat: only a *direct* `ref.watch(pageContextProvider)` from a
/// widget in this subtree observes the branch-local override. A root-level
/// provider that derives from [pageContextProvider] (e.g.
/// [activeVideoIdProvider]) is instantiated in the root container
/// and therefore always reads the *global* route — by design, since playback
/// gating must follow the genuinely-active tab. Any new provider that reads
/// [pageContextProvider] inherits this global behaviour even when consumed
/// inside a branch; reach for the scoped value only via a direct widget read.
@visibleForTesting
Page<void> branchPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    name: goRouterPageName(state),
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    // Keyed on the route's SUBJECT, not on `state.pageKey`. go_router keys a
    // page on the route *pattern* — `newMatchedPath` is built from
    // `route.path`, so `/profile/<a>` and `/profile/<b>` both come back as
    // `ValueKey('/profile/:npub')`. Without a key of its own this scope is
    // never re-created when only a path parameter changes, and the
    // single-value override below keeps replaying the first subject the
    // branch ever rendered: the shell's app bar follows the live route while
    // the branch body stays on the previous account.
    //
    // Not the whole path, because two feeds rewrite their own URL on every
    // swipe (`ExploreFeedContent` and `ProfileVideoFeedView` both call
    // `context.go` from `onPageChanged`); a path key would dispose their
    // players and scroll position mid-swipe. `subjectKey` excludes the video
    // index for exactly that reason.
    //
    // Neither key weakens the freeze this scope exists for: an inactive
    // branch is not rebuilt at all, so its key cannot change and it goes on
    // rendering its own content.
    child: ProviderScope(
      key: ValueKey(parseRoute(state.uri.path).subjectKey),
      overrides: [
        pageContextProvider.overrideWith(
          (ref) => Stream<RouteContext>.value(parseRoute(state.uri.path)),
        ),
      ],
      child: child,
    ),
  );
}
