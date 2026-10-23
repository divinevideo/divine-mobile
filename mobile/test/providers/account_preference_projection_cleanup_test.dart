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
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
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
  final entered = Completer<void>();
  final release = Completer<void>();

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
