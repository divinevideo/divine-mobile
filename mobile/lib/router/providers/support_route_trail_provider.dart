// ABOUTME: Retains recent route types for bug reports and exported diagnostics
// ABOUTME: Excludes support routes so opening the report form preserves context

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/providers/router_location_provider.dart';
import 'package:openvine/router/route_paths.dart';

const _maxSupportRouteTrailLength = 5;

/// A parameter-free snapshot safe to include in support diagnostics.
class SupportRouteSnapshot {
  const SupportRouteSnapshot({
    required this.currentScreen,
    required this.recentScreens,
  });

  final String? currentScreen;
  final List<String> recentScreens;
}

/// Retains the route trail from before the user entered the Support Center.
///
/// This provider must be activated at app startup. Starting it when the report
/// form opens would lose every route that the diagnostic is meant to retain.
class SupportRouteTrail extends Notifier<List<RouteType>> {
  @override
  List<RouteType> build() {
    ref.listen(routerLocationProvider, (_, next) {
      final location = next.asData?.value;
      if (location != null) _record(location);
    });

    final initialLocation = ref.read(routerLocationProvider).asData?.value;
    if (initialLocation == null) return const [];
    return _updatedTrail(const [], initialLocation);
  }

  SupportRouteSnapshot get snapshot => SupportRouteSnapshot(
    currentScreen: state.isEmpty ? null : state.last.name,
    recentScreens: List.unmodifiable(state.map((route) => route.name)),
  );

  void _record(String location) {
    final updated = _updatedTrail(state, location);
    if (!identical(updated, state)) state = updated;
  }

  static List<RouteType> _updatedTrail(
    List<RouteType> current,
    String location,
  ) {
    final uri = Uri.tryParse(location);
    if (uri == null || _isSupportPath(uri.path)) return current;

    final route = parseKnownRoute(uri.path)?.type;
    if (route == null || (current.isNotEmpty && current.last == route)) {
      return current;
    }

    final updated = [...current, route];
    if (updated.length > _maxSupportRouteTrailLength) {
      updated.removeRange(0, updated.length - _maxSupportRouteTrailLength);
    }
    return List.unmodifiable(updated);
  }

  static bool _isSupportPath(String path) =>
      path == RoutePaths.supportCenter ||
      path.startsWith('${RoutePaths.supportCenter}/');
}

final supportRouteTrailProvider =
    NotifierProvider<SupportRouteTrail, List<RouteType>>(SupportRouteTrail.new);
