// ABOUTME: Shared CustomTransitionPage with the classic fade-upwards
// ABOUTME: transition (pre-Pie Android) for modal creation/library flows

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// Wraps [child] in a page that fades in while sliding up the last
/// quarter — the classic pre-Pie Android transition.
///
/// Mirrors go_router's default page metadata (`name`, `arguments`,
/// `restorationId`) from [state] so root-navigator observers such as
/// `PageLoadObserver` keep resolving a real route name instead of
/// `unknown_route`. Call it from a route's `pageBuilder`.
CustomTransitionPage<void> fadeUpwardsPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: goRouterPageName(state),
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    child: child,
    // It brings its own transition, so the theme's frame never reaches it:
    // framed here, as the theme's page routes are, the page ends before a
    // status bar column and the column stays put while the page fades in.
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        StatusBarColumnFrame(
          child: const FadeUpwardsPageTransitionsBuilder()
              .buildTransitions<void>(
                null,
                context,
                animation,
                secondaryAnimation,
                child,
              ),
        ),
  );
}
