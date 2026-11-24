// ABOUTME: Root back button dispatcher that answers a system back itself when
// ABOUTME: go_router has no route matched, where its popRoute throws.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';

/// The [RootBackButtonDispatcher] the app's [Router] is given.
///
/// go_router 18.0.1's `GoRouterDelegate.popRoute` reads
/// `currentConfiguration.matches.last` without an empty check, so a system
/// back throws `Bad state: No element` whenever nothing is matched: on the
/// not-found page for a location entered with `go` or a deep link, while the
/// first location is still resolving, and after the last page was popped.
///
/// With no matches there is nothing for go_router to pop, so this answers the
/// back itself. The not-found page goes to the home feed, as its own button
/// does; anything else is left to the platform, as go_router does on a root
/// page it cannot pop.
class EmptyMatchSafeBackButtonDispatcher extends RootBackButtonDispatcher {
  /// Creates a dispatcher for [router]'s delegate.
  EmptyMatchSafeBackButtonDispatcher(this._router);

  final GoRouter _router;

  @override
  Future<bool> didPopRoute() {
    final configuration = _router.routerDelegate.currentConfiguration;
    if (configuration.matches.isNotEmpty) return super.didPopRoute();
    if (!configuration.isError) return SynchronousFuture<bool>(false);
    _router.go(RoutePaths.videoFeedForIndex(0));
    return SynchronousFuture<bool>(true);
  }
}
