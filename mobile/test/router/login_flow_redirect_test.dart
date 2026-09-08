// ABOUTME: Tests the redirect logic for login flow navigation
// ABOUTME: Tests redirect function behavior without full router instantiation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/services/auth_service.dart';

/// Isolated test of the redirect logic that mirrors app_router.dart redirect
/// function. This helps us understand what SHOULD happen without Firebase
/// dependencies.
///
/// The authenticated auth-route decision (rule 1, including the expired-session
/// and anonymous recovery exceptions) delegates to the real
/// [authenticatedRedirectsFromAuthEntry] helper, so that branch cannot drift
/// from the router. Only the unauthenticated `isAuthRoute` mirror (rule 2)
/// remains a local copy — keep it in sync when adding a new auth route.
///
/// The actual redirect logic is:
/// 1. If authenticated AND on top-level auth entry routes -> redirect to /home/0
///    (EXCEPT expired-session users and anonymous email-recovery users
///    navigating to loginOptionsPath)
///    (EXCEPT import-key, which doubles as an authenticated account-switch route)
/// 2. If NOT on auth route AND unauthenticated -> redirect to /welcome
/// 3. Otherwise -> null (no redirect)
String? testRedirectLogic({
  required String location,
  required AuthState authState,
  bool hasExpiredOAuthSession = false,
  bool isAnonymous = false,
}) {
  // Auth routes that should be accessible without authentication.
  // Mirrors the isAuthRoute check in app_router.dart.
  final isAuthRoute =
      location.startsWith(WelcomeScreen.path) ||
      location.startsWith(KeyImportScreen.path) ||
      location.startsWith(NostrConnectScreen.path) ||
      location.startsWith(WelcomeScreen.inviteGatePath) ||
      location.startsWith(WelcomeScreen.resetPasswordPath) ||
      location.startsWith(ResetPasswordScreen.path) ||
      location.startsWith(EmailVerificationScreen.path);

  // Rule 1: Authenticated users on redirectable auth routes go to home.
  // Delegates to the real shared helper so this mirror cannot drift from the
  // router; the expired-session login-options exception lives there too.
  if (authState == AuthState.authenticated &&
      authenticatedRedirectsFromAuthEntry(
        location,
        hasExpiredOAuthSession: hasExpiredOAuthSession,
        isAnonymous: isAnonymous,
      )) {
    return VideoFeedPage.pathForIndex(0);
  }

  // Rule 2: Unauthenticated users on non-auth routes go to welcome
  if (!isAuthRoute && authState == AuthState.unauthenticated) {
    return WelcomeScreen.path;
  }

  // Rule 3: No redirect needed
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow Redirect Logic', () {
    group('Unauthenticated user scenarios', () {
      test('unauthenticated user on /welcome stays there', () {
        final redirect = testRedirectLogic(
          location: WelcomeScreen.path,
          authState: AuthState.unauthenticated,
        );
        expect(
          redirect,
          isNull,
          reason: '${WelcomeScreen.path} should not redirect',
        );
      });

      test('unauthenticated user can access ${WelcomeScreen.inviteGatePath}', () {
        final redirect = testRedirectLogic(
          location: WelcomeScreen.inviteGatePath,
          authState: AuthState.unauthenticated,
        );
        expect(
          redirect,
          isNull,
          reason:
              '${WelcomeScreen.inviteGatePath} is an auth route, should not redirect',
        );
      });

      test(
        'unauthenticated user can access ${WelcomeScreen.loginOptionsPath}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.loginOptionsPath} is an auth route, should not redirect',
          );
        },
      );

      test('unauthenticated user can access ${KeyImportScreen.path}', () {
        final redirect = testRedirectLogic(
          location: KeyImportScreen.path,
          authState: AuthState.unauthenticated,
        );
        expect(
          redirect,
          isNull,
          reason:
              '${KeyImportScreen.path} is an auth route, should not redirect',
        );
      });

      test(
        'unauthenticated user can access ${ResetPasswordScreen.path} deep link',
        () {
          final redirect = testRedirectLogic(
            location: ResetPasswordScreen.path,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${ResetPasswordScreen.path} is a deep link auth route, '
                'should not redirect to /welcome',
          );
        },
      );

      test(
        'unauthenticated user can access ${WelcomeScreen.resetPasswordPath}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.resetPasswordPath,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.resetPasswordPath} is an auth route, '
                'should not redirect',
          );
        },
      );

      test(
        'unauthenticated user can access ${EmailVerificationScreen.path}',
        () {
          final redirect = testRedirectLogic(
            location: EmailVerificationScreen.path,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${EmailVerificationScreen.path} is an auth route, '
                'should not redirect',
          );
        },
      );

      test(
        'unauthenticated user on ${VideoFeedPage.pathForIndex(0)} redirects to /welcome',
        () {
          final redirect = testRedirectLogic(
            location: VideoFeedPage.pathForIndex(0),
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            equals(WelcomeScreen.path),
            reason: 'Protected route should redirect unauthenticated user',
          );
        },
      );

      test(
        'unauthenticated user on ${ExploreScreen.path} redirects to ${WelcomeScreen.path}',
        () {
          final redirect = testRedirectLogic(
            location: ExploreScreen.path,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            equals(WelcomeScreen.path),
            reason: 'Protected route should redirect unauthenticated user',
          );
        },
      );
    });

    group('Authenticated user scenarios', () {
      test(
        'authenticated user on ${WelcomeScreen.path} redirects to ${VideoFeedPage.pathForIndex(0)}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.path,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            equals(VideoFeedPage.pathForIndex(0)),
            reason:
                'Authenticated user on auth route goes to ${VideoFeedPage.pathForIndex(0)}',
          );
        },
      );

      test(
        'authenticated user on ${WelcomeScreen.inviteGatePath} redirects to ${VideoFeedPage.pathForIndex(0)}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.inviteGatePath,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            equals(VideoFeedPage.pathForIndex(0)),
            reason: 'Authenticated user on invite gate should go to home',
          );
        },
      );

      test(
        'authenticated user on ${WelcomeScreen.loginOptionsPath} redirects to ${VideoFeedPage.pathForIndex(0)}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            equals(VideoFeedPage.pathForIndex(0)),
            reason: 'Authenticated user on auth route should go to home',
          );
        },
      );

      test(
        'authenticated user can access ${KeyImportScreen.path} to import another key',
        () {
          final redirect = testRedirectLogic(
            location: KeyImportScreen.path,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${KeyImportScreen.path} is also an authenticated account-switch route',
          );
        },
      );

      test(
        'authenticated user can access ${WelcomeScreen.resetPasswordPath} deep link flow',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.resetPasswordPath,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            isNull,
            reason: 'Authenticated users should remain on reset-password deep links',
          );
        },
      );

      test(
        'authenticated user can access ${EmailVerificationScreen.path} deep link flow',
        () {
          final redirect = testRedirectLogic(
            location: EmailVerificationScreen.path,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                'Authenticated users should remain on verify-email deep links',
          );
        },
      );

      test(
        'authenticated user on ${VideoFeedPage.pathForIndex(0)} stays there',
        () {
          final redirect = testRedirectLogic(
            location: VideoFeedPage.pathForIndex(0),
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            isNull,
            reason: '${VideoFeedPage.pathForIndex(0)} should not redirect',
          );
        },
      );

      test('authenticated user on ${ExploreScreen.path} stays there', () {
        final redirect = testRedirectLogic(
          location: ExploreScreen.path,
          authState: AuthState.authenticated,
        );
        expect(
          redirect,
          isNull,
          reason: '${ExploreScreen.path} should not redirect',
        );
      });
    });

    group('Edge cases', () {
      test(
        '${WelcomeScreen.inviteGatePath} should NEVER redirect to ${WelcomeScreen.path} for unauthenticated users',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.inviteGatePath,
            authState: AuthState.unauthenticated,
          );

          expect(
            redirect,
            isNot(equals(WelcomeScreen.path)),
            reason:
                'BUG: ${WelcomeScreen.inviteGatePath} is part of the auth flow and must remain accessible',
          );
        },
      );

      test(
        '${WelcomeScreen.loginOptionsPath} should NEVER redirect to ${WelcomeScreen.path} for unauthenticated users',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
          );

          expect(
            redirect,
            isNot(equals(WelcomeScreen.path)),
            reason:
                'BUG: ${LoginOptionsScreen.path} is an auth route and should be accessible '
                'to unauthenticated users trying to log in!',
          );
        },
      );

      test('expired-session user on ${WelcomeScreen.loginOptionsPath} '
          'should NOT be bounced to home (the original bug)', () {
        // This test reproduces the bug: authenticated users with an
        // expired OAuth session were redirected away from loginOptionsPath,
        // making the "Sign in" button on the Session Expired banner useless.
        final redirect = testRedirectLogic(
          location: WelcomeScreen.loginOptionsPath,
          authState: AuthState.authenticated,
          hasExpiredOAuthSession: true,
        );
        expect(
          redirect,
          isNull,
          reason:
              'Expired-session user must reach login options to '
              're-authenticate, not be bounced to home',
        );
      });

      test(
        'expired-session user on ${WelcomeScreen.path} still redirects to home',
        () {
          // The exception only applies to loginOptionsPath, not all auth routes
          final redirect = testRedirectLogic(
            location: WelcomeScreen.path,
            authState: AuthState.authenticated,
            hasExpiredOAuthSession: true,
          );
          expect(
            redirect,
            equals(VideoFeedPage.pathForIndex(0)),
            reason:
                'Expired-session exception only applies to loginOptionsPath',
          );
        },
      );

      test(
        'non-expired authenticated user on ${WelcomeScreen.loginOptionsPath} '
        'still redirects to home',
        () {
          // Normal authenticated users (no expired session) should still
          // be redirected away from auth routes as before
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.authenticated,
          );
          expect(
            redirect,
            equals(VideoFeedPage.pathForIndex(0)),
            reason:
                'Normal authenticated user should still be redirected to home',
          );
        },
      );

      test('${ResetPasswordScreen.path} deep link should NEVER redirect to '
          '${WelcomeScreen.path} for unauthenticated users', () {
        final redirect = testRedirectLogic(
          location: ResetPasswordScreen.path,
          authState: AuthState.unauthenticated,
        );

        expect(
          redirect,
          isNot(equals(WelcomeScreen.path)),
          reason:
              'BUG: ${ResetPasswordScreen.path} is a deep link auth route '
              'and must be accessible to unauthenticated users resetting '
              'their password!',
        );
      });
    });
  });

  group('Route normalization bug - THE ROOT CAUSE', () {
    test(
      '${WelcomeScreen.loginOptionsPath} should parse and rebuild correctly (not /home/0)',
      () {
        final parsed = parseRoute(WelcomeScreen.loginOptionsPath);
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.loginOptions),
          reason:
              '${WelcomeScreen.loginOptionsPath} should parse to loginOptions type, not home',
        );
        expect(
          rebuilt,
          equals(WelcomeScreen.loginOptionsPath),
          reason:
              'Rebuilding ${WelcomeScreen.loginOptionsPath} should NOT become /home/0',
        );
      },
    );

    test(
      '${WelcomeScreen.path} should parse and rebuild to ${WelcomeScreen.path}',
      () {
        final parsed = parseRoute(WelcomeScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(parsed.type, equals(RouteType.welcome));
        expect(rebuilt, equals(WelcomeScreen.path));
      },
    );

    test(
      '${KeyImportScreen.path} should parse and rebuild to ${KeyImportScreen.path}',
      () {
        final parsed = parseRoute(KeyImportScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(parsed.type, equals(RouteType.importKey));
        expect(rebuilt, equals(KeyImportScreen.path));
      },
    );
  });

  group('authenticatedRedirectsFromAuthEntry', () {
    test('anonymous email recovery has no pending home redirect', () {
      expect(
        authenticatedRedirectsFromAuthEntry(
          '${WelcomeScreen.loginOptionsPath}?email=existing%40example.com',
          hasExpiredOAuthSession: false,
          isAnonymous: true,
        ),
        isFalse,
      );
    });

    test('registered users with an email query still redirect home', () {
      expect(
        authenticatedRedirectsFromAuthEntry(
          '${WelcomeScreen.loginOptionsPath}?email=existing%40example.com',
          hasExpiredOAuthSession: false,
          isAnonymous: false,
        ),
        isTrue,
      );
    });

    group('redirects an authenticated user home from', () {
      for (final location in <String>[
        WelcomeScreen.path,
        NostrConnectScreen.path,
        WelcomeScreen.inviteGatePath,
        WelcomeScreen.createAccountPath,
        WelcomeScreen.loginOptionsPath,
      ]) {
        test(location, () {
          expect(
            authenticatedRedirectsFromAuthEntry(
              location,
              hasExpiredOAuthSession: false,
              isAnonymous: false,
            ),
            isTrue,
            reason: '$location is a sign-in entry point — bounce home',
          );
        });
      }
    });

    group('leaves an authenticated user on', () {
      for (final location in <String>[
        WelcomeScreen.resetPasswordPath,
        ResetPasswordScreen.path,
        EmailVerificationScreen.path,
        KeyImportScreen.path,
        VideoFeedPage.pathForIndex(0),
        ExploreScreen.path,
      ]) {
        test(location, () {
          expect(
            authenticatedRedirectsFromAuthEntry(
              location,
              hasExpiredOAuthSession: false,
              isAnonymous: false,
            ),
            isFalse,
            reason: '$location is a route the router leaves the user on',
          );
        });
      }
    });

    test('leaves an expired-session user on login options', () {
      expect(
        authenticatedRedirectsFromAuthEntry(
          WelcomeScreen.loginOptionsPath,
          hasExpiredOAuthSession: true,
          isAnonymous: false,
        ),
        isFalse,
        reason: 'expired-session users must reach login options to re-auth',
      );
    });

    test('still redirects an expired-session user from /welcome', () {
      expect(
        authenticatedRedirectsFromAuthEntry(
          WelcomeScreen.path,
          hasExpiredOAuthSession: true,
          isAnonymous: false,
        ),
        isTrue,
        reason: 'the expired-session exception only applies to login options',
      );
    });
  });
}
