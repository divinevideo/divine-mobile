import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

/// Whether an authenticated user currently on [location] is one the router's
/// authenticated auth-route redirect bounces home to the feed.
///
/// Mirrors that redirect in `goRouterProvider` (`app_router.dart`): an
/// authenticated user is only redirected home from the sign-in entry points
/// (`/welcome`, `/nostr-connect`, `/welcome/create-account`,
/// `/welcome/login-options`), with the same expired-session and anonymous
/// recovery exceptions for login options.
///
/// It is deliberately narrower than `app_router.dart`'s broad auth-entry check:
/// auth-entry routes an authenticated user is intentionally left on —
/// reset-password and email-verification deep links, key import (an
/// account-switch route), and the minor-account-review entry routes — return
/// `false`.
///
/// The startup splash gate (`StartupSplashReleaseController`, #5242) uses this
/// to hold the splash only while a home-redirect is actually pending, so a
/// cold-start auth deep link releases the splash as soon as auth settles
/// instead of waiting for the restore timeout. Keep this in sync with the
/// auth-route redirect in `app_router.dart`; `login_flow_redirect_test`
/// exercises it directly.
bool authenticatedRedirectsFromAuthEntry(
  String location, {
  required bool hasExpiredOAuthSession,
  required bool isAnonymous,
}) {
  final uri = Uri.parse(location);
  final path = uri.path;
  if (hasExpiredOAuthSession && path == WelcomeScreen.loginOptionsPath) {
    return false;
  }
  if (isAnonymous &&
      path == WelcomeScreen.loginOptionsPath &&
      uri.queryParameters.containsKey('email')) {
    return false;
  }
  return path == WelcomeScreen.path ||
      path == NostrConnectScreen.path ||
      path == WelcomeScreen.createAccountPath ||
      path == WelcomeScreen.loginOptionsPath;
}
