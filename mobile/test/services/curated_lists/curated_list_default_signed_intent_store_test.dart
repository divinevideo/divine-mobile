// ABOUTME: Verifies durable default-list retries require genuine owner signatures.
// ABOUTME: Uses the personal-event database and preserves invalid evidence.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/curated_lists/curated_list_default_signed_intent_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(CuratedDefaultSignedIntentStore, () {
    late AppDatabase database;
    late CuratedDefaultSignedIntentStore store;
    late Event signed;
    late String owner;
    setUp(() async {
      database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      store = CuratedDefaultSignedIntentStore(database.personalEventsDao);
      // Synthetic public test key, unrelated to any application account.
      final signer = LocalNostrSigner('1'.padLeft(64, '0'));
      owner = (await signer.getPublicKey())!;
      signed = Event(
        owner,
        30005,
        [
          ['d', 'my_vine_list'],
        ],
        (await signer.nip44Encrypt(owner, '[]'))!,
        createdAt: 1700000000,
      );
      await signer.signEvent(signed);
    });
    test(
      'persists encrypted signed evidence and verifies it on read',
      () async {
        expect(await store.save(signed), isTrue);
        expect((await store.read(owner))?.id, signed.id);
        expect((await store.read(owner))?.content, signed.content);
        expect(await store.read('b' * 64), isNull);
      },
    );
    test(
      'ordinary cached events never grant explicit retry authority',
      () async {
        await database.personalEventsDao.upsertPersonalEvent(signed);
        expect(await store.read(owner), isNull);
      },
    );
    test('rejects forged signatures even with a valid event hash', () async {
      final forged = Event.fromJson({...signed.toJson(), 'sig': '0' * 128});
      expect(forged.isValid, isTrue);
      expect(await store.save(forged), isFalse);
      await database.personalEventsDao.upsertPersonalEvent(
        forged,
        retainForRetry: true,
      );
      expect(await store.read(owner), isNull);
      expect(
        await database.personalEventsDao.getById(pubkey: owner, id: forged.id),
        isNotNull,
      );
    });
    test(
      'unreadable intent remains held without authorizing a retry',
      () async {
        expect(await store.save(signed), isTrue);
        await database.customStatement(
          'UPDATE personal_events SET tags = ? WHERE id = ?',
          ['not json', signed.id],
        );
        expect(await store.read(owner), isNull);
        expect(await database.personalEventsDao.getAllForOwner(owner), isEmpty);
        expect(await database.personalEventsDao.countForOwner(owner), 1);
        expect(await store.read(owner), isNull);
      },
    );

    test('owner cleanup removes only that owner signed intent', () async {
      expect(await store.save(signed), isTrue);
      await database.personalEventsDao.deleteAllForOwner('b' * 64);
      expect(await store.read(owner), isNotNull);
      await database.personalEventsDao.deleteAllForOwner(owner);
      expect(await store.read(owner), isNull);
    });
  });
}
