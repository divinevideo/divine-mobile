import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _incoming =
    '2222222222222222222222222222222222222222222222222222222222222222';

class _Box extends Mock implements Box<dynamic> {}

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
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (!commitAfterGate) dirty[pubkey] = preferences;
    if (!markDirtyEntered.isCompleted) markDirtyEntered.complete();
    await markDirtyGate?.future;
    if (commitAfterGate) dirty[pubkey] = preferences;
  }

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
