// ABOUTME: An ownerless outgoing auth object cannot erase a newer account.
// ABOUTME: Uses real account leases and real key storage with a native channel seam.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show NostrRemoteSigner, NostrRemoteSignerInfo;
import 'package:openvine/constants/terms_acceptance_keys.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/account_session_store.dart'
    show kSessionRecoveryAnchorKey;
import 'package:openvine/services/auth/account_storage_exception.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_lists/curated_list_account_authority.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shared_channel_override.dart';
import '../../test_setup.dart';

class _Discovery extends Mock implements RelayDiscoveryService {}

class _CaptureProbeStorage extends SecureKeyStorage {
  _CaptureProbeStorage({
    required super.platformStorage,
    required this.beforeCapture,
  }) : super(securityConfig: SecurityConfig.desktop);

  final void Function() beforeCapture;

  @override
  Future<LoginRecordsSnapshot?> captureLoginRecordsStrict(
    String ownerPubkey, {
    required bool requireOwnedKeysAbsent,
    void Function()? ensureCurrent,
  }) {
    beforeCapture();
    return super.captureLoginRecordsStrict(
      ownerPubkey,
      requireOwnedKeysAbsent: requireOwnedKeysAbsent,
      ensureCurrent: ensureCurrent,
    );
  }
}

class _RemoteSigner extends Mock implements NostrRemoteSigner {}

class _OAuth extends Mock implements KeycastOAuth {}

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
  const primaryKey = 'nostr_primary_key';
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const secure = FlutterSecureStorage();
  late SharedPreferences prefs;
  late SecureKeyStorage storage;
  late _Discovery discovery;
  late Map<String, String> native;
  late Map<String, String> legacyNative;
  String? failedRead;
  String? refusedDelete;
  String? ignoredDelete;
  String? failedReadAfterDelete;
  bool cleanupAttempted = false;
  var databaseCleanups = 0;
  late List<({String method, String? key})> nativeMutations;
  late List<({String slot, String? key})> nativeReads;
  String? heldDelete;
  Completer<void>? deleteEntered;
  Completer<void>? resumeDelete;
  String? heldRead;
  Completer<void>? readEntered;
  Completer<void>? resumeRead;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    native = {};
    legacyNative = {};
    failedRead = null;
    refusedDelete = null;
    ignoredDelete = null;
    failedReadAfterDelete = null;
    cleanupAttempted = false;
    databaseCleanups = 0;
    nativeMutations = [];
    nativeReads = [];
    heldDelete = null;
    deleteEntered = null;
    resumeDelete = null;
    heldRead = null;
    readEntered = null;
    resumeRead = null;
    overrideSharedChannel(channel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>? ?? {};
      final key = args['key'] as String?;
      final options = args['options'] as Map<dynamic, dynamic>? ?? {};
      final slot =
          options['fixtureStorageSlot'] ?? options['preferencesKeyPrefix'];
      final isLegacy =
          slot == 'legacy' ||
          options['accessibility'] == 'first_unlock_this_device';
      final target = isLegacy ? legacyNative : native;
      switch (call.method) {
        case 'read':
          nativeReads.add((slot: isLegacy ? 'legacy' : 'current', key: key));
          if (heldRead == key) {
            heldRead = null;
            readEntered!.complete();
            await resumeRead!.future;
          }
          if (key == failedRead ||
              (cleanupAttempted && key == failedReadAfterDelete)) {
            throw PlatformException(code: 'controlled_native_read_refusal');
          }
          return target[key];
        case 'write':
          nativeMutations.add((method: call.method, key: key));
          target[key!] = args['value'] as String;
        case 'delete':
          if (heldDelete == key) {
            heldDelete = null;
            deleteEntered!.complete();
            await resumeDelete!.future;
          }
          nativeMutations.add((method: call.method, key: key));
          cleanupAttempted = true;
          if (key == refusedDelete) {
            throw PlatformException(code: 'controlled_native_delete_refusal');
          }
          if (key != ignoredDelete) {
            target.remove(key);
          }
        case 'deleteAll':
          nativeMutations.add((method: call.method, key: null));
          target.clear();
        case 'readAll':
          return Map<String, String>.of(target);
        case 'containsKey':
          return target.containsKey(key);
        case 'getCapabilities':
          return {'basicSecureStorage': true};
      }
      return null;
    });
    storage = SecureKeyStorage(
      securityConfig: SecurityConfig.desktop,
      platformStorage: PlatformSecureStorage.forPlatform(
        TargetPlatform.iOS,
        fallbackStorage: _slotStorage('current'),
        legacyStorage: _slotStorage('legacy'),
      ),
    );
    await storage.initialize();
    discovery = _Discovery();
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async =>
          RelayDiscoveryResult.failure('No network in ownerless tests'),
    );
    when(() => discovery.clearCache(any())).thenAnswer((_) async {});
  });

  AuthService subject({
    RemoteSignerFactory? remoteSignerFactory,
    KeycastOAuth? oauthClient,
    bool injectSecureStorage = true,
  }) {
    final cleanup = UserDataCleanupService(prefs);
    cleanup.onDatabaseCleanup =
        ({
          String? userPubkey,
          bool deleteUserData = false,
          bool preserveActiveSession = false,
          bool forgetAccount = false,
        }) async {
          databaseCleanups++;
        };
    final auth = AuthService(
      userDataCleanupService: cleanup,
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: storage,
      flutterSecureStorage: injectSecureStorage ? secure : null,
      remoteSignerFactory: remoteSignerFactory,
      oauthClient: oauthClient,
      relayDiscoveryService: discovery,
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
    addTearDown(auth.dispose);
    return auth;
  }

  Map<String, Object?> preferencesSnapshot() => {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  Future<void> saveIncomingGlobals(String owner) async {
    // Actual native writes after B's genuine local activation. These synthetic
    // OAuth values are retained credentials, not proof of an OAuth login.
    await secure.write(key: 'keycast_session', value: 'session-for-$owner');
    await secure.write(
      key: 'keycast_refresh_token',
      value: 'refresh-for-$owner',
    );
    await secure.write(key: 'keycast_auth_handle', value: 'handle-for-$owner');
  }

  Future<void> expectCurrentIncoming(AuthService incoming) async {
    final owner = incoming.currentPublicKeyHex!;
    expect(incoming.authState, AuthState.authenticated);
    expect(incoming.committedAccountActivationReceipt!.isCurrent, isTrue);
    expect(prefs.getString('current_user_pubkey_hex'), owner);
    expect(
      AccountActivationCoordinator.forPreferences(prefs).committedOwnerPubkey,
      owner,
    );
    storage.clearCache();
    expect((await storage.getKeyContainer())!.publicKeyHex, owner);
    expect(incoming.takeFreshAccountListCreationPermit(), isNull);
  }

  group('ownerless sign out ownership', () {
    for (final retryRemoval in [false, true]) {
      test('Keycast public-only archive removal completes '
          '(retry=$retryRemoval)', () async {
        final oauth = _OAuth();
        when(oauth.logout).thenAnswer((_) async {});
        final auth = subject(oauthClient: oauth);
        final identity = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        addTearDown(identity.dispose);
        final owner = identity.publicKeyHex;
        final archive = 'saved_identity_${identity.npub}';
        await auth.signInWithDivineOAuth(
          KeycastSession(
            bunkerUrl: 'https://keycast.example.invalid',
            accessToken: 'synthetic-owned-token',
            userPubkey: owner,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        expect(auth.authState, AuthState.authenticated);
        expect(native[primaryKey], isNull);
        expect(
          native[archive],
          'privateKeyHex:|publicKeyHex:$owner|npub:${identity.npub}',
        );
        if (retryRemoval) {
          ignoredDelete = archive;
          await expectLater(
            auth.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true),
            throwsA(isA<PlatformSecureStorageException>()),
          );
          expect(native[archive], isNotNull);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isTrue,
          );
          ignoredDelete = null;
        }
        await auth.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true);
        expect(native[archive], isNull);
        expect(legacyNative[archive], isNull);
        expect(native['keycast_session'], isNull);
        expect(auth.authState, AuthState.unauthenticated);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
        await auth.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      });
    }

    for (final deleteKeys in [false, true]) {
      test(
        'repeated verified sign out preserves signed-out list authority '
        '(deleteKeys=$deleteKeys)',
        () async {
          final auth = subject();
          expect((await auth.importFromHex('3' * 64)).success, isTrue);
          var teardowns = 0;
          auth.registerBeforeSessionTeardownCallback(() async {
            teardowns++;
          });
          await auth.signOut(deleteKeys: deleteKeys);
          final coordinator = AccountActivationCoordinator.forPreferences(
            prefs,
          );
          final authority = CuratedListAccountAuthority(
            authService: auth,
            preferences: prefs,
          );
          final lease = CuratedListSessionCoordinator.forPreferences(prefs)
              .acquire();
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeLegacy = Map<String, String>.of(legacyNative);
          final beforeMutations = List.of(nativeMutations);
          final beforeCleanups = databaseCleanups;
          expect(coordinator.hasUnresolvedActivation, isFalse);
          expect(authority.isCurrent, isTrue);
          expect(lease.isCurrent, isTrue);

          Object? repeatedError;
          try {
            await auth.signOut(deleteKeys: deleteKeys);
          } on Object catch (error) {
            repeatedError = error;
          }

          expect(coordinator.hasUnresolvedActivation, isFalse);
          expect(authority.isCurrent, isTrue);
          expect(lease.isCurrent, isTrue);
          expect(repeatedError, isNull);
          expect(auth.authState, AuthState.unauthenticated);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(legacyNative, beforeLegacy);
          expect(nativeMutations, beforeMutations);
          expect(databaseCleanups, beforeCleanups);
          expect(teardowns, 1);
        },
      );
    }

    for (final evidence in ['unreadable', 'pending']) {
      test('repeated sign out rejects $evidence activation evidence', () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        await auth.signOut(deleteKeys: true);
        final previous = prefs.getString(
          AccountActivationCoordinator.storageKey,
        )!;
        final raw = evidence == 'unreadable'
            ? 'unreadable activation evidence'
            : jsonEncode({
                ...jsonDecode(previous) as Map<String, dynamic>,
                'phase': 'pending',
              });
        await prefs.setString(AccountActivationCoordinator.storageKey, raw);
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        final beforeCleanups = databaseCleanups;
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(isA<AccountStorageException>()),
        );
        expect(prefs.getString(AccountActivationCoordinator.storageKey), raw);
        expect(native, beforeNative);
        expect(nativeMutations, beforeMutations);
        expect(databaseCleanups, beforeCleanups);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    for (final evidence in [
      'cleanup',
      'native credentials',
      'native read failure',
      'native PRIMARY',
      'legacy PRIMARY',
    ]) {
      test('repeated sign out cannot hide new $evidence', () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        await auth.signOut(deleteKeys: true);
        if (evidence == 'cleanup') {
          await prefs.setString(
            PendingAccountCleanup.storageKey,
            'unreadable cleanup evidence',
          );
        } else if (evidence == 'native credentials') {
          native['keycast_refresh_token'] = 'unattributed-native-token';
        } else if (evidence == 'native read failure') {
          failedRead = 'keycast_session';
        } else if (evidence == 'native PRIMARY') {
          native[primaryKey] = 'unattributed retained PRIMARY';
        } else {
          legacyNative[primaryKey] = 'unattributed retained legacy PRIMARY';
        }
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeLegacy = Map<String, String>.of(legacyNative);
        final beforeMutations = List.of(nativeMutations);
        final beforeCleanups = databaseCleanups;
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(isA<Exception>()),
        );
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(legacyNative, beforeLegacy);
        expect(nativeMutations, beforeMutations);
        expect(databaseCleanups, beforeCleanups);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    for (final strongerScope in ['login deletion', 'local data deletion']) {
      test(
        'repeated logout cannot silently complete new $strongerScope',
        () async {
          final auth = subject();
          expect((await auth.importFromHex('3' * 64)).success, isTrue);
          await auth.signOut(
            deleteKeys: strongerScope == 'local data deletion',
          );
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          final beforeCleanups = databaseCleanups;
          await expectLater(
            auth.signOut(
              deleteKeys: true,
              deleteLocalUserData: strongerScope == 'local data deletion',
            ),
            throwsA(isA<AccountStorageException>()),
          );
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(databaseCleanups, beforeCleanups);
        },
      );
    }

    test(
      'new owned PRIMARY during destructive capture refuses completion',
      () async {
        final keys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final raw = keys.withPrivateKey(
          (privateKey) =>
              'privateKeyHex:$privateKey|'
              'publicKeyHex:${keys.publicKeyHex}|npub:${keys.npub}',
        );
        keys.dispose();
        storage.dispose();
        late List<({String method, String? key})> mutationsAtCapture;
        storage = _CaptureProbeStorage(
          platformStorage: PlatformSecureStorage.forPlatform(
            TargetPlatform.iOS,
            fallbackStorage: _slotStorage('current'),
            legacyStorage: _slotStorage('legacy'),
          ),
          beforeCapture: () {
            expect(native[primaryKey], isNull);
            native[primaryKey] = raw;
            mutationsAtCapture = List.of(nativeMutations);
          },
        );
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(
            isA<PlatformSecureStorageException>().having(
              (error) => error.code,
              'owned key reappeared',
              'key_deletion_unverified',
            ),
          ),
        );
        expect(native[primaryKey], raw);
        expect(nativeMutations, mutationsAtCapture);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      },
    );

    test(
      'unavailable snapshot preserves the successful first logout contract',
      () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        failedRead = primaryKey;
        await auth.signOut();
        final authority = CuratedListAccountAuthority(
          authService: auth,
          preferences: prefs,
        );
        expect(auth.authState, AuthState.unauthenticated);
        expect(authority.isCurrent, isTrue);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        await expectLater(
          auth.signOut(),
          throwsA(isA<AccountStorageException>()),
        );
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(nativeMutations, beforeMutations);
      },
    );

    for (final evidence in ['removed-owner archive', 'recovery anchor']) {
      test(
        'weaker repeat still verifies original $evidence boundary',
        () async {
          final auth = subject();
          expect((await auth.importFromHex('3' * 64)).success, isTrue);
          final owner = auth.currentPublicKeyHex!;
          await auth.signOut(deleteKeys: true);
          if (evidence == 'removed-owner archive') {
            native['keycast_session_$owner'] = 'reappearing-archive';
          } else {
            await prefs.setString(
              kSessionRecoveryAnchorKey,
              'unattributed-recovery-anchor',
            );
          }
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          await expectLater(
            auth.signOut(),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isTrue,
          );
        },
      );
    }

    test(
      'repeated sign-out verification cannot retire an incoming activation',
      () async {
        final old = subject();
        expect((await old.importFromHex('3' * 64)).success, isTrue);
        await old.signOut(deleteKeys: true);
        heldRead = 'keycast_session';
        readEntered = Completer<void>();
        resumeRead = Completer<void>();
        final repeated = expectLater(
          old.signOut(deleteKeys: true),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        try {
          await readEntered!.future;
          final coordinator = AccountActivationCoordinator.forPreferences(
            prefs,
          );
          final incomingStarted = coordinator.changes.firstWhere(
            (_) => coordinator.hasUnresolvedActivation,
          );
          final incoming = subject();
          final incomingAttempt = incoming.importFromHex('4' * 64);
          await incomingStarted;
          resumeRead!.complete();
          await repeated;
          expect((await incomingAttempt).success, isTrue);
          await expectCurrentIncoming(incoming);
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          await pumpEventQueue();
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(old.committedAccountActivationReceipt, isNull);
        } finally {
          if (!resumeRead!.isCompleted) resumeRead!.complete();
          await repeated;
        }
      },
    );

    test('a synchronous retirement listener cannot reenter the notification controller', () async {
      final coordinator = AccountActivationCoordinator.forPreferences(prefs);
      AccountActivationTicket? captured;
      var retired = false;
      var notices = 0;
      final subscription = coordinator.changes.listen((_) {
        notices++;
        if (!retired) {
          retired = true;
          coordinator.retire(captured);
          expect(coordinator.committedOwnerPubkey, isNull);
          expect(coordinator.hasUnresolvedActivation, isTrue);
        }
      });
      addTearDown(subscription.cancel);
      final keys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
      final owner = keys.publicKeyHex;
      keys.dispose();
      await expectLater(
        coordinator.begin(
          ownerPubkey: owner,
          isCurrent: () => true,
          onTicket: (ticket) => captured = ticket,
        ),
        throwsA(isA<AccountActivationRetiredException>()),
      );
      await pumpEventQueue();
      expect(notices, 2);
      expect(coordinator.committedOwnerPubkey, isNull);
      expect(
        prefs.containsKey(AccountActivationCoordinator.storageKey),
        isFalse,
      );
    });

    test(
      'healthy ownerless cleanup completes without an owner receipt',
      () async {
        await prefs.setBool(TermsAcceptanceKeys.ageVerified16Plus, true);
        await prefs.setString(TermsAcceptanceKeys.termsAcceptedAt, 'accepted');
        final auth = subject();
        expect(auth.currentPublicKeyHex, isNull);
        await auth.signOut();
        expect(auth.authState, AuthState.unauthenticated);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(
          prefs.containsKey(TermsAcceptanceKeys.ageVerified16Plus),
          isFalse,
        );
        expect(prefs.containsKey(TermsAcceptanceKeys.termsAcceptedAt), isFalse);
        expect(native['keycast_refresh_token'], isNull);
        expect(native[primaryKey], isNull);
        final coordinator = AccountActivationCoordinator.forPreferences(prefs);
        expect(coordinator.committedOwnerPubkey, isNull);
        expect(coordinator.hasUnresolvedActivation, isFalse);
        expect(
          prefs.containsKey(AccountActivationCoordinator.storageKey),
          isFalse,
        );
      },
    );

    for (final deleteKeys in [false, true]) {
      test(
        'paused ownerless teardown preserves incoming B (deleteKeys=$deleteKeys)',
        () async {
          final old = subject();
          final entered = Completer<void>();
          final resume = Completer<void>();
          old.registerBeforeSessionTeardownCallback(() async {
            entered.complete();
            await resume.future;
          });
          final outgoing = expectLater(
            old.signOut(deleteKeys: deleteKeys),
            throwsA(isA<AccountActivationRetiredException>()),
          );
          try {
            await entered.future;
            final incoming = subject();
            expect((await incoming.importFromHex('3' * 64)).success, isTrue);
            await pumpEventQueue();
            await expectCurrentIncoming(incoming);
            await saveIncomingGlobals(incoming.currentPublicKeyHex!);
            final beforePrefs = preferencesSnapshot();
            final beforeNative = Map<String, String>.of(native);
            final beforeMutations = List.of(nativeMutations);
            resume.complete();
            await outgoing;
            expect(preferencesSnapshot(), beforePrefs);
            expect(native, beforeNative);
            expect(nativeMutations, beforeMutations);
            await expectCurrentIncoming(incoming);
            expect(old.committedAccountActivationReceipt, isNull);
            expect(old.takeFreshAccountListCreationPermit(), isNull);
          } finally {
            if (!resume.isCompleted) {
              resume.complete();
            }
            await outgoing;
          }
        },
      );
    }

    test(
      'an in-flight ownerless native delete drains before B commits',
      () async {
        heldDelete = 'keycast_session';
        deleteEntered = Completer<void>();
        resumeDelete = Completer<void>();
        final old = subject();
        final outgoing = expectLater(
          old.signOut(),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        Future<void>? incomingChecked;
        final incoming = subject();
        var settled = false;
        try {
          await deleteEntered!.future;
          final begun = AccountActivationCoordinator.forPreferences(prefs)
              .changes
              .first;
          final next = incoming
              .importFromHex('3' * 64)
              .whenComplete(() => settled = true);
          incomingChecked = expectLater(
            next,
            completion(
              isA<AuthResult>().having(
                (value) => value.success,
                'success',
                isTrue,
              ),
            ),
          );
          await begun;
          await pumpEventQueue();
          expect(settled, isFalse);
          expect(incoming.committedAccountActivationReceipt, isNull);
          resumeDelete!.complete();
          await outgoing;
          await incomingChecked;
          await expectCurrentIncoming(incoming);
        } finally {
          if (!resumeDelete!.isCompleted) {
            resumeDelete!.complete();
          }
          await outgoing;
          if (incomingChecked != null) {
            await incomingChecked;
          }
        }
      },
    );

    for (final evidence in [
      'activation',
      'cleanup',
      'nativeOwner',
      'primary',
    ]) {
      test(
        'ownerless cleanup preserves $evidence evidence without attribution',
        () async {
          final auth = subject();
          await prefs.setBool(TermsAcceptanceKeys.ageVerified16Plus, true);
          switch (evidence) {
            case 'activation':
              await prefs.setString(
                AccountActivationCoordinator.storageKey,
                '{unreadable',
              );
            case 'cleanup':
              await prefs.setString(
                PendingAccountCleanup.storageKey,
                '{unreadable',
              );
            case 'nativeOwner':
              await prefs.setString('current_user_pubkey_hex', 'a' * 64);
            case 'primary':
              await storage.importFromHex('3' * 64);
          }
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          await expectLater(
            auth.signOut(deleteKeys: true),
            throwsA(
              anyOf(
                isA<AccountStorageException>(),
                isA<UserDataCleanupException>(),
              ),
            ),
          );
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(auth.takeFreshAccountListCreationPermit(), isNull);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .committedOwnerPubkey,
            isNull,
          );
        },
      );
    }

    for (final evidence in [
      'orphaned-token',
      'malformed-session',
      'foreign-session',
    ]) {
      test('ownerless cleanup preserves $evidence OAuth evidence', () async {
        final auth = subject();
        await prefs.setBool(TermsAcceptanceKeys.ageVerified16Plus, true);
        if (evidence == 'orphaned-token') {
          await secure.write(
            key: 'keycast_refresh_token',
            value: 'unattributed-token',
          );
        } else if (evidence == 'malformed-session') {
          await secure.write(key: 'keycast_session', value: '{unreadable');
        } else {
          final session = KeycastSession(
            bunkerUrl: 'https://keycast.example.invalid',
            accessToken: 'synthetic-token',
            userPubkey: 'b' * 64,
            refreshToken: 'foreign-refresh',
            authorizationHandle: 'foreign-handle',
          );
          await session.save(secure);
          await secure.write(
            key: 'keycast_refresh_token',
            value: session.refreshToken,
          );
          await secure.write(
            key: 'keycast_auth_handle',
            value: session.authorizationHandle,
          );
        }
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(nativeMutations, beforeMutations);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    test(
      'ownerless native PRIMARY read failure cannot authorize deletion',
      () async {
        final auth = subject();
        native[primaryKey] = '{retained_unreadable_primary';
        await prefs.setBool(TermsAcceptanceKeys.ageVerified16Plus, true);
        failedRead = primaryKey;
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(
            anyOf(isA<PlatformException>(), isA<SecureKeyStorageException>()),
          ),
        );
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(nativeMutations, beforeMutations);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      },
    );

    test(
      'ownerless native legacy PRIMARY is retained without migration',
      () async {
        final auth = subject();
        legacyNative[primaryKey] = '{retained_legacy_primary';
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeLegacy = Map<String, String>.of(legacyNative);
        final beforeMutations = List.of(nativeMutations);
        nativeReads.clear();
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(legacyNative, beforeLegacy);
        expect(
          nativeReads.where((read) => read.key == primaryKey),
          containsAll([
            (slot: 'current', key: primaryKey),
            (slot: 'legacy', key: primaryKey),
          ]),
        );
        expect(nativeMutations, beforeMutations);
        expect(auth.committedAccountActivationReceipt, isNull);
      },
    );

    Future<void> seedOwnedOAuth(AuthService auth) async {
      final result = await auth.importFromHex('3' * 64);
      expect(result.success, isTrue);
      final session = KeycastSession(
        bunkerUrl: 'https://keycast.example.invalid',
        accessToken: 'synthetic-owned-token',
        userPubkey: auth.currentPublicKeyHex,
        refreshToken: 'owned-refresh',
        authorizationHandle: 'owned-handle',
      );
      await session.save(secure);
      await secure.write(
        key: 'keycast_refresh_token',
        value: session.refreshToken,
      );
      await secure.write(
        key: 'keycast_auth_handle',
        value: session.authorizationHandle,
      );
    }

    test(
      'known owner healthy OAuth cleanup proves all global slots absent',
      () async {
        final auth = subject();
        await seedOwnedOAuth(auth);
        await auth.signOut();
        expect(auth.authState, AuthState.unauthenticated);
        expect(native['keycast_session'], isNull);
        expect(native['keycast_refresh_token'], isNull);
        expect(native['keycast_auth_handle'], isNull);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      },
    );

    for (final fault in [
      'permanent-delete-refusal',
      'false-delete-ack',
      'post-cleanup-read-error',
    ]) {
      test('known owner cannot complete logout with $fault', () async {
        final auth = subject();
        await seedOwnedOAuth(auth);
        final retainedRefresh = native['keycast_refresh_token'];
        cleanupAttempted = false;
        if (fault == 'permanent-delete-refusal') {
          refusedDelete = 'keycast_refresh_token';
        } else if (fault == 'false-delete-ack') {
          ignoredDelete = 'keycast_refresh_token';
        } else {
          failedReadAfterDelete = 'keycast_refresh_token';
        }
        await expectLater(
          auth.signOut(),
          throwsA(
            anyOf(isA<UserDataCleanupException>(), isA<PlatformException>()),
          ),
        );
        if (fault != 'post-cleanup-read-error') {
          expect(native['keycast_refresh_token'], retainedRefresh);
        }
        expect(auth.authState, AuthState.unauthenticated);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    for (final evidence in [
      'foreign-session',
      'mismatched-refresh',
      'malformed-session',
    ]) {
      test(
        'known owner preserves $evidence credentials before any cleanup',
        () async {
          final auth = subject();
          await seedOwnedOAuth(auth);
          if (evidence == 'foreign-session') {
            final session = KeycastSession(
              bunkerUrl: 'https://keycast.example.invalid',
              accessToken: 'foreign-token',
              userPubkey: 'b' * 64,
            );
            await session.save(secure);
          } else if (evidence == 'mismatched-refresh') {
            await secure.write(
              key: 'keycast_refresh_token',
              value: 'unknown-refresh',
            );
          } else {
            await secure.write(key: 'keycast_session', value: '{unreadable');
          }
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          await expectLater(
            auth.signOut(deleteKeys: true),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isTrue,
          );
        },
      );
    }

    for (final slot in ['bunker_info', 'amber_pubkey', 'amber_package']) {
      test(
        'ownerless cleanup preserves unknown $slot before mutations',
        () async {
          final auth = subject();
          await secure.write(key: slot, value: 'unattributed-native-value');
          final beforePrefs = preferencesSnapshot();
          final beforeNative = Map<String, String>.of(native);
          final beforeMutations = List.of(nativeMutations);
          await expectLater(
            auth.signOut(deleteKeys: true),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(preferencesSnapshot(), beforePrefs);
          expect(native, beforeNative);
          expect(nativeMutations, beforeMutations);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isTrue,
          );
        },
      );
    }

    for (final kind in ['bunker', 'amber']) {
      test('known $kind metadata is archived before globals retire', () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        final owner = auth.currentPublicKeyHex!;
        if (kind == 'bunker') {
          // This only verifies native archive scope, not a remote connection.
          // The remote key differs from owner; account-bound archive equality
          // authorizes the exact URL, never the remote signer key alone.
          final info = NostrRemoteSignerInfo(
            remoteSignerPubkey: 'b' * 64,
            relays: ['wss://relay.example.invalid'],
            userPubkey: owner,
          );
          final raw = info.toString();
          await secure.write(key: 'bunker_info', value: raw);
          await secure.write(key: 'bunker_info_$owner', value: raw);
          await auth.signOut();
          expect(native['bunker_info'], isNull);
          expect(native['bunker_info_$owner'], raw);
        } else {
          await secure.write(key: 'amber_pubkey', value: owner);
          await secure.write(key: 'amber_package', value: 'example.amber');
          await auth.signOut();
          expect(native['amber_pubkey'], isNull);
          expect(native['amber_package'], isNull);
          expect(native['amber_pubkey_$owner'], owner);
          expect(native['amber_package_$owner'], 'example.amber');
        }
        expect(auth.authState, AuthState.unauthenticated);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      });
    }

    for (final mismatch in [
      'foreign-amber',
      'orphan-amber-package',
      'foreign-bunker',
      'unbound-bunker',
      'malformed-bunker',
    ]) {
      test('known logout preserves $mismatch credentials', () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        final owner = auth.currentPublicKeyHex!;
        if (mismatch == 'foreign-amber') {
          await secure.write(key: 'amber_pubkey', value: 'b' * 64);
          await secure.write(key: 'amber_package', value: 'example.amber');
        } else if (mismatch == 'orphan-amber-package') {
          await secure.write(key: 'amber_package', value: 'example.amber');
        } else if (mismatch == 'malformed-bunker') {
          await secure.write(key: 'bunker_info', value: 'not-a-bunker-url');
        } else {
          final info = NostrRemoteSignerInfo(
            remoteSignerPubkey: 'b' * 64,
            relays: ['wss://relay.example.invalid'],
            userPubkey: mismatch == 'foreign-bunker' ? 'b' * 64 : null,
          );
          await secure.write(key: 'bunker_info', value: info.toString());
          await secure.write(key: 'bunker_info_$owner', value: info.toString());
        }
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        await expectLater(
          auth.signOut(deleteKeys: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(native, beforeNative);
        expect(nativeMutations, beforeMutations);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isTrue,
        );
      });
    }

    for (final kind in [
      'keycast_session',
      'bunker_info',
      'amber_pubkey',
      'amber_package',
    ]) {
      for (final fault in ['refused-delete', 'false-ack', 'readback-error']) {
        test(
          'destructive logout verifies $kind archive after $fault',
          () async {
            final auth = subject();
            expect((await auth.importFromHex('3' * 64)).success, isTrue);
            final owner = auth.currentPublicKeyHex!;
            final foreignArchive = 'keycast_session_${'b' * 64}';
            await secure.write(key: foreignArchive, value: '{foreign-evidence');
            final foreignRaw = native[foreignArchive];
            String raw;
            if (kind == 'keycast_session') {
              raw = jsonEncode(
                KeycastSession(
                  bunkerUrl: 'https://keycast.example.invalid',
                  accessToken: 'owned-archive-token',
                  userPubkey: owner,
                ).toJson(),
              );
            } else if (kind == 'bunker_info') {
              raw = NostrRemoteSignerInfo(
                remoteSignerPubkey: 'b' * 64,
                relays: ['wss://relay.example.invalid'],
                userPubkey: owner,
              ).toString();
            } else {
              raw = kind == 'amber_pubkey' ? owner : 'example.amber';
              await secure.write(key: 'amber_pubkey_$owner', value: owner);
            }
            final archive = '${kind}_$owner';
            await secure.write(key: archive, value: raw);
            cleanupAttempted = false;
            if (fault == 'refused-delete') {
              refusedDelete = archive;
            } else if (fault == 'false-ack') {
              ignoredDelete = archive;
            } else {
              failedReadAfterDelete = archive;
            }
            await expectLater(
              auth.signOut(deleteKeys: true),
              throwsA(
                anyOf(
                  isA<UserDataCleanupException>(),
                  isA<PlatformException>(),
                  isA<SecureKeyStorageException>(),
                ),
              ),
            );
            if (fault != 'readback-error') {
              expect(native[archive], raw);
            }
            expect(native[foreignArchive], foreignRaw);
            expect(auth.committedAccountActivationReceipt, isNull);
            expect(
              AccountActivationCoordinator.forPreferences(prefs)
                  .hasUnresolvedActivation,
              isTrue,
            );
          },
        );
      }
    }

    for (final (kind, deleteKeys) in [
      ('bunker', false),
      ('amber', false),
    ]) {
      test('actual $kind logout preserves a foreign PRIMARY and legacy bytes '
          '(deleteKeys=$deleteKeys)', () async {
        debugDefaultTargetPlatformOverride = kind == 'amber'
            ? TargetPlatform.android
            : TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        // Real native storage contains another account before external sign-in.
        final foreign = await storage.importFromHex('4' * 64);
        final foreignOwner = foreign.publicKeyHex;
        final beforePrimary = native[primaryKey];
        legacyNative[primaryKey] = beforePrimary!;
        final beforeLegacy = Map<String, String>.of(legacyNative);
        final ownerKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        final owner = ownerKeys.publicKeyHex;
        final ownerNpub = ownerKeys.npub;
        ownerKeys.dispose();
        AuthService auth;
        if (kind == 'bunker') {
          final signer = _RemoteSigner();
          when(signer.connect).thenAnswer((_) async => 'ack');
          when(signer.pullPubkey).thenAnswer((_) async => owner);
          when(signer.close).thenReturn(null);
          auth = subject(
            remoteSignerFactory: (_, info) {
              // This is the exact live info object AuthService later binds to
              // the user key. The transport mock does not create a receipt.
              when(() => signer.info).thenReturn(info);
              return signer;
            },
          );
          final url = Uri(
            scheme: 'bunker',
            host: 'b' * 64,
            queryParameters: {'relay': 'wss://relay.example.invalid'},
          ).toString();
          expect((await auth.connectWithBunker(url)).success, isTrue);
          expect(auth.authenticationSource, AuthenticationSource.bunker);
        } else {
          const signerChannel = MethodChannel('nostrmoPlugin');
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(signerChannel, (call) async {
                if (call.method == 'existAndroidNostrSigner') {
                  return true;
                }
                if (call.method == 'startActivityForResult') {
                  return {
                    'resultCode': -1,
                    'intent': {
                      'extras': {
                        'signature': owner,
                        'package': 'example.amber',
                      },
                    },
                  };
                }
                return null;
              });
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(signerChannel, null);
          });
          auth = subject();
          expect((await auth.connectWithAmber()).success, isTrue);
          expect(auth.authenticationSource, AuthenticationSource.amber);
        }
        expect(auth.currentPublicKeyHex, owner);
        expect(auth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        await auth.signOut(deleteKeys: deleteKeys);
        expect(native[primaryKey], beforePrimary);
        expect(legacyNative, beforeLegacy);
        expect(auth.authState, AuthState.unauthenticated);
        expect(
          prefs.getString('session_recovery_anchor_npub'),
          deleteKeys ? null : ownerNpub,
        );
        final authority = CuratedListAccountAuthority(
          authService: auth,
          preferences: prefs,
        );
        final lease = CuratedListSessionCoordinator.forPreferences(prefs)
            .acquire();
        final beforeRepeat = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeMutations = List.of(nativeMutations);
        final beforeCleanups = databaseCleanups;
        await auth.signOut();
        expect(authority.isCurrent, isTrue);
        expect(lease.isCurrent, isTrue);
        expect(preferencesSnapshot(), beforeRepeat);
        expect(native, beforeNative);
        expect(legacyNative, beforeLegacy);
        expect(nativeMutations, beforeMutations);
        expect(databaseCleanups, beforeCleanups);
        storage.clearCache();
        expect((await storage.getKeyContainer())!.publicKeyHex, foreignOwner);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      });
    }

    test(
      'destructive repeated logout preserves proven foreign PRIMARY bytes',
      () async {
        final foreign = SecureKeyContainer.fromPrivateKeyHex('4' * 64);
        final raw = foreign.withPrivateKey(
          (privateKey) =>
              'privateKeyHex:$privateKey|'
              'publicKeyHex:${foreign.publicKeyHex}|npub:${foreign.npub}',
        );
        foreign.dispose();
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        native[primaryKey] = raw;
        legacyNative[primaryKey] = raw;
        await auth.signOut(deleteKeys: true);
        final authority = CuratedListAccountAuthority(
          authService: auth,
          preferences: prefs,
        );
        final lease = CuratedListSessionCoordinator.forPreferences(prefs)
            .acquire();
        final beforePrefs = preferencesSnapshot();
        final beforeNative = Map<String, String>.of(native);
        final beforeLegacy = Map<String, String>.of(legacyNative);
        final beforeMutations = List.of(nativeMutations);
        final beforeCleanups = databaseCleanups;
        await auth.signOut();
        expect(authority.isCurrent, isTrue);
        expect(lease.isCurrent, isTrue);
        expect(preferencesSnapshot(), beforePrefs);
        expect(native, beforeNative);
        expect(legacyNative, beforeLegacy);
        expect(nativeMutations, beforeMutations);
        expect(databaseCleanups, beforeCleanups);
      },
    );

    for (final raw in [
      '{"bunker_url":"https://keycast.example.invalid","access_token":"token","scope":"policy:full"}',
      '{"bunker_url":"https://keycast.example.invalid","access_token":"token","future_field":{"order":[3,1,2]}}',
    ]) {
      test('ordinary logout preserves exact attributed OAuth raw schema $raw', () async {
        final auth = subject();
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        final owner = auth.currentPublicKeyHex!;
        // Keep a valid deliberately noncanonical JSON shape and future fields.
        final captured = raw.replaceFirst('}', ',"user_pubkey":"$owner"}');
        // The nested-body control inserts owner at top level through decoding
        // only for construction; the exact final raw is not normalized later.
        final value = raw.contains('future_field')
            ? '{"user_pubkey":"$owner","future_field":{"order":[3,1,2]},"access_token":"token","bunker_url":"https://keycast.example.invalid"}'
            : captured;
        await secure.write(key: 'keycast_session', value: value);
        await auth.signOut();
        expect(native['keycast_session_$owner'], value);
        expect(native['keycast_session'], isNull);
        expect(auth.authState, AuthState.unauthenticated);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      });
    }

    test(
      'remote OAuth logout failure remains advisory after local absence proof',
      () async {
        final oauth = _OAuth();
        when(oauth.logout).thenThrow(StateError('remote logout unavailable'));
        final auth = subject(oauthClient: oauth);
        expect((await auth.importFromHex('3' * 64)).success, isTrue);
        await auth.signOut();
        expect(auth.authState, AuthState.unauthenticated);
        expect(native['keycast_session'], isNull);
        expect(native['keycast_refresh_token'], isNull);
        expect(native['keycast_auth_handle'], isNull);
        expect(
          AccountActivationCoordinator.forPreferences(prefs)
              .hasUnresolvedActivation,
          isFalse,
        );
      },
    );

    test('destructive fallback preserves foreign globals added by outgoing callback', () async {
      final auth = subject();
      expect((await auth.importFromHex('3' * 64)).success, isTrue);
      final owner = auth.currentPublicKeyHex!;
      late Map<String, String> afterCallback;
      late List<({String method, String? key})> mutationsAfterCallback;
      auth.registerBeforeSessionTeardownCallback(() async {
        final foreign = KeycastSession(
          bunkerUrl: 'https://keycast.example.invalid',
          accessToken: 'foreign-token',
          userPubkey: 'b' * 64,
          refreshToken: 'foreign-refresh',
          authorizationHandle: 'foreign-handle',
        );
        await foreign.save(secure);
        await secure.write(
          key: 'keycast_refresh_token',
          value: foreign.refreshToken,
        );
        await secure.write(
          key: 'keycast_auth_handle',
          value: foreign.authorizationHandle,
        );
        afterCallback = Map<String, String>.of(native);
        mutationsAfterCallback = List.of(nativeMutations);
      });
      await expectLater(
        auth.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true),
        throwsA(isA<UserDataCleanupException>()),
      );
      expect(native, afterCallback);
      expect(nativeMutations, mutationsAfterCallback);
      expect(auth.currentPublicKeyHex, isNull);
      expect(auth.authState, AuthState.unauthenticated);
      expect(auth.committedAccountActivationReceipt, isNull);
      expect(
        native['saved_identity_${SecureKeyContainer.fromPublicKey(owner).npub}'],
        isNull,
      );
      final record = jsonDecode(
        prefs.getString(AccountActivationCoordinator.storageKey)!,
      ) as Map<String, dynamic>;
      expect(record['phase'], 'pending');
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isTrue,
      );
    });

    test(
      'retired destructive fallback cannot mutate a newer actual account',
      () async {
        final outgoing = subject();
        expect((await outgoing.importFromHex('3' * 64)).success, isTrue);
        final entered = Completer<void>();
        final resume = Completer<void>();
        outgoing.registerBeforeSessionTeardownCallback(() async {
          entered.complete();
          await resume.future;
        });
        final checked = expectLater(
          outgoing.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        final incoming = subject();
        Future<AuthResult>? next;
        try {
          await entered.future;
          final begun = AccountActivationCoordinator.forPreferences(prefs)
              .changes
              .first;
          next = incoming.importFromHex('4' * 64);
          await begun;
          resume.complete();
          await checked;
          expect((await next).success, isTrue);
          await expectCurrentIncoming(incoming);
          expect(outgoing.committedAccountActivationReceipt, isNull);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isFalse,
          );
        } finally {
          if (!resume.isCompleted) {
            resume.complete();
          }
          await checked;
          if (next != null) {
            await next;
          }
        }
      },
    );

    test(
      'retired destructive native completion cannot run the fallback cleanup',
      () async {
        final outgoing = subject();
        expect((await outgoing.importFromHex('3' * 64)).success, isTrue);
        heldDelete = 'keycast_session';
        deleteEntered = Completer<void>();
        resumeDelete = Completer<void>();
        final checked = expectLater(
          outgoing.signOut(deleteKeys: true, abortOnKeyDeletionFailure: true),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        final incoming = subject();
        Future<AuthResult>? next;
        try {
          await deleteEntered!.future;
          final begun = AccountActivationCoordinator.forPreferences(prefs)
              .changes
              .first;
          next = incoming.importFromHex('4' * 64);
          await begun;
          resumeDelete!.complete();
          await checked;
          expect((await next).success, isTrue);
          await expectCurrentIncoming(incoming);
          expect(outgoing.committedAccountActivationReceipt, isNull);
          expect(
            AccountActivationCoordinator.forPreferences(prefs)
                .hasUnresolvedActivation,
            isFalse,
          );
        } finally {
          if (!resumeDelete!.isCompleted) {
            resumeDelete!.complete();
          }
          await checked;
          if (next != null) {
            await next;
          }
        }
      },
    );

    test('ordinary logout verifies tokens when secure storage uses production defaults', () async {
      final auth = subject(injectSecureStorage: false);
      await seedOwnedOAuth(auth);
      final owner = auth.currentPublicKeyHex!;
      final original = native['keycast_session'];
      await auth.signOut();
      expect(native['keycast_session_$owner'], original);
      expect(native['keycast_session'], isNull);
      expect(native['keycast_refresh_token'], isNull);
      expect(native['keycast_auth_handle'], isNull);
      expect(auth.authState, AuthState.unauthenticated);
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
    });

    test(
      'ownerless reservation itself cannot create account authority',
      () async {
        final coordinator = AccountActivationCoordinator.forPreferences(prefs);
        final reservation = await coordinator.reserveOwnerlessSignOut(
          isCurrent: () => true,
        );
        expect(coordinator.hasUnresolvedActivation, isTrue);
        expect(coordinator.committedOwnerPubkey, isNull);
        expect(
          prefs.containsKey(AccountActivationCoordinator.storageKey),
          isFalse,
        );
        coordinator.completeOwnerlessSignOut(reservation);
        expect(coordinator.hasUnresolvedActivation, isFalse);
        expect(coordinator.committedOwnerPubkey, isNull);
        expect(
          prefs.containsKey(AccountActivationCoordinator.storageKey),
          isFalse,
        );
      },
    );
  });
}
