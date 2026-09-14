// ABOUTME: Tests isDmRestrictedProvider (#176, #8561) — only an affirmative
// ABOUTME: Greenlight designation restricts DMs, and that designation is sticky.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubkey = 'a' * 64;

  late SharedPreferences prefs;
  late _MockAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
    when(
      () => authService.authenticationSource,
    ).thenReturn(AuthenticationSource.divineOAuth);
  });

  ProviderContainer containerWith({
    required AuthState authState,
    Future<ProtectedMinorStatus> Function()? status,
    AuthenticationSource authSource = AuthenticationSource.divineOAuth,
  }) {
    when(() => authService.authenticationSource).thenReturn(authSource);
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(authState),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(authService),
        if (status != null)
          protectedMinorStatusProvider.overrideWith((ref) => status()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('unresolved with no verdict', () {
    test('unauthenticated with no verdict persisted is unrestricted', () {
      final container = containerWith(authState: AuthState.unauthenticated);

      expect(container.read(isDmRestrictedProvider), isFalse);
    });
  });

  group('trusted live verdict', () {
    test('a trusted not-protected answer lifts the restriction', () async {
      final container = containerWith(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.notProtected(),
      );
      await container.read(protectedMinorStatusProvider.future);

      expect(container.read(isDmRestrictedProvider), isFalse);
    });

    test('a trusted protected answer restricts', () async {
      final container = containerWith(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.protected(),
      );
      await container.read(protectedMinorStatusProvider.future);

      expect(container.read(isDmRestrictedProvider), isTrue);
    });
  });

  group('persisted verdict', () {
    test(
      'a trusted verdict persists and relaxes the next cold start',
      () async {
        final first = containerWith(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.notProtected(),
        );
        await first.read(protectedMinorStatusProvider.future);
        expect(first.read(isDmRestrictedProvider), isFalse);

        // Next session: status unresolved (e.g. offline), but the persisted
        // positive not-protected verdict keeps an adult unrestricted.
        final second = containerWith(
          authState: AuthState.authenticated,
          status: () => Completer<ProtectedMinorStatus>().future,
        );
        expect(second.read(isDmRestrictedProvider), isFalse);
      },
    );

    test(
      'sticky protected survives an unresolved recheck (token gap)',
      () async {
        final store = ProtectedMinorStickyStore(prefs: prefs);
        await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());

        final container = containerWith(
          authState: AuthState.authenticated,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(isDmRestrictedProvider), isTrue);
      },
    );
  });

  group('unknown verdict', () {
    test('an unknown resolution falls back to the persisted verdict', () async {
      final store = ProtectedMinorStickyStore(prefs: prefs);
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());

      final container = containerWith(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.unknown(),
      );
      await container.read(protectedMinorStatusProvider.future);

      expect(container.read(isDmRestrictedProvider), isFalse);
    });

    test(
      'an unknown resolution leaves an undesignated account unrestricted',
      () async {
        final container = containerWith(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.unknown(),
        );
        await container.read(protectedMinorStatusProvider.future);

        expect(container.read(isDmRestrictedProvider), isFalse);
        final store = ProtectedMinorStickyStore(prefs: prefs);
        expect(store.lastKnownFor(pubkey), isNull);
      },
    );
  });

  // Authentication source does not confer protected-minor status. With no
  // affirmative live or persisted designation, every account is unrestricted.
  group('per-auth-source fail direction with an absent verdict', () {
    for (final source in AuthenticationSource.values) {
      test('$source -> unrestricted', () {
        final container = containerWith(
          authState: AuthState.authenticated,
          authSource: source,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(isDmRestrictedProvider), isFalse);
      });
    }
  });

  // Merely having used Keycast is not an affirmative Greenlight designation.
  group('ever-Keycast pubkey remains unrestricted without a verdict', () {
    for (final source in [
      AuthenticationSource.automatic,
      AuthenticationSource.importedKeys,
      AuthenticationSource.bunker,
      AuthenticationSource.amber,
      AuthenticationSource.nip07,
    ]) {
      test('$source with Keycast marker -> unrestricted', () async {
        final store = ProtectedMinorStickyStore(prefs: prefs);
        await store.markKeycastAccount(pubkey);

        final container = containerWith(
          authState: AuthState.authenticated,
          authSource: source,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(isDmRestrictedProvider), isFalse);
      });
    }
  });

  group('auth transitions', () {
    test(
      'a live provider does not infer Greenlight status after an account switch',
      () async {
        // Regression test for the provider-cache staleness in
        // keycastSignalApplicableProvider: AuthService mutates its pubkey and
        // auth source in place, so without a currentAuthStateProvider watch the
        // extracted provider keeps a stale value into the next account's
        // session — and a stale `false` unrestricts a Keycast-backed account.
        //
        // Uses the real currentAuthStateProvider stream over a mock AuthService
        // so an auth transition propagates exactly as in
        // production; overriding currentAuthStateProvider with a value would
        // hide the defect.
        const pubkeyA =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const pubkeyB =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

        final authStateController = StreamController<AuthState>.broadcast();
        addTearDown(authStateController.close);

        var state = AuthState.authenticated;
        var source = AuthenticationSource.importedKeys;
        var key = pubkeyA;

        final liveAuth = _MockAuthService();
        when(() => liveAuth.authState).thenAnswer((_) => state);
        when(
          () => liveAuth.authStateStream,
        ).thenAnswer((_) => authStateController.stream);
        when(() => liveAuth.authenticationSource).thenAnswer((_) => source);
        when(() => liveAuth.currentPublicKeyHex).thenAnswer((_) => key);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(liveAuth),
            protectedMinorStatusProvider.overrideWith(
              // Never resolves: Keycast unreachable for both accounts.
              (ref) => Completer<ProtectedMinorStatus>().future,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep a listener attached across the whole sequence, as an app-shell
        // consumer would.
        final sub = container.listen(
          isDmRestrictedProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        await pumpEventQueue();

        // Account A: pure self-custody, never seen by Keycast -> unrestricted.
        expect(container.read(isDmRestrictedProvider), isFalse);

        // Sign out.
        state = AuthState.unauthenticated;
        key = '';
        authStateController.add(AuthState.unauthenticated);
        await pumpEventQueue();
        expect(container.read(isDmRestrictedProvider), isFalse);

        // Sign in as account B: divineOAuth, Keycast unreachable, and no
        // persisted Greenlight designation. It remains unrestricted.
        state = AuthState.authenticated;
        source = AuthenticationSource.divineOAuth;
        key = pubkeyB;
        authStateController.add(AuthState.authenticated);
        await pumpEventQueue();

        expect(container.read(isDmRestrictedProvider), isFalse);
      },
    );
  });
}
