import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';

class _MemoryPushStore implements NotificationPreferencesStore {
  NotificationPreferences saved = const NotificationPreferences();
  final dirty = <String, NotificationPreferences>{};
  Completer<void>? markDirtyGate;
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
    dirty[pubkey] = preferences;
    await markDirtyGate?.future;
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
