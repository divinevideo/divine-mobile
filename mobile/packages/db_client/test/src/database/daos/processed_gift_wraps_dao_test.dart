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

  Future<bool> recordedFor(String wrapId, String owner) =>
      dao.hasGiftWrapForOwner(giftWrapId: wrapId, ownerPubkey: owner);

  Future<void> insertLegacyRow(String wrapId, {required String? owner}) =>
      database.customStatement(
        'INSERT INTO processed_gift_wraps '
        '(gift_wrap_id, processed_at, owner_pubkey) VALUES (?, 100, ?)',
        [wrapId, owner],
      );

  group(ProcessedGiftWrapsDao, () {
    group('hasGiftWrapForOwner', () {
      test("does not see another account's row", () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        // An unwrapped kind 4 carries one event id shared by both ends, so
        // this is how the ledger looks when the other party is also a local
        // account. B never stored it and must not act as though it had.
        expect(await recordedFor(wrap1, ownerB), isFalse);
      });

      test("sees this account's own row", () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(await recordedFor(wrap1, ownerA), isTrue);
      });

      test("counts a legacy ownerless row as the account's own", () async {
        await insertLegacyRow(wrap1, owner: null);
        await insertLegacyRow(wrap2, owner: '');

        expect(await recordedFor(wrap1, ownerB), isTrue);
        expect(await recordedFor(wrap2, ownerB), isTrue);
      });

      test('is false for an id nobody recorded', () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(await recordedFor(wrap2, ownerA), isFalse);
      });
    });

    test('hasGiftWrapForOwner is false before any record', () async {
      expect(await recordedFor(wrap1, ownerA), isFalse);
    });

    test('record then hasGiftWrapForOwner returns true', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await recordedFor(wrap1, ownerA), isTrue);
      expect(await recordedFor(wrap2, ownerA), isFalse);
    });

    test('record is idempotent — re-recording the same wrap does not throw '
        'and keeps a single row', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      expect(await recordedFor(wrap1, ownerA), isTrue);
      expect(await dao.count(), 1);
    });

    test("the first account to record an id keeps it — a second account's "
        'record is ignored, so only the first one dedups', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

      // The key is the id alone. Only a kind 4 can reach it for two accounts,
      // and the second one re-handles the event rather than skipping it.
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerB);

      expect(await dao.count(), 1);
      expect(await recordedFor(wrap1, ownerA), isTrue);
      expect(await recordedFor(wrap1, ownerB), isFalse);
    });

    test('record rejects an empty owner', () async {
      await expectLater(
        dao.record(giftWrapId: wrap1, ownerPubkey: ''),
        throwsArgumentError,
      );

      expect(await recordedFor(wrap1, ownerA), isFalse);
    });

    group('giftWrapIdsPresent', () {
      test('returns only the recorded subset', () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(
          await dao.giftWrapIdsPresent({wrap1, wrap2}, ownerPubkey: ownerA),
          equals({wrap1}),
        );
      });

      test("leaves out another account's rows", () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
        await dao.record(giftWrapId: wrap2, ownerPubkey: ownerB);

        expect(
          await dao.giftWrapIdsPresent({wrap1, wrap2}, ownerPubkey: ownerB),
          equals({wrap2}),
        );
      });

      test("counts a legacy ownerless row as the account's own", () async {
        await insertLegacyRow(wrap1, owner: null);

        expect(
          await dao.giftWrapIdsPresent({wrap1}, ownerPubkey: ownerB),
          equals({wrap1}),
        );
      });

      test('returns an empty set for empty input', () async {
        await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);

        expect(
          await dao.giftWrapIdsPresent(const <String>{}, ownerPubkey: ownerA),
          isEmpty,
        );
      });
    });

    test('account-switch cleanup preserves another owner', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await dao.record(giftWrapId: wrap2, ownerPubkey: ownerB);

      final deleted = await dao.clearForAccountSwitch(ownerA);

      expect(deleted, 1);
      expect(await recordedFor(wrap1, ownerA), isFalse);
      expect(await recordedFor(wrap2, ownerB), isTrue);
      expect(await dao.count(), 1);
    });

    test('exact-owner deletion preserves a legacy ownerless row', () async {
      await dao.record(giftWrapId: wrap1, ownerPubkey: ownerA);
      await insertLegacyRow(wrap2, owner: null);

      expect(await dao.deleteAllForOwner(ownerA), 1);
      expect(await recordedFor(wrap2, ownerA), isTrue);
    });

    test('unknown-owner cleanup removes NULL and empty legacy rows', () async {
      await insertLegacyRow(wrap1, owner: null);
      await insertLegacyRow(wrap2, owner: '');
      const ownedWrap =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      await dao.record(giftWrapId: ownedWrap, ownerPubkey: ownerB);

      expect(await dao.clearUnowned(), 2);
      expect(await dao.count(), 1);
      expect(await recordedFor(ownedWrap, ownerB), isTrue);
    });
  });
}
