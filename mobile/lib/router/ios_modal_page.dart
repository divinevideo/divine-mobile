// ABOUTME: Shared MaterialPage that presents as a full-screen modal on iOS
// ABOUTME: only, leaving the Android page transition untouched

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/go_router_page_name.dart';

/// Wraps [child] in a page that presents as a full-screen modal on iOS and as a
/// regular page everywhere else.
///
/// On iOS the full-screen-dialog flag selects Cupertino's slide-up transition.
/// That also disables the edge back-swipe and holds the screen behind still.
/// It stays `false` on Android, where Material would freeze the screen behind
/// during the transition.
///
/// Mirrors go_router's default page metadata (`name`, `arguments`,
/// `restorationId`) from [state] so root-navigator observers such as
/// `PageLoadObserver` keep resolving a real route name instead of
/// `unknown_route`. Call it from a route's `pageBuilder`. [platform] overrides
/// [defaultTargetPlatform], for tests.
MaterialPage<void> iosModalPage({
  required GoRouterState state,
  required Widget child,
  TargetPlatform? platform,
}) {
  return MaterialPage<void>(
    key: state.pageKey,
    name: goRouterPageName(state),
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    fullscreenDialog: (platform ?? defaultTargetPlatform) == TargetPlatform.iOS,
    child: child,
  );
}
