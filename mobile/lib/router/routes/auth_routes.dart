// ABOUTME: Auth-entry routes (welcome subtree, key import, nostr connect, reset, verify)
// ABOUTME: Split from app_router.dart (#4508)

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

List<RouteBase> authRoutes(Ref ref) {
  return [
    GoRoute(
      path: WelcomeScreen.path,
      name: WelcomeScreen.routeName,
      builder: (_, state) {
        _captureProductAnalyticsUtm(ref, state);
        return WelcomeScreen(
          initialSelectedPubkeyHex:
              state.uri.queryParameters[WelcomeScreen.selectedPubkeyParam],
        );
      },
      routes: [
        GoRoute(
          path: 'create-account',
          name: CreateAccountScreen.routeName,
          builder: (_, state) {
            _captureProductAnalyticsUtm(ref, state);
            return const CreateAccountScreen();
          },
        ),
        GoRoute(
          path: 'login-options',
          name: LoginOptionsScreen.routeName,
          builder: (_, state) => LoginOptionsScreen(
            initialEmail: state.uri.queryParameters['email'],
            initialError: state.uri.queryParameters['error'],
          ),
          routes: [
            // Route for deep link when resetting password
            GoRoute(
              path: 'reset-password',
              name: ResetPasswordScreen.routeName,
              builder: (ctx, st) {
                final token = st.uri.queryParameters['token'];
                final email = st.uri.queryParameters['email'];
                return ResetPasswordScreen(token: token ?? '', email: email);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: KeyImportScreen.path,
      name: KeyImportScreen.routeName,
      builder: (_, _) => const KeyImportScreen(),
    ),
    GoRoute(
      path: NostrConnectScreen.path,
      name: NostrConnectScreen.routeName,
      builder: (_, _) => const NostrConnectScreen(),
    ),
    GoRoute(
      path: SecureAccountScreen.path,
      name: SecureAccountScreen.routeName,
      builder: (_, _) => const SecureAccountScreen(),
    ),
    // redirect deep link route to full reset password path
    GoRoute(
      path: ResetPasswordScreen.path,
      redirect: (context, state) => rewriteResetPasswordDeepLink(state.uri),
    ),
    // Email verification route - supports both modes:
    // - Token mode (deep link): /verify-email?token=xyz
    // - Polling mode (after registration): /verify-email?deviceCode=abc&verifier=def&email=user@example.com
    GoRoute(
      path: EmailVerificationScreen.path,
      name: EmailVerificationScreen.routeName,
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return EmailVerificationScreen(
          token: params['token'],
          deviceCode: params['deviceCode'],
          verifier: params['verifier'],
          email: params['email'],
          restored: params['restored'] == 'true',
        );
      },
    ),
  ];
}

void _captureProductAnalyticsUtm(Ref ref, GoRouterState state) {
  ref
      .read(analyticsServiceProvider)
      .captureProductAnalyticsUtm(state.uri.queryParameters);
}
