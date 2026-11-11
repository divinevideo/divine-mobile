// ABOUTME: Auth-entry routes (welcome subtree, key import, nostr connect, reset, verify)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/router_guards.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';

part 'auth_routes.g.dart';

/// The sign-in screens.
///
/// The redirect gate decides who may reach them by comparing these location
/// strings, so a path or query key here changes who is let through.
List<RouteBase> authRoutes() => $appRoutes;

/// Welcome, with create account and sign in nested under it.
@TypedGoRoute<WelcomeRouteData>(
  path: WelcomeScreen.path,
  name: WelcomeScreen.routeName,
  routes: [
    TypedGoRoute<CreateAccountRouteData>(
      path: WelcomeScreen.createAccountSegment,
      name: CreateAccountScreen.routeName,
    ),
    TypedGoRoute<LoginOptionsRouteData>(
      path: WelcomeScreen.loginOptionsSegment,
      name: LoginOptionsScreen.routeName,
      routes: [
        TypedGoRoute<ResetPasswordRouteData>(
          path: LoginOptionsScreen.resetPasswordSegment,
          name: ResetPasswordScreen.routeName,
        ),
      ],
    ),
  ],
)
class WelcomeRouteData extends GoRouteData with $WelcomeRouteData {
  const WelcomeRouteData({
    @TypedQueryParameter(name: WelcomeScreen.selectedPubkeyParam)
    this.selectedPubkey,
  });

  /// The account to pre-select, as hex.
  final String? selectedPubkey;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    _captureProductAnalyticsUtm(context, state);
    return WelcomeScreen(initialSelectedPubkeyHex: selectedPubkey);
  }
}

class CreateAccountRouteData extends GoRouteData with $CreateAccountRouteData {
  const CreateAccountRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    _captureProductAnalyticsUtm(context, state);
    return const CreateAccountScreen();
  }
}

class LoginOptionsRouteData extends GoRouteData with $LoginOptionsRouteData {
  const LoginOptionsRouteData({
    @TypedQueryParameter(name: 'email') this.email,
    @TypedQueryParameter(name: 'error') this.error,
  });

  /// An email to prefill, from create-account recovery.
  final String? email;

  /// A message to show above the form, from create-account recovery.
  final String? error;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LoginOptionsScreen(initialEmail: email, initialError: error);
}

/// The password-reset form a reset link lands on.
class ResetPasswordRouteData extends GoRouteData with $ResetPasswordRouteData {
  const ResetPasswordRouteData({
    @TypedQueryParameter(name: 'token') this.token,
    @TypedQueryParameter(name: 'email') this.email,
  });

  /// The reset token; the screen opens with an empty one when it is absent.
  final String? token;

  final String? email;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ResetPasswordScreen(token: token ?? '', email: email);
}

@TypedGoRoute<KeyImportRouteData>(
  path: KeyImportScreen.path,
  name: KeyImportScreen.routeName,
)
class KeyImportRouteData extends GoRouteData with $KeyImportRouteData {
  const KeyImportRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const KeyImportScreen();
}

@TypedGoRoute<NostrConnectRouteData>(
  path: NostrConnectScreen.path,
  name: NostrConnectScreen.routeName,
)
class NostrConnectRouteData extends GoRouteData with $NostrConnectRouteData {
  const NostrConnectRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NostrConnectScreen();
}

@TypedGoRoute<SecureAccountRouteData>(
  path: SecureAccountScreen.path,
  name: SecureAccountScreen.routeName,
)
class SecureAccountRouteData extends GoRouteData with $SecureAccountRouteData {
  const SecureAccountRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SecureAccountScreen();
}

/// The `/reset-password` address reset emails link to. It has no name and no
/// screen: it forwards to [ResetPasswordRouteData]'s nested address.
@TypedGoRoute<ResetPasswordDeepLinkRouteData>(path: ResetPasswordScreen.path)
class ResetPasswordDeepLinkRouteData extends GoRouteData
    with $ResetPasswordDeepLinkRouteData {
  const ResetPasswordDeepLinkRouteData();

  /// Always redirects, so [build] is never reached.
  @override
  String redirect(BuildContext context, GoRouterState state) =>
      rewriteResetPasswordDeepLink(state.uri);
}

/// Email verification, in two modes:
/// - token mode, from a deep link: `/verify-email?token=xyz`
/// - polling mode, after registration:
///   `/verify-email?deviceCode=abc&verifier=def&email=user@example.com`
@TypedGoRoute<EmailVerificationRouteData>(
  path: EmailVerificationScreen.path,
  name: EmailVerificationScreen.routeName,
)
class EmailVerificationRouteData extends GoRouteData
    with $EmailVerificationRouteData {
  const EmailVerificationRouteData({
    @TypedQueryParameter(name: 'token') this.token,
    @TypedQueryParameter(name: 'deviceCode') this.deviceCode,
    @TypedQueryParameter(name: 'verifier') this.verifier,
    @TypedQueryParameter(name: 'email') this.email,
    @TypedQueryParameter(name: 'restored') this.restored,
  });

  final String? token;
  final String? deviceCode;
  final String? verifier;
  final String? email;

  /// `true` when a cold start restored the verification; any other value, or
  /// none, is a fresh one.
  final String? restored;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      EmailVerificationScreen(
        token: token,
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
        restored: restored == 'true',
      );
}

/// Records the link's UTM parameters, read through the widget tree: a typed
/// route has no `Ref`.
void _captureProductAnalyticsUtm(BuildContext context, GoRouterState state) {
  ProviderScope.containerOf(context, listen: false)
      .read(analyticsServiceProvider)
      .captureProductAnalyticsUtm(state.uri.queryParameters);
}
