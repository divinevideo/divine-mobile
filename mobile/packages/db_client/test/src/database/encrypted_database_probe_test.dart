import 'dart:io';

import 'package:db_client/db_client.dart'
    show AppDatabase, encryptedDatabaseOpensCleanly;
import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('encryptedDatabaseOpensCleanly', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    const otherKey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_opens_cleanly_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('returns true for a healthy encrypted database', () async {
      await _seedRealSchemaDatabase(dbPath, validKey, eventCount: 10);

      expect(
        await encryptedDatabaseOpensCleanly(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isTrue,
      );
    });

    test(
      'retains verification and its index across consecutive encrypted opens',
      () async {
        await _seedRealSchemaDatabase(dbPath, validKey, eventCount: 0);
        final raw = sqlite3.open(dbPath);
        try {
          applyCipherKey(raw, validKey);
          for (final checked in [0, 1]) {
            raw.execute(
              'INSERT INTO event (id,pubkey,created_at,kind,tags,content,sig,expire_at,signature_verified) '
              'VALUES (?,?,?,?,?,?,?,?,?)',
              [
                checked == 0 ? 'a' * 64 : 'b' * 64,
                'c' * 64,
                100 + checked,
                1,
                '[]',
                'cached',
                'd' * 128,
                4102444800,
                checked,
              ],
            );
          }
        } finally {
          raw.dispose();
        }
        for (var launch = 0; launch < 2; launch++) {
          expect(
            await encryptedDatabaseOpensCleanly(
              rawKeyHex: validKey,
              databasePath: dbPath,
            ),
            isTrue,
          );
          final db = AppDatabase(
            openEncryptedConnection(rawKeyHex: validKey, databasePath: dbPath),
          );
          try {
            expect(await db.nostrEventsDao.getEventCount(), 2);
            expect(await db.nostrEventsDao.getRecentVerifiedEventIdSigs(), [
              (id: 'b' * 64, sig: 'd' * 128),
            ]);
            final plan = await db
                .customSelect(
                  'EXPLAIN QUERY PLAN SELECT id,sig FROM event WHERE signature_verified=1 ORDER BY created_at DESC LIMIT 50000',
                )
                .get();
            expect(
              plan.map((row) => row.read<String>('detail')).join(' '),
              contains('idx_event_verified_created_at'),
            );
          } finally {
            await db.close();
          }
        }
      },
    );

    test('returns false when the key cannot decrypt the database', () async {
      await _seedRealSchemaDatabase(dbPath, validKey, eventCount: 10);

      expect(
        await encryptedDatabaseOpensCleanly(
          rawKeyHex: otherKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });

    test(
      'returns false when the startup cleanup hits on-disk corruption',
      () async {
        // The schema page stays intact (so the file opens and the cipher key
        // works), but the event b-tree pages are damaged. The reactive probe
        // must trip when Drift's beforeOpen `DELETE FROM event …` walks them —
        // the exact field failure — and translate the background-isolate error
        // into `false` rather than rethrowing.
        await _seedRealSchemaDatabase(dbPath, validKey, eventCount: 800);
        _corruptBackHalf(dbPath);

        expect(
          await encryptedDatabaseOpensCleanly(
            rawKeyHex: validKey,
            databasePath: dbPath,
          ),
          isFalse,
        );
      },
    );
  });
}

/// Builds a real-schema encrypted database at [path] (via Drift's onCreate),
/// then bulk-inserts [eventCount] NULL-expiry `event` rows through a raw keyed
/// handle so the table spans multiple pages.
Future<void> _seedRealSchemaDatabase(
  String path,
  String key, {
  required int eventCount,
}) async {
  final db = AppDatabase(
    openEncryptedConnection(rawKeyHex: key, databasePath: path),
  );
  // Forces onCreate (createAll) so the file carries the full Drift schema.
  await db.customSelect('SELECT 1;').get();
  await db.close();

  if (eventCount == 0) return;

  final raw = sqlite3.open(path);
  try {
    applyCipherKey(raw, key);
    final insert = raw.prepare(
      'INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      raw.execute('BEGIN');
      for (var i = 0; i < eventCount; i += 1) {
        final suffix = i.toString().padLeft(6, '0');
        insert.execute([
          'e$suffix',
          'pubkey_$suffix',
          1700000000 + i,
          1,
          '[]',
          'content_$suffix',
          'sig_$suffix',
        ]);
      }
      raw.execute('COMMIT');
    } finally {
      insert.close();
    }
  } finally {
    raw.close();
  }
}

/// Overwrites the back half of the file so the event b-tree pages are damaged
/// while the header + schema pages stay intact.
void _corruptBackHalf(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  for (var i = bytes.length ~/ 2; i < bytes.length; i += 1) {
    bytes[i] = 0xFF;
  }
  file.writeAsBytesSync(bytes);
}
