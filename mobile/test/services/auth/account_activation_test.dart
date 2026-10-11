// ABOUTME: Real import/generation cannot overtake an older native rollback.
// ABOUTME: Verifies PRIMARY, session metadata and fresh grants settle together.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show NostrRemoteSigner, NostrRemoteSignerInfo;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/signer_secure_store.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shared_channel_override.dart';
import '../../test_setup.dart';

class _Discovery extends Mock implements RelayDiscoveryService {}

class _RemoteSigner extends Mock implements NostrRemoteSigner {}

void main() {
  setupTestEnvironment();
  const primaryKey = 'nostr_primary_key';
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late SharedPreferences prefs;
  late SecureKeyStorage storage;
  late _Discovery discovery;
  late Map<String, String> native;
  Completer<void>? writeEntered;
  Completer<void>? resumeWrite;
  var holdNextPrimary = false;
  var heldKey = primaryKey;
  String? refusedKey;
  String? lyingKey;
  String? failedValue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    native = {};
    holdNextPrimary = false;
    heldKey = primaryKey;
    refusedKey = null;
    lyingKey = null;
    failedValue = null;
    writeEntered = null;
    resumeWrite = null;
    overrideSharedChannel(channel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>? ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return native[key];
        case 'write':
          if (key == refusedKey && args['value'] == failedValue) {
            throw PlatformException(code: 'test_native_write_refused');
          }
          if (key == lyingKey && args['value'] == failedValue) {
            return null;
          }
          if (key == heldKey && holdNextPrimary) {
            holdNextPrimary = false;
            writeEntered!.complete();
            await resumeWrite!.future;
          }
          native[key!] = args['value'] as String;
        case 'delete':
          native.remove(key);
        case 'deleteAll':
          native.clear();
        case 'readAll':
          return Map<String, String>.of(native);
        case 'containsKey':
          return native.containsKey(key);
        case 'getCapabilities':
          return {'basicSecureStorage': true};
      }
      return null;
    });
    storage = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
    await storage.initialize();
    discovery = _Discovery();
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async =>
          RelayDiscoveryResult.failure('No network in native entry tests'),
    );
    when(() => discovery.clearCache(any())).thenAnswer((_) async {});
  });

  AuthService subject({RemoteSignerFactory? remoteSignerFactory}) {
    final auth = AuthService(
      userDataCleanupService: UserDataCleanupService(prefs),
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: storage,
      flutterSecureStorage: const FlutterSecureStorage(),
      remoteSignerFactory: remoteSignerFactory,
      relayDiscoveryService: discovery,
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
    addTearDown(auth.dispose);
    return auth;
  }

  group('PRIMARY activation ordering', () {
    for (final entry in [
      'nsec',
      'hex',
      'generation',
      'anonymous private',
      'anonymous generated',
      'stored restore',
      'cold known',
      'cold last-used',
    ]) {
      test(
        '$entry settles after a held real outgoing rollback write',
        () async {
          final outgoing = subject();
          final initial = await outgoing.importFromHex('2' * 64);
          expect(initial.success, isTrue);
          final oldOwner = outgoing.currentPublicKeyHex!;
          final snapshot = (await storage.getKeyContainer())!;
          final oldReceipt = outgoing.committedAccountActivationReceipt!;
          final authority = outgoing.captureAccountRollbackAuthority(
            hostIsCurrent: () => true,
          );
          authority.retireForSwitch();
          final attemptedKeys = SecureKeyContainer.fromPrivateKeyHex('4' * 64);
          final attemptedOwner = attemptedKeys.publicKeyHex;
          attemptedKeys.dispose();
          final failedIncoming = subject();
          await failedIncoming.prepareAccountSwitchActivation(
            prefs,
            ownerPubkey: attemptedOwner,
            outgoingHostIsCurrent: () => true,
          );
          final failedTicket = failedIncoming.retireAccountSwitchActivation()!;
          final rollbackTicket = await authority.beginRollback(
            prefs,
            failedTicket,
          );
          final coordinator = AccountActivationCoordinator.forPreferences(
            prefs,
          );
          writeEntered = Completer<void>();
          resumeWrite = Completer<void>();
          holdNextPrimary = true;
          final rollback = coordinator.runGuardedStorage(
            rollbackTicket,
            () => storage.restorePrimaryKeyContainer(snapshot),
          );
          final oldChecked = expectLater(
            rollback,
            throwsA(isA<AccountActivationRetiredException>()),
          );
          final target = subject();
          final imported = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
          final expectedImportOwner = imported.publicKeyHex;
          final nsec = imported.withNsec((value) => value);
          if (entry == 'stored restore' || entry.startsWith('cold')) {
            await storage.storeIdentityKeyContainer(imported.npub, imported);
          }
          imported.dispose();
          Future<void>? nextChecked;
          var nextSettled = false;
          try {
            await writeEntered!.future.timeout(const Duration(seconds: 5));
            if (entry.startsWith('cold')) {
              // Model a cold PRIMARY miss with an intact actual identity archive.
              // The older PRIMARY write has already entered the native channel.
              native.remove(primaryKey);
              storage.clearCache();
              final timestamp = DateTime.utc(2026);
              await prefs.setString(
                kKnownAccountsKey,
                jsonEncode([
                  KnownAccount(
                    pubkeyHex: expectedImportOwner,
                    authSource: AuthenticationSource.importedKeys,
                    addedAt: timestamp,
                    lastUsedAt: timestamp,
                  ).toJson(),
                ]),
              );
              if (entry == 'cold last-used') {
                await prefs.setString(
                  'last_used_npub',
                  NostrKeyUtils.encodePubKey(expectedImportOwner),
                );
              } else {
                await prefs.remove('last_used_npub');
              }
            }
            final nextBegun = coordinator.changes.first;
            Future<AuthResult> restorePreparedAccount() async {
              await target.prepareAccountSwitchActivation(
                prefs,
                ownerPubkey: expectedImportOwner,
                outgoingHostIsCurrent: () => authority.isCurrent,
              );
              await target.signInForAccount(
                expectedImportOwner,
                AuthenticationSource.importedKeys,
              );
              // Native identity settlement cannot grant authority before the
              // incoming host explicitly commits through its public seam.
              expect(target.currentPublicKeyHex, expectedImportOwner);
              expect(target.isAuthenticated, isTrue);
              expect(target.committedAccountActivationReceipt, isNull);
              expect(coordinator.hasUnresolvedActivation, isTrue);
              expect(target.takeFreshAccountListCreationPermit(), isNull);
              await target.commitAccountSwitchActivation(
                hostIsCurrent: () =>
                    target.isAuthenticated &&
                    target.currentPublicKeyHex == expectedImportOwner,
              );
              return const AuthResult(success: true);
            }

            final next = switch (entry) {
              'nsec' => target.importFromNsec(nsec),
              'hex' => target.importFromHex('3' * 64),
              'anonymous private' =>
                target
                    .createAnonymousAccountFromPrivateKeyHex('3' * 64)
                    .then((_) => const AuthResult(success: true)),
              'anonymous generated' => target.createAnonymousAccount().then(
                (_) => const AuthResult(success: true),
              ),
              'stored restore' => restorePreparedAccount(),
              'cold known' || 'cold last-used' => target.initialize().then(
                (_) => AuthResult(success: target.isAuthenticated),
              ),
              _ => target.createNewIdentity(),
            };
            nextChecked = expectLater(
              next.whenComplete(() => nextSettled = true),
              completion(
                isA<AuthResult>().having((r) => r.success, 'success', isTrue),
              ),
            );
            await nextBegun.timeout(const Duration(seconds: 5));
            expect(nextSettled, isFalse);
            expect(target.currentIdentity, isNull);
            expect(prefs.getString('current_user_pubkey_hex'), oldOwner);
            expect(target.committedAccountActivationReceipt, isNull);
            expect(oldReceipt.isCurrent, isFalse);
          } finally {
            if (!resumeWrite!.isCompleted) {
              resumeWrite!.complete();
            }
            await oldChecked;
            if (nextChecked != null) {
              await nextChecked;
            }
          }
          final owner = target.currentPublicKeyHex!;
          expect(nextSettled, isTrue);
          final createsFresh =
              entry == 'generation' || entry == 'anonymous generated';
          if (!createsFresh) {
            expect(owner, expectedImportOwner);
          }
          storage.clearCache();
          final persisted = await storage.getKeyContainer();
          expect(persisted!.publicKeyHex, owner);
          expect(prefs.getString('current_user_pubkey_hex'), owner);
          expect(coordinator.committedOwnerPubkey, owner);
          expect(target.committedAccountActivationReceipt!.isCurrent, isTrue);
          expect(coordinator.hasUnresolvedActivation, isFalse);
          expect(outgoing.committedAccountActivationReceipt, isNull);
          final grant = target.takeFreshAccountListCreationPermit();
          if (createsFresh) {
            expect(grant, isNotNull);
            expect(grant!.consumeFor(owner), isTrue);
            expect(grant.consumeFor(owner), isFalse);
          } else {
            expect(grant, isNull);
          }
        },
      );
    }

    test(
      'an unprepared stored restore preserves a live outgoing native lease',
      () async {
        final outgoing = subject();
        expect((await outgoing.importFromHex('2' * 64)).success, isTrue);
        final oldOwner = outgoing.currentPublicKeyHex!;
        final oldIdentity = outgoing.currentIdentity;
        final snapshot = (await storage.getKeyContainer())!;
        final authority = outgoing.captureAccountRollbackAuthority(
          hostIsCurrent: () => true,
        );
        authority.retireForSwitch();
        final attemptedKeys = SecureKeyContainer.fromPrivateKeyHex('4' * 64);
        final attemptedOwner = attemptedKeys.publicKeyHex;
        attemptedKeys.dispose();
        final failedIncoming = subject();
        await failedIncoming.prepareAccountSwitchActivation(
          prefs,
          ownerPubkey: attemptedOwner,
          outgoingHostIsCurrent: () => authority.isCurrent,
        );
        final rollbackTicket = await authority.beginRollback(
          prefs,
          failedIncoming.retireAccountSwitchActivation()!,
        );
        final coordinator = AccountActivationCoordinator.forPreferences(prefs);
        final imported = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final incomingOwner = imported.publicKeyHex;
        await storage.storeIdentityKeyContainer(imported.npub, imported);
        imported.dispose();
        final target = subject();
        writeEntered = Completer<void>();
        resumeWrite = Completer<void>();
        holdNextPrimary = true;
        final rollback = coordinator.runGuardedStorage(
          rollbackTicket,
          () => storage.restorePrimaryKeyContainer(snapshot),
        );
        final rollbackChecked = expectLater(rollback, completes);
        Map<String, String>? beforeNative;
        Map<String, Object?>? beforePreferences;
        try {
          await writeEntered!.future.timeout(const Duration(seconds: 5));
          beforeNative = Map<String, String>.of(native);
          beforePreferences = {
            for (final key in prefs.getKeys()) key: prefs.get(key),
          };
          await expectLater(
            target
                .signInForAccount(
                  incomingOwner,
                  AuthenticationSource.importedKeys,
                )
                .timeout(const Duration(seconds: 5)),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(native, beforeNative);
          expect(
            {for (final key in prefs.getKeys()) key: prefs.get(key)},
            beforePreferences,
          );
          expect(outgoing.currentIdentity, same(oldIdentity));
          expect(outgoing.currentPublicKeyHex, oldOwner);
          expect(authority.isCurrent, isTrue);
          expect(
            () => coordinator.ensureCurrent(rollbackTicket),
            returnsNormally,
          );
          expect(target.currentIdentity, isNull);
          expect(target.isAuthenticated, isFalse);
          expect(target.committedAccountActivationReceipt, isNull);
          expect(target.takeFreshAccountListCreationPermit(), isNull);
          expect(coordinator.hasUnresolvedActivation, isTrue);
        } finally {
          if (!resumeWrite!.isCompleted) {
            resumeWrite!.complete();
          }
          await rollbackChecked;
        }
        expect(native, beforeNative);
        expect(
          {for (final key in prefs.getKeys()) key: prefs.get(key)},
          beforePreferences,
        );
        storage.clearCache();
        expect((await storage.getKeyContainer())!.publicKeyHex, oldOwner);
        expect(authority.isCurrent, isTrue);
        expect(
          () => coordinator.ensureCurrent(rollbackTicket),
          returnsNormally,
        );
        expect(target.currentIdentity, isNull);
        expect(target.committedAccountActivationReceipt, isNull);
        expect(target.takeFreshAccountListCreationPermit(), isNull);
      },
    );
  });

  group('external signer activation ordering', () {
    test(
      'a bunker save cannot overtake an older real native restore',
      () async {
        String ownerFor(String value) {
          final keys = SecureKeyContainer.fromPrivateKeyHex(value * 64);
          final owner = keys.publicKeyHex;
          keys.dispose();
          return owner;
        }

        final oldOwner = ownerFor('2');
        final nextOwner = ownerFor('3');
        String urlFor(String owner) =>
            'bunker://$owner?relay=wss%3A%2F%2Frelay.example.com';
        NostrRemoteSigner factory(int mode, NostrRemoteSignerInfo info) {
          final signer = _RemoteSigner();
          when(() => signer.info).thenReturn(info);
          when(signer.connect).thenAnswer((_) async => 'ack');
          when(signer.pullPubkey)
              .thenAnswer((_) async => info.remoteSignerPubkey);
          when(signer.close).thenReturn(null);
          return signer;
        }

        final outgoing = subject(remoteSignerFactory: factory);
        expect(
          (await outgoing.connectWithBunker(urlFor(oldOwner))).success,
          isTrue,
        );
        final oldRaw = native['bunker_info'];
        expect(
          NostrRemoteSignerInfo.parseBunkerUrl(oldRaw!).userPubkey,
          oldOwner,
        );
        final authority = outgoing.captureAccountRollbackAuthority(
          hostIsCurrent: () => true,
        );
        authority.retireForSwitch();
        final failed = subject();
        await failed.prepareAccountSwitchActivation(
          prefs,
          ownerPubkey: ownerFor('4'),
          outgoingHostIsCurrent: () => true,
        );
        final rollbackTicket = await authority.beginRollback(
          prefs,
          failed.retireAccountSwitchActivation()!,
        );
        final coordinator = AccountActivationCoordinator.forPreferences(prefs);
        heldKey = 'bunker_info';
        holdNextPrimary = true;
        writeEntered = Completer<void>();
        resumeWrite = Completer<void>();
        final oldChecked = expectLater(
          coordinator.runGuardedStorage(
            rollbackTicket,
            () => const FlutterSecureStorage().write(
              key: 'bunker_info',
              value: oldRaw,
            ),
          ),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        final target = subject(remoteSignerFactory: factory);
        Future<void>? nextChecked;
        var settled = false;
        try {
          await writeEntered!.future.timeout(const Duration(seconds: 5));
          final nextBegun = coordinator.changes.first;
          nextChecked = expectLater(
            target
                .connectWithBunker(urlFor(nextOwner))
                .whenComplete(() => settled = true),
            completion(
              isA<AuthResult>().having(
                (result) => result.success,
                'success',
                isTrue,
              ),
            ),
          );
          await nextBegun.timeout(const Duration(seconds: 5));
          expect(settled, isFalse);
          expect(native['bunker_info'], oldRaw);
          expect(target.committedAccountActivationReceipt, isNull);
        } finally {
          resumeWrite!.complete();
          await oldChecked;
          if (nextChecked != null) {
            await nextChecked;
          }
        }
        expect(target.currentPublicKeyHex, nextOwner);
        expect(target.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(
          NostrRemoteSignerInfo.parseBunkerUrl(native['bunker_info']!)
              .userPubkey,
          nextOwner,
        );
        expect(prefs.getString('current_user_pubkey_hex'), nextOwner);
        expect(outgoing.committedAccountActivationReceipt, isNull);
        expect(target.takeFreshAccountListCreationPermit(), isNull);
      },
    );
  });

  group('coupled OAuth native settlement', () {
    for (final slot in ['keycast_refresh_token', 'keycast_auth_handle']) {
      for (final outcome in ['success', 'refused', 'mismatch']) {
        test('$slot held outgoing restore followed by $outcome B readback', () async {
          const platform = FlutterSecureStorage();
          final store = SignerSecureStore(platform);
          final localA = await storage.importFromHex('2' * 64);
          final ownerA = localA.publicKeyHex;
          final localB = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
          final ownerB = localB.publicKeyHex;
          await storage.storeIdentityKeyContainer(localB.npub, localB);
          localB.dispose();
          KeycastSession sessionFor(String owner, String label) =>
              KeycastSession(
                bunkerUrl: 'https://keycast.example.com',
                accessToken: 'synthetic-access-$label',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                userPubkey: owner,
                refreshToken: 'synthetic-refresh-$label',
                authorizationHandle: 'synthetic-handle-$label',
              );
          final sessionA = sessionFor(ownerA, 'A');
          final sessionB = sessionFor(ownerB, 'B');
          final outgoing = subject();
          await outgoing.signInWithDivineOAuth(sessionA);
          expect(outgoing.committedAccountActivationReceipt!.isCurrent, isTrue);
          await store.archive(ownerA, throwOnFailure: true);
          final archiveKey = 'keycast_session_$ownerA';
          final archiveRaw = native[archiveKey];
          expect(archiveRaw, isNotNull);
          final authority = outgoing.captureAccountRollbackAuthority(
            hostIsCurrent: () => true,
          );
          authority.retireForSwitch();
          final failed = subject();
          final failedKeys = SecureKeyContainer.fromPrivateKeyHex('4' * 64);
          final failedOwner = failedKeys.publicKeyHex;
          failedKeys.dispose();
          await failed.prepareAccountSwitchActivation(
            prefs,
            ownerPubkey: failedOwner,
            outgoingHostIsCurrent: () => true,
          );
          final rollbackTicket = await authority.beginRollback(
            prefs,
            failed.retireAccountSwitchActivation()!,
          );
          final coordinator = AccountActivationCoordinator.forPreferences(
            prefs,
          );
          heldKey = slot;
          holdNextPrimary = true;
          writeEntered = Completer<void>();
          resumeWrite = Completer<void>();
          final oldChecked = expectLater(
            coordinator.runGuardedStorage(
              rollbackTicket,
              () => store.restoreActiveKeys(
                ownerA,
                AuthenticationSource.divineOAuth,
                ensureCurrent: () => coordinator.ensureCurrent(rollbackTicket),
              ),
            ),
            throwsA(isA<AccountActivationRetiredException>()),
          );
          final target = subject();
          Future<void>? nextChecked;
          var settled = false;
          final valueB = slot == 'keycast_refresh_token'
              ? sessionB.refreshToken!
              : sessionB.authorizationHandle!;
          final valueA = slot == 'keycast_refresh_token'
              ? sessionA.refreshToken!
              : sessionA.authorizationHandle!;
          try {
            await writeEntered!.future.timeout(const Duration(seconds: 5));
            // Model the caller's real save before it hands the session to Auth.
            // This bypasses Auth's queue and may be overwritten by held A I/O.
            await sessionB.save(platform);
            await platform.write(
              key: 'keycast_refresh_token',
              value: sessionB.refreshToken,
            );
            await platform.write(
              key: 'keycast_auth_handle',
              value: sessionB.authorizationHandle,
            );
            final nextBegun = coordinator.changes.first;
            final next = target
                .signInWithDivineOAuth(sessionB)
                .whenComplete(() => settled = true);
            nextChecked = expectLater(
              next,
              outcome == 'success'
                  ? completes
                  : throwsA(isA<UserDataCleanupException>()),
            );
            await nextBegun.timeout(const Duration(seconds: 5));
            expect(settled, isFalse);
            expect(target.committedAccountActivationReceipt, isNull);
            expect(native[slot], valueB);
            failedValue = valueB;
            refusedKey = outcome == 'refused' ? slot : null;
            lyingKey = outcome == 'mismatch' ? slot : null;
          } finally {
            resumeWrite!.complete();
            await oldChecked;
            if (nextChecked != null) {
              await nextChecked;
            }
          }
          expect(native[archiveKey], archiveRaw);
          expect(jsonDecode(native['keycast_session']!)['user_pubkey'], ownerB);
          expect(outgoing.committedAccountActivationReceipt, isNull);
          expect(target.takeFreshAccountListCreationPermit(), isNull);
          if (outcome == 'success') {
            expect(native['keycast_refresh_token'], sessionB.refreshToken);
            expect(native['keycast_auth_handle'], sessionB.authorizationHandle);
            expect(target.currentPublicKeyHex, ownerB);
            expect(target.committedAccountActivationReceipt!.isCurrent, isTrue);
            expect(prefs.getString('current_user_pubkey_hex'), ownerB);
            expect(coordinator.hasUnresolvedActivation, isFalse);
          } else {
            expect(
              native[slot],
              valueA,
              reason: 'failed raw credential evidence is retained',
            );
            expect(target.authState, AuthState.unauthenticated);
            expect(
              target.lastFailureReason,
              AuthFailureReason.accountCleanupFailed,
            );
            expect(target.committedAccountActivationReceipt, isNull);
            expect(coordinator.hasUnresolvedActivation, isTrue);
            expect(
              prefs.getString(AccountActivationCoordinator.storageKey),
              isNotNull,
            );
          }
        });
      }
    }
  });
}
