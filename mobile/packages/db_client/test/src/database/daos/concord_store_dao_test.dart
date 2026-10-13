// ABOUTME: Exercises durable Concord ciphertext storage and account isolation.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Synthetic account identifiers, never real users.
  final accountA = 'a' * 64;
  final accountB = 'b' * 64;
  late Directory directory;
  late File file;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('concord_store_');
    file = File('${directory.path}/database.sqlite');
    database = AppDatabase.test(NativeDatabase(file));
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'retains ciphertext and acknowledgements after database reopen',
    () async {
      await database.concordStoreDao.put(
        account: accountA,
        scope: 'relay/channel',
        key: 'wrap',
        value: 'ciphertext',
      );
      await database.concordStoreDao.put(
        account: accountA,
        scope: 'relay/channel',
        key: 'ack',
        value: 'pending',
      );
      await database.concordStoreDao.put(
        account: accountA,
        scope: 'relay/channel',
        key: 'ack',
        value: 'accepted',
      );
      await database.close();
      database = AppDatabase.test(NativeDatabase(file));
      expect(
        await database.concordStoreDao.get(
          account: accountA,
          scope: 'relay/channel',
          key: 'wrap',
        ),
        'ciphertext',
      );
      expect(
        await database.concordStoreDao.get(
          account: accountA,
          scope: 'relay/channel',
          key: 'ack',
        ),
        'accepted',
      );
    },
  );

  test(
    'isolates account and scope and clears only the requested account',
    () async {
      for (final account in [accountA, accountB]) {
        for (final scope in ['relay/channel', 'other/channel']) {
          await database.concordStoreDao.put(
            account: account,
            scope: scope,
            key: 'wrap',
            value: '$account/$scope',
          );
        }
      }
      await database.concordStoreDao.remove(
        account: accountA,
        scope: 'relay/channel',
        key: 'wrap',
      );
      expect(
        await database.concordStoreDao.get(
          account: accountA,
          scope: 'relay/channel',
          key: 'wrap',
        ),
        isNull,
      );
      expect(
        await database.concordStoreDao.get(
          account: accountA,
          scope: 'other/channel',
          key: 'wrap',
        ),
        '$accountA/other/channel',
      );
      await database.concordStoreDao.clearAccount(accountA);
      expect(
        await database.concordStoreDao.get(
          account: accountA,
          scope: 'other/channel',
          key: 'wrap',
        ),
        isNull,
      );
      for (final scope in ['relay/channel', 'other/channel']) {
        expect(
          await database.concordStoreDao.get(
            account: accountB,
            scope: scope,
            key: 'wrap',
          ),
          '$accountB/$scope',
        );
      }
    },
  );
}
