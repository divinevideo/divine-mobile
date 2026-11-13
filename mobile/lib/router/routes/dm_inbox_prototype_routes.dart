// ABOUTME: PROTOTYPE (#8076): the four-tab DM inbox on fixture data.
// ABOUTME: Registered only in debug builds; remove with the prototype.

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';

part 'dm_inbox_prototype_routes.g.dart';

/// The prototype's routes, registered only when [enabled].
///
/// Defaults to debug builds, matching the Developer Options tile: hiding the
/// tile alone would leave the path reachable by typed URL. The caller also
/// gates on [kDebugMode], because only a const condition at the call site
/// keeps the prototype out of a release binary.
List<RouteBase> dmInboxPrototypeRoutes({bool enabled = kDebugMode}) =>
    enabled ? $appRoutes : const [];

@TypedGoRoute<DmInboxPrototypeRouteData>(
  path: DmInboxTabsPrototypeScreen.path,
  name: DmInboxTabsPrototypeScreen.routeName,
)
class DmInboxPrototypeRouteData extends GoRouteData
    with $DmInboxPrototypeRouteData {
  const DmInboxPrototypeRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DmInboxTabsPrototypeScreen();
}
