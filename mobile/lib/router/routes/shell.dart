// ABOUTME: Bottom-nav StatefulShellRoute (home/explore/inbox/profile branches)
// ABOUTME: Split from app_router.dart (#4508); owns per-branch pageContext scoping
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/startup/app_side_effects.dart';

List<RouteBase> shellRoutes() {
  return [
    // Bottom-nav tabs live in a StatefulShellRoute so every tab keeps its
    // own Navigator (and state) alive while inactive — that is what lets the
    // tab switch cross-fade between two live tabs (see AppShellBranchContainer).
    //
    // Each branch screen reads the *globally-active* route via
    // pageContextProvider and renders a placeholder when it doesn't match.
    // Because all branches stay mounted, [branchPage] scopes
    // pageContextProvider per branch so each tab sees *its own* route context
    // (not the active tab's) and keeps rendering real content while inactive.
    StatefulShellRoute(
      // go_router 17 started notifying the root observers from inside a
      // shell's branch navigators, and its 18.x line is what the
      // material_ui migration needs (#8916). Taking the new default would
      // make root observers emit screen-view and page-load events for every
      // in-branch push. That is a product-analytics decision, not a side
      // effect of a design-system migration, so behaviour is pinned here
      // until #9079 is decided deliberately.
      notifyRootObserver: false,
      // Transition-free on purpose: the shell replaces `/welcome` on the root
      // navigator when the authenticated redirect lands (startup restore,
      // login), and the startup splash lifts at the *start* of that
      // navigation. A default MaterialPage here plays a ~400ms slide that
      // shows the welcome screen exiting — the "sign-in page glimpse" of
      // #5242 in its post-splash form. Pinned by shell_transition_test.
      pageBuilder: (context, state, navigationShell) => NoTransitionPage<void>(
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
          // Provided above AppShell so both consumers can reach the same
          // instance: VineBottomNav (inside AppShell) signals a home-tab retap
          // and renders the refresh spinner; VideoFeedView (inside the home
          // branch) listens and performs the refresh.
          child: BlocProvider<HomeFeedRetapCubit>(
            create: (_) => HomeFeedRetapCubit(),
            child: AppShell(
              currentIndex: navigationShell.currentIndex,
              child: navigationShell,
            ),
          ),
        ),
      ),
      navigatorContainerBuilder: (context, navigationShell, children) =>
          AppShellBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          ),
      branches: [
        // HOME tab
        StatefulShellBranch(
          navigatorKey: NavigatorKeys.home,
          initialLocation: VideoFeedPage.pathForIndex(0),
          routes: [
            GoRoute(
              path: RoutePaths.followingNew,
              // This contract location intentionally parses as RouteType.following
              // while rendering the home branch's Following feed. Keep the exact
              // literal ahead of /following/:pubkey so `new` is never treated as
              // an account identifier.
              pageBuilder: (ctx, st) => _branchPage(
                st,
                const VideoFeedPage(initialMode: FeedMode.following),
              ),
            ),
            GoRoute(
              path: VideoFeedPage.pathWithIndex,
              name: VideoFeedPage.routeName,
              pageBuilder: (ctx, st) => branchPage(
                st,
                VideoFeedPage(
                  initialIndex: homeInitialIndexFromPathParameters(
                    st.pathParameters,
                  ),
                ),
              ),
            ),
          ],
        ),

        // EXPLORE tab (grid + tab-by-name + feed)
        StatefulShellBranch(
          navigatorKey: NavigatorKeys.explore,
          initialLocation: ExploreScreen.path,
          routes: [
            GoRoute(
              path: ExploreScreen.path,
              name: ExploreScreen.routeName,
              pageBuilder: (ctx, st) => branchPage(st, const ExploreScreen()),
            ),
            GoRoute(
              path: ExploreScreen.pathTabSubpath,
              pageBuilder: (_, st) {
                final slug = st.pathParameters['name'];
                final tabName = ExploreScreen.tabNameFromPathParameter(slug);
                return branchPage(
                  st,
                  ExploreScreen(initialTabName: tabName, initialTabSlug: slug),
                );
              },
            ),
            GoRoute(
              path: ExploreScreen.pathWithIndex,
              pageBuilder: (ctx, st) => branchPage(st, const ExploreScreen()),
            ),
          ],
        ),

        // INBOX tab (inbox + notifications share tab position 2)
        StatefulShellBranch(
          navigatorKey: NavigatorKeys.inbox,
          initialLocation: InboxPage.path,
          routes: [
            GoRoute(
              path: NotificationsPage.pathWithIndex,
              name: NotificationsPage.routeName,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const NotificationsPage()),
            ),
            GoRoute(
              path: InboxPage.path,
              name: InboxPage.routeName,
              pageBuilder: (ctx, st) => branchPage(st, const InboxPage()),
            ),
          ],
        ),

        // PROFILE tab (own profile grid/feed + liked-videos)
        StatefulShellBranch(
          navigatorKey: NavigatorKeys.profile,
          initialLocation: ProfileScreenRouter.path,
          routes: [
            GoRoute(
              path: ProfileScreenRouter.path,
              name: ProfileScreenRouter.routeName,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const ProfileScreenRouter()),
            ),
            GoRoute(
              path: ProfileScreenRouter.pathWithNpub,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const ProfileScreenRouter()),
            ),
            GoRoute(
              path: ProfileScreenRouter.pathWithIndex,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const ProfileScreenRouter()),
            ),
            GoRoute(
              path: LikedVideosScreenRouter.path,
              name: LikedVideosScreenRouter.routeName,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const LikedVideosScreenRouter()),
            ),
            GoRoute(
              path: LikedVideosScreenRouter.pathWithIndex,
              pageBuilder: (ctx, st) =>
                  branchPage(st, const LikedVideosScreenRouter()),
            ),
          ],
        ),
      ],
    ),
  ];
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
