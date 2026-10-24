// ABOUTME: Account isolation and durable cleanup for official announcement state.

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/services/announcement_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Mock implements AnnouncementsRepository {}

class _CacheDao extends Mock implements CacheDao {}

void main() {
  const alice =
      '31ef21a624ab5576f14705fdbb56bead914b20154baf8a47d7c28c8103718b04';
  const bob =
      '9cedf5a0f75ba9be6541bf2b83c663c695431d548512ed9b42bf891a904d7b28';
  late SharedPreferences prefs;
  late SqliteCacheStore cache;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = SqliteCacheStore(NativeDatabase.memory());
    await CacheSync.init(dao: cache.dao);
  });
  tearDown(() => cache.close());
  group('readSeen, writeSeen, and clearOwner', () {
    test(
      'an unavailable optional cache does not fail initialization',
      () async {
        final unavailable = _CacheDao();
        when(() => unavailable.readEntry(any())).thenThrow(
          StateError('optional cache was not initialized'),
        );
        await CacheSync.init(dao: unavailable);
        final store = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        expect(await store.readCatalog(), isNull);
        await store.writeSeen(['announcement:seen']);
        expect(await store.readSeen(), ['announcement:seen']);
      },
    );

    test(
      'retains a stale public cache for validated offline hydration',
      () async {
        await CacheSync.write<String>(
          key: SharedPreferencesAnnouncementStore.catalogCacheKey,
          value: 'stale catalog envelope',
          toJson: (value) => value,
          ttl: const Duration(seconds: -1),
        );
        expect(
          (await cache.dao.readEntry(
            SharedPreferencesAnnouncementStore.catalogCacheKey,
          ))?.isStale,
          isTrue,
        );
        final store = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        expect(await store.readCatalog(), 'stale catalog envelope');
        expect(prefs.getKeys(), isEmpty);
      },
    );

    test(
      'seen IDs belong to their account, public catalog is shared in cache_sync',
      () async {
        final a = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        final b = SharedPreferencesAnnouncementStore(prefs: prefs, owner: bob);
        await a.writeSeen(['announcement:first']);
        await a.writeCatalog('catalog-a');
        expect(await a.readSeen(), ['announcement:first']);
        expect(await b.readSeen(), isEmpty);
        expect(await b.readCatalog(), 'catalog-a');
        expect(
          (await cache.dao.readEntry(
            SharedPreferencesAnnouncementStore.catalogCacheKey,
          ))?.payload,
          'catalog-a',
        );
        expect(prefs.getKeys().every((key) => key.contains(alice)), isTrue);
        expect(prefs.getKeys(), hasLength(1));
      },
    );
    test(
      'cleanup drains outgoing writes before deleting only that owner',
      () async {
        final a = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        final b = SharedPreferencesAnnouncementStore(prefs: prefs, owner: bob);
        await a.writeSeen(['announcement:old']);
        await a.writeCatalog('public catalog');
        await b.writeSeen(['announcement:b']);
        final repository = _Repository();
        final finishing = Completer<void>();
        when(repository.close).thenAnswer((_) async {
          await finishing.future;
          await a.writeSeen(['announcement:late']);
        });
        final sessions = AnnouncementSessions();
        sessions.register(alice, repository);
        final cleanup = sessions.clearOwner(prefs, alice);
        expect(await a.readSeen(), ['announcement:old']);
        finishing.complete();
        await cleanup;
        expect(await a.readSeen(), isEmpty);
        expect(await b.readSeen(), ['announcement:b']);
        expect(await b.readCatalog(), 'public catalog');
        verify(repository.close).called(1);
      },
    );
  });
}
