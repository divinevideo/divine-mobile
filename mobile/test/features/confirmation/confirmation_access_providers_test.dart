// ABOUTME: Tests for the Divine Confirmation access reader and the developer
// ABOUTME: settings that force an answer or simulate the requirement.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

/// Developer mode a test can turn off while the container lives, as the
/// developer options switch does.
class _DeveloperMode extends IsDeveloperModeEnabledNotifier {
  _DeveloperMode(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void turnOff() => state = false;
}

/// Auth state a test can move while the container lives, as a sign-out and
/// the next sign-in do.
class _AuthState extends CurrentAuthState {
  @override
  AuthState build() => AuthState.authenticated;

  void moveTo(AuthState value) => state = value;
}

void main() {
  late _MockIdentityClaimsRepository repository;

  setUp(() {
    repository = _MockIdentityClaimsRepository();
    when(
      () => repository.confirmationAccess(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => ConfirmationAccess.has);
  });

  Future<ProviderContainer> containerWith({
    required bool developerMode,
    String? storedOverride,
    bool? storedSimulation,
    bool debugBuild = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      confirmationAccessOverrideKey: ?storedOverride,
      confirmationRequirementSimulatedKey: ?storedSimulation,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isDeveloperModeEnabledProvider.overrideWith(
          () => _DeveloperMode(developerMode),
        ),
        confirmationAccessDebugBuildProvider.overrideWithValue(debugBuild),
        identityClaimsRepositoryProvider.overrideWithValue(repository),
        currentAuthStateProvider.overrideWith(_AuthState.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('confirmationAccessReaderProvider', () {
    test('an override applies in developer mode', () async {
      final container = await containerWith(
        storedOverride: 'hasNot',
        developerMode: true,
      );

      final read = container.read(confirmationAccessReaderProvider);

      expect(await read(), equals(ConfirmationAccess.hasNot));
      expect(await read(refresh: true), equals(ConfirmationAccess.hasNot));
      verifyNever(
        () => repository.confirmationAccess(refresh: any(named: 'refresh')),
      );
    });

    test('an override applies in a debug build', () async {
      final container = await containerWith(
        storedOverride: 'unknown',
        developerMode: false,
        debugBuild: true,
      );

      final read = container.read(confirmationAccessReaderProvider);

      expect(await read(), equals(ConfirmationAccess.unknown));
    });

    test('a stored override is ignored once developer mode is off', () async {
      final container = await containerWith(
        storedOverride: 'hasNot',
        developerMode: true,
      );
      expect(
        await container.read(confirmationAccessReaderProvider)(),
        equals(ConfirmationAccess.hasNot),
      );

      (container.read(
        isDeveloperModeEnabledProvider.notifier,
      ) as _DeveloperMode).turnOff();

      expect(
        await container.read(confirmationAccessReaderProvider)(),
        equals(ConfirmationAccess.has),
      );
      verify(() => repository.confirmationAccess()).called(1);
      // Still stored: turning developer mode back on restores it.
      expect(
        container.read(confirmationAccessOverrideProvider),
        equals(ConfirmationAccess.hasNot),
      );
    });

    test('a sign-out then a sign-in drops the forced answer', () async {
      final container = await containerWith(
        storedOverride: 'hasNot',
        developerMode: true,
      );
      expect(
        await container.read(confirmationAccessReaderProvider)(),
        equals(ConfirmationAccess.hasNot),
      );
      final auth =
          container.read(currentAuthStateProvider.notifier) as _AuthState;

      // The sign-out sweeps the stored key before the auth state flips.
      await container
          .read(sharedPreferencesProvider)
          .remove(
            confirmationAccessOverrideKey,
          );
      auth.moveTo(AuthState.unauthenticated);
      auth.moveTo(AuthState.authenticated);

      expect(container.read(confirmationAccessOverrideProvider), isNull);
      expect(
        await container.read(confirmationAccessReaderProvider)(),
        equals(ConfirmationAccess.has),
      );
      verify(() => repository.confirmationAccess()).called(1);
    });

    test('with no override the reader is the repository', () async {
      final container = await containerWith(developerMode: true);

      final read = container.read(confirmationAccessReaderProvider);

      expect(await read(), equals(ConfirmationAccess.has));
      await read(refresh: true);
      verify(() => repository.confirmationAccess()).called(1);
      verify(() => repository.confirmationAccess(refresh: true)).called(1);
    });
  });

  group('confirmationAccessOverrideProvider', () {
    test('reads nothing for a missing or unrecognised stored value', () async {
      expect(
        (await containerWith(
          developerMode: true,
        )).read(confirmationAccessOverrideProvider),
        isNull,
      );
      expect(
        (await containerWith(
          storedOverride: 'maybe',
          developerMode: true,
        )).read(confirmationAccessOverrideProvider),
        isNull,
      );
    });

    test('set stores the choice and null clears it', () async {
      final container = await containerWith(developerMode: true);
      final notifier = container.read(
        confirmationAccessOverrideProvider.notifier,
      );
      final prefs = container.read(sharedPreferencesProvider);

      await notifier.set(ConfirmationAccess.hasNot);
      expect(
        container.read(confirmationAccessOverrideProvider),
        equals(ConfirmationAccess.hasNot),
      );
      expect(prefs.getString(confirmationAccessOverrideKey), equals('hasNot'));

      await notifier.set(null);
      expect(container.read(confirmationAccessOverrideProvider), isNull);
      expect(prefs.containsKey(confirmationAccessOverrideKey), isFalse);
    });
  });

  group('simulateConfirmationRequirementProvider', () {
    test('applies a stored choice in developer mode', () async {
      final container = await containerWith(
        storedSimulation: true,
        developerMode: true,
      );

      expect(container.read(simulateConfirmationRequirementProvider), isTrue);
    });

    test('applies a stored choice in a debug build', () async {
      final container = await containerWith(
        storedSimulation: true,
        developerMode: false,
        debugBuild: true,
      );

      expect(container.read(simulateConfirmationRequirementProvider), isTrue);
    });

    test('is off with nothing stored', () async {
      final container = await containerWith(
        developerMode: true,
        debugBuild: true,
      );

      expect(container.read(simulateConfirmationRequirementProvider), isFalse);
    });

    test('a stored choice is ignored once developer mode is off', () async {
      final container = await containerWith(
        storedSimulation: true,
        developerMode: true,
      );
      expect(container.read(simulateConfirmationRequirementProvider), isTrue);

      (container.read(
        isDeveloperModeEnabledProvider.notifier,
      ) as _DeveloperMode).turnOff();

      expect(container.read(simulateConfirmationRequirementProvider), isFalse);
      // Still stored: turning developer mode back on restores it.
      expect(container.read(confirmationRequirementSimulatedProvider), isTrue);
    });
  });

  group('confirmationRequirementSimulatedProvider', () {
    test('set stores the choice, and false clears it', () async {
      final container = await containerWith(developerMode: true);
      final notifier = container.read(
        confirmationRequirementSimulatedProvider.notifier,
      );
      final prefs = container.read(sharedPreferencesProvider);

      await notifier.set(on: true);
      expect(container.read(confirmationRequirementSimulatedProvider), isTrue);
      expect(prefs.getBool(confirmationRequirementSimulatedKey), isTrue);

      await notifier.set(on: false);
      expect(container.read(confirmationRequirementSimulatedProvider), isFalse);
      expect(prefs.containsKey(confirmationRequirementSimulatedKey), isFalse);
    });
  });
}
