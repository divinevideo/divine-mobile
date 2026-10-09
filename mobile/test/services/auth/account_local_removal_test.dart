// ABOUTME: Inactive account deletion proves native owner copies and absence.
// ABOUTME: Foreign active authority survives failures and stale native cleanup.

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/account_session_store.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/shared_channel_override.dart';
import '../../test_setup.dart';

class _Discovery extends Mock implements RelayDiscoveryService {}

class _CacheRecord {
  _CacheRecord(this.payload, this.expiresAt, this.lastAccess);

  final String payload;
  final DateTime? expiresAt;
  int lastAccess;
}

class _RemovalCacheDao implements CacheDao {
  final _records = <String, _CacheRecord>{};
  final deletedPrefixes = <String>[];
  int _accessSequence = 0;

  @override
  Future<String?> read(String key) async {
    final record = _records[key];
    if (record == null) return null;
    if (record.expiresAt?.isAfter(DateTime.now()) == false) {
      _records.remove(key);
      return null;
    }
    record.lastAccess = _accessSequence++;
    return record.payload;
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _records[key] = _CacheRecord(
      payload,
      ttl == null ? null : DateTime.now().add(ttl),
      _accessSequence++,
    );
  }

  @override
  Future<void> delete(String key) async {
    _records.remove(key);
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    deletedPrefixes.add(prefix);
    _records.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> totalPayloadBytes() async => _records.values.fold<int>(
    0,
    (total, record) => total + utf8.encode(record.payload).length,
  );

  @override
  Future<void> evictOldest(int bytesToFree) async {
    final oldest = _records.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));
    var freed = 0;
    for (final entry in oldest) {
      if (freed >= bytesToFree) break;
      _records.remove(entry.key);
      freed += utf8.encode(entry.value.payload).length;
    }
  }
}

class _RemovalPrefsBackend extends InMemorySharedPreferencesStore {
  _RemovalPrefsBackend() : super.empty();
  String? heldSuffix;
  String? retainedSuffix;
  Completer<void>? entered;
  Completer<void>? resume;

  @override
  Future<bool> remove(String key) async {
    if (heldSuffix != null && key.endsWith(heldSuffix!)) {
      heldSuffix = null;
      entered!.complete();
      await resume!.future;
    }
    if (retainedSuffix != null && key.endsWith(retainedSuffix!)) return true;
    return super.remove(key);
  }
}

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
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const nativeChannel = MethodChannel('openvine.secure_storage');
  const primary = 'nostr_primary_key';
  late SharedPreferences prefs;
  late SharedPreferencesStorePlatform previousPrefsBackend;
  late _RemovalPrefsBackend backend;
  late _RemovalCacheDao cache;
  late Map<String, String> native;
  late List<String> deletes;
  late _Discovery discovery;
  late SecureKeyContainer alice;
  late AuthService bob;
  late SecureKeyStorage bobStorage;
  late String bobOwner;
  late AccountActivationReceipt bobReceipt;
  String? unavailableRead;
  String? retainedDelete;
  String? heldDelete;
  Completer<void>? deleteEntered;
  Completer<void>? resumeDelete;

  String id(String slot, String key) => '$slot::$key';
  String rawKey(SecureKeyContainer keys) => keys.withPrivateKey(
    (privateKey) =>
        'privateKeyHex:$privateKey|publicKeyHex:${keys.publicKeyHex}|npub:${keys.npub}',
  );
  String savedKey(SecureKeyContainer keys) => 'saved_identity_${keys.npub}';
  String? slotOf(Map<dynamic, dynamic> arguments) {
    final options = arguments['options'] as Map<dynamic, dynamic>? ?? {};
    final slot =
        options['fixtureStorageSlot'] ?? options['preferencesKeyPrefix'];
    if (slot != null) return slot as String;
    return switch (options['accessibility']) {
      'first_unlock' => 'current',
      'first_unlock_this_device' => 'legacy',
      _ => null,
    };
  }

  SecureKeyStorage keyStorage() => SecureKeyStorage(
    securityConfig: SecurityConfig.desktop,
    platformStorage: PlatformSecureStorage.forPlatform(
      TargetPlatform.iOS,
      fallbackStorage: _slotStorage('current'),
      legacyStorage: _slotStorage('legacy'),
    ),
  );
  AuthService subject(SecureKeyStorage keys) {
    final auth = AuthService(
      keyStorage: keys,
      flutterSecureStorage: const FlutterSecureStorage(),
      userDataCleanupService: UserDataCleanupService(prefs),
      backgroundActivityManager: BackgroundActivityManager(),
      relayDiscoveryService: discovery,
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
    addTearDown(auth.dispose);
    return auth;
  }

  Future<void> rememberAlice() async {
    final accounts = (jsonDecode(
      prefs.getString(kKnownAccountsKey) ?? '[]',
    ) as List<dynamic>).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    accounts.add(
      KnownAccount(
        pubkeyHex: alice.publicKeyHex,
        authSource: AuthenticationSource.importedKeys,
        addedAt: now,
        lastUsedAt: now,
      ).toJson(),
    );
    await prefs.setString(kKnownAccountsKey, jsonEncode(accounts));
  }

  Future<void> expectBobCurrent() async {
    expect(bob.isAuthenticated, isTrue);
    expect(bob.currentPublicKeyHex, bobOwner);
    expect(
      identical(bob.committedAccountActivationReceipt, bobReceipt),
      isTrue,
    );
    expect(bobReceipt.isCurrent, isTrue);
    expect(prefs.get('current_user_pubkey_hex'), bobOwner);
    expect(
      AccountActivationCoordinator.forPreferences(prefs).committedOwnerPubkey,
      bobOwner,
    );
    for (final operation in ['private-list', 'profile']) {
      expect(
        await CacheSync.read<String>(
          key: '$bobOwner:$operation',
          fromJson: (raw) => raw,
        ),
        'bob-$operation-cache',
      );
      expect(
        await CacheSync.read<String>(
          key: '${alice.publicKeyHex}:$operation',
          fromJson: (raw) => raw,
        ),
        isNull,
      );
    }
    expect(cache.deletedPrefixes, contains(alice.publicKeyHex));
    expect(cache.deletedPrefixes, isNot(contains(bobOwner)));
  }

  bool knowsAlice() =>
      (jsonDecode(prefs.getString(kKnownAccountsKey)!) as List<dynamic>).any(
        (account) =>
            (account as Map<String, dynamic>)['pubkeyHex'] ==
            alice.publicKeyHex,
      );

  setUp(() async {
    previousPrefsBackend = SharedPreferencesStorePlatform.instance;
    backend = _RemovalPrefsBackend();
    SharedPreferencesStorePlatform.instance = backend;
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(kKnownAccountsKey, '[]');
    cache = _RemovalCacheDao();
    await CacheSync.init(dao: cache);
    native = {};
    deletes = [];
    unavailableRead = null;
    retainedDelete = null;
    heldDelete = null;
    deleteEntered = null;
    resumeDelete = null;
    overrideSharedChannel(secureChannel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>? ?? {};
      final key = args['key'] as String?;
      final storageSlot =
          key == primary || key?.startsWith('saved_identity_') == true
          ? slotOf(args) ?? 'current'
          : 'global';
      final coordinate = key == null ? null : id(storageSlot, key);
      switch (call.method) {
        case 'read':
          if (coordinate == unavailableRead) {
            throw PlatformException(code: 'fixture_native_read_denied');
          }
          return native[coordinate];
        case 'write':
          native[coordinate!] = args['value'] as String;
        case 'delete':
          deletes.add(coordinate!);
          if (coordinate == heldDelete) {
            heldDelete = null;
            deleteEntered!.complete();
            await resumeDelete!.future;
          }
          if (coordinate != retainedDelete) native.remove(coordinate);
        case 'containsKey':
          return native.containsKey(coordinate);
        case 'readAll':
          return <String, String>{
            for (final entry in native.entries)
              if (entry.key.startsWith('$storageSlot::'))
                entry.key.substring(storageSlot.length + 2): entry.value,
          };
        case 'deleteAll':
          fail('Account removal must not call deleteAll');
      }
      return null;
    });
    overrideSharedChannel(nativeChannel, (call) async {
      if (call.method == 'getCapabilities') return {'basicSecureStorage': true};
      throw MissingPluginException(
        'No custom native key backend in this iOS fixture',
      );
    });
    discovery = _Discovery();
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async =>
          RelayDiscoveryResult.failure('No network in native removal tests'),
    );
    when(() => discovery.clearCache(any())).thenAnswer((_) async {});
    alice = SecureKeyContainer.fromPrivateKeyHex('1' * 64);
    addTearDown(alice.dispose);
    bobStorage = keyStorage();
    bob = subject(bobStorage);
    expect((await bob.importFromHex('2' * 64)).success, isTrue);
    bobOwner = bob.currentPublicKeyHex!;
    bobReceipt = bob.committedAccountActivationReceipt!;
    await rememberAlice();
    for (final operation in ['private-list', 'profile']) {
      await CacheSync.write<String>(
        key: '${alice.publicKeyHex}:$operation',
        value: 'alice-$operation-cache',
        toJson: (value) => value,
      );
      await CacheSync.write<String>(
        key: '$bobOwner:$operation',
        value: 'bob-$operation-cache',
        toJson: (value) => value,
      );
    }
    cache.deletedPrefixes.clear();
    deletes.clear();
  });
  tearDown(() {
    if (resumeDelete != null && !resumeDelete!.isCompleted) {
      resumeDelete!.complete();
    }
    if (backend.resume != null && !backend.resume!.isCompleted) {
      backend.resume!.complete();
    }
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previousPrefsBackend;
  });

  group('Verified inactive account removal', () {
    test('verified current and legacy Alice copies disappear while Bob remains current', () async {
      final bobPrimary = native[id('current', primary)];
      for (final coordinate in [
        id('legacy', primary),
        id('current', savedKey(alice)),
        id('legacy', savedKey(alice)),
      ]) {
        native[coordinate] = rawKey(alice);
      }
      native[id('global', 'amber_pubkey_${alice.publicKeyHex}')] =
          alice.publicKeyHex;
      native[id('global', 'amber_package_${alice.publicKeyHex}')] =
          'com.example.alice';
      native[id('global', 'amber_pubkey')] = bobOwner;
      native[id('global', 'amber_package')] = 'com.example.bob';
      await prefs.setString(
        SavedSoundsService.accountStorageKey(alice.publicKeyHex),
        '[{"id":"alice-private"}]',
      );
      await prefs.setString(
        SavedSoundsService.accountStorageKey(bobOwner),
        '[{"id":"bob-private"}]',
      );
      await prefs.setString(
        CuratedListRecoveryJournal.storageKey(alice.publicKeyHex),
        jsonEncode({
          'alice-list': const CuratedListRecoveryRecord(
            plaintextEventIds: ['alice-event'],
          ).toJson(),
        }),
      );

      await bob.deleteLocalAccount(alice.publicKeyHex);

      await expectBobCurrent();
      expect(native[id('current', primary)], bobPrimary);
      expect(native[id('global', 'amber_pubkey')], bobOwner);
      expect(native[id('global', 'amber_package')], 'com.example.bob');
      expect(native.containsKey(id('legacy', primary)), isFalse);
      expect(native.containsKey(id('current', savedKey(alice))), isFalse);
      expect(native.containsKey(id('legacy', savedKey(alice))), isFalse);
      expect(
        native.containsKey(id('global', 'amber_pubkey_${alice.publicKeyHex}')),
        isFalse,
      );
      expect(
        native.containsKey(id('global', 'amber_package_${alice.publicKeyHex}')),
        isFalse,
      );
      expect(
        prefs.containsKey(
          SavedSoundsService.accountStorageKey(alice.publicKeyHex),
        ),
        isFalse,
      );
      expect(
        prefs.containsKey(
          CuratedListRecoveryJournal.storageKey(alice.publicKeyHex),
        ),
        isFalse,
      );
      expect(
        prefs.getString(SavedSoundsService.accountStorageKey(bobOwner)),
        '[{"id":"bob-private"}]',
      );
      expect(knowsAlice(), isFalse);
    });

    for (final defect in [
      'malformed current PRIMARY',
      'denied current PRIMARY read',
      'foreign Alice archive',
      'malformed Alice archive',
      'silent owned key delete',
    ]) {
      test('$defect refuses completion and preserves Bob authority', () async {
        final bobPrimary = native[id('current', primary)]!;
        final archive = id('current', savedKey(alice));
        switch (defect) {
          case 'malformed current PRIMARY':
            native[id('current', primary)] = '{unreadable-primary';
          case 'denied current PRIMARY read':
            unavailableRead = id('current', primary);
          case 'foreign Alice archive':
            native[archive] = bobPrimary;
          case 'malformed Alice archive':
            native[archive] = '{unreadable-archive';
          case 'silent owned key delete':
            native[archive] = rawKey(alice);
            retainedDelete = archive;
        }
        final before = Map<String, String>.of(native);
        await expectLater(
          bob.deleteLocalAccount(alice.publicKeyHex),
          throwsA(isA<SecureKeyStorageException>()),
        );
        await expectBobCurrent();
        expect(native, before);
        expect(knowsAlice(), isTrue);
        expect(deletes, isNot(contains(id('current', primary))));
      });
    }

    test('a contradictory signer archive retains evidence but removes verified Alice data and keys', () async {
      final archive = id('global', 'amber_pubkey_${alice.publicKeyHex}');
      native[archive] = bobOwner;
      native[id('legacy', savedKey(alice))] = rawKey(alice);
      await prefs.setString(
        SavedSoundsService.accountStorageKey(alice.publicKeyHex),
        '[{"id":"alice-private"}]',
      );
      await prefs.setString(
        SavedSoundsService.accountStorageKey(bobOwner),
        '[{"id":"bob-private"}]',
      );

      await expectLater(
        bob.deleteLocalAccount(alice.publicKeyHex),
        throwsA(isA<SecureKeyStorageException>()),
      );

      await expectBobCurrent();
      expect(native[archive], bobOwner);
      expect(native.containsKey(id('legacy', savedKey(alice))), isFalse);
      expect(
        prefs.containsKey(
          SavedSoundsService.accountStorageKey(alice.publicKeyHex),
        ),
        isFalse,
      );
      expect(
        prefs.getString(SavedSoundsService.accountStorageKey(bobOwner)),
        '[{"id":"bob-private"}]',
      );
      expect(knowsAlice(), isTrue);
    });

    test('silent signer deletion acknowledgement cannot falsely complete local removal', () async {
      final archive = id('global', 'amber_pubkey_${alice.publicKeyHex}');
      native[archive] = alice.publicKeyHex;
      retainedDelete = archive;
      await expectLater(
        bob.deleteLocalAccount(alice.publicKeyHex),
        throwsA(isA<SecureKeyStorageException>()),
      );
      await expectBobCurrent();
      expect(native[archive], alice.publicKeyHex);
      expect(knowsAlice(), isTrue);
    });

    test('held Alice cleanup drains before C authenticates and never deletes C credentials', () async {
      KeycastSession sessionFor(String owner, String label) => KeycastSession(
        bunkerUrl: 'https://keycast.example.com',
        userPubkey: owner,
        accessToken: 'synthetic-access-$label',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        refreshToken: 'synthetic-refresh-$label',
        authorizationHandle: 'synthetic-handle-$label',
      );
      final sessionA = sessionFor(alice.publicKeyHex, 'A');
      native.addAll({
        id('global', 'keycast_session'): jsonEncode(sessionA.toJson()),
        id('global', 'keycast_refresh_token'): sessionA.refreshToken!,
        id('global', 'keycast_auth_handle'): sessionA.authorizationHandle!,
      });
      final cKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
      final cOwner = cKeys.publicKeyHex;
      native[id('current', savedKey(cKeys))] = rawKey(cKeys);
      cKeys.dispose();
      final sessionC = sessionFor(cOwner, 'C');
      heldDelete = id('global', 'keycast_refresh_token');
      deleteEntered = Completer<void>();
      resumeDelete = Completer<void>();
      final rejected = expectLater(
        bob.deleteLocalAccount(alice.publicKeyHex),
        throwsA(isA<AccountActivationRetiredException>()),
      );
      final incoming = subject(keyStorage());
      Future<void>? incomingChecked;
      var settled = false;
      try {
        await deleteEntered!.future.timeout(const Duration(seconds: 5));
        final nextBegun = AccountActivationCoordinator.forPreferences(prefs)
            .changes
            .first;
        final next = incoming
            .signInWithDivineOAuth(sessionC)
            .whenComplete(() => settled = true);
        incomingChecked = expectLater(next, completes);
        await nextBegun.timeout(const Duration(seconds: 5));
        expect(settled, isFalse);
        expect(incoming.committedAccountActivationReceipt, isNull);
        expect(
          native[id('global', 'keycast_session')],
          jsonEncode(sessionA.toJson()),
        );
        expect(
          native[id('global', 'keycast_auth_handle')],
          sessionA.authorizationHandle,
        );
      } finally {
        resumeDelete!.complete();
        await rejected;
        if (incomingChecked != null) await incomingChecked;
      }
      expect(incoming.currentPublicKeyHex, cOwner);
      expect(incoming.committedAccountActivationReceipt!.isCurrent, isTrue);
      expect(
        native[id('global', 'keycast_session')],
        jsonEncode(sessionC.toJson()),
      );
      expect(
        native[id('global', 'keycast_refresh_token')],
        sessionC.refreshToken,
      );
      expect(
        native[id('global', 'keycast_auth_handle')],
        sessionC.authorizationHandle,
      );
      expect(prefs.get('current_user_pubkey_hex'), cOwner);
      expect(deletes, isNot(contains(id('global', 'keycast_auth_handle'))));
      expect(deletes, isNot(contains(id('global', 'keycast_session'))));
      expect(knowsAlice(), isTrue);
    });

    test('retry after real failed destructive teardown retires only its owned intent', () async {
      retainedDelete = id('current', primary);
      await expectLater(
        bob.signOut(deleteKeys: true, deleteLocalUserData: true),
        throwsA(isA<SecureKeyStorageException>()),
      );
      expect(bob.currentIdentity, isNull);
      expect(bob.currentPublicKeyHex, isNull);
      expect(bob.committedAccountActivationReceipt, isNull);
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isTrue,
      );
      final raw = prefs.getString(AccountActivationCoordinator.storageKey)!;
      expect(
        (jsonDecode(raw) as Map<String, dynamic>)['ownerPubkey'],
        bobOwner,
      );
      retainedDelete = null;

      await bob.deleteLocalAccount(bobOwner);

      expect(bob.isAuthenticated, isFalse);
      expect(bob.committedAccountActivationReceipt, isNull);
      expect(bob.takeFreshAccountListCreationPermit(), isNull);
      expect(native.containsKey(id('current', primary)), isFalse);
      expect(prefs.get(AccountActivationCoordinator.storageKey), isNull);
      expect(prefs.get('current_user_pubkey_hex'), isNull);
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
    });

    Future<AuthService> coldAlice(
      Object? activation, {
      bool storedOwner = true,
    }) async {
      await bob.dispose();
      await backend.clear();
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(
        kKnownAccountsKey,
        jsonEncode([
          KnownAccount(
            pubkeyHex: alice.publicKeyHex,
            authSource: AuthenticationSource.importedKeys,
            addedAt: now,
            lastUsedAt: now,
          ).toJson(),
        ]),
      );
      if (storedOwner) {
        await prefs.setString('current_user_pubkey_hex', alice.publicKeyHex);
      }
      await prefs.setString(kLastUsedNpubKey, alice.npub);
      await prefs.setString(kSessionRecoveryAnchorKey, alice.npub);
      await prefs.setString(
        kAuthenticationSourceKey,
        AuthenticationSource.importedKeys.code,
      );
      if (activation != null) {
        await prefs.setString(
          AccountActivationCoordinator.storageKey,
          activation as String,
        );
      }
      native.clear();
      native[id('current', primary)] = rawKey(alice);
      native[id('current', savedKey(alice))] = rawKey(alice);
      native[id('legacy', primary)] = rawKey(alice);
      return subject(keyStorage());
    }

    String recordFor(
      String owner,
      String phase, {
      int version = 1,
      String? token,
    }) => jsonEncode({
      'version': version,
      'token': token ?? 'a' * 48,
      'ownerPubkey': owner,
      'phase': phase,
    });

    for (final phase in [
      'pending',
      'identityReady',
      'committed',
      'signedOut',
    ]) {
      test(
        'cold verified Alice $phase retirement never invents authentication',
        () async {
          final actor = await coldAlice(recordFor(alice.publicKeyHex, phase));
          expect(actor.currentIdentity, isNull);
          await actor.deleteLocalAccount(alice.publicKeyHex);
          expect(actor.isAuthenticated, isFalse);
          expect(actor.committedAccountActivationReceipt, isNull);
          expect(actor.takeFreshAccountListCreationPermit(), isNull);
          expect(native, isEmpty);
          expect(prefs.get(AccountActivationCoordinator.storageKey), isNull);
          expect(prefs.get('current_user_pubkey_hex'), isNull);
          expect(prefs.get(kLastUsedNpubKey), isNull);
          expect(prefs.get(kSessionRecoveryAnchorKey), isNull);
          expect(
            prefs.get(kAuthenticationSourceKey),
            AuthenticationSource.none.code,
          );
          expect(knowsAlice(), isFalse);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isFalse,
          );
        },
      );
    }

    for (final defect in [
      'malformed',
      'foreign',
      'future version',
      'future phase',
      'invalid token',
    ]) {
      test('cold $defect intent remains raw and removal incomplete', () async {
        final raw = switch (defect) {
          'malformed' => '{unreadable intent',
          'foreign' => recordFor(bobOwner, 'pending'),
          'future version' => recordFor(
            alice.publicKeyHex,
            'pending',
            version: 2,
          ),
          'future phase' => recordFor(alice.publicKeyHex, 'futurePhase'),
          _ => recordFor(alice.publicKeyHex, 'pending', token: 'invalid-token'),
        };
        final actor = await coldAlice(raw);
        await expectLater(
          actor.deleteLocalAccount(alice.publicKeyHex),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(actor.currentIdentity, isNull);
        expect(actor.committedAccountActivationReceipt, isNull);
        expect(actor.takeFreshAccountListCreationPermit(), isNull);
        expect(prefs.get(AccountActivationCoordinator.storageKey), raw);
        expect(prefs.get('current_user_pubkey_hex'), alice.publicKeyHex);
        expect(knowsAlice(), isTrue);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    for (final slot in [
      'current_user_pubkey_hex',
      AccountActivationCoordinator.storageKey,
    ]) {
      test(
        'silent $slot removal acknowledgement cannot finalize cold Alice',
        () async {
          final raw = recordFor(alice.publicKeyHex, 'pending');
          final actor = await coldAlice(raw);
          backend.retainedSuffix = slot;
          await expectLater(
            actor.deleteLocalAccount(alice.publicKeyHex),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(
            prefs.get(slot),
            slot == 'current_user_pubkey_hex' ? alice.publicKeyHex : raw,
          );
          expect(actor.committedAccountActivationReceipt, isNull);
          expect(actor.takeFreshAccountListCreationPermit(), isNull);
          expect(knowsAlice(), isTrue);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isTrue,
          );
        },
      );
    }

    test(
      'held real signed-out retirement cannot erase incoming C activation intent',
      () async {
        await bob.signOut();
        final terminalRaw = prefs.getString(
          AccountActivationCoordinator.storageKey,
        )!;
        expect(jsonDecode(terminalRaw)['phase'], 'signedOut');
        expect(jsonDecode(terminalRaw)['ownerPubkey'], bobOwner);
        expect(prefs.get('current_user_pubkey_hex'), isNull);
        expect(bob.committedAccountActivationReceipt, isNull);
        await bob.dispose();
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        expect(prefs.get(AccountActivationCoordinator.storageKey), terminalRaw);
        final actor = subject(keyStorage());
        expect(actor.committedAccountActivationReceipt, isNull);
        expect(actor.takeFreshAccountListCreationPermit(), isNull);
        backend.heldSuffix = AccountActivationCoordinator.storageKey;
        backend.entered = Completer<void>();
        backend.resume = Completer<void>();
        final cKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final cOwner = cKeys.publicKeyHex;
        native[id('current', savedKey(cKeys))] = rawKey(cKeys);
        cKeys.dispose();
        final sessionC = KeycastSession(
          bunkerUrl: 'https://keycast.example.com',
          userPubkey: cOwner,
          accessToken: 'synthetic-access-C',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'synthetic-refresh-C',
          authorizationHandle: 'synthetic-handle-C',
        );
        final rejected = expectLater(
          actor.deleteLocalAccount(bobOwner),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        final incoming = subject(keyStorage());
        Future<void>? incomingChecked;
        var settled = false;
        try {
          await backend.entered!.future.timeout(const Duration(seconds: 5));
          final nextBegun = AccountActivationCoordinator.forPreferences(prefs)
              .changes
              .first;
          incomingChecked = expectLater(
            incoming
                .signInWithDivineOAuth(sessionC)
                .whenComplete(() => settled = true),
            completes,
          );
          await nextBegun.timeout(const Duration(seconds: 5));
          expect(settled, isFalse);
          expect(incoming.committedAccountActivationReceipt, isNull);
        } finally {
          backend.resume!.complete();
          await rejected;
          if (incomingChecked != null) await incomingChecked;
        }
        expect(incoming.currentPublicKeyHex, cOwner);
        expect(incoming.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(prefs.get('current_user_pubkey_hex'), cOwner);
        expect(
          (jsonDecode(prefs.getString(AccountActivationCoordinator.storageKey)!)
              as Map<String, dynamic>)['ownerPubkey'],
          cOwner,
        );
        expect(
          native[id('global', 'keycast_refresh_token')],
          sessionC.refreshToken,
        );
        expect(
          native[id('global', 'keycast_auth_handle')],
          sessionC.authorizationHandle,
        );
        expect(
          native[id('global', 'keycast_session')],
          jsonEncode(sessionC.toJson()),
        );
      },
    );

    test(
      'interrupted Alice recovery refuses C before retirement and permits retry afterwards',
      () async {
        final raw = recordFor(alice.publicKeyHex, 'pending');
        final actor = await coldAlice(raw);
        final cKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final cOwner = cKeys.publicKeyHex;
        final cArchive = id('current', savedKey(cKeys));
        final cRaw = rawKey(cKeys);
        native[cArchive] = cRaw;
        cKeys.dispose();
        final sessionC = KeycastSession(
          bunkerUrl: 'https://keycast.example.com',
          userPubkey: cOwner,
          accessToken: 'synthetic-access-C',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'synthetic-refresh-C',
          authorizationHandle: 'synthetic-handle-C',
        );
        final incoming = subject(keyStorage());
        await expectLater(
          incoming.signInWithDivineOAuth(sessionC),
          throwsA(
            isA<UserDataCleanupException>().having(
              (error) => error.cause,
              'cause',
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Account activation evidence requires recovery',
              ),
            ),
          ),
        );
        expect(incoming.isAuthenticated, isFalse);
        expect(incoming.currentPublicKeyHex, isNull);
        expect(incoming.committedAccountActivationReceipt, isNull);
        expect(incoming.takeFreshAccountListCreationPermit(), isNull);
        expect(prefs.get(AccountActivationCoordinator.storageKey), raw);
        expect(prefs.get('current_user_pubkey_hex'), alice.publicKeyHex);
        expect(native[cArchive], cRaw);
        expect(native[id('global', 'keycast_session')], isNull);
        expect(native[id('global', 'keycast_refresh_token')], isNull);
        expect(native[id('global', 'keycast_auth_handle')], isNull);

        await actor.deleteLocalAccount(alice.publicKeyHex);
        expect(actor.committedAccountActivationReceipt, isNull);
        expect(actor.takeFreshAccountListCreationPermit(), isNull);
        expect(prefs.get(AccountActivationCoordinator.storageKey), isNull);
        expect(prefs.get('current_user_pubkey_hex'), isNull);
        expect(native[cArchive], cRaw);
        await incoming.signInWithDivineOAuth(sessionC);
        expect(incoming.currentPublicKeyHex, cOwner);
        expect(incoming.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(prefs.get('current_user_pubkey_hex'), cOwner);
        expect(
          native[id('global', 'keycast_session')],
          jsonEncode(sessionC.toJson()),
        );
        expect(
          native[id('global', 'keycast_refresh_token')],
          sessionC.refreshToken,
        );
        expect(
          native[id('global', 'keycast_auth_handle')],
          sessionC.authorizationHandle,
        );
      },
    );

    test('deleting the current owner uses verified sign out instead of inactive cleanup', () async {
      await bob.deleteLocalAccount(bobOwner);
      expect(bob.isAuthenticated, isFalse);
      expect(bob.currentPublicKeyHex, isNull);
      expect(bob.committedAccountActivationReceipt, isNull);
      expect(native.containsKey(id('current', primary)), isFalse);
      expect(prefs.get('current_user_pubkey_hex'), isNull);
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
      expect(await cache.read('$bobOwner:private-list'), isNull);
      expect(await cache.read('$bobOwner:profile'), isNull);
      expect(
        await cache.read('${alice.publicKeyHex}:private-list'),
        'alice-private-list-cache',
      );
      expect(
        await cache.read('${alice.publicKeyHex}:profile'),
        'alice-profile-cache',
      );
      expect(cache.deletedPrefixes, contains(bobOwner));
      expect(cache.deletedPrefixes, isNot(contains(alice.publicKeyHex)));
    });
  });
}
