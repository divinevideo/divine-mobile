// ABOUTME: Tests for where the app reads Divine Confirmation access from, and
// ABOUTME: the developer override that forces an answer for testing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
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
    bool debugBuild = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      confirmationAccessOverrideKey: ?storedOverride,
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
}
