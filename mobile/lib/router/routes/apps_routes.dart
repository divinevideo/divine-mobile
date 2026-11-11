// ABOUTME: Nostr-apps routes (directory, permissions, sandbox, iframe, app detail)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/router/widgets/resolved_app_route_screen.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';

part 'apps_routes.g.dart';

/// The Nostr apps directory, its permissions screen and the per-app screens.
///
/// Declaration order is match order: `/apps/permissions` is declared before
/// `/apps/:slug` so the literal segment is never captured as a slug.
List<RouteBase> appsRoutes() => $appRoutes;

/// The directory of approved Nostr apps.
@TypedGoRoute<AppsDirectoryRouteData>(
  path: AppsDirectoryScreen.path,
  name: AppsDirectoryScreen.routeName,
)
class AppsDirectoryRouteData extends GoRouteData with $AppsDirectoryRouteData {
  const AppsDirectoryRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AppsDirectoryScreen();
}

/// The remembered integration permissions the viewer can review and revoke.
@TypedGoRoute<AppsPermissionsRouteData>(
  path: AppsPermissionsScreen.path,
  name: AppsPermissionsScreen.routeName,
)
class AppsPermissionsRouteData extends GoRouteData
    with $AppsPermissionsRouteData {
  const AppsPermissionsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    // A typed route has no `Ref`, so the providers are read through the tree.
    final container = ProviderScope.containerOf(context, listen: false);
    final authService = container.read(authServiceProvider);
    final grantStore = container.read(nostrAppGrantStoreProvider);
    return AppsPermissionsScreen(
      grantStore: grantStore,
      currentUserPubkey: authService.currentPublicKeyHex,
    );
  }
}

/// An app in the in-app sandbox, resolved from the `appId` path parameter so
/// a pasted URL or a browser refresh reaches the app instead of a dead end
/// (#3335).
@TypedGoRoute<NostrAppSandboxRouteData>(
  path: NostrAppSandboxScreen.path,
  name: NostrAppSandboxScreen.routeName,
)
class NostrAppSandboxRouteData extends GoRouteData
    with $NostrAppSandboxRouteData {
  const NostrAppSandboxRouteData({required this.appId, this.$extra});

  final String appId;

  /// A [NostrAppDirectoryEntry] hint that skips the directory fetch, read
  /// through [extraAs]; absent after a deep link or a refresh.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ResolvedAppRouteScreen(
        appId: appId,
        initialApp: extraAs<NostrAppDirectoryEntry>($extra),
        onResolved: (app) => NostrAppSandboxScreen(app: app),
      );
}

/// An app in the web iframe sandbox, resolved the same way as
/// [NostrAppSandboxRouteData]. Nothing in the app navigates here, so a URL is
/// the only way in.
@TypedGoRoute<WebIframeSandboxRouteData>(
  path: WebIframeSandboxScreen.path,
  name: WebIframeSandboxScreen.routeName,
)
class WebIframeSandboxRouteData extends GoRouteData
    with $WebIframeSandboxRouteData {
  const WebIframeSandboxRouteData({required this.appId, this.$extra});

  final String appId;

  /// A [NostrAppDirectoryEntry] hint that skips the directory fetch, read
  /// through [extraAs]; absent after a deep link or a refresh.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ResolvedAppRouteScreen(
        appId: appId,
        initialApp: extraAs<NostrAppDirectoryEntry>($extra),
        onResolved: (app) => WebIframeSandboxScreen(app: app),
      );
}

/// An app's detail page by slug. Declared after the permissions route so
/// `permissions` is never read as a slug.
@TypedGoRoute<AppDetailRouteData>(
  path: AppDetailScreen.path,
  name: AppDetailScreen.routeName,
)
class AppDetailRouteData extends GoRouteData with $AppDetailRouteData {
  const AppDetailRouteData({required this.slug, this.$extra});

  final String slug;

  /// A [NostrAppDirectoryEntry] hint that skips the directory fetch, read
  /// through [extraAs]; absent after a deep link or a refresh.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => AppDetailScreen(
    slug: slug,
    initialEntry: extraAs<NostrAppDirectoryEntry>($extra),
  );
}
