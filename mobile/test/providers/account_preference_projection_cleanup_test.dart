import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../services/support/fake_account_state.dart';

class _Client extends Mock implements NostrClient {}

class _Session extends NostrSession {
  _Session(this.initial);
  final NostrSessionReadiness initial;
  @override
  NostrSessionReadiness build() => initial;
}

class _HeldNativeWrite extends InMemorySharedPreferencesStore {
  _HeldNativeWrite(this.heldKey, Map<String, Object> values)
    : super.withData(values);

  final String heldKey;
  bool hold = true;
  bool failReads = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    if (failReads) throw StateError('Native preference readback failed');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (hold && key == 'flutter.$heldKey' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('account preference native projection cleanup', () {
    test(
      'stopping an old binding neither detaches nor drains the incoming owner',
      () async {
        final originalBackend = SharedPreferencesStorePlatform.instance;
        SharedPreferences.setMockInitialValues({});
        final backend = _HeldNativeWrite(
          AccountPreferenceStore.projectionOwnerStorageKey,
          {},
        )..hold = false;
        SharedPreferencesStorePlatform.instance = backend;
        final prefs = await SharedPreferences.getInstance();
        final store = AccountPreferenceStore(prefs);
        final first = FakeAccountState('a' * 64);
        final incoming = FakeAccountState('b' * 64, {'content_language': 'ja'});
        await store.bind(first);
        backend.hold = true;
        final binding = store.bind(incoming);
        addTearDown(() async {
          if (!backend.release.isCompleted) backend.release.complete();
          await binding;
          store.dispose();
          await first.close();
          await incoming.close();
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = originalBackend;
        });
        await backend.entered.future;
        var stopped = false;
        final stopping = store.stopProjection(first).then((_) {
          stopped = true;
        });
        await pumpEventQueue();
        expect(stopped, isTrue);
        expect(store.read('content_language'), 'ja');
        backend.release.complete();
        await binding;
        await stopping;
        expect(prefs.getString('content_language'), 'ja');
      },
    );

    test(
      'inactive cleanup preserves a held active preference and its reader',
      () async {
        final originalBackend = SharedPreferencesStorePlatform.instance;
        final removedOwner = 'a' * 64;
        final activeOwner = 'b' * 64;
        SharedPreferences.setMockInitialValues({});
        final backend = _HeldNativeWrite('content_language', {
          'flutter.current_user_pubkey_hex': activeOwner,
          'flutter.content_language': 'es',
        });
        SharedPreferencesStorePlatform.instance = backend;
        final prefs = await SharedPreferences.getInstance();
        final store = AccountPreferenceStore(prefs);
        final active = FakeAccountState(activeOwner, {
          'content_language': 'ja',
        });
        final removed = FakeAccountState(removedOwner);
        final binding = store.bind(active);
        final language = LanguagePreferenceService(accountPreferences: store);
        addTearDown(() async {
          if (!backend.release.isCompleted) backend.release.complete();
          await binding;
          language.dispose();
          store.dispose();
          await active.close();
          await removed.close();
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = originalBackend;
        });
        await backend.entered.future;
        await language.initialize();
        expect(language.contentLanguage, 'ja');
        expect(prefs.getString('content_language'), 'ja');
        var notifications = 0;
        language.addListener(() => notifications++);
        final cleanup = UserDataCleanupService(
          prefs,
          onAccountStateWritesStop: (_) => store.stopProjection(removed),
        );
        await cleanup.deleteAccountData(
          removedOwner,
          userNpub: NostrKeyUtils.encodePubKey(removedOwner),
          preserveActiveSession: true,
        );
        expect(backend.release.isCompleted, isFalse);
        // Native readback exposes the old committed value while the active
        // owner's write is held. Its bound adapter must retain the current choice.
        expect(prefs.getString('content_language'), 'es');
        await language.reloadFromStorage();
        expect(language.contentLanguage, 'ja');
        expect(store.read('content_language'), 'ja');
        expect(notifications, 0);
        expect(prefs.getString('current_user_pubkey_hex'), activeOwner);
        backend.release.complete();
        await binding;
        await pumpEventQueue();
        expect(language.contentLanguage, 'ja');
        await prefs.reload();
        expect(prefs.getString('content_language'), 'ja');
        expect(
          prefs.getString(AccountPreferenceStore.projectionOwnerStorageKey),
          activeOwner,
        );
      },
    );

    for (final inactive in [false, true]) {
      for (final readFails in [false, true]) {
        test(
          'post-drain readback inactive: $inactive, fails: $readFails',
          () async {
            final originalBackend = SharedPreferencesStorePlatform.instance;
            final owner = 'a' * 64;
            final other = 'b' * 64;
            final ownerJournal =
                'account_state_divine/preferences/v1_${owner}_state';
            final otherJournal =
                'account_state_divine/preferences/v1_${other}_state';
            final ownerLibrary = SavedSoundsService.accountStorageKey(owner);
            final otherLibrary = SavedSoundsService.accountStorageKey(other);
            final heldKey = inactive
                ? ownerJournal
                : AccountPreferenceStore.projectionOwnerStorageKey;
            SharedPreferences.setMockInitialValues({});
            final backend = _HeldNativeWrite(heldKey, {
              'flutter.current_user_pubkey_hex': inactive ? other : owner,
              'flutter.content_language': 'es',
              'flutter.$otherJournal': 'other journal',
              'flutter.$ownerLibrary': 'owner library',
              'flutter.$otherLibrary': 'other library',
              if (inactive)
                'flutter.${AccountPreferenceStore.projectionOwnerStorageKey}':
                    other,
            });
            SharedPreferencesStorePlatform.instance = backend;
            final prefs = await SharedPreferences.getInstance();
            final lateWrite = prefs.setString(
              heldKey,
              inactive ? 'late journal' : owner,
            );
            addTearDown(() async {
              if (!backend.release.isCompleted) backend.release.complete();
              await lateWrite;
              SharedPreferences.resetStatic();
              SharedPreferencesStorePlatform.instance = originalBackend;
            });
            await backend.entered.future;
            var databaseErased = false;
            final cleanup =
                UserDataCleanupService(
                    prefs,
                    onAccountStateWritesStop: (stoppedOwner) async {
                      expect(stoppedOwner, owner);
                      await lateWrite;
                      backend.failReads = readFails;
                    },
                  )
                  ..onDatabaseCleanup =
                      ({
                        String? userPubkey,
                        bool deleteUserData = false,
                        bool preserveActiveSession = false,
                        bool forgetAccount = false,
                      }) async {
                        expect(userPubkey, owner);
                        databaseErased = true;
                      };
            final operation = inactive
                ? cleanup.deleteAccountData(
                    owner,
                    userNpub: NostrKeyUtils.encodePubKey(owner),
                    preserveActiveSession: true,
                  )
                : cleanup.clearUserSpecificData(
                    userPubkey: owner,
                    forgetAccount: true,
                  );
            final checked = readFails
                ? expectLater(
                    operation,
                    throwsA(
                      inactive
                          ? isA<StateError>()
                          : isA<UserDataCleanupException>(),
                    ),
                  )
                : operation.then((_) {});
            await pumpEventQueue();
            expect(prefs.get(heldKey), isNull);
            expect(PendingAccountCleanup.read(prefs)?.userPubkey, owner);
            expect(databaseErased, isFalse);
            backend.release.complete();
            await checked;
            backend.failReads = false;
            await prefs.reload();
            expect(databaseErased, !readFails);
            expect(prefs.getString(otherJournal), 'other journal');
            expect(prefs.getString(otherLibrary), 'other library');
            if (readFails) {
              expect(
                prefs.getString(heldKey),
                inactive ? 'late journal' : owner,
              );
              expect(prefs.getString('content_language'), 'es');
              expect(prefs.getString(ownerLibrary), 'owner library');
              final pending = PendingAccountCleanup.read(prefs)!;
              expect(pending.userPubkey, owner);
              expect(pending.forgetAccount, !inactive);
              expect(pending.deleteUserData, inactive);
              expect(pending.preserveActiveSession, inactive);
            } else {
              expect(prefs.get(heldKey), isNull);
              expect(PendingAccountCleanup.read(prefs), isNull);
              expect(
                prefs.getString(ownerLibrary),
                inactive ? null : 'owner library',
              );
            }
            if (inactive) {
              expect(prefs.getString('current_user_pubkey_hex'), other);
              expect(prefs.getString('content_language'), 'es');
              expect(
                prefs.getString(
                  AccountPreferenceStore.projectionOwnerStorageKey,
                ),
                other,
              );
            }
          },
        );
      }
    }

    for (final key in [
      AccountPreferenceStore.projectionOwnerStorageKey,
      'content_language',
    ]) {
      for (final swapContainer in [false, true]) {
        test(
          'drains $key with account container replaced: $swapContainer',
          () async {
            final signer = LocalNostrSigner('1'.padLeft(64, '0'));
            final owner = (await signer.getPublicKey())!;
            final originalBackend = SharedPreferencesStorePlatform.instance;
            SharedPreferences.setMockInitialValues({});
            final backend = _HeldNativeWrite(key, {
              'flutter.current_user_pubkey_hex': owner,
              'flutter.content_language': 'es',
            });
            SharedPreferencesStorePlatform.instance = backend;
            final prefs = await SharedPreferences.getInstance();
            final database = AppDatabase.test(NativeDatabase.memory());
            final device = DeviceScope(
              database: database,
              sharedPreferences: prefs,
              feedModePersistence: FeedModePersistenceRegistry(
                sharedPreferences: prefs,
              ),
              switchController: AccountSwitchController(),
              appVersion: 'test',
              documentsPath: '/documents',
              startupPerformance: StartupPerformanceService(
                crashReporting: CrashReportingService(),
              ),
              crashReporting: CrashReportingService(),
              logMessageBatcher: LogMessageBatcher(),
            );
            final client = _Client();
            when(() => client.signer).thenReturn(signer);
            final departing = buildAccountContainer(
              device,
              accountOverrides: [
                nostrServiceProvider.overrideWithValue(client),
                nostrSessionProvider.overrideWith(
                  () => _Session(
                    NostrSessionReadiness.identityKnown(pubkey: owner),
                  ),
                ),
              ],
            );
            var active = departing;
            final repository = departing.read(accountPreferenceSyncProvider)!;
            Future<void>? removal;
            addTearDown(() async {
              if (!backend.release.isCompleted) backend.release.complete();
              await removal;
              active.dispose();
              await repository.close();
              await pumpEventQueue();
              await database.close();
              SharedPreferences.resetStatic();
              SharedPreferencesStorePlatform.instance = originalBackend;
            });
            await backend.entered.future;
            if (swapContainer) {
              departing.dispose();
              active = buildAccountContainer(device);
            }
            var erased = false;
            final cleanup = active.read(userDataCleanupServiceProvider);
            cleanup.onDatabaseCleanup =
                ({
                  String? userPubkey,
                  bool deleteUserData = false,
                  bool preserveActiveSession = false,
                  bool forgetAccount = false,
                }) async {
                  erased = true;
                };
            removal = cleanup
                .clearUserSpecificData(userPubkey: owner, forgetAccount: true)
                .then((_) {});
            await pumpEventQueue();
            final erasedBeforeRelease = erased;
            expect(PendingAccountCleanup.read(prefs)?.forgetAccount, isTrue);
            if (key == AccountPreferenceStore.projectionOwnerStorageKey) {
              expect(prefs.get(key), isNull);
            }
            backend.release.complete();
            await removal;
            await pumpEventQueue();
            await prefs.reload();
            expect(
              (await backend.getAll())['flutter.$key'],
              isNull,
              reason: 'The outgoing native write must settle before erasure',
            );
            expect(prefs.get(key), isNull);
            expect(erasedBeforeRelease, isFalse);
            expect(erased, isTrue);
            expect(
              prefs.containsKey(
                AccountPreferenceStore.projectionOwnerStorageKey,
              ),
              isFalse,
            );
            expect(prefs.containsKey('content_language'), isFalse);
          },
        );
      }
    }
  });
}
