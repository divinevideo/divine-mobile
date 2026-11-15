// ABOUTME: Page for a fullscreen video opened from a grid tile: the tile's
// ABOUTME: picture flies into the player instead of the page sliding in.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_flight_transition.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';

/// Wraps [child] in a page that opens out of [origin]'s tile.
///
/// Mirrors go_router's default page metadata (`name`, `arguments`,
/// `restorationId`) from [state], as `fadeUpwardsPage` does, so root-navigator
/// observers keep resolving the route's name.
CustomTransitionPage<void> videoTileTransitionPage({
  required GoRouterState state,
  required VideoTileOrigin origin,
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
    transitionDuration: VideoTileFlightTransition.openDuration,
    reverseTransitionDuration: VideoTileFlightTransition.closeDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        VideoTileFlightTransition(
          animation: animation,
          origin: origin,
          child: child,
        ),
  );
}
