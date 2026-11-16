// ABOUTME: Page for a fullscreen video opened from a grid tile: the tile's
// ABOUTME: picture flies into the player, and a swipe drags it back.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_back_gesture.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_flight_transition.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';

/// Wraps [child] in a page that opens out of [origin]'s tile.
///
/// Mirrors go_router's default page metadata (`name`, `arguments`,
/// `restorationId`) from [state], as `fadeUpwardsPage` does, so root-navigator
/// observers keep resolving the route's name.
VideoTileTransitionPage videoTileTransitionPage({
  required GoRouterState state,
  required VideoTileOrigin origin,
  required Widget child,
}) {
  return VideoTileTransitionPage(
    key: state.pageKey,
    name: goRouterPageName(state),
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    origin: origin,
    child: child,
  );
}

/// A page whose route flies [origin]'s picture into [child] with a
/// [VideoTileFlightTransition].
///
/// On iOS and macOS, where the default page route has a back swipe, a drag
/// from the leading edge flies the picture back towards the tile under the
/// finger, as [VideoTileBackGesture] describes.
class VideoTileTransitionPage extends Page<void> {
  /// Creates the page.
  const VideoTileTransitionPage({
    required this.origin,
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The tile the picture flies out of.
  final VideoTileOrigin origin;

  /// The page's content.
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) =>
      _VideoTileTransitionRoute(page: this);
}

class _VideoTileTransitionRoute extends PageRoute<void> {
  _VideoTileTransitionRoute({required VideoTileTransitionPage page})
    : super(settings: page);

  VideoTileTransitionPage get _page => settings as VideoTileTransitionPage;

  final _popGesture = ValueNotifier<bool>(false);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => VideoTileFlightTransition.openDuration;

  @override
  Duration get reverseTransitionDuration =>
      VideoTileFlightTransition.closeDuration;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => VideoTileBackGestureDetector(
    enabledCallback: () => _hasBackSwipe && popGestureEnabled,
    onStartPopGesture: _startPopGesture,
    child: VideoTileFlightTransition(
      animation: animation,
      origin: _page.origin,
      popGestureInProgress: _popGesture,
      child: child,
    ),
  );

  /// Whether the platform's own page routes have a back swipe.
  static bool get _hasBackSwipe => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  VideoTileBackGesture _startPopGesture() => VideoTileBackGesture(
    navigator: navigator!,
    controller: controller!,
    inProgress: _popGesture,
    isCurrent: () => isCurrent,
    isActive: () => isActive,
    openDuration: transitionDuration,
    closeDuration: reverseTransitionDuration,
  );

  @override
  void dispose() {
    _popGesture.dispose();
    super.dispose();
  }
}
