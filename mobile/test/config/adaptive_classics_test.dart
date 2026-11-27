// ABOUTME: Tests the Adaptive Classics build switch and per-account gate:
// ABOUTME: on by default, active only for a confirmed non-protected account.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/auth_service.dart';

class _MutableAuthStateNotifier extends CurrentAuthState {
  _MutableAuthStateNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void set(AuthState next) => state = next;
}

ProviderContainer _container({
  required AuthState authState,
  required Future<ProtectedMinorStatus> Function() status,
}) {
  final container = ProviderContainer(
    overrides: [
      currentAuthStateProvider.overrideWithValue(authState),
      protectedMinorStatusProvider.overrideWith((ref) => status()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<bool> _settledGate(
  ProviderContainer container,
  Provider<bool> gate,
) async {
  // Keep the async status alive while it resolves, then read the gate.
  final subscription = container.listen(
    protectedMinorStatusProvider,
    (_, _) {},
  );
  addTearDown(subscription.close);
  try {
    await container.read(protectedMinorStatusProvider.future);
  } on Object {
    // A failed lookup is a valid input: the gate must still fail closed.
  }
  return container.read(gate);
}

void main() {
  group('Adaptive Classics build switch', () {
    test('ships on by default unless the build turns it off', () {
      // Test runs do not define ADAPTIVE_CLASSICS_ENABLED, so this observes
      // the shipped default.
      expect(
        const bool.hasEnvironment('ADAPTIVE_CLASSICS_ENABLED') ||
            adaptiveClassicsEnabled,
        isTrue,
      );
    });
  });

  group('confirmedNotProtectedMinorProvider', () {
    test(
      'is true only for an authenticated, resolved not-protected account',
      () async {
        final container = _container(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.notProtected(),
        );
        expect(
          await _settledGate(container, confirmedNotProtectedMinorProvider),
          isTrue,
        );
      },
    );

    test(
      'is false when Keycast answers without a verified_minor field',
      () async {
        final container = _container(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.fromKeycast(
            KeycastAccountStatus.fromJson(const {
              'email': 'a@b.com',
              'email_verified': true,
              'public_key': 'abc',
            }),
          ),
        );
        expect(
          await _settledGate(container, confirmedNotProtectedMinorProvider),
          isFalse,
        );
      },
    );

    test('is false for a protected minor', () async {
      final container = _container(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.protected(),
      );
      expect(
        await _settledGate(container, confirmedNotProtectedMinorProvider),
        isFalse,
      );
    });

    test(
      'is false for an unknown status, such as a session with no Keycast token',
      () async {
        final container = _container(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.unknown(),
        );
        expect(
          await _settledGate(container, confirmedNotProtectedMinorProvider),
          isFalse,
        );
      },
    );

    test('is false when the status lookup fails', () async {
      final container = _container(
        authState: AuthState.authenticated,
        status: () async => throw StateError('keycast unavailable'),
      );
      expect(
        await _settledGate(container, confirmedNotProtectedMinorProvider),
        isFalse,
      );
    });

    test('is false while the status is still loading', () {
      final pending = Completer<ProtectedMinorStatus>();
      final container = _container(
        authState: AuthState.authenticated,
        status: () => pending.future,
      );
      container.listen(protectedMinorStatusProvider, (_, _) {});
      expect(container.read(confirmedNotProtectedMinorProvider), isFalse);
    });

    test(
      'is false before authentication, even with a not-protected status',
      () async {
        final container = _container(
          authState: AuthState.unauthenticated,
          status: () async => ProtectedMinorStatus.notProtected(),
        );
        expect(
          await _settledGate(container, confirmedNotProtectedMinorProvider),
          isFalse,
        );
      },
    );

    test(
      'preserves confirmation during a same-account refresh and closes if the '
      'refresh turns protected or fails',
      () async {
        var nextStatus = Completer<ProtectedMinorStatus>()
          ..complete(ProtectedMinorStatus.notProtected());
        final container = _container(
          authState: AuthState.authenticated,
          status: () => nextStatus.future,
        );
        expect(
          await _settledGate(container, confirmedNotProtectedMinorProvider),
          isTrue,
        );

        // Simulate an AccountStateResumeRefresher invalidation while still
        // authenticated.
        nextStatus = Completer<ProtectedMinorStatus>();
        container.invalidate(protectedMinorStatusProvider);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);

        // A server-side flip to protected closes the gate immediately.
        nextStatus.complete(ProtectedMinorStatus.protected());
        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(confirmedNotProtectedMinorProvider), isFalse);

        // Confirm again, then resolve unknown: must fail closed.
        nextStatus = Completer<ProtectedMinorStatus>()
          ..complete(ProtectedMinorStatus.notProtected());
        container.invalidate(protectedMinorStatusProvider);
        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);

        nextStatus = Completer<ProtectedMinorStatus>();
        container.invalidate(protectedMinorStatusProvider);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);
        nextStatus.complete(ProtectedMinorStatus.unknown());
        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(confirmedNotProtectedMinorProvider), isFalse);

        // Confirm again, then fail a refresh with a retryable Exception:
        // must fail closed immediately even under Riverpod 3's default retry.
        nextStatus = Completer<ProtectedMinorStatus>()
          ..complete(ProtectedMinorStatus.notProtected());
        container.invalidate(protectedMinorStatusProvider);
        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);

        nextStatus = Completer<ProtectedMinorStatus>();
        container.invalidate(protectedMinorStatusProvider);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);
        nextStatus.completeError(Exception('keycast 503'));
        await pumpEventQueue();
        expect(container.read(confirmedNotProtectedMinorProvider), isFalse);
      },
    );

    test(
      'resets confirmation across an account switch even without an active '
      'watcher during the unauthenticated frame',
      () async {
        final authNotifier = _MutableAuthStateNotifier(AuthState.authenticated);
        var nextStatus = Completer<ProtectedMinorStatus>()
          ..complete(ProtectedMinorStatus.notProtected());
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWith(() => authNotifier),
            protectedMinorStatusProvider.overrideWith((ref) {
              final state = ref.watch(currentAuthStateProvider);
              if (state != AuthState.authenticated) {
                return Future.value(ProtectedMinorStatus.notProtected());
              }
              return nextStatus.future;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(protectedMinorStatusProvider.future);
        expect(container.read(confirmedNotProtectedMinorProvider), isTrue);

        // Account A logs out and Account B begins authenticating while nobody
        // reads confirmedNotProtectedMinorProvider during unauthenticated.
        nextStatus = Completer<ProtectedMinorStatus>();
        authNotifier.set(AuthState.unauthenticated);
        authNotifier.set(AuthState.authenticated);

        expect(container.read(confirmedNotProtectedMinorProvider), isFalse);
      },
    );

    test(
      'fails closed during a reload after an unwatched flip to protected or '
      'unknown',
      () async {
        for (final flippedStatus in [
          ProtectedMinorStatus.protected(),
          ProtectedMinorStatus.unknown(),
        ]) {
          var nextStatus = Completer<ProtectedMinorStatus>()
            ..complete(ProtectedMinorStatus.notProtected());
          final container = _container(
            authState: AuthState.authenticated,
            status: () => nextStatus.future,
          );
          final sub = container.listen(protectedMinorStatusProvider, (_, _) {});
          addTearDown(sub.close);

          await container.read(protectedMinorStatusProvider.future);
          expect(container.read(confirmedNotProtectedMinorProvider), isTrue);

          // Status flips while confirmedNotProtectedMinorProvider is unwatched.
          nextStatus = Completer<ProtectedMinorStatus>()
            ..complete(flippedStatus);
          container.invalidate(protectedMinorStatusProvider);
          await container.read(protectedMinorStatusProvider.future);

          // A subsequent reload starts before anyone re-reads the gate.
          nextStatus = Completer<ProtectedMinorStatus>();
          container.invalidate(protectedMinorStatusProvider);

          expect(container.read(confirmedNotProtectedMinorProvider), isFalse);
        }
      },
    );
  });

  group('adaptiveClassicsEnabledProvider', () {
    test(
      'follows the build switch for a confirmed non-protected account',
      () async {
        final container = _container(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.notProtected(),
        );
        expect(
          await _settledGate(container, adaptiveClassicsEnabledProvider),
          adaptiveClassicsEnabled,
        );
      },
    );

    test('keeps a protected minor on the archive path', () async {
      final container = _container(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.protected(),
      );
      expect(
        await _settledGate(container, adaptiveClassicsEnabledProvider),
        isFalse,
      );
    });

    test('keeps an unconfirmed account on the archive path', () async {
      final container = _container(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.unknown(),
      );
      expect(
        await _settledGate(container, adaptiveClassicsEnabledProvider),
        isFalse,
      );
    });
  });
}
