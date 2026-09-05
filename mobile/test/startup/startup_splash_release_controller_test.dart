import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/auth_entry_redirect.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/startup/startup_splash_release_controller.dart';

/// Regression coverage for #5242: the native splash must stay up for an
/// authenticated user until the `/welcome` → `/home` redirect has been applied,
/// while releasing immediately for everyone else, and always within the
/// timeout floor. Fired exactly once.
void main() {
  group(StartupSplashReleaseController, () {
    // Mirrors the redirect-away set in `authenticatedRedirectsFromAuthEntry`:
    // an authenticated user is bounced home only from the sign-in entry
    // points, not from the deep-link auth routes they are left on
    // (reset-password, email verification, key import).
    bool authenticatedRedirectPending(String location) =>
        location == '/welcome' ||
        location == '/welcome/login-options' ||
        location == '/welcome/create-account' ||
        location == '/nostr-connect';

    // A non-default timeout keeps the floor explicit in the elapse math.
    const timeout = Duration(seconds: 5);

    test('authenticated holds the splash until the router leaves /welcome', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/welcome');
        var state = AuthState.checking;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => state,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        async.flushMicrotasks();
        expect(releases, 0, reason: 'checking must not release');

        state = AuthState.authenticated;
        auth.add(AuthState.authenticated);
        async.flushMicrotasks();
        expect(
          releases,
          0,
          reason: 'authenticated while still on /welcome must not release',
        );

        location.value = '/home';
        expect(
          releases,
          1,
          reason: 'redirect off /welcome releases the splash',
        );

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test('authenticated can recheck a non-routing startup gate', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/home');
        var deletionLookupPending = true;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => AuthState.authenticated,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: (_) => deletionLookupPending,
          timeout: timeout,
          release: () => releases++,
        );

        expect(releases, 0, reason: 'unresolved lookup holds the splash');

        deletionLookupPending = false;
        controller.reevaluate();
        expect(releases, 1, reason: 'settled lookup releases the splash');

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test(
      'authenticated release follows delegate-style redirect notification',
      () {
        fakeAsync((async) {
          final auth = StreamController<AuthState>.broadcast();
          final location = _RouterDelegateLocation('/welcome');
          var state = AuthState.checking;
          var releases = 0;

          final controller = StartupSplashReleaseController(
            authStateStream: auth.stream,
            currentAuthState: () => state,
            locationListenable: location,
            currentLocation: () => location.value,
            authenticatedRedirectPending: authenticatedRedirectPending,
            timeout: timeout,
            release: () => releases++,
          );

          state = AuthState.authenticated;
          auth.add(AuthState.authenticated);
          async.flushMicrotasks();
          expect(releases, 0);

          location.setSilently('/home');
          expect(
            releases,
            0,
            reason:
                'GoRouteInformationProvider redirect writeback does not notify',
          );

          location.notifyRedirectApplied();
          expect(
            releases,
            1,
            reason:
                'GoRouterDelegate notifies after currentConfiguration updates',
          );

          controller.dispose();
          unawaited(auth.close());
        });
      },
    );

    test('unauthenticated releases immediately while on /welcome', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/welcome');
        var state = AuthState.checking;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => state,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        state = AuthState.unauthenticated;
        auth.add(AuthState.unauthenticated);
        async.flushMicrotasks();
        expect(
          releases,
          1,
          reason: 'unauthenticated correctly lands on /welcome — release now',
        );

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test('awaitingTosAcceptance releases immediately', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/welcome');
        var state = AuthState.checking;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => state,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        state = AuthState.awaitingTosAcceptance;
        auth.add(AuthState.awaitingTosAcceptance);
        async.flushMicrotasks();
        expect(releases, 1);

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test('public recorder route releases an authenticated launch', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/video-recorder');
        var state = AuthState.checking;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => state,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        state = AuthState.authenticated;
        auth.add(AuthState.authenticated);
        async.flushMicrotasks();
        expect(
          releases,
          1,
          reason: '/video-recorder is not an auth-entry route — release',
        );

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test(
      'authenticated reset-password deep link releases without waiting for '
      'the timeout',
      () {
        fakeAsync((async) {
          final auth = StreamController<AuthState>.broadcast();
          // A cold-start deep link lands an authenticated user directly on the
          // nested reset-password route, which the router intentionally leaves
          // them on — no home-redirect is pending, so the splash must release
          // at once rather than hang until the timeout floor (#5242 review).
          final location = ValueNotifier<String>(
            '/welcome/login-options/reset-password',
          );
          var state = AuthState.checking;
          var releases = 0;

          final controller = StartupSplashReleaseController(
            authStateStream: auth.stream,
            currentAuthState: () => state,
            locationListenable: location,
            currentLocation: () => location.value,
            authenticatedRedirectPending: authenticatedRedirectPending,
            timeout: timeout,
            release: () => releases++,
          );

          state = AuthState.authenticated;
          auth.add(AuthState.authenticated);
          async.flushMicrotasks();
          expect(
            releases,
            1,
            reason:
                'an authenticated deep-link auth route the router leaves the '
                'user on must release immediately, not at the timeout',
          );

          // No lingering timer to fire later.
          async.elapse(timeout * 2);
          expect(releases, 1);

          controller.dispose();
          location.dispose();
          unawaited(auth.close());
        });
      },
    );

    test(
      'anonymous login recovery releases without waiting for the timeout',
      () {
        fakeAsync((async) {
          final auth = StreamController<AuthState>.broadcast();
          final location = ValueNotifier<String>(
            '/welcome/login-options?email=existing%40example.com',
          );
          var state = AuthState.checking;
          var releases = 0;

          final controller = StartupSplashReleaseController(
            authStateStream: auth.stream,
            currentAuthState: () => state,
            locationListenable: location,
            currentLocation: () => location.value,
            authenticatedRedirectPending: (currentLocation) =>
                authenticatedRedirectsFromAuthEntry(
                  currentLocation,
                  hasExpiredOAuthSession: false,
                  isAnonymous: true,
                ),
            timeout: timeout,
            release: () => releases++,
          );

          state = AuthState.authenticated;
          auth.add(AuthState.authenticated);
          async.flushMicrotasks();

          expect(
            releases,
            1,
            reason: 'the router leaves anonymous recovery on login options',
          );

          controller.dispose();
          location.dispose();
          unawaited(auth.close());
        });
      },
    );

    test(
      'authenticated email-verification deep link releases immediately',
      () {
        fakeAsync((async) {
          final auth = StreamController<AuthState>.broadcast();
          final location = ValueNotifier<String>('/verify-email');
          var state = AuthState.checking;
          var releases = 0;

          final controller = StartupSplashReleaseController(
            authStateStream: auth.stream,
            currentAuthState: () => state,
            locationListenable: location,
            currentLocation: () => location.value,
            authenticatedRedirectPending: authenticatedRedirectPending,
            timeout: timeout,
            release: () => releases++,
          );

          state = AuthState.authenticated;
          auth.add(AuthState.authenticated);
          async.flushMicrotasks();
          expect(
            releases,
            1,
            reason:
                '/verify-email is a deep-link auth route an authenticated user '
                'stays on — release',
          );

          controller.dispose();
          location.dispose();
          unawaited(auth.close());
        });
      },
    );

    test('timeout floor releases when no terminal state is reached', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/welcome');
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => AuthState.checking,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        async.elapse(timeout - const Duration(milliseconds: 1));
        expect(releases, 0, reason: 'splash held until the floor elapses');

        async.elapse(const Duration(milliseconds: 1));
        expect(releases, 1, reason: 'timeout floor releases a hung restore');

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test('releases exactly once across later changes and the timeout', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/welcome');
        var state = AuthState.checking;
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => state,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        state = AuthState.authenticated;
        auth.add(AuthState.authenticated);
        async.flushMicrotasks();
        location.value = '/home';
        expect(releases, 1);

        // Further churn must not re-fire.
        location.value = '/welcome';
        location.value = '/explore';
        auth.add(AuthState.authenticated);
        async.flushMicrotasks();
        async.elapse(timeout * 2);
        expect(releases, 1, reason: 'release is idempotent');

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });

    test('releases synchronously when already settled at construction', () {
      fakeAsync((async) {
        final auth = StreamController<AuthState>.broadcast();
        final location = ValueNotifier<String>('/home');
        var releases = 0;

        final controller = StartupSplashReleaseController(
          authStateStream: auth.stream,
          currentAuthState: () => AuthState.authenticated,
          locationListenable: location,
          currentLocation: () => location.value,
          authenticatedRedirectPending: authenticatedRedirectPending,
          timeout: timeout,
          release: () => releases++,
        );

        expect(
          releases,
          1,
          reason: 'authenticated + already off /welcome releases at once',
        );

        // No lingering timer to fire later.
        async.elapse(timeout * 2);
        expect(releases, 1);

        controller.dispose();
        location.dispose();
        unawaited(auth.close());
      });
    });
  });
}

class _RouterDelegateLocation extends ChangeNotifier {
  _RouterDelegateLocation(this.value);

  String value;

  void setSilently(String nextValue) {
    value = nextValue;
  }

  void notifyRedirectApplied() {
    notifyListeners();
  }
}
