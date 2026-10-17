import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sound request workflow storage', () {
    late Directory directory;
    late File file;
    late AppDatabase db;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sound_request_state_');
      file = File('${directory.path}/database.sqlite');
      db = AppDatabase.test(NativeDatabase(file));
    });
    tearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });

    test(
      'retains account records across reopen and reconciles deletions',
      () async {
        for (final owner in ['a' * 64, 'b' * 64]) {
          await db.soundRequestStateDao.writeAccount(owner, {
            'jobs': {'one': 'pending', 'two': 'pending'},
            'requests': {'three': 'dismissed'},
          });
        }
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        expect(
          await db.soundRequestStateDao.readAccount('a' * 64),
          hasLength(3),
        );
        await db.soundRequestStateDao.writeAccount('a' * 64, {
          'jobs': {'one': 'delivered'},
          'requests': {'three': 'dismissed'},
        });
        final rows = await db.soundRequestStateDao.readAccount('a' * 64);
        expect(
          {for (final row in rows) row.recordKey: row.value},
          {
            'one': 'delivered',
            'three': 'dismissed',
          },
        );
        expect(
          await db.soundRequestStateDao.readAccount('b' * 64),
          hasLength(3),
        );
        expect(await db.soundRequestStateDao.clearAccount('a' * 64), 2);
        expect(await db.soundRequestStateDao.readAccount('a' * 64), isEmpty);
        expect(
          await db.soundRequestStateDao.readAccount('b' * 64),
          hasLength(3),
        );
      },
    );

    test('rolls back a transition when a record write fails', () async {
      final owner = 'a' * 64;
      await db.soundRequestStateDao.writeAccount(owner, {
        'jobs': {'one': 'pending'},
      });
      await db.customStatement(
        'CREATE TRIGGER reject_bad_sound_state BEFORE INSERT '
        'ON sound_request_states '
        "WHEN NEW.section = 'bad' BEGIN "
        "SELECT RAISE(ABORT, 'test refusal'); END",
      );
      await expectLater(
        db.soundRequestStateDao.writeAccount(owner, {
          'jobs': {'one': 'delivered'},
          'bad': {'two': 'rejected'},
        }),
        throwsA(isA<Exception>()),
      );
      final rows = await db.soundRequestStateDao.readAccount(owner);
      expect(rows, hasLength(1));
      expect(rows.single.value, 'pending');
    });
  });
}
