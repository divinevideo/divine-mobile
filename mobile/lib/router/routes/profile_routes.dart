// ABOUTME: Profile routes (verify, profile setup edit/setup, followers, following, other profile)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:unified_logger/unified_logger.dart';

part 'profile_routes.g.dart';

List<RouteBase> profileRoutes() => $appRoutes;

@TypedGoRoute<VerifyRouteData>(
  path: VerifyPage.path,
  name: VerifyPage.routeName,
  routes: [
    TypedGoRoute<VerifyConnectRouteData>(
      path: VerifyConnectPage.path,
      name: VerifyConnectPage.routeName,
    ),
  ],
)
class VerifyRouteData extends GoRouteData with $VerifyRouteData {
  const VerifyRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) => const VerifyPage();
}

/// Links one NIP-39 platform; pops with a [VerifyConnectResult] once linked,
/// if any.
class VerifyConnectRouteData extends GoRouteData with $VerifyConnectRouteData {
  const VerifyConnectRouteData({required this.platform, this.replacing});

  /// The platform key, as `VerifierPlatform.key`.
  final String platform;

  /// Handle of the sign-in link being renewed, when the flow replaces one.
  final String? replacing;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VerifyConnectPage(platformKey: platform, replacingIdentity: replacing);
}

@TypedGoRoute<EditProfileRouteData>(
  path: ProfileSetupScreen.editPath,
  name: ProfileSetupScreen.editRouteName,
)
class EditProfileRouteData extends GoRouteData with $EditProfileRouteData {
  const EditProfileRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    _logProfileSetupBuild(ProfileSetupScreen.editPath, state);
    return const ProfileSetupScreen(isNewUser: false);
  }
}

@TypedGoRoute<SetupProfileRouteData>(
  path: ProfileSetupScreen.setupPath,
  name: ProfileSetupScreen.setupRouteName,
)
class SetupProfileRouteData extends GoRouteData with $SetupProfileRouteData {
  const SetupProfileRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    _logProfileSetupBuild(ProfileSetupScreen.setupPath, state);
    return const ProfileSetupScreen(isNewUser: true);
  }
}

void _logProfileSetupBuild(String path, GoRouterState state) {
  Log.debug(
    '$path route builder called',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
  Log.debug(
    '$path state.uri = ${state.uri}',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
  Log.debug(
    '$path state.matchedLocation = ${state.matchedLocation}',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
  Log.debug(
    '$path state.fullPath = ${state.fullPath}',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
}

/// A user's followers; routes to My or Others based on [pubkey].
@TypedGoRoute<FollowersRouteData>(
  path: FollowersScreenRouter.path,
  name: FollowersScreenRouter.routeName,
)
class FollowersRouteData extends GoRouteData with $FollowersRouteData {
  const FollowersRouteData({required this.pubkey, this.$extra});

  final String pubkey;

  /// The display-name hint, read through [extraAs]; absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (pubkey.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidUserId);
    }
    return FollowersScreenRouter(
      pubkey: pubkey,
      displayName: extraAs<String>($extra),
    );
  }
}

/// Who a user follows; routes to My or Others based on [pubkey].
@TypedGoRoute<FollowingRouteData>(
  path: FollowingScreenRouter.path,
  name: FollowingScreenRouter.routeName,
)
class FollowingRouteData extends GoRouteData with $FollowingRouteData {
  const FollowingRouteData({required this.pubkey, this.$extra});

  final String pubkey;

  /// The display-name hint, read through [extraAs]; absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (pubkey.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidUserId);
    }
    return FollowingScreenRouter(
      pubkey: pubkey,
      displayName: extraAs<String>($extra),
    );
  }
}

/// Another user's profile, pushed from feeds and search with no bottom nav.
///
/// The router widget redirects a self-visit to the own-profile tab.
@TypedGoRoute<OtherProfileRouteData>(
  path: OtherProfileScreen.pathWithNpub,
  name: OtherProfileScreen.routeName,
)
class OtherProfileRouteData extends GoRouteData with $OtherProfileRouteData {
  const OtherProfileRouteData({required this.npub, this.$extra});

  final String npub;

  /// A map with optional `displayName` and `avatarUrl` hints, for users with
  /// no kind 0 profile; read through [extraValue], absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (npub.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidProfileId);
    }
    return OtherProfileScreenRouter(
      npub: npub,
      displayNameHint: extraValue<String>($extra, 'displayName'),
      avatarUrlHint: extraValue<String>($extra, 'avatarUrl'),
    );
  }
}
