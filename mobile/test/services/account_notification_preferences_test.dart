import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _incoming =
    '2222222222222222222222222222222222222222222222222222222222222222';

class _Box extends Mock implements Box<dynamic> {}

class _PushAuth extends Mock implements AuthService {}

class _PushClient extends Mock implements NostrClient {}

class _PushSigner extends Mock implements NostrSigner {}

class _PushNotifications extends Mock implements NotificationService {}

class _PushEnvironment extends EnvironmentConfig {
  const _PushEnvironment() : super(environment: AppEnvironment.staging);
  @override
  String get pushServicePubkey => '3' * 64;
}

class _MemoryPushStore implements NotificationPreferencesStore {
  NotificationPreferences saved = const NotificationPreferences();
  final dirty = <String, NotificationPreferences>{};
  Completer<void>? markDirtyGate;
  bool commitAfterGate = false;
  final markDirtyEntered = Completer<void>();
  @override
  Future<NotificationPreferences> loadPreferences() async => saved;
  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    saved = preferences;
  }

  @override
  Future<void> clearPreferences() async {
    saved = const NotificationPreferences();
  }

  @override
  Future<bool> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (!commitAfterGate) dirty[pubkey] = preferences;
    if (!markDirtyEntered.isCompleted) markDirtyEntered.complete();
    await markDirtyGate?.future;
    if (commitAfterGate) dirty[pubkey] = preferences;
    return true;
  }

  @override
  Future<NotificationPreferencesDirtyRead> readDirty(String pubkey) async =>
      (preferences: await loadDirty(pubkey), succeeded: true);

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async =>
      dirty[pubkey];
  @override
  Future<void> clearDirty(String pubkey) async {
    dirty.remove(pubkey);
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (dirty[pubkey] == preferences) dirty.remove(pubkey);
  }

  @override
  Future<int?> loadPublishedSchemaVersion(String pubkey) async => 1;
  @override
  Future<void> savePublishedSchemaVersion(String pubkey, int version) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('account notification preferences', () {
    group('ordered production push delivery', () {
      setUpAll(() {
        registerFallbackValue(Event(_account, 1, [], '', createdAt: 1));
        registerFallbackValue(<String>[]);
        registerFallbackValue(Duration.zero);
      });
      for (final heldStage in ['encryption', 'signing', 'completion']) {
        test('latest remote flags survive reverse $heldStage order', () async {
          SharedPreferences.setMockInitialValues({});
          final port = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final account = FakeAccountState(_account, {
            'notifications/mentionsEnabled': false,
          });
          await port.bind(account);
          final store = _MemoryPushStore()..markDirtyGate = Completer<void>();
          final signer = _PushSigner();
          final auth = _PushAuth();
          final client = _PushClient();
          final identity = BunkerNostrIdentity(
            pubkey: _account,
            remoteSigner: signer,
          );
          when(() => auth.currentIdentity).thenReturn(identity);
          final entered = Completer<void>();
          final release = Completer<void>();
          final delivered = <Event>[];
          final done = Completer<void>();
          var encrypted = 0;
          var signed = 0;
          var handedOff = 0;
          var timestamp = 1700000000;
          when(() => signer.nip44Encrypt(any(), any()))
              .thenAnswer((call) async {
                if (encrypted++ == 0 && heldStage == 'encryption') {
                  entered.complete();
                  await release.future;
                }
                return call.positionalArguments[1] as String;
              });
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((call) async {
            if (signed++ == 0 && heldStage == 'signing') {
              entered.complete();
              await release.future;
            }
            return Event(
              _account,
              call.namedArguments[#kind] as int,
              call.namedArguments[#tags] as List<List<String>>,
              call.namedArguments[#content] as String,
              createdAt: timestamp++,
            );
          });
          when(
            () => client.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((call) async {
            final event = call.positionalArguments.first as Event;
            if (handedOff++ == 0 && heldStage == 'completion') {
              entered.complete();
              await release.future;
            }
            delivered.add(event);
            if (delivered.length == 2) done.complete();
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const ['wss://relay.example'],
              rejectedBy: const {},
              noResponseFrom: const [],
            );
          });
          final push = PushNotificationService(
            authService: auth,
            nostrClient: client,
            notificationService: _PushNotifications(),
            environmentConfig: const _PushEnvironment(),
            getToken: () async => null,
          );
          final service = NotificationPreferencesService(
            store: store,
            currentPubkey: () => _account,
            accountPreferences: port,
            publishPreferences: (_, prefs) => push.updatePreferences(prefs),
          );
          addTearDown(service.dispose);
          final update = service.updatePreferences(
            const NotificationPreferences(
              likesEnabled: false,
              mentionsEnabled: false,
            ),
          );
          await store.markDirtyEntered.future;
          account.receive({'notifications/commentsEnabled': false});
          await pumpEventQueue();
          store.markDirtyGate!.complete();
          await update;
          await entered.future;
          await pumpEventQueue();
          release.complete();
          await done.future;
          await pumpEventQueue();
          final current = await service.loadPreferences();
          expect(jsonDecode(delivered.last.content), {
            'kinds': current.toKindsList(),
            'campaignsEnabled': current.campaignsEnabled,
          });
          expect(current.likesEnabled, isFalse);
          expect(current.commentsEnabled, isFalse);
          expect(store.dirty, isEmpty);
          expect(account.localWrites, 1);
          service.dispose();
          push.dispose();
          port.dispose();
          await account.close();
        });
      }
    });

    group('production dirty store failures', () {
      test(
        'an acknowledged choice cannot overwrite unread newer durable intent',
        () async {
          SharedPreferences.setMockInitialValues({});
          final port = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final account = FakeAccountState(_account);
          await port.bind(account);
          addTearDown(port.dispose);
          addTearDown(account.close);
          final box = _Box();
          final persisted = <Object, Object?>{};
          const dirtyKey = 'push_preferences_dirty_$_account';
          var failRead = false;
          when(() => box.get(any())).thenAnswer((call) {
            if (call.positionalArguments.first == dirtyKey && failRead) {
              throw StateError('dirty read unavailable');
            }
            return persisted[call.positionalArguments.first];
          });
          when(() => box.put(any(), any())).thenAnswer((call) async {
            persisted[call.positionalArguments.first as Object] =
                call.positionalArguments[1];
          });
          when(() => box.delete(any())).thenAnswer((call) async {
            persisted.remove(call.positionalArguments.first);
          });
          final store = HiveNotificationPreferencesStore(
            openBox: () async => box,
            openDirtyBox: () async => box,
          );
          const old = NotificationPreferences(commentsEnabled: false);
          const latest = NotificationPreferences(likesEnabled: false);
          final published = <NotificationPreferences>[];
          final service = NotificationPreferencesService(
            store: store,
            accountPreferences: port,
            currentPubkey: () => _account,
            publishPreferences: (_, prefs) async {
              published.add(prefs);
              if (published.length == 1) failRead = true;
              return true;
            },
          );
          addTearDown(service.dispose);
          await service.updatePreferences(old);
          await pumpEventQueue();
          expect(published, [old]);
          expect(await store.markDirty(_account, latest), isTrue);
          expect(
            await service.syncDirtyPreferencesForPubkey(_account),
            NotificationPreferencesSyncOutcome.stillDirty,
          );
          expect(jsonDecode(persisted[dirtyKey]! as String), latest.toJson());
          expect(published, [old]);
          failRead = false;
          expect(
            await service.syncDirtyPreferencesForPubkey(_account),
            NotificationPreferencesSyncOutcome.publishedAndCleared,
          );
          expect(published, [old, latest]);
          expect(await store.loadDirty(_account), isNull);
        },
      );

      for (final sameChoice in [true, false]) {
        test(
          'successful explicit queue coalesces and deduplicates, same choice: '
          '$sameChoice',
          () async {
            SharedPreferences.setMockInitialValues({});
            final port = AccountPreferenceStore(
              await SharedPreferences.getInstance(),
            );
            final account = FakeAccountState(_account);
            await port.bind(account);
            addTearDown(port.dispose);
            addTearDown(account.close);
            final box = _Box();
            final persisted = <Object, Object?>{};
            when(
              () => box.get(any()),
            ).thenAnswer((call) => persisted[call.positionalArguments.first]);
            when(() => box.put(any(), any())).thenAnswer((call) async {
              persisted[call.positionalArguments.first as Object] =
                  call.positionalArguments[1];
            });
            when(() => box.delete(any())).thenAnswer((call) async {
              persisted.remove(call.positionalArguments.first);
            });
            final store = HiveNotificationPreferencesStore(
              openBox: () async => box,
              openDirtyBox: () async => box,
            );
            const old = NotificationPreferences();
            const latest = NotificationPreferences(
              likesEnabled: false,
              commentsEnabled: false,
            );
            await store.markDirty(_account, old);
            final entered = Completer<void>();
            final release = Completer<void>();
            final published = <NotificationPreferences>[];
            final service = NotificationPreferencesService(
              store: store,
              currentPubkey: () => _account,
              accountPreferences: port,
              publishPreferences: (_, prefs) async {
                published.add(prefs);
                if (published.length == 1) {
                  entered.complete();
                  await release.future;
                }
                return true;
              },
            );
            addTearDown(service.dispose);
            final predecessor = service.syncDirtyPreferencesForPubkey(_account);
            await entered.future;
            if (sameChoice) {
              await service.updatePreferences(old);
            } else {
              account.receive({'notifications/commentsEnabled': false});
              await pumpEventQueue();
              account.receive({'notifications/likesEnabled': false});
              await pumpEventQueue();
            }
            release.complete();
            await predecessor;
            await pumpEventQueue();
            expect(published, [old, if (!sameChoice) latest]);
            expect(await store.loadDirty(_account), isNull);
            expect(
              await service.syncDirtyPreferencesForPubkey(_account),
              NotificationPreferencesSyncOutcome.nothingToDrain,
            );
            expect(published, [old, if (!sameChoice) latest]);
          },
        );
      }

      for (final storageFailure in ['put', 'read']) {
        for (final predecessorAccepted in [true, false]) {
          for (final delivery in ['accepted', 'refused', 'thrown']) {
            test('$storageFailure with predecessor $predecessorAccepted and '
                'new delivery $delivery retains the explicit account choice', () async {
              SharedPreferences.setMockInitialValues({});
              final port = AccountPreferenceStore(
                await SharedPreferences.getInstance(),
              );
              final account = FakeAccountState(_account);
              await port.bind(account);
              addTearDown(port.dispose);
              addTearDown(account.close);
              final preferencesBox = _Box();
              final dirtyBox = _Box();
              final persisted = <Object, Object?>{};
              const dirtyKey = 'push_preferences_dirty_$_account';
              var failStorage = false;
              var storageFailed = false;
              when(() => preferencesBox.get(any())).thenReturn(null);
              when(() => dirtyBox.get(any())).thenAnswer((call) {
                final key = call.positionalArguments.first;
                if (key == dirtyKey &&
                    failStorage &&
                    storageFailure == 'read') {
                  storageFailed = true;
                  throw StateError('dirty read refused');
                }
                return persisted[key];
              });
              when(() => dirtyBox.put(any(), any())).thenAnswer((call) async {
                final key = call.positionalArguments[0] as Object;
                if (key == dirtyKey && failStorage && storageFailure == 'put') {
                  storageFailed = true;
                  // Failed Hive backend writes roll back the optimistic cache;
                  // the production store catches this error and leaves P1.
                  throw StateError('dirty put rolled back');
                }
                persisted[key] = call.positionalArguments[1];
              });
              when(() => dirtyBox.delete(any())).thenAnswer((call) async {
                persisted.remove(call.positionalArguments.first);
              });
              final store = HiveNotificationPreferencesStore(
                openBox: () async => preferencesBox,
                openDirtyBox: () async => dirtyBox,
              );
              const old = NotificationPreferences();
              const latest = NotificationPreferences(commentsEnabled: false);
              await store.markDirty(_account, old);
              final entered = Completer<void>();
              final release = Completer<void>();
              final published = <NotificationPreferences>[];
              var latestAttempts = 0;
              final service = NotificationPreferencesService(
                store: store,
                currentPubkey: () => _account,
                accountPreferences: port,
                publishPreferences: (_, prefs) async {
                  published.add(prefs);
                  if (published.length == 1) {
                    entered.complete();
                    await release.future;
                    return predecessorAccepted;
                  }
                  if (prefs == latest && latestAttempts++ == 0) {
                    if (delivery == 'thrown') {
                      throw StateError('publish refused');
                    }
                    return delivery == 'accepted';
                  }
                  return true;
                },
              );
              addTearDown(service.dispose);
              final predecessor = service.syncDirtyPreferencesForPubkey(
                _account,
              );
              await entered.future;
              failStorage = true;
              account.receive({'notifications/commentsEnabled': false});
              await pumpEventQueue();
              release.complete();
              await predecessor;
              await pumpEventQueue();
              expect(storageFailed, isTrue);
              expect(published, [old, latest]);
              expect(await service.loadPreferences(), latest);
              expect(account.localWrites, 0);
              // Recovery uses the existing no-argument retry path. No new
              // account event or explicit preference snapshot is supplied.
              failStorage = false;
              await service.syncDirtyPreferencesForPubkey(_account);
              expect(published.last, latest);
              expect(latestAttempts, delivery == 'accepted' ? 1 : 2);
              expect(await store.loadDirty(_account), isNull);
              final attempts = published.length;
              expect(
                await service.syncDirtyPreferencesForPubkey(_account),
                NotificationPreferencesSyncOutcome.nothingToDrain,
              );
              expect(published, hasLength(attempts));
            });
          }
        }
      }
    });

    group('ordered delivery lifecycle', () {
      for (final failure in ['refused', 'thrown']) {
        test(
          'a $failure delivery retains and retries the latest dirty snapshot',
          () async {
            final store = _MemoryPushStore();
            const old = NotificationPreferences(likesEnabled: false);
            const latest = NotificationPreferences(
              likesEnabled: false,
              commentsEnabled: false,
            );
            store.dirty[_account] = old;
            final entered = Completer<void>();
            final release = Completer<void>();
            final published = <NotificationPreferences>[];
            final service = NotificationPreferencesService(
              store: store,
              currentPubkey: () => _account,
              publishPreferences: (_, prefs) async {
                published.add(prefs);
                if (published.length == 1) {
                  entered.complete();
                  await release.future;
                  if (failure == 'thrown') {
                    throw StateError('publication failed');
                  }
                  return false;
                }
                return true;
              },
            );
            addTearDown(service.dispose);
            final first = service.syncDirtyPreferencesForPubkey(_account);
            final failureObserved = failure == 'thrown'
                ? expectLater(first, throwsStateError)
                : null;
            await entered.future;
            store.dirty[_account] = latest;
            final retry = service.syncDirtyPreferencesForPubkey(_account);
            await pumpEventQueue();
            expect(published, [old]);
            release.complete();
            if (failureObserved != null) {
              await failureObserved;
            } else {
              expect(
                await first,
                NotificationPreferencesSyncOutcome.stillDirty,
              );
            }
            expect(
              await retry,
              NotificationPreferencesSyncOutcome.publishedAndCleared,
            );
            expect(published, [old, latest]);
            expect(store.dirty, isEmpty);
            expect(
              await service.syncDirtyPreferencesForPubkey(_account),
              NotificationPreferencesSyncOutcome.nothingToDrain,
            );
            expect(published, [old, latest]);
          },
        );
      }
      for (final ending in ['switch', 'dispose']) {
        test(
          '$ending cancels queued delivery without blocking another owner',
          () async {
            final store = _MemoryPushStore();
            store.dirty[_account] = const NotificationPreferences(
              likesEnabled: false,
            );
            store.dirty[_incoming] = const NotificationPreferences(
              commentsEnabled: false,
            );
            var owner = _account;
            final entered = Completer<void>();
            final release = Completer<void>();
            final published = <String>[];
            final service = NotificationPreferencesService(
              store: store,
              currentPubkey: () => owner,
              publishPreferences: (pubkey, _) async {
                published.add(pubkey);
                if (pubkey == _account) {
                  entered.complete();
                  await release.future;
                }
                return true;
              },
            );
            addTearDown(service.dispose);
            final first = service.syncDirtyPreferencesForPubkey(_account);
            await entered.future;
            final queued = service.syncDirtyPreferencesForPubkey(_account);
            if (ending == 'switch') {
              owner = _incoming;
              expect(
                await service.syncDirtyPreferencesForPubkey(_incoming),
                NotificationPreferencesSyncOutcome.publishedAndCleared,
              );
            } else {
              service.dispose();
            }
            release.complete();
            expect(await first, NotificationPreferencesSyncOutcome.stillDirty);
            expect(await queued, NotificationPreferencesSyncOutcome.stillDirty);
            expect(published, [_account, if (ending == 'switch') _incoming]);
            expect(store.dirty[_account], isNotNull);
            expect(store.dirty.containsKey(_incoming), ending == 'dispose');
          },
        );
      }
    });

    for (final mode in [
      'held initial load',
      'cached migration',
      'unawaited reload',
    ]) {
      test(
        '$mode reads the incoming account without async cancellation errors',
        () async {
          SharedPreferences.setMockInitialValues({
            'current_user_pubkey_hex': _account,
          });
          final port = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final outgoing = FakeAccountState(_account);
          final incoming = FakeAccountState(_incoming);
          await incoming.setValue('notifications/commentsEnabled', false);
          await port.bind(outgoing);
          final box = _Box();
          when(() => box.get(any())).thenReturn(
            jsonEncode(
              const NotificationPreferences(likesEnabled: false).toJson(),
            ),
          );
          when(() => box.put(any(), any())).thenAnswer((_) async {});
          when(() => box.delete(any())).thenAnswer((_) async {});
          final opened = Completer<void>();
          final release = Completer<Box<dynamic>>();
          var owner = _account;
          final service = NotificationPreferencesService(
            store: HiveNotificationPreferencesStore(
              openBox: () {
                if (!opened.isCompleted) opened.complete();
                return release.future;
              },
              openDirtyBox: () async => box,
            ),
            currentPubkey: () => owner,
            publishPreferences: (_, _) async => true,
            accountPreferences: port,
          );
          late NotificationSettingsCubit cubit;
          final errors = <Object>[];
          await runZonedGuarded(() async {
            cubit = NotificationSettingsCubit(preferencesService: service);
            if (mode == 'cached migration') {
              release.complete(box);
              await cubit.load();
            }
            Future<void>? load;
            if (mode == 'unawaited reload') {
              outgoing.receive({'notifications/likesEnabled': false});
              await opened.future;
            } else {
              load = cubit.load().catchError(errors.add);
              if (mode != 'cached migration') await opened.future;
            }
            owner = _incoming;
            await port.bind(incoming);
            if (!release.isCompleted) release.complete(box);
            await load;
            await pumpEventQueue();
          }, (error, _) => errors.add(error));
          expect(errors, isEmpty);
          expect(cubit.state.preferences.commentsEnabled, isFalse);
          expect(cubit.state.preferences.likesEnabled, isTrue);
          expect(incoming.values, {'notifications/commentsEnabled': false});
          await cubit.close();
          service.dispose();
          port.dispose();
          await outgoing.close();
          await incoming.close();
        },
      );
    }
    test(
      'remote flags refresh settings and push registration without echo; reset persists null',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final port = AccountPreferenceStore(preferences);
        final repository = FakeAccountState(_account);
        await port.bind(repository);
        final push = _MemoryPushStore();
        final registrations = <NotificationPreferences>[];
        final service = NotificationPreferencesService(
          store: push,
          currentPubkey: () => _account,
          accountPreferences: port,
          publishPreferences: (_, preferences) async {
            registrations.add(preferences);
            return true;
          },
        );
        final cubit = NotificationSettingsCubit(preferencesService: service);
        await cubit.load();
        repository.receive({
          'notifications/likesEnabled': false,
          'notifications/campaignsEnabled': true,
        });
        await pumpEventQueue();
        expect(cubit.state.preferences.likesEnabled, isFalse);
        expect(cubit.state.preferences.campaignsEnabled, isTrue);
        expect(registrations.last.likesEnabled, isFalse);
        expect(repository.localWrites, 0);
        await cubit.resetToDefaults();
        expect(repository.value('notifications/likesEnabled'), isNull);
        expect(repository.contains('notifications/likesEnabled'), isTrue);
        expect(cubit.state.preferences, const NotificationPreferences());
        expect(
          repository.values.keys
              .where((key) => key.startsWith('notifications/'))
              .length,
          7,
        );
        await cubit.close();
        service.dispose();
        port.dispose();
        await repository.close();
      },
    );

    test(
      'local choices persist only changed fields and complete while push network is offline',
      () async {
        SharedPreferences.setMockInitialValues({});
        final port = AccountPreferenceStore(
          await SharedPreferences.getInstance(),
        );
        final repository = FakeAccountState(_account);
        await port.bind(repository);
        final network = Completer<bool>();
        final service = NotificationPreferencesService(
          store: _MemoryPushStore(),
          currentPubkey: () => _account,
          accountPreferences: port,
          publishPreferences: (_, _) => network.future,
        );
        await service.updatePreferences(
          const NotificationPreferences(likesEnabled: false),
        );
        expect(repository.values, {'notifications/likesEnabled': false});
        network.complete(false);
        await pumpEventQueue();
        service.dispose();
        port.dispose();
        await repository.close();
      },
    );
    for (final reset in [false, true]) {
      test(
        'remote flags during held local ${reset ? 'reset' : 'update'} converge',
        () async {
          SharedPreferences.setMockInitialValues({});
          final port = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final repository = FakeAccountState(_account, {
            if (reset) 'notifications/likesEnabled': false,
          });
          await port.bind(repository);
          final push = _MemoryPushStore()..markDirtyGate = Completer<void>();
          final registrations = <NotificationPreferences>[];
          final service = NotificationPreferencesService(
            store: push,
            currentPubkey: () => _account,
            accountPreferences: port,
            publishPreferences: (_, preferences) async {
              registrations.add(preferences);
              return true;
            },
          );
          final update = reset
              ? service.resetToDefaults()
              : service.updatePreferences(
                  const NotificationPreferences(likesEnabled: false),
                );
          await push.markDirtyEntered.future;
          await pumpEventQueue();
          repository.receive({'notifications/commentsEnabled': false});
          await pumpEventQueue();
          final writes = repository.localWrites;
          push.markDirtyGate!.complete();
          await update;
          await pumpEventQueue();
          final current = await service.loadPreferences();
          expect(current.commentsEnabled, isFalse);
          expect(current.likesEnabled, reset);
          expect(registrations.last, current);
          expect(
            repository.localWrites,
            writes,
            reason: 'remote refresh never echoes',
          );
          expect(push.dirty, isEmpty);
          service.dispose();
          port.dispose();
          await repository.close();
        },
      );
    }

    for (final mode in ['switch', 'dispose', 'retry', 'later edit']) {
      test(
        'queued remote refresh respects $mode after a held local write',
        () async {
          SharedPreferences.setMockInitialValues({});
          final port = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final outgoing = FakeAccountState(_account);
          final incoming = FakeAccountState(_incoming, {
            'notifications/followsEnabled': false,
          });
          await port.bind(outgoing);
          final push = _MemoryPushStore()
            ..markDirtyGate = Completer<void>()
            ..commitAfterGate = mode == 'later edit';
          final dirtyGate = push.markDirtyGate!;
          final registrations = <(String, NotificationPreferences)>[];
          var owner = _account;
          var accepts = mode != 'retry';
          final service = NotificationPreferencesService(
            store: push,
            currentPubkey: () => owner,
            accountPreferences: port,
            publishPreferences: (owner, preferences) async {
              registrations.add((owner, preferences));
              return accepts;
            },
          );
          final update = service.updatePreferences(
            const NotificationPreferences(likesEnabled: false),
          );
          await push.markDirtyEntered.future;
          outgoing.receive({'notifications/commentsEnabled': false});
          await pumpEventQueue();
          Future<void>? later;
          if (mode == 'later edit') {
            push.markDirtyGate = null;
            later = service.updatePreferences(
              const NotificationPreferences(commentsEnabled: false),
            );
            await pumpEventQueue();
          } else if (mode == 'switch') {
            owner = _incoming;
            await port.bind(incoming);
          } else if (mode == 'dispose') {
            service.dispose();
          }
          dirtyGate.complete();
          await update;
          await later;
          await pumpEventQueue();
          if (mode == 'dispose') {
            expect(registrations, isEmpty);
          } else {
            final current = await service.loadPreferences();
            expect(registrations.last, (owner, current));
            if (mode == 'switch') {
              expect(
                registrations.every((entry) => entry.$1 == _incoming),
                isTrue,
              );
              expect(incoming.localWrites, 0);
            } else if (mode == 'retry') {
              expect(push.dirty[_account], current);
              accepts = true;
              await service.syncDirtyPreferencesForPubkey(_account);
              expect(push.dirty, isEmpty);
              expect(registrations.last.$2, current);
            } else {
              expect(current.likesEnabled, isTrue);
              expect(current.commentsEnabled, isFalse);
            }
          }
          service.dispose();
          port.dispose();
          await outgoing.close();
          await incoming.close();
        },
      );
    }

    test('unrelated preference arrival does not cancel a pending push registration', () async {
      SharedPreferences.setMockInitialValues({});
      final port = AccountPreferenceStore(
        await SharedPreferences.getInstance(),
      );
      final repository = FakeAccountState(_account);
      await port.bind(repository);
      final push = _MemoryPushStore()..markDirtyGate = Completer<void>();
      final registrations = <NotificationPreferences>[];
      final service = NotificationPreferencesService(
        store: push,
        currentPubkey: () => _account,
        accountPreferences: port,
        publishPreferences: (_, preferences) async {
          registrations.add(preferences);
          return true;
        },
      );
      repository.receive({'notifications/likesEnabled': false});
      await pumpEventQueue();
      repository.receive({'content_language': 'es'});
      await pumpEventQueue();
      push.markDirtyGate!.complete();
      await pumpEventQueue();
      expect(registrations.single.likesEnabled, isFalse);
      service.dispose();
      port.dispose();
      await repository.close();
    });
  });
}
