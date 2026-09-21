import 'dart:io';

import 'package:db_client/src/database/connection/database_backup_retention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('formatDatabaseBackupStamp', () {
    test('renders a UTC instant in ISO 8601 basic format', () {
      expect(
        formatDatabaseBackupStamp(DateTime.utc(2026, 9, 21, 12, 58, 17)),
        equals('20260921T125817Z'),
      );
    });

    test('normalizes a local instant to UTC', () {
      final local = DateTime.utc(2026, 9, 21, 12, 58, 17).toLocal();

      expect(
        formatDatabaseBackupStamp(local),
        equals('20260921T125817Z'),
      );
    });

    test('pads every field so stamps sort chronologically as strings', () {
      final january = formatDatabaseBackupStamp(DateTime.utc(2026, 1, 2, 3, 4));
      final december = formatDatabaseBackupStamp(DateTime.utc(2026, 12, 2));

      expect(january, equals('20260102T030400Z'));
      expect(january.compareTo(december), isNegative);
    });
  });

  group('parseDatabaseBackupStamp', () {
    test('round-trips a stamp this library wrote', () {
      final when = DateTime.utc(2026, 9, 21, 12, 58, 17);

      expect(
        parseDatabaseBackupStamp(formatDatabaseBackupStamp(when)),
        equals(when),
      );
    });

    test('returns null for a name that is not a stamp', () {
      expect(parseDatabaseBackupStamp('1'), isNull);
      expect(parseDatabaseBackupStamp(''), isNull);
      expect(parseDatabaseBackupStamp('20260921125817Z'), isNull);
      expect(parseDatabaseBackupStamp('2026092!T125817Z'), isNull);
    });

    test('rejects an out-of-range field instead of rolling it over', () {
      // DateTime.utc(2026, 2, 31) silently becomes March 3rd, which would give
      // the copy a date its name does not name.
      expect(parseDatabaseBackupStamp('20260231T000000Z'), isNull);
      expect(parseDatabaseBackupStamp('20260921T256100Z'), isNull);
    });
  });

  group('nextPreservedDatabaseCopyPath', () {
    late Directory tempRoot;
    late String dbPath;
    final now = DateTime.utc(2026, 9, 21, 12, 58, 17);

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('db_backup_next_path_');
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [0]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('stamps the name with the preservation time', () {
      expect(
        nextPreservedDatabaseCopyPath(
          dbPath,
          suffix: keyLossWipeBackupSuffix,
          now: now,
        ),
        equals('$dbPath$keyLossWipeBackupSuffix.20260921T125817Z'),
      );
    });

    test('appends an index when the stamped name is already a file', () {
      final stamped = '$dbPath$keyLossWipeBackupSuffix.20260921T125817Z';
      File(stamped).writeAsBytesSync(const [1]);

      expect(
        nextPreservedDatabaseCopyPath(
          dbPath,
          suffix: keyLossWipeBackupSuffix,
          now: now,
        ),
        equals('$stamped.1'),
      );
    });

    test('does not reuse a name owned only by a rollback journal', () {
      final stamped = '$dbPath$keyLossWipeBackupSuffix.20260921T125817Z';
      File('$stamped-journal').writeAsBytesSync(const [9]);

      final next = nextPreservedDatabaseCopyPath(
        dbPath,
        suffix: keyLossWipeBackupSuffix,
        now: now,
      );

      expect(next, equals('$stamped.1'));
      expect(File('$stamped-journal').readAsBytesSync(), equals([9]));
    });

    test('keeps probing past an occupied index', () {
      final stamped = '$dbPath$keyLossWipeBackupSuffix.20260921T125817Z';
      File(stamped).writeAsBytesSync(const [1]);
      File('$stamped.1-wal').writeAsBytesSync(const [2]);

      expect(
        nextPreservedDatabaseCopyPath(
          dbPath,
          suffix: keyLossWipeBackupSuffix,
          now: now,
        ),
        equals('$stamped.2'),
      );
    });
  });

  group('sweepPreservedDatabaseCopies', () {
    late Directory tempRoot;
    late String dbPath;
    final now = DateTime.utc(2026, 9, 21, 12);

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('db_backup_sweep_');
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [0]);
      File('$dbPath-wal').writeAsBytesSync(const [0]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    String writeCopy(
      String suffix, {
      DateTime? stamp,
      int? index,
      List<String> sidecars = const [],
    }) {
      final name = StringBuffer('$dbPath$suffix');
      if (stamp != null) name.write('.${formatDatabaseBackupStamp(stamp)}');
      if (index != null) name.write('.$index');
      final path = name.toString();
      File(path).writeAsBytesSync(const [1]);
      for (final sidecar in sidecars) {
        File('$path$sidecar').writeAsBytesSync(const [2]);
      }
      return path;
    }

    test('keeps only the newest copy of a suffix, sidecars included', () {
      final older = writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now.subtract(const Duration(days: 3)),
        sidecars: const ['-wal', '-shm'],
      );
      final newest = writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now.subtract(const Duration(days: 1)),
        sidecars: const ['-wal'],
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(older).existsSync(), isFalse);
      expect(File('$older-wal').existsSync(), isFalse);
      expect(File('$older-shm').existsSync(), isFalse);
      expect(File(newest).existsSync(), isTrue);
      expect(File('$newest-wal').existsSync(), isTrue);
    });

    test('keeps a lone copy while it is inside the retention window', () {
      final copy = writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now
            .subtract(preservedDatabaseCopyRetention) //
            .add(const Duration(minutes: 1)),
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(copy).existsSync(), isTrue);
    });

    test('deletes a copy once the retention window has closed', () {
      final copy = writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now.subtract(preservedDatabaseCopyRetention),
        sidecars: const ['-journal'],
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(copy).existsSync(), isFalse);
      expect(File('$copy-journal').existsSync(), isFalse);
    });

    test('applies the window to each suffix independently', () {
      final expiredKeyLoss = writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now.subtract(const Duration(days: 40)),
      );
      final freshCorruption = writeCopy(
        corruptionRecoveryBackupSuffix,
        stamp: now.subtract(const Duration(days: 2)),
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(expiredKeyLoss).existsSync(), isFalse);
      expect(File(freshCorruption).existsSync(), isTrue);
    });

    test('never touches the live database or its sidecars', () {
      writeCopy(
        keyLossWipeBackupSuffix,
        stamp: now.subtract(const Duration(days: 40)),
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(dbPath).existsSync(), isTrue);
      expect(File('$dbPath-wal').existsSync(), isTrue);
    });

    test('leaves the plaintext migration backup to its own cleanup', () {
      final plaintext = writeCopy(
        preCipherMigrationBackupSuffix,
        stamp: now.subtract(const Duration(days: 400)),
      );

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(
        File(plaintext).existsSync(),
        isTrue,
        reason:
            'deleting it early would defeat "keep the plaintext original '
            'until a keyed open proves the encrypted database works"',
      );
    });

    test('ignores a neighbouring file that merely shares the prefix', () {
      final notes = '$dbPath${keyLossWipeBackupSuffix}_notes';
      File(notes).writeAsBytesSync(const [3]);

      sweepPreservedDatabaseCopies(dbPath, now: now);

      expect(File(notes).existsSync(), isTrue);
    });

    test('is a no-op when the database directory is gone', () {
      tempRoot.deleteSync(recursive: true);

      expect(
        () => sweepPreservedDatabaseCopies(dbPath, now: now),
        returnsNormally,
      );
    });

    group('copies written before stamping', () {
      test('drops a half-renamed group rather than letting it outrank the '
          'copy that still holds the database', () {
        // A crash between renaming the database and its sidecars leaves one
        // group with only sidecars. It sorts newest, so ranking it would
        // delete the group the database is actually in.
        final withDatabase = writeCopy(
          keyLossWipeBackupSuffix,
          stamp: now.subtract(const Duration(days: 1)),
        );
        final orphanSidecar =
            '$dbPath$keyLossWipeBackupSuffix.${formatDatabaseBackupStamp(now)}'
            '-wal';
        File(orphanSidecar).writeAsBytesSync(const [7]);

        sweepPreservedDatabaseCopies(dbPath, now: now);

        expect(File(withDatabase).existsSync(), isTrue);
        expect(File(orphanSidecar).existsSync(), isFalse);
      });

      test('adopts a surviving legacy copy rather than deleting it', () {
        final legacy = writeCopy(
          keyLossWipeBackupSuffix,
          sidecars: const ['-wal'],
        );

        sweepPreservedDatabaseCopies(dbPath, now: now);

        expect(
          File(legacy).existsSync(),
          isFalse,
          reason: 'the copy is renamed, not left under its unstamped name',
        );
        final adopted =
            '$dbPath$keyLossWipeBackupSuffix.${formatDatabaseBackupStamp(now)}';
        expect(File(adopted).existsSync(), isTrue);
        expect(File('$adopted-wal').existsSync(), isTrue);
      });

      test('gives an adopted copy a full window from the adopting sweep', () {
        writeCopy(keyLossWipeBackupSuffix);

        sweepPreservedDatabaseCopies(dbPath, now: now);
        final stillThere = findPreservedDatabaseCopies(
          dbPath,
          suffix: keyLossWipeBackupSuffix,
        );
        sweepPreservedDatabaseCopies(
          dbPath,
          now: now.add(preservedDatabaseCopyRetention),
        );

        expect(stillThere, hasLength(1));
        expect(
          findPreservedDatabaseCopies(
            dbPath,
            suffix: keyLossWipeBackupSuffix,
          ),
          isEmpty,
        );
      });

      test('ranks a legacy copy older than any stamped one', () {
        final legacy = writeCopy(keyLossWipeBackupSuffix);
        final stamped = writeCopy(
          keyLossWipeBackupSuffix,
          stamp: now.subtract(const Duration(days: 10)),
        );

        sweepPreservedDatabaseCopies(dbPath, now: now);

        expect(File(legacy).existsSync(), isFalse);
        expect(File(stamped).existsSync(), isTrue);
      });

      test('ranks a legacy index after the bare legacy name', () {
        final bare = writeCopy(keyLossWipeBackupSuffix);
        final indexed = writeCopy(keyLossWipeBackupSuffix, index: 2);

        sweepPreservedDatabaseCopies(dbPath, now: now);

        expect(File(bare).existsSync(), isFalse);
        expect(File(indexed).existsSync(), isFalse);
        final survivors = findPreservedDatabaseCopies(
          dbPath,
          suffix: keyLossWipeBackupSuffix,
        );
        expect(
          survivors,
          hasLength(1),
          reason:
              'the higher index was written later, so it is the survivor '
              'and it stays visible to later sweeps',
        );
        expect(survivors.single.stamp, equals(now));
      });
    });
  });

  group('deletePreservedDatabaseCopies', () {
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('db_backup_delete_all_');
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [0]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('removes every copy of the suffix regardless of age or name', () {
      final bare = '$dbPath$preCipherMigrationBackupSuffix';
      final indexed = '$bare.1';
      final stamped = '$bare.20260921T125817Z';
      for (final path in [bare, indexed, stamped]) {
        File(path).writeAsBytesSync(const [1]);
        File('$path-wal').writeAsBytesSync(const [2]);
      }
      final other = '$dbPath$keyLossWipeBackupSuffix.20260921T125817Z';
      File(other).writeAsBytesSync(const [3]);

      deletePreservedDatabaseCopies(
        dbPath,
        suffix: preCipherMigrationBackupSuffix,
      );

      for (final path in [bare, indexed, stamped]) {
        expect(File(path).existsSync(), isFalse);
        expect(File('$path-wal').existsSync(), isFalse);
      }
      expect(File(dbPath).existsSync(), isTrue);
      expect(File(other).existsSync(), isTrue);
    });
  });

  group('preservedDatabaseCopySuffixes', () {
    test('names every suffix exactly once', () {
      expect(
        preservedDatabaseCopySuffixes.toSet(),
        hasLength(preservedDatabaseCopySuffixes.length),
      );
    });

    test('excludes the plaintext migration backup', () {
      expect(
        preservedDatabaseCopySuffixes,
        isNot(contains(preCipherMigrationBackupSuffix)),
      );
    });
  });
}
