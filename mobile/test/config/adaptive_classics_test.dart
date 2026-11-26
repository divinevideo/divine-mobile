// ABOUTME: Tests the Adaptive Classics build switch and per-account gate:
// ABOUTME: on by default, active only for a confirmed non-protected account.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/auth_service.dart';

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
      // Test runs pass no dart-define, so this observes the shipped default.
      const definedValue = bool.fromEnvironment(
        'ADAPTIVE_CLASSICS_ENABLED',
        defaultValue: true,
      );
      expect(adaptiveClassicsEnabled, definedValue);
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
