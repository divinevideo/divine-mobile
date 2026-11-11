// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $welcomeRouteData,
  $keyImportRouteData,
  $nostrConnectRouteData,
  $secureAccountRouteData,
  $resetPasswordDeepLinkRouteData,
  $emailVerificationRouteData,
];

RouteBase get $welcomeRouteData => GoRouteData.$route(
  path: '/welcome',
  name: 'welcome',
  hasOverriddenOnExit: false,
  factory: $WelcomeRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'create-account',
      name: 'create-account',
      hasOverriddenOnExit: false,
      factory: $CreateAccountRouteData._fromState,
    ),
    GoRouteData.$route(
      path: 'login-options',
      name: 'login-options',
      hasOverriddenOnExit: false,
      factory: $LoginOptionsRouteData._fromState,
      routes: [
        GoRouteData.$route(
          path: 'reset-password',
          name: 'reset-password',
          hasOverriddenOnExit: false,
          factory: $ResetPasswordRouteData._fromState,
        ),
      ],
    ),
  ],
);

mixin $WelcomeRouteData on GoRouteData {
  static WelcomeRouteData _fromState(GoRouterState state) => WelcomeRouteData(
    selectedPubkey: state.uri.queryParameters['selectedPubkey'],
  );

  WelcomeRouteData get _self => this as WelcomeRouteData;

  @override
  String get location => GoRouteData.$location(
    '/welcome',
    queryParams: {
      if (_self.selectedPubkey != null) 'selectedPubkey': _self.selectedPubkey,
    },
  );

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

mixin $CreateAccountRouteData on GoRouteData {
  static CreateAccountRouteData _fromState(GoRouterState state) =>
      const CreateAccountRouteData();

  @override
  String get location => GoRouteData.$location('/welcome/create-account');

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

mixin $LoginOptionsRouteData on GoRouteData {
  static LoginOptionsRouteData _fromState(GoRouterState state) =>
      LoginOptionsRouteData(
        email: state.uri.queryParameters['email'],
        error: state.uri.queryParameters['error'],
      );

  LoginOptionsRouteData get _self => this as LoginOptionsRouteData;

  @override
  String get location => GoRouteData.$location(
    '/welcome/login-options',
    queryParams: {
      if (_self.email != null) 'email': _self.email,
      if (_self.error != null) 'error': _self.error,
    },
  );

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

mixin $ResetPasswordRouteData on GoRouteData {
  static ResetPasswordRouteData _fromState(GoRouterState state) =>
      ResetPasswordRouteData(
        token: state.uri.queryParameters['token'],
        email: state.uri.queryParameters['email'],
      );

  ResetPasswordRouteData get _self => this as ResetPasswordRouteData;

  @override
  String get location => GoRouteData.$location(
    '/welcome/login-options/reset-password',
    queryParams: {
      if (_self.token != null) 'token': _self.token,
      if (_self.email != null) 'email': _self.email,
    },
  );

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

RouteBase get $keyImportRouteData => GoRouteData.$route(
  path: '/import-key',
  name: 'import-key',
  hasOverriddenOnExit: false,
  factory: $KeyImportRouteData._fromState,
);

mixin $KeyImportRouteData on GoRouteData {
  static KeyImportRouteData _fromState(GoRouterState state) =>
      const KeyImportRouteData();

  @override
  String get location => GoRouteData.$location('/import-key');

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

RouteBase get $nostrConnectRouteData => GoRouteData.$route(
  path: '/nostr-connect',
  name: 'nostr-connect',
  hasOverriddenOnExit: false,
  factory: $NostrConnectRouteData._fromState,
);

mixin $NostrConnectRouteData on GoRouteData {
  static NostrConnectRouteData _fromState(GoRouterState state) =>
      const NostrConnectRouteData();

  @override
  String get location => GoRouteData.$location('/nostr-connect');

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

RouteBase get $secureAccountRouteData => GoRouteData.$route(
  path: '/secure-account',
  name: 'secure-account',
  hasOverriddenOnExit: false,
  factory: $SecureAccountRouteData._fromState,
);

mixin $SecureAccountRouteData on GoRouteData {
  static SecureAccountRouteData _fromState(GoRouterState state) =>
      const SecureAccountRouteData();

  @override
  String get location => GoRouteData.$location('/secure-account');

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

RouteBase get $resetPasswordDeepLinkRouteData => GoRouteData.$route(
  path: '/reset-password',
  hasOverriddenOnExit: false,
  factory: $ResetPasswordDeepLinkRouteData._fromState,
);

mixin $ResetPasswordDeepLinkRouteData on GoRouteData {
  static ResetPasswordDeepLinkRouteData _fromState(GoRouterState state) =>
      const ResetPasswordDeepLinkRouteData();

  @override
  String get location => GoRouteData.$location('/reset-password');

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

RouteBase get $emailVerificationRouteData => GoRouteData.$route(
  path: '/verify-email',
  name: 'verify-email',
  hasOverriddenOnExit: false,
  factory: $EmailVerificationRouteData._fromState,
);

mixin $EmailVerificationRouteData on GoRouteData {
  static EmailVerificationRouteData _fromState(GoRouterState state) =>
      EmailVerificationRouteData(
        token: state.uri.queryParameters['token'],
        deviceCode: state.uri.queryParameters['deviceCode'],
        verifier: state.uri.queryParameters['verifier'],
        email: state.uri.queryParameters['email'],
        restored: state.uri.queryParameters['restored'],
      );

  EmailVerificationRouteData get _self => this as EmailVerificationRouteData;

  @override
  String get location => GoRouteData.$location(
    '/verify-email',
    queryParams: {
      if (_self.token != null) 'token': _self.token,
      if (_self.deviceCode != null) 'deviceCode': _self.deviceCode,
      if (_self.verifier != null) 'verifier': _self.verifier,
      if (_self.email != null) 'email': _self.email,
      if (_self.restored != null) 'restored': _self.restored,
    },
  );

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
