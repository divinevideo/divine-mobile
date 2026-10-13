import 'dart:io';

import 'package:db_client/src/database/connection/hot_journal_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('sweepStrandedHotJournalSnapshots', () {
    late Directory root;
    late Directory systemTemp;
    late String databasePath;

    setUp(() {
      root = Directory.systemTemp.createTempSync(
        'db_client_snapshot_sweep_test_',
      );
      systemTemp = Directory(p.join(root.path, 'tmp'))..createSync();
      databasePath = p.join(root.path, 'divine_db.db');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('deletes the snapshot beside the database and leaves a restore '
        'that did not finish', () {
      // The names are what builds leave beside the database, so they are
      // spelled out here rather than read from the code.
      final snapshot = Directory('$databasePath.hot_journal_snapshot')
        ..createSync();
      File(p.join(snapshot.path, 'database')).writeAsBytesSync(const [1]);
      final restore = Directory('$databasePath.hot_journal_restore')
        ..createSync();
      final owed = File(p.join(restore.path, 'database'))
        ..writeAsBytesSync(const [2]);

      IOOverrides.runZoned(
        () => sweepStrandedHotJournalSnapshots(databasePath),
        getSystemTempDirectory: () => systemTemp,
      );

      expect(snapshot.existsSync(), isFalse);
      expect(owed.existsSync(), isTrue);
    });

    test('deletes snapshot directories in the temp folder and nothing else '
        'there', () {
      // The literal is the directory name shipped builds already left on
      // devices, so it is spelled out here rather than read from the code.
      const prefix = 'divine_hot_journal_recovery_';
      for (final name in ['${prefix}first', '${prefix}second']) {
        final stranded = Directory(p.join(systemTemp.path, name))..createSync();
        File(p.join(stranded.path, 'database')).writeAsBytesSync(const [1]);
        File(p.join(stranded.path, 'journal')).writeAsBytesSync(const [2]);
      }
      Directory(p.join(systemTemp.path, 'other_directory')).createSync();
      File(p.join(systemTemp.path, 'other_file')).writeAsBytesSync(const [3]);
      File(p.join(systemTemp.path, '${prefix}file')).writeAsBytesSync(const [
        4,
      ]);

      IOOverrides.runZoned(
        () => sweepStrandedHotJournalSnapshots(databasePath),
        getSystemTempDirectory: () => systemTemp,
      );

      expect(
        systemTemp.listSync().map((entity) => p.basename(entity.path)),
        unorderedEquals(['other_directory', 'other_file', '${prefix}file']),
      );
    });

    test('deletes a snapshot an earlier build marked as an unfinished '
        'restore', () {
      // The names are what those builds wrote to devices, so they are spelled
      // out here rather than read from the code.
      final marked = Directory(
        p.join(systemTemp.path, 'divine_hot_journal_recovery_marked'),
      )..createSync();
      File(p.join(marked.path, 'database')).writeAsBytesSync(const [1]);
      File(p.join(marked.path, 'journal')).writeAsBytesSync(const [2]);
      File(
        p.join(marked.path, 'restoring'),
      ).writeAsStringSync('../database/divine_db.db');

      IOOverrides.runZoned(
        () => sweepStrandedHotJournalSnapshots(databasePath),
        getSystemTempDirectory: () => systemTemp,
      );

      expect(marked.existsSync(), isFalse);
    });

    test('returns normally when the temp directory cannot be listed', () {
      final notADirectory = File(p.join(systemTemp.path, 'not_a_directory'))
        ..writeAsBytesSync(const [0]);

      expect(
        () => IOOverrides.runZoned(
          () => sweepStrandedHotJournalSnapshots(databasePath),
          getSystemTempDirectory: () => Directory(notADirectory.path),
        ),
        returnsNormally,
      );
    });
  });
}
