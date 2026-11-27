// ABOUTME: Tests protectedMinorStatusProvider guard branches (#174):
// ABOUTME: unauthenticated -> not protected, debug override forces protected.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('protectedMinorStatusProvider', () {
    test(
      'unauthenticated resolves to not-protected without any fetch',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(
              AuthState.unauthenticated,
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final status = await container.read(
          protectedMinorStatusProvider.future,
        );

        expect(status.isProtectedMinor, isFalse);
      },
    );

    test('debug override forces protected when authenticated', () async {
      SharedPreferences.setMockInitialValues({
        'protected_minor_override': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(protectedMinorStatusProvider.future);

      expect(status.isProtectedMinor, isTrue);
    });

    test(
      'authenticated: real path reads session token and fetches the flag',
      () async {
        SharedPreferences.setMockInitialValues({}); // no override -> real fetch
        final prefs = await SharedPreferences.getInstance();

        final oauth = KeycastOAuth(
          config: const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'c',
            redirectUri: 'divine://cb',
          ),
          storage: MemoryKeycastStorage(),
          httpClient: MockClient((req) async {
            // Proves the provider threads the session token into the request.
            expect(req.headers['Authorization'], 'Bearer tok123');
            return http.Response(
              '{"email":"a","email_verified":true,"public_key":"p",'
              '"verified_minor":true,"verified_minor_at":"2026-06-30T12:00:00Z"}',
              200,
            );
          }),
        );

        // The token comes from the owner-bound gate rather than straight off the
        // stored session, so a session another account left behind cannot answer
        // the minor question for this one.
        final authService = _MockAuthService();
        when(
          authService.activeAccountKeycastToken,
        ).thenAnswer((_) async => 'tok123');

        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            sharedPreferencesProvider.overrideWithValue(prefs),
            oauthClientProvider.overrideWithValue(oauth),
            authServiceProvider.overrideWithValue(authService),
          ],
        );
        addTearDown(container.dispose);

        final status = await container.read(
          protectedMinorStatusProvider.future,
        );

        expect(status.isProtectedMinor, isTrue);
        expect(status.verifiedMinorAt, DateTime.utc(2026, 6, 30, 12));
      },
    );

    // A session the gate refuses (unbound, or bound to another account) yields
    // no token at all. That must read as unknown — not as a positive
    // not-a-minor, which would lift the #175/#176 protections and overwrite the
    // sticky verdict on an absent signal.
    test(
      'authenticated: a refused session resolves to unknown, no fetch',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        var requests = 0;
        final oauth = KeycastOAuth(
          config: const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'c',
            redirectUri: 'divine://cb',
          ),
          storage: MemoryKeycastStorage(),
          httpClient: MockClient((req) async {
            requests++;
            return http.Response('{}', 200);
          }),
        );

        final authService = _MockAuthService();
        when(
          authService.activeAccountKeycastToken,
        ).thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            sharedPreferencesProvider.overrideWithValue(prefs),
            oauthClientProvider.overrideWithValue(oauth),
            authServiceProvider.overrideWithValue(authService),
          ],
        );
        addTearDown(container.dispose);

        final status = await container.read(
          protectedMinorStatusProvider.future,
        );

        expect(status.kind, ProtectedMinorStatusKind.unknown);
        expect(requests, isZero);
      },
    );
  });

  group('isProtectedMinorProvider', () {
    test(
      'isProtectedMinorProvider: false until resolved, true once protected',
      () async {
        SharedPreferences.setMockInitialValues({
          'protected_minor_override': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        // Before the async status resolves, the seam reads false (safe default).
        expect(container.read(isProtectedMinorProvider), isFalse);

        // After resolution (override forces protected) an authenticated, freshly
        // resolved status is trusted, so it reads true.
        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(isProtectedMinorProvider), isTrue);
      },
    );

    test(
      'isProtectedMinorProvider: unauthenticated notProtected does NOT wipe a '
      'confirmed minor (fail-safe)',
      () async {
        const minorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        SharedPreferences.setMockInitialValues({
          'protected_minor_sticky_$minorPubkey': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(minorPubkey);

        final container = ProviderContainer(
          overrides: [
            // Auth still restoring: the #174 seam emits notProtected() here.
            currentAuthStateProvider.overrideWithValue(AuthState.checking),
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(prefs),
            protectedMinorStatusProvider.overrideWith(
              (ref) async => ProtectedMinorStatus.notProtected(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(protectedMinorStatusProvider.future);

        // Must stay protected (sticky), and the store must not be wiped to false.
        expect(container.read(isProtectedMinorProvider), isTrue);
        expect(prefs.getBool('protected_minor_sticky_$minorPubkey'), isTrue);
      },
    );

    test(
      'isProtectedMinorProvider: authenticated notProtected lifts and persists '
      'the lift',
      () async {
        const pubkey =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        SharedPreferences.setMockInitialValues({
          'protected_minor_sticky_$pubkey': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(prefs),
            protectedMinorStatusProvider.overrideWith(
              (ref) async => ProtectedMinorStatus.notProtected(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(protectedMinorStatusProvider.future);

        // A real (authenticated, resolved) not-protected signal lifts protection.
        expect(container.read(isProtectedMinorProvider), isFalse);
        expect(prefs.getBool('protected_minor_sticky_$pubkey'), isFalse);
      },
    );

    test(
      'isProtectedMinorProvider: authenticated unknown (e.g. a missing token) '
      'falls to the sticky verdict and keeps a confirmed minor protected',
      () async {
        // The load-bearing case for the null-token fix: the repo now yields
        // unknown (not notProtected) on a missing token, so a confirmed minor must
        // stay protected via the sticky store and the store must NOT be wiped.
        const pubkey =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
        SharedPreferences.setMockInitialValues({
          'protected_minor_sticky_$pubkey': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(prefs),
            protectedMinorStatusProvider.overrideWith(
              (ref) async => ProtectedMinorStatus.unknown(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(protectedMinorStatusProvider.future);

        expect(container.read(isProtectedMinorProvider), isTrue);
        expect(prefs.getBool('protected_minor_sticky_$pubkey'), isTrue);
      },
    );

    for (final (description, flag) in [
      ('missing', ''),
      ('malformed', ',"verified_minor":"false"'),
    ]) {
      test('a $description Keycast verdict preserves known protection', () async {
        const pubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const stickyKey = 'protected_minor_sticky_$pubkey';
        SharedPreferences.setMockInitialValues({stickyKey: true});
        final prefs = await SharedPreferences.getInstance();
        final oauth = KeycastOAuth(
          config: const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'c',
            redirectUri: 'divine://cb',
          ),
          storage: MemoryKeycastStorage(),
          httpClient: MockClient((_) async {
            return http.Response(
              '{"email":"a","email_verified":true,"public_key":"$pubkey"$flag}',
              200,
            );
          }),
        );

        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
        when(authService.activeAccountKeycastToken)
            .thenAnswer((_) async => 'tok');
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            authServiceProvider.overrideWithValue(authService),
            oauthClientProvider.overrideWithValue(oauth),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final status = await container.read(
          protectedMinorStatusProvider.future,
        );
        expect(container.read(isProtectedMinorProvider), isTrue);
        expect(prefs.getBool(stickyKey), isTrue);
        expect(status.kind, ProtectedMinorStatusKind.unknown);
      });
    }

    test(
      'isProtectedMinorProvider: authenticated unknown for a never-seen account '
      'does NOT over-restrict (stays not-protected)',
      () async {
        const pubkey =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(prefs),
            protectedMinorStatusProvider.overrideWith(
              (ref) async => ProtectedMinorStatus.unknown(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(protectedMinorStatusProvider.future);

        // Never positively seen -> unknown must not invent protection.
        expect(container.read(isProtectedMinorProvider), isFalse);
      },
    );
  });
}
