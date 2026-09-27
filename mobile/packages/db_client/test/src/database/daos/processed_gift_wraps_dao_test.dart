// ABOUTME: Unit tests for ProcessedGiftWrapsDao — the dedup ledger that stops
// ABOUTME: DM reaction/deletion gift wraps re-decrypting every launch (#5452).

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProcessedGiftWrapsDao dao;
  late String tempDbPath;

  const ownerA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const ownerB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const wrap1 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const wrap2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('pgw_ledger_test_');
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.processedGiftWrapsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
  });

  group(ProcessedGiftWrapsDao, () {
    group('hasGiftWrapForOwner', () {
      test("does not see another account's row", () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        // An unwrapped kind 4 carries one event id shared by both ends, so
        // this is how the ledger looks when the other party is also a local
        // account. B never stored it and must not act as though it had.
        expect(
          await dao.hasGiftWrapForOwner(
            giftWrapId: wrap1,
            ownerPubkey: ownerB,
          ),
          isFalse,
        );
      });

      test("sees this account's own row", () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(
          await dao.hasGiftWrapForOwner(
            giftWrapId: wrap1,
            ownerPubkey: ownerA,
          ),
          isTrue,
        );
      });

      test('leaves the global probe answering for every account', () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        // The cost decision stays global: the event is terminally handled on
        // this device, so nobody pays to decrypt it again.
        expect(await dao.hasGiftWrap(wrap1), isTrue);
      });

      test('is false for an id nobody recorded', () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(
          await dao.hasGiftWrapForOwner(
            giftWrapId: wrap2,
            ownerPubkey: ownerA,
          ),
          isFalse,
        );
      });
    });

    test('hasGiftWrap is false before any record', () async {
      expect(await dao.hasGiftWrap(wrap1), isFalse);
    });

    test('record then hasGiftWrap returns true', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await dao.hasGiftWrap(wrap1), isTrue);
      expect(await dao.hasGiftWrap(wrap2), isFalse);
    });

    test('record is idempotent — re-recording the same wrap does not throw '
        'and keeps a single row', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await dao.hasGiftWrap(wrap1), isTrue);
      expect(await dao.count(), 1);
    });

    test('dedup is global — a wrap recorded under one owner dedups for '
        'another account on the device', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      // hasGiftWrap takes no owner: a different account sees the same wrap as
      // already processed.
      expect(await dao.hasGiftWrap(wrap1), isTrue);

      // A second record under a different owner is ignored (gift-wrap ids are
      // globally unique), leaving a single row.
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerB);
      expect(await dao.count(), 1);
    });

    test('record rejects an empty owner', () async {
      await expectLater(
        dao.record(giftWrapId: wrap1, ownerPubkey: ''),
        throwsArgumentError,
      );

      expect(await dao.hasGiftWrap(wrap1), isFalse);
    });

    test('giftWrapIdsPresent returns only the recorded subset', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await dao.giftWrapIdsPresent({wrap1, wrap2}), equals({wrap1}));
    });

    test('giftWrapIdsPresent returns an empty set for empty input', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await dao.giftWrapIdsPresent(const <String>{}), isEmpty);
    });

    test('account-switch cleanup preserves another owner', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await dao.record(giftWrapId: wrap2, ownerPubkey: ownerB);

      final deleted = await dao.clearForAccountSwitch(ownerA);

      expect(deleted, 1);
      expect(await dao.hasGiftWrap(wrap1), isFalse);
      expect(await dao.hasGiftWrap(wrap2), isTrue);
      expect(await dao.count(), 1);
    });

    test('exact-owner deletion preserves a legacy ownerless row', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await database.customStatement(
        'INSERT INTO processed_gift_wraps '
        '(gift_wrap_id, processed_at, owner_pubkey) VALUES (?, 100, NULL)',
        [wrap2],
      );

      expect(await dao.deleteAllForOwner(ownerA), 1);
      expect(await dao.hasGiftWrap(wrap2), isTrue);
    });

    test('unknown-owner cleanup removes NULL and empty legacy rows', () async {
      await database.customStatement(
        'INSERT INTO processed_gift_wraps '
        '(gift_wrap_id, processed_at, owner_pubkey) VALUES (?, 100, NULL)',
        [wrap1],
      );
      await database.customStatement(
        'INSERT INTO processed_gift_wraps '
        "(gift_wrap_id, processed_at, owner_pubkey) VALUES (?, 100, '')",
        [wrap2],
      );
      const ownedWrap =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      await dao.record(giftWrapId: ownedWrap, ownerPubkey: ownerB);

      expect(await dao.clearUnowned(), 2);
      expect(await dao.count(), 1);
      expect(await dao.hasGiftWrap(ownedWrap), isTrue);
    });
  });
}
