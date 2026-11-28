// ABOUTME: Typed full-screen route for permanent and optional people discovery.
// ABOUTME: Direct links honor the internal feature flag as well as entry points.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/find_people/find_people_page.dart';

part 'find_people_routes.g.dart';

List<RouteBase> findPeopleRoutes() => $appRoutes;

@TypedGoRoute<FindPeopleRouteData>(path: RoutePaths.findPeople)
class FindPeopleRouteData extends GoRouteData with $FindPeopleRouteData {
  const FindPeopleRouteData({this.source});
  final String? source;

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(isFeatureEnabledProvider(FeatureFlag.findPeople))
      ? null
      : RoutePaths.root;

  @override
  Widget build(BuildContext context, GoRouterState state) => FindPeoplePage(
    source: source == 'onboarding' ? 'onboarding' : 'findPeople',
  );
}
