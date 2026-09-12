// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title uses Bricolage Grotesque font, camera button in bottom nav

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/navigation/back_navigation_executor.dart';
import 'package:openvine/router/navigation/back_navigation_policy.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/shell/shell_chrome.dart';
import 'package:openvine/router/shell/shell_title_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Duration of the cross-fade applied when switching between bottom-nav tabs.
/// Kept short so tab switches stay snappy.
const Duration _kTabFadeDuration = Duration(milliseconds: 120);

/// Resolves the route context the shell chrome (app bar) should render for,
/// plus the value the caller must cache for the next build.
///
/// While a full-screen route is pushed above the whole shell —
/// [isShellCovered] true, i.e. the shell's `ModalRoute.isCurrent` is false —
/// the global pageContext points at that pushed route (camera, editor, …)
/// rather than the active tab underneath. Rendering the chrome off it would
/// pop a suppressed app bar (own-profile grid, inbox) in and out for the
/// length of the push/pop transition, shoving the still-visible tab content
/// down. So while covered the chrome freezes to [lastTabContext] — the last
/// context seen while the shell was on top — and the cache is left untouched.
({RouteContext? context, RouteContext? nextCache}) resolveShellChromeContext({
  required bool isShellCovered,
  required RouteContext? liveContext,
  required RouteContext? lastTabContext,
}) {
  if (isShellCovered) {
    return (context: lastTabContext ?? liveContext, nextCache: lastTabContext);
  }
  return (context: liveContext, nextCache: liveContext ?? lastTabContext);
}

/// Shell chrome (app bar + bottom nav) wrapped around the [StatefulShellRoute]
/// branch container.
///
/// [child] is the `StatefulNavigationShell` (rendered via
/// [AppShellBranchContainer]); [currentIndex] is its active branch. AppShell
/// itself no longer animates the tab switch — the cross-fade lives in
/// [AppShellBranchContainer], which keeps every branch alive.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, required this.currentIndex, super.key});

  final Widget child;
  final int currentIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with RouteAware {
  int get currentIndex => widget.currentIndex;
  Widget get child => widget.child;

  /// Last route context observed while the shell was the top-most route.
  ///
  /// Used to freeze the chrome (app bar) while a full-screen route is pushed
  /// above the shell — see the note in [build] — so the global pageContext
  /// flipping to the pushed route can't pop the app bar in/out mid-transition.
  RouteContext? _lastTabRouteContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Observe the root navigator so the home feed knows when a full-screen
    // route (profile, fullscreen video, recorder) covers the shell. The
    // subscription is keyed on the shell's own route, so didPopNext only fires
    // when the route directly above the shell is popped — not when a route
    // above another pushed route closes.
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _setShellObscured({
    required bool obscured,
    bool clearOverlayOwners = false,
  }) {
    // RouteAware callbacks can fire mid-frame; defer the provider write so it
    // never lands during this shell's own build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellObscuredProvider.notifier).setObscured(obscured: obscured);
      if (!obscured) {
        final overlayVisibility = ref.read(overlayVisibilityProvider.notifier);
        if (clearOverlayOwners) {
          // Force-clear the page owners because a `go()`-style back can skip a
          // pushed route's own completion callback (#6239): go_router completes
          // an `ImperativeRouteMatch` only on the pop path, so the
          // `pushWithVideoPause` completer never fires and its token strands.
          //
          // Page owners only. A popped route above the shell does *not* prove
          // no overlay owner remains: a pause-aware sheet with
          // `useRootNavigator: false` lives on a branch navigator, so the shell
          // stays the top root route while that sheet is on screen. Clearing
          // sheet owners here destroyed that live hold and resumed playback
          // behind the visible sheet. A sheet token is released by its own
          // route's dismiss callback and cannot strand the way a `go()`-removed
          // page token does, so it never needed clearing here.
          overlayVisibility.clearPageOpen();
        } else if (ModalRoute.of(context)?.isCurrent ?? false) {
          // `didPush` runs when this shell route is newly installed, before a
          // branch-navigator sheet belonging to this shell can exist. Clear
          // stale owners only when the fresh shell is also the top root route;
          // otherwise it may still sit below a live page owner.
          overlayVisibility.clearOverlays();
        }
      }
    });
  }

  // Resets the flag whenever a fresh shell mounts. Without this, a stale
  // `true` survives when the shell is removed while covered and later
  // re-shown without a pop event reaching it (e.g. sign-out navigates to
  // /welcome, then the user returns home) — the home feed would stay paused.
  @override
  void didPush() => _setShellObscured(obscured: false);

  @override
  void didPushNext() => _setShellObscured(obscured: true);

  @override
  void didPopNext() =>
      _setShellObscured(obscured: false, clearOverlayOwners: true);

  String? _currentUserNpub() {
    final hex = ref.read(authServiceProvider).currentPublicKeyHex;
    return hex == null ? null : NostrKeyUtils.encodePubKey(hex);
  }

  /// Runs the shared back policy for the app-bar back button.
  void _handleAppBarBack() {
    Log.info(
      '👆 User tapped back button',
      name: 'Navigation',
      category: LogCategory.ui,
    );
    final router = GoRouter.of(context);
    final tabHistory = ref.read(tabHistoryProvider.notifier);
    final previousTab = tabHistory.getPreviousTab();
    executeBackAction(
      resolveBackAction(
        context: ref.read(pageContextProvider).asData?.value,
        canPop: router.canPop(),
        previousTab: previousTab,
        lastIndexForPreviousTab: previousTab == null
            ? null
            : ref
                  .read(lastTabPositionProvider.notifier)
                  .recordedPosition(routeTypeForTab(previousTab)),
        currentUserNpub: previousTab == 3 ? _currentUserNpub() : null,
      ),
      router: router,
      tabHistory: tabHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Publish the authoritative active branch (navigationShell.currentIndex)
    // so backgrounded tab screens can pause off it. Deferred to a post-frame
    // callback because a provider must not be mutated during build. This is
    // the platform-agnostic source — the URL-derived pageContext can lag on
    // web for StatefulShellRoute branch switches, which left the home feed
    // playing on other tabs there.
    final activeIndex = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(activeBranchIndexProvider.notifier);
      if (notifier.state != activeIndex) notifier.state = activeIndex;
    });

    // The shell chrome (app bar) mirrors the *active tab's* route. While a
    // full-screen route is pushed above the whole shell (camera, editor,
    // video detail, …) the global pageContext points at that pushed route,
    // not the tab underneath. Recomputing the chrome off it makes a
    // suppressed app bar (own-profile grid, inbox) pop in for the length of
    // the push/pop transition, shoving the still-visible tab content down.
    // Freeze the chrome to the last tab context while the shell is covered so
    // the transition stays still. `isCurrent` is false exactly when a route
    // sits on top of the shell (it also gates resizeToAvoidBottomInset below).
    final shellRoute = ModalRoute.of(context);
    final isShellCovered = !(shellRoute?.isCurrent ?? true);
    final pageCtxAsync = ref.watch(pageContextProvider);
    final chrome = resolveShellChromeContext(
      isShellCovered: isShellCovered,
      liveContext: pageCtxAsync.asData?.value,
      lastTabContext: _lastTabRouteContext,
    );
    _lastTabRouteContext = chrome.nextCache;
    final chromeCtx = chrome.context;

    final profilePubkeyHex = shellTitleProfilePubkeyHex(chromeCtx);
    final title = resolveShellTitle(
      l10n: context.l10n,
      context: chromeCtx,
      exploreTabName:
          chromeCtx?.type == RouteType.explore && chromeCtx?.videoIndex != null
          ? ref.watch(exploreTabNameProvider)
          : null,
      profileDisplayName: profilePubkeyHex == null
          ? null
          : ref
                .watch(fetchUserProfileProvider(profilePubkeyHex))
                .value
                ?.displayName,
    );

    final showBackButton = shellShowsBackButton(
      context: chromeCtx,
      currentUserHex: ref.read(authServiceProvider).currentPublicKeyHex,
    );

    return ShellChrome(
      currentIndex: currentIndex,
      title: title,
      routeContext: chromeCtx,
      suppressAppBar: shellSuppressesAppBar(
        context: chromeCtx,
        currentIndex: currentIndex,
        currentUserHex: ref.read(authServiceProvider).currentPublicKeyHex,
      ),
      showBackButton: showBackButton,
      resizeToAvoidBottomInset: shellRoute?.isCurrent ?? true,
      onBackPressed: _handleAppBarBack,
      child: child,
    );
  }
}

/// Cross-fades between the [StatefulShellRoute] branch navigators.
///
/// Every branch stays mounted (state preserved); the active branch is fully
/// opaque and interactive, the others sit at opacity 0 with their tickers
/// paused, pointer events ignored, and — crucially — excluded from the
/// semantics and focus trees. `Opacity`/`IgnorePointer` alone do not hide a
/// subtree from screen readers or focus traversal, so without
/// [ExcludeSemantics]/[ExcludeFocus] the three hidden tabs would still be
/// announced and focusable. On a tab switch the outgoing branch fades out
/// while the incoming one fades in — a true cross-fade between two live tabs.
/// Within-tab navigation never reaches here (those are [NoTransitionPage]s
/// inside a single branch).
class AppShellBranchContainer extends StatelessWidget {
  const AppShellBranchContainer({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  /// Index (in [children]) of the branch navigator to display.
  final int currentIndex;

  /// The branch navigators, one per [StatefulShellBranch], kept alive.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _kTabFadeDuration;
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (index) {
        final isActive = index == currentIndex;
        return AnimatedOpacity(
          opacity: isActive ? 1 : 0,
          duration: duration,
          curve: Curves.easeInOut,
          child: ExcludeSemantics(
            excluding: !isActive,
            child: ExcludeFocus(
              excluding: !isActive,
              child: IgnorePointer(
                ignoring: !isActive,
                child: TickerMode(enabled: isActive, child: children[index]),
              ),
            ),
          ),
        );
      }),
    );
  }
}
