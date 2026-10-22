// ABOUTME: Sign-out must accept the live filter's empty migration marker.
// ABOUTME: Real provider cleanup still rejects retained account preferences.

import 'dart:io';

import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/shared_channel_override.dart';
import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';
import '../test_setup.dart';

class _Discovery extends Mock implements RelayDiscoveryService {}

class _SlotLinuxOptions extends LinuxOptions {
  const _SlotLinuxOptions(this.slot);

  final String slot;

  @override
  Map<String, String> toMap() => {'fixtureStorageSlot': slot};
}

class _SlotWindowsOptions extends WindowsOptions {
  const _SlotWindowsOptions(this.slot);

  final String slot;

  @override
  Map<String, String> toMap() => {'fixtureStorageSlot': slot};
}

FlutterSecureStorage _slotStorage(String slot) => FlutterSecureStorage(
  aOptions: AndroidOptions(preferencesKeyPrefix: slot),
  iOptions: IOSOptions(
    accessibility: slot == 'current'
        ? KeychainAccessibility.first_unlock
        : KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: slot == 'current'
        ? KeychainAccessibility.first_unlock
        : KeychainAccessibility.first_unlock_this_device,
  ),
  lOptions: _SlotLinuxOptions(slot),
  wOptions: _SlotWindowsOptions(slot),
);

void main() {
  setupTestEnvironment();
  group('Sign-out with live content-filter reset', () {
    const secure = FlutterSecureStorage();
    const nativeChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    late SharedPreferences prefs;
    late AppDatabase db;
    late SqliteCacheStore cache;
    late Directory tempDir;
    late PathProviderPlatform previousPathProvider;
    late Map<String, String> currentNative;
    late Map<String, String> legacyNative;
    late _Discovery discovery;
    late List<({ProviderContainer container, AuthService auth})> sessions;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.test(NativeDatabase.memory());
      cache = SqliteCacheStore(NativeDatabase.memory());
      await CacheSync.init(dao: cache.dao);
      sessions = [];
      currentNative = {};
      legacyNative = {};
      overrideSharedChannel(nativeChannel, (call) async {
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        final options = args['options'] as Map<dynamic, dynamic>? ?? {};
        final slot =
            options['fixtureStorageSlot'] ?? options['preferencesKeyPrefix'];
        final values =
            slot == 'legacy' ||
                options['accessibility'] == 'first_unlock_this_device'
            ? legacyNative
            : currentNative;
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            values[key!] = args['value'] as String;
          case 'delete':
            values.remove(key);
          case 'deleteAll':
            values.clear();
          case 'readAll':
            return Map<String, String>.of(values);
          case 'containsKey':
            return values.containsKey(key);
          case 'getCapabilities':
            return {'basicSecureStorage': true};
        }
        return null;
      });
      discovery = _Discovery();
      when(() => discovery.discoverRelays(any())).thenAnswer(
        (_) async =>
            RelayDiscoveryResult.failure('No network in cleanup tests'),
      );
      when(() => discovery.clearCache(any())).thenAnswer((_) async {});
      tempDir = await Directory.systemTemp.createTemp('signout_filter_reset_');
      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      await TestHelpers.initHiveHome();
      await TestHelpers.cleanupHiveBox(HiveBoxNames.notifications);
      await TestHelpers.cleanupHiveBox(HiveBoxNames.peopleLists);
    });

    tearDown(() async {
      for (final session in sessions.reversed) {
        await session.auth.dispose();
        session.container.dispose();
      }
      await db.close();
      await cache.close();
      await TestHelpers.cleanupHiveBox(HiveBoxNames.notifications);
      await TestHelpers.cleanupHiveBox(HiveBoxNames.peopleLists);
      PathProviderPlatform.instance = previousPathProvider;
      await tempDir.delete(recursive: true);
    });

    Future<({ProviderContainer container, AuthService auth})> session() async {
      final keyStorage = SecureKeyStorage(
        securityConfig: SecurityConfig.desktop,
        platformStorage: PlatformSecureStorage.forPlatform(
          TargetPlatform.iOS,
          fallbackStorage: _slotStorage('current'),
          legacyStorage: _slotStorage('legacy'),
        ),
      );
      await keyStorage.initialize();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          isProtectedMinorProvider.overrideWithValue(false),
          openVineImageCacheClearProvider.overrideWithValue(() async {}),
          // These fixtures have no upload files. All database deletions and the
          // production preference-service reset callback remain live.
          pendingUploadOwnerCleanupProvider.overrideWithValue((_) async => 0),
          authServiceProvider.overrideWith(
            (ref) => AuthService(
              userDataCleanupService: ref.watch(userDataCleanupServiceProvider),
              keyStorage: keyStorage,
              flutterSecureStorage: secure,
              backgroundActivityManager: BackgroundActivityManager(),
              relayDiscoveryService: discovery,
              profileCheckIndexerUrl: 'unsupported://profile.invalid',
            ),
          ),
        ],
      );
      final value = (
        container: container,
        auth: container.read(authServiceProvider),
      );
      sessions.add(value);
      return value;
    }

    Future<ContentFilterService> changeLiveFilters(
      ProviderContainer container,
    ) async {
      final filter = container.read(contentFilterServiceProvider);
      await filter.initialized;
      await filter.setPreference(
        ContentLabel.spoiler,
        ContentFilterPreference.hide,
      );
      expect(
        prefs.containsKey(ContentFilterService.filterPrefsStorageKey),
        isTrue,
      );
      expect(
        filter.getPreference(ContentLabel.spoiler),
        ContentFilterPreference.hide,
      );
      return filter;
    }

    Future<void> restartPreferences() async {
      final previous = prefs;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      expect(prefs, isNot(same(previous)));
    }

    void expectEmptyFilters(
      ProviderContainer container,
      ContentFilterService filter,
    ) {
      expect(container.read(contentFilterServiceProvider), same(filter));
      expect(
        filter.getPreference(ContentLabel.spoiler),
        ContentFilterPreference.warn,
      );
      expect(
        filter.getPreference(ContentLabel.nudity),
        ContentFilterPreference.hide,
      );
      expect(prefs.get(ContentFilterService.filterMigratedStorageKey), isTrue);
      expect(
        prefs.containsKey(ContentFilterService.filterPrefsStorageKey),
        isFalse,
      );
      expect(
        prefs.containsKey(
          ContentFilterService.legacyAdultContentPreferenceStorageKey,
        ),
        isFalse,
      );
      expect(prefs.containsKey(PendingAccountCleanup.storageKey), isFalse);
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
    }

    test(
      'sign-out resets the live filter and permits same-account restart',
      () async {
        final outgoing = await session();
        expect((await outgoing.auth.importFromHex('2' * 64)).success, isTrue);
        final owner = outgoing.auth.currentPublicKeyHex!;
        final filter = await changeLiveFilters(outgoing.container);

        await outgoing.auth.signOut();

        expect(outgoing.auth.authState, AuthState.unauthenticated);
        expect(outgoing.auth.currentPublicKeyHex, isNull);
        expect(prefs.get('current_user_pubkey_hex'), isNull);
        expectEmptyFilters(outgoing.container, filter);
        await restartPreferences();
        final restarted = await session();
        await restarted.auth.initialize();
        expect(restarted.auth.authState, AuthState.authenticated);
        expect(restarted.auth.currentPublicKeyHex, owner);
        expect(
          restarted.auth.committedAccountActivationReceipt!.isCurrent,
          isTrue,
        );
        final restartedFilter = restarted.container.read(
          contentFilterServiceProvider,
        );
        await restartedFilter.initialized;
        expect(
          restartedFilter.getPreference(ContentLabel.spoiler),
          ContentFilterPreference.warn,
        );
      },
    );

    test(
      'removing active account data permits restoring a different account',
      () async {
        final outgoing = await session();
        expect((await outgoing.auth.importFromHex('2' * 64)).success, isTrue);
        final removedOwner = outgoing.auth.currentPublicKeyHex!;
        final removedNpub = outgoing.auth.currentNpub!;
        final filter = await changeLiveFilters(outgoing.container);
        final otherKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final otherOwner = otherKeys.publicKeyHex;
        final otherNpub = otherKeys.npub;
        await secure.write(
          key: 'saved_identity_$otherNpub',
          value: otherKeys.withPrivateKey(
            (hex) =>
                'privateKeyHex:$hex|publicKeyHex:$otherOwner|npub:$otherNpub',
          ),
        );
        otherKeys.dispose();

        await outgoing.auth.signOut(
          deleteKeys: true,
          deleteLocalUserData: true,
        );

        expect(outgoing.auth.authState, AuthState.unauthenticated);
        expectEmptyFilters(outgoing.container, filter);
        expect(currentNative.containsKey('nostr_primary_key'), isFalse);
        expect(
          currentNative.containsKey('saved_identity_$removedNpub'),
          isFalse,
        );
        expect(await secure.read(key: 'saved_identity_$otherNpub'), isNotNull);
        await restartPreferences();
        final restarted = await session();
        await restarted.auth.initializeForAccountSwitch();
        await restarted.auth.signInForAccount(
          otherOwner,
          AuthenticationSource.importedKeys,
        );
        expect(restarted.auth.currentPublicKeyHex, otherOwner);
        expect(restarted.auth.currentPublicKeyHex, isNot(removedOwner));
        expect(
          restarted.auth.committedAccountActivationReceipt!.isCurrent,
          isTrue,
        );
      },
    );

    test('ownerless keyless sign-out permits creating a new account', () async {
      final outgoing = await session();
      final filter = await changeLiveFilters(outgoing.container);
      expect(outgoing.auth.currentPublicKeyHex, isNull);

      await outgoing.auth.signOut();

      expect(outgoing.auth.authState, AuthState.unauthenticated);
      expectEmptyFilters(outgoing.container, filter);
      expect(currentNative, isEmpty);
      expect((await outgoing.auth.createNewIdentity()).success, isTrue);
      expect(outgoing.auth.authState, AuthState.authenticated);
      expect(
        outgoing.auth.committedAccountActivationReceipt!.isCurrent,
        isTrue,
      );
    });

    test('keyless OAuth sign-out retires owned session globals', () async {
      final outgoing = await session();
      final coordinates = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
      final owner = coordinates.publicKeyHex;
      coordinates.dispose();
      final oauthSession = KeycastSession(
        bunkerUrl: 'https://keycast.example.invalid',
        accessToken: 'owned-access-token',
        refreshToken: 'owned-refresh-token',
        authorizationHandle: 'owned-authorization-handle',
        userPubkey: owner,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await outgoing.auth.signInWithDivineOAuth(oauthSession);
      expect(outgoing.auth.authState, AuthState.authenticated);
      expect(
        outgoing.auth.authenticationSource,
        AuthenticationSource.divineOAuth,
      );
      expect(outgoing.auth.currentPublicKeyHex, owner);
      expect(currentNative.containsKey('nostr_primary_key'), isFalse);
      final filter = await changeLiveFilters(outgoing.container);

      await outgoing.auth.signOut();

      expect(outgoing.auth.authState, AuthState.unauthenticated);
      expect(outgoing.auth.currentPublicKeyHex, isNull);
      expectEmptyFilters(outgoing.container, filter);
      for (final key in [
        'keycast_session',
        'keycast_refresh_token',
        'keycast_auth_handle',
      ]) {
        expect(await secure.read(key: key), isNull);
      }
      expect(await secure.read(key: 'keycast_session_$owner'), isNotNull);
      expect(currentNative.containsKey('nostr_primary_key'), isFalse);
    });

    test(
      'neutral filter marker cannot heal another account cold pending intent',
      () async {
        final alice = SecureKeyContainer.fromPrivateKeyHex('2' * 64);
        final owner = alice.publicKeyHex;
        await secure.write(
          key: 'nostr_primary_key',
          value: alice.withPrivateKey(
            (hex) =>
                'privateKeyHex:$hex|publicKeyHex:$owner|npub:${alice.npub}',
          ),
        );
        alice.dispose();
        await AccountActivationCoordinator.forPreferences(prefs).begin(
          ownerPubkey: owner,
          isCurrent: () => true,
        );
        await prefs.setBool(
          ContentFilterService.filterMigratedStorageKey,
          true,
        );
        final retained = prefs.get(AccountActivationCoordinator.storageKey);
        final nativeBefore = Map<String, String>.of(currentNative);
        final legacyBefore = Map<String, String>.of(legacyNative);
        await restartPreferences();
        final incoming = await session();
        final gate = AccountActivationCoordinator.forPreferences(prefs);
        expect(gate.hasUnresolvedActivation, isTrue);

        final attempt = await incoming.auth.importFromHex('3' * 64);

        expect(attempt.success, isFalse);
        expect(incoming.auth.authState, AuthState.unauthenticated);
        expect(incoming.auth.currentPublicKeyHex, isNull);
        expect(incoming.auth.committedAccountActivationReceipt, isNull);
        expect(incoming.auth.takeFreshAccountListCreationPermit(), isNull);
        expect(prefs.get(AccountActivationCoordinator.storageKey), retained);
        expect(
          prefs.get(ContentFilterService.filterMigratedStorageKey),
          isTrue,
        );
        expect(currentNative, nativeBefore);
        expect(legacyNative, legacyBefore);
        expect(gate.hasUnresolvedActivation, isTrue);
        expect(gate.committedOwnerPubkey, isNull);
      },
    );

    for (final retained in <({String name, String key, Object value})>[
      (
        name: 'filter payload',
        key: ContentFilterService.filterPrefsStorageKey,
        value: '{"spoiler":"hide"}',
      ),
      (
        name: 'legacy adult preference',
        key: ContentFilterService.legacyAdultContentPreferenceStorageKey,
        value: 0,
      ),
      (
        name: 'false migration marker',
        key: ContentFilterService.filterMigratedStorageKey,
        value: false,
      ),
      (
        name: 'malformed migration marker',
        key: ContentFilterService.filterMigratedStorageKey,
        value: 'true',
      ),
      (
        name: 'another account preference',
        key: LanguagePreferenceService.prefsKey,
        value: 'es',
      ),
    ]) {
      test('sign-out remains incomplete with retained ${retained.name}', () async {
        final outgoing = await session();
        expect((await outgoing.auth.importFromHex('2' * 64)).success, isTrue);
        await changeLiveFilters(outgoing.container);
        final cleanup = outgoing.container.read(userDataCleanupServiceProvider);
        final productionCleanup = cleanup.onDatabaseCleanup!;
        cleanup.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
              bool forgetAccount = false,
            }) async {
              // Delegate to the actual provider reset, then simulate a retained
              // account write. The regression must not exempt these values.
              await productionCleanup(
                userPubkey: userPubkey,
                deleteUserData: deleteUserData,
                preserveActiveSession: preserveActiveSession,
              );
              switch (retained.value) {
                case final bool value:
                  await prefs.setBool(retained.key, value);
                case final int value:
                  await prefs.setInt(retained.key, value);
                case final String value:
                  await prefs.setString(retained.key, value);
              }
            };

        await expectLater(
          outgoing.auth.signOut(),
          throwsA(isA<UserDataCleanupException>()),
        );

        expect(prefs.get(retained.key), retained.value);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
        expect(outgoing.auth.committedAccountActivationReceipt, isNull);
      });
    }
  });
}
