// ABOUTME: Finds creation sessions beneath a pushed page before replacing their media.

import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';

/// Whether a recorder, editor or metadata page still owns a live session
/// anywhere in the router's stack, including shell and imperative pushes.
bool hasCreationSessionInRouteStack(RouteMatchList configuration) =>
    _containsCreationRoute(configuration.matches);

bool _containsCreationRoute(List<RouteMatchBase> matches) {
  for (final match in matches) {
    final route = match.route;
    if (route is GoRoute &&
        const {
          RoutePaths.videoRecorder,
          RoutePaths.videoEditor,
          RoutePaths.videoMetadata,
        }.contains(route.path)) {
      return true;
    }
    if (match is ImperativeRouteMatch &&
        _containsCreationRoute(match.matches.matches)) {
      return true;
    }
    if (match is ShellRouteMatch && _containsCreationRoute(match.matches)) {
      return true;
    }
  }
  return false;
}
