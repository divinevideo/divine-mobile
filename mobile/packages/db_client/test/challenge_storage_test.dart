import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift/app_database/generated/schema_v29.dart' as v29;

void main() {
  group('durable challenge storage', () {
    test(
      'real v29 file upgrades and reopens without claiming ownerless data',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'challenge-migration-',
        );
        final file = File('${directory.path}/app.sqlite');
        final legacy = v29.DatabaseAtV29(NativeDatabase(file));
        await legacy.customSelect('SELECT 1').get();
        await legacy.close();
        var db = AppDatabase.test(NativeDatabase(file));
        final owner = 'a' * 64;
        final epoch = await db.challengeRecordsDao.openOwner(owner);
        await db.challengeRecordsDao.put(
          owner,
          epoch,
          'context',
          'recording',
          'reviewed',
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          db.schemaVersion,
        );
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        expect(
          (await db.challengeRecordsDao.read(
            owner,
            epoch,
            'context',
          )).single.payload,
          'reviewed',
        );
        await db.close();
        await directory.delete(recursive: true);
      },
    );
    test(
      'salvage repair never grants orphaned challenge '
      'signing records a generation',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'challenge-salvage-',
        );
        final file = File('${directory.path}/app.sqlite');
        var db = AppDatabase.test(NativeDatabase(file));
        final owner = 'a' * 64;
        final epoch = await db.challengeRecordsDao.openOwner(owner);
        await db.challengeRecordsDao.put(
          owner,
          epoch,
          'action',
          'key',
          'orphan',
          signedBody: 'body',
        );
        await db.customStatement('DROP TABLE challenge_owners');
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        final next = await db.challengeRecordsDao.openOwner(owner);
        expect(next, isNot(epoch));
        expect(
          await db.challengeRecordsDao.read(owner, next, 'action'),
          isEmpty,
        );
        await db.close();
        await directory.delete(recursive: true);
      },
    );
    test('restart preserves exact signed bytes and isolates owners', () async {
      final directory = await Directory.systemTemp.createTemp(
        'challenge-reopen-',
      );
      final file = File('${directory.path}/app.sqlite');
      var db = AppDatabase.test(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      final owner = 'a' * 64;
      final other = 'b' * 64;
      final epoch = await db.challengeRecordsDao.openOwner(owner);
      final otherEpoch = await db.challengeRecordsDao.openOwner(other);
      final body = '  {"id":"${'c' * 64}"}\n';
      await db.challengeRecordsDao.put(
        owner,
        epoch,
        'action',
        'review',
        'evidence',
        signedBody: body,
        insertOnly: true,
      );
      await db.challengeRecordsDao.put(
        other,
        otherEpoch,
        'context',
        'draft',
        'other',
      );
      await db.close();
      db = AppDatabase.test(NativeDatabase(file));
      expect(await db.challengeRecordsDao.openOwner(owner), epoch);
      final rows = await db.challengeRecordsDao.read(owner, epoch, 'action');
      expect(rows.single.signedBody, body);
      expect(
        await db.challengeRecordsDao.put(
          owner,
          epoch,
          'action',
          'review',
          'replacement',
          signedBody: 'changed',
          insertOnly: true,
        ),
        'evidence',
      );
      await expectLater(
        db.challengeRecordsDao.put(
          owner,
          epoch,
          'action',
          'review',
          'replacement',
          signedBody: 'changed',
        ),
        throwsStateError,
      );
      await db.challengeRecordsDao.removeOwner(owner);
      await expectLater(
        db.challengeRecordsDao.read(owner, epoch, 'action'),
        throwsA(isA<ChallengeOwnerRevoked>()),
      );
      expect(
        (await db.challengeRecordsDao.read(
          other,
          otherEpoch,
          'context',
        )).single.payload,
        'other',
      );
      final next = await db.challengeRecordsDao.openOwner(owner);
      expect(next, isNot(epoch));
      expect(await db.challengeRecordsDao.read(owner, next, 'action'), isEmpty);
    });
    for (final category in ['retained', 'context', 'action', 'handoff']) {
      test('late $category write cannot resurrect removed owner', () async {
        final directory = await Directory.systemTemp.createTemp(
          'challenge-race-',
        );
        final db = AppDatabase.test(
          NativeDatabase(File('${directory.path}/app.sqlite')),
        );
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        final owner = 'a' * 64;
        final epoch = await db.challengeRecordsDao.openOwner(owner);
        final release = Completer<void>();
        // The application checked its current owner before awaiting an I/O
        // boundary. Cleanup finishes while that write is suspended.
        final checked = Completer<void>();
        Future<void> delayedWrite() async {
          checked.complete();
          await release.future;
          await db.challengeRecordsDao.put(
            owner,
            epoch,
            category,
            'key',
            'late',
          );
        }

        final write = delayedWrite();
        await checked.future;
        await db.challengeRecordsDao.removeOwner(owner);
        final failure = expectLater(
          write,
          throwsA(isA<ChallengeOwnerRevoked>()),
        );
        release.complete();
        await failure;
        final rows = await db
            .customSelect('SELECT * FROM challenge_records')
            .get();
        expect(rows, isEmpty);
      });
    }
    test(
      'fresh database owns dedicated generation and record tables',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'challenge-db-',
        );
        final db = AppDatabase.test(
          NativeDatabase(File('${directory.path}/app.sqlite')),
        );
        addTearDown(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        final tables = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
        expect(
          tables.map((row) => row.read<String>('name')),
          containsAll(['challenge_owners', 'challenge_records']),
        );
      },
    );
  });
}
