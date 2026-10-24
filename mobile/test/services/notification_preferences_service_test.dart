// ABOUTME: Tests persistence behavior for push notification preferences.
// ABOUTME: Verifies dirty retry state survives notification cache cleanup.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

class _MockHiveBox extends Mock implements Box<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('unbound account preference port', () {
    for (final mutation in ['snapshot', 'field', 'reset']) {
      test(
        'unbound $mutation mutation retains its account lease',
        () async {
          SharedPreferences.setMockInitialValues({});
          final account = AccountPreferenceStore(
            await SharedPreferences.getInstance(),
          );
          final entered = Completer<void>();
          final release = Completer<void>();
          var saves = 0;
          final store = _MemoryNotificationPreferencesStore()
            ..beforeSave = () async {
              ++saves;
              entered.complete();
              await release.future;
            };
          final firstOwner = 'a' * 64;
          var owner = firstOwner;
          final publishedOwners = <String>[];
          final service = NotificationPreferencesService(
            store: store,
            currentPubkey: () => owner,
            accountPreferences: account,
            publishPreferences: (pubkey, _) async {
              publishedOwners.add(pubkey);
              return false;
            },
          );
          final incoming = FakeAccountState('b' * 64);
          addTearDown(service.dispose);
          addTearDown(account.dispose);
          addTearDown(incoming.close);
          final operation = switch (mutation) {
            'reset' => service.resetToDefaults(),
            'field' => service.updatePreference(
              NotificationPreference.commentsEnabled,
              false,
            ),
            _ => service.updatePreferences(
              const NotificationPreferences(commentsEnabled: false),
            ),
          };
          final cancelled = expectLater(operation, throwsStateError);
          await entered.future;
          final queuedCancellation = mutation == 'field'
              ? expectLater(
                  service.updatePreference(
                    NotificationPreference.likesEnabled,
                    false,
                  ),
                  throwsStateError,
                )
              : null;
          owner = incoming.pubkey;
          await account.bind(incoming);
          release.complete();
          await cancelled;
          await queuedCancellation;
          expect(saves, 1);
          expect(incoming.values, isEmpty);
          expect(await store.loadDirty(firstOwner), isNull);
          expect(publishedOwners, isNot(contains(firstOwner)));
        },
      );
    }

    test(
      'unbound persistence failure is propagated before dirty publication',
      () async {
        SharedPreferences.setMockInitialValues({});
        final account = AccountPreferenceStore(
          await SharedPreferences.getInstance(),
        );
        final failure = StateError('preference storage refused');
        final store = _MemoryNotificationPreferencesStore()
          ..beforeSave = () async {
            throw failure;
          };
        final owner = 'a' * 64;
        var published = false;
        final service = NotificationPreferencesService(
          store: store,
          currentPubkey: () => owner,
          accountPreferences: account,
          publishPreferences: (_, _) async {
            published = true;
            return true;
          },
        );
        addTearDown(service.dispose);
        addTearDown(account.dispose);
        await expectLater(
          service.updatePreferences(
            const NotificationPreferences(commentsEnabled: false),
          ),
          throwsA(same(failure)),
        );
        expect(await store.loadDirty(owner), isNull);
        expect(published, isFalse);
      },
    );

    test('merges concurrent legacy field choices after a held save', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var saves = 0;
      final store = _MemoryNotificationPreferencesStore()
        ..beforeSave = () async {
          if (saves++ == 0) {
            entered.complete();
            await release.future;
          }
        };
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => null,
        publishPreferences: (_, _) async => false,
      );
      addTearDown(service.dispose);
      final first = service.updatePreference(
        NotificationPreference.likesEnabled,
        false,
      );
      await entered.future;
      final second = service.updatePreference(
        NotificationPreference.commentsEnabled,
        false,
      );
      await pumpEventQueue();
      release.complete();
      await Future.wait([first, second]);

      expect(
        await service.loadPreferences(),
        const NotificationPreferences(
          likesEnabled: false,
          commentsEnabled: false,
        ),
      );
    });

    test(
      'a rejected legacy field save does not block the next choice',
      () async {
        var saves = 0;
        final store = _MemoryNotificationPreferencesStore()
          ..beforeSave = () async {
            if (saves++ == 0) throw StateError('preference storage refused');
          };
        final owner = 'a' * 64;
        final published = <NotificationPreferences>[];
        final service = NotificationPreferencesService(
          store: store,
          currentPubkey: () => owner,
          publishPreferences: (_, preferences) async {
            published.add(preferences);
            return false;
          },
        );
        addTearDown(service.dispose);
        await expectLater(
          service.updatePreference(NotificationPreference.likesEnabled, false),
          throwsStateError,
        );
        expect(await store.loadDirty(owner), isNull);
        expect(published, isEmpty);
        await service.updatePreference(
          NotificationPreference.commentsEnabled,
          false,
        );

        const effective = NotificationPreferences(commentsEnabled: false);
        expect(await service.loadPreferences(), effective);
        expect(await store.loadDirty(owner), effective);
        expect(published, [effective]);
      },
    );

    test('saves and publishes the same legacy preference snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final account = AccountPreferenceStore(
        await SharedPreferences.getInstance(),
      );
      final store = _MemoryNotificationPreferencesStore();
      final published = <NotificationPreferences>[];
      final owner = 'a' * 64;
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => owner,
        accountPreferences: account,
        publishPreferences: (_, preferences) async {
          published.add(preferences);
          return false;
        },
      );
      addTearDown(service.dispose);
      addTearDown(account.dispose);
      const choices = NotificationPreferences(commentsEnabled: false);
      await service.updatePreferences(choices);
      await pumpEventQueue();
      expect(await service.loadPreferences(), choices);
      expect(await store.loadDirty(owner), choices);
      expect(published, [choices]);
      await service.resetToDefaults();
      await pumpEventQueue();
      expect(await service.loadPreferences(), const NotificationPreferences());
      expect(await store.loadDirty(owner), const NotificationPreferences());
      expect(published, [choices, const NotificationPreferences()]);
    });
  });

  group('clearPreferences', () {
    test('propagates a failed deletion to account cleanup', () async {
      final box = _MockHiveBox();
      final failure = StateError('preference deletion failed');
      final store = HiveNotificationPreferencesStore(openBox: () async => box);
      when(() => box.delete('push_preferences')).thenThrow(failure);

      await expectLater(store.clearPreferences(), throwsA(same(failure)));
    });
  });

  group('markDirty', () {
    test('dirty preferences survive notification box cleanup', () async {
      const pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const prefs = NotificationPreferences(commentsEnabled: false);
      final notificationBox = _MockHiveBox();
      final dirtyBox = _MockHiveBox();
      final notificationStorage = <dynamic, dynamic>{};
      final dirtyStorage = <dynamic, dynamic>{};
      final store = HiveNotificationPreferencesStore(
        openBox: () async => notificationBox,
        openDirtyBox: () async => dirtyBox,
      );
      when(() => notificationBox.put(any(), any())).thenAnswer((invocation) {
        notificationStorage[invocation.positionalArguments[0]] =
            invocation.positionalArguments[1];
        return Future<void>.value();
      });
      when(() => dirtyBox.put(any(), any())).thenAnswer((invocation) {
        dirtyStorage[invocation.positionalArguments[0]] =
            invocation.positionalArguments[1];
        return Future<void>.value();
      });
      when(() => dirtyBox.get(any())).thenAnswer(
        (invocation) => dirtyStorage[invocation.positionalArguments[0]],
      );

      await store.markDirty(pubkey, prefs);
      await notificationBox.put('cached_notification', {
        'id': 'cached_notification',
      });

      notificationStorage.clear();

      expect(await store.loadDirty(pubkey), prefs);
      expect(notificationStorage, isEmpty);
    });
  });

  group('syncDirtyPreferencesForPubkey', () {
    test(
      'syncs and clears matching dirty preferences after publish succeeds',
      () async {
        const pubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const prefs = NotificationPreferences(commentsEnabled: false);
        final store = _MemoryNotificationPreferencesStore();
        final published = <NotificationPreferences>[];
        final service = NotificationPreferencesService(
          store: store,
          currentPubkey: () => pubkey,
          publishPreferences: (publishPubkey, preferences) async {
            expect(publishPubkey, pubkey);
            published.add(preferences);
            return true;
          },
        );

        await store.markDirty(pubkey, prefs);
        final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

        expect(outcome, NotificationPreferencesSyncOutcome.publishedAndCleared);
        expect(published, [prefs]);
        expect(await store.loadDirty(pubkey), isNull);
      },
    );

    test('keeps dirty preferences after publish failure', () async {
      const pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const prefs = NotificationPreferences(commentsEnabled: false);
      final store = _MemoryNotificationPreferencesStore();
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (_, _) async => false,
      );

      await store.markDirty(pubkey, prefs);
      final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

      expect(outcome, NotificationPreferencesSyncOutcome.stillDirty);
      expect(await store.loadDirty(pubkey), prefs);
    });

    test('reports nothing to drain when no dirty preferences exist', () async {
      const pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final store = _MemoryNotificationPreferencesStore();
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (_, _) async => true,
      );

      final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

      expect(outcome, NotificationPreferencesSyncOutcome.nothingToDrain);
    });
  });

  group('published kind-list schema', () {
    const pubkey =
        '3333333333333333333333333333333333333333333333333333333333333333';

    test('republishes for a user who upgraded across a kinds change', () async {
      // The pre-upgrade state: preferences stored, nothing dirty, and no
      // schema marker because the marker did not exist when they last
      // published. The push service is still filtering on the old kind list.
      final store = _MemoryNotificationPreferencesStore()
        ..preferences = const NotificationPreferences();
      final published = <NotificationPreferences>[];
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (_, prefs) async {
          published.add(prefs);
          return true;
        },
      );

      expect(await service.markDirtyIfSchemaOutdated(pubkey), isTrue);
      final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

      expect(outcome, NotificationPreferencesSyncOutcome.publishedAndCleared);
      expect(published.single.toKindsList(), contains(34236));
      expect(
        store.publishedSchemaVersions[pubkey],
        NotificationPreferencesService.publishedKindsSchemaVersion,
      );
    });

    test('does not republish once the marker is current', () async {
      final store = _MemoryNotificationPreferencesStore()
        ..publishedSchemaVersions[pubkey] =
            NotificationPreferencesService.publishedKindsSchemaVersion;
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (_, _) async => true,
      );

      expect(await service.markDirtyIfSchemaOutdated(pubkey), isFalse);
      expect(
        await service.syncDirtyPreferencesForPubkey(pubkey),
        NotificationPreferencesSyncOutcome.nothingToDrain,
      );
    });

    test('leaves the marker behind when the publish fails, so the next '
        'readiness pass retries', () async {
      final store = _MemoryNotificationPreferencesStore()
        ..preferences = const NotificationPreferences();
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (_, _) async => false,
      );

      await service.markDirtyIfSchemaOutdated(pubkey);
      final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

      expect(outcome, NotificationPreferencesSyncOutcome.stillDirty);
      expect(store.publishedSchemaVersions[pubkey], isNull);
      // The retry rides the surviving dirty entry rather than a second
      // schema-triggered mark, so the pending payload is never clobbered.
      expect(store.dirty[pubkey], isNotNull);
      expect(await service.markDirtyIfSchemaOutdated(pubkey), isFalse);
    });
  });
}

class _MemoryNotificationPreferencesStore
    implements NotificationPreferencesStore {
  final publishedSchemaVersions = <String, int>{};

  @override
  Future<void> clearPreferences() async {
    preferences = null;
  }

  @override
  Future<int?> loadPublishedSchemaVersion(String pubkey) async =>
      publishedSchemaVersions[pubkey];

  @override
  Future<void> savePublishedSchemaVersion(String pubkey, int version) async {
    publishedSchemaVersions[pubkey] = version;
  }

  NotificationPreferences? preferences;
  Future<void> Function()? beforeSave;
  final dirty = <String, NotificationPreferences>{};

  @override
  Future<NotificationPreferences> loadPreferences() async {
    return preferences ?? const NotificationPreferences();
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    await beforeSave?.call();
    this.preferences = preferences;
  }

  @override
  Future<bool> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    dirty[pubkey] = preferences;
    return true;
  }

  @override
  Future<NotificationPreferencesDirtyRead> readDirty(String pubkey) async =>
      (preferences: await loadDirty(pubkey), succeeded: true);

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async {
    return dirty[pubkey];
  }

  @override
  Future<void> clearDirty(String pubkey) async {
    dirty.remove(pubkey);
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (dirty[pubkey] == preferences) {
      dirty.remove(pubkey);
    }
  }
}
