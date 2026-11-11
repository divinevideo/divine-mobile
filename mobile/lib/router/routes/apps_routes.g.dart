// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $appsDirectoryRouteData,
  $appsPermissionsRouteData,
  $nostrAppSandboxRouteData,
  $webIframeSandboxRouteData,
  $appDetailRouteData,
];

RouteBase get $appsDirectoryRouteData => GoRouteData.$route(
  path: '/apps',
  name: 'apps-directory',
  hasOverriddenOnExit: false,
  factory: $AppsDirectoryRouteData._fromState,
);

mixin $AppsDirectoryRouteData on GoRouteData {
  static AppsDirectoryRouteData _fromState(GoRouterState state) =>
      const AppsDirectoryRouteData();

  @override
  String get location => GoRouteData.$location('/apps');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appsPermissionsRouteData => GoRouteData.$route(
  path: '/apps/permissions',
  name: 'apps-permissions',
  hasOverriddenOnExit: false,
  factory: $AppsPermissionsRouteData._fromState,
);

mixin $AppsPermissionsRouteData on GoRouteData {
  static AppsPermissionsRouteData _fromState(GoRouterState state) =>
      const AppsPermissionsRouteData();

  @override
  String get location => GoRouteData.$location('/apps/permissions');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $nostrAppSandboxRouteData => GoRouteData.$route(
  path: '/apps/:appId/sandbox',
  name: 'nostr-app-sandbox',
  hasOverriddenOnExit: false,
  factory: $NostrAppSandboxRouteData._fromState,
);

mixin $NostrAppSandboxRouteData on GoRouteData {
  static NostrAppSandboxRouteData _fromState(GoRouterState state) =>
      NostrAppSandboxRouteData(
        appId: state.pathParameters['appId']!,
        $extra: state.extra as Object?,
      );

  NostrAppSandboxRouteData get _self => this as NostrAppSandboxRouteData;

  @override
  String get location => GoRouteData.$location(
    '/apps/${Uri.encodeComponent(_self.appId)}/sandbox',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $webIframeSandboxRouteData => GoRouteData.$route(
  path: '/apps/:appId/web-sandbox',
  name: 'web-iframe-sandbox',
  hasOverriddenOnExit: false,
  factory: $WebIframeSandboxRouteData._fromState,
);

mixin $WebIframeSandboxRouteData on GoRouteData {
  static WebIframeSandboxRouteData _fromState(GoRouterState state) =>
      WebIframeSandboxRouteData(
        appId: state.pathParameters['appId']!,
        $extra: state.extra as Object?,
      );

  WebIframeSandboxRouteData get _self => this as WebIframeSandboxRouteData;

  @override
  String get location => GoRouteData.$location(
    '/apps/${Uri.encodeComponent(_self.appId)}/web-sandbox',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $appDetailRouteData => GoRouteData.$route(
  path: '/apps/:slug',
  name: 'app-detail',
  hasOverriddenOnExit: false,
  factory: $AppDetailRouteData._fromState,
);

mixin $AppDetailRouteData on GoRouteData {
  static AppDetailRouteData _fromState(GoRouterState state) =>
      AppDetailRouteData(
        slug: state.pathParameters['slug']!,
        $extra: state.extra as Object?,
      );

  AppDetailRouteData get _self => this as AppDetailRouteData;

  @override
  String get location =>
      GoRouteData.$location('/apps/${Uri.encodeComponent(_self.slug)}');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}
