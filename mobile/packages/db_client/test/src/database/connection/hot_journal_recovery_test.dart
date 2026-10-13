import 'dart:io';

import 'package:db_client/src/database/connection/hot_journal_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('sweepStrandedHotJournalSnapshots', () {
    late Directory systemTemp;

    setUp(() {
      systemTemp = Directory.systemTemp.createTempSync(
        'db_client_snapshot_sweep_test_',
      );
    });

    tearDown(() {
      if (systemTemp.existsSync()) systemTemp.deleteSync(recursive: true);
    });

    test('deletes snapshot directories and nothing else', () {
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
        sweepStrandedHotJournalSnapshots,
        getSystemTempDirectory: () => systemTemp,
      );

      expect(
        systemTemp.listSync().map((entity) => p.basename(entity.path)),
        unorderedEquals(['other_directory', 'other_file', '${prefix}file']),
      );
    });

    test('returns normally when the temp directory cannot be listed', () {
      final notADirectory = File(p.join(systemTemp.path, 'not_a_directory'))
        ..writeAsBytesSync(const [0]);

      expect(
        () => IOOverrides.runZoned(
          sweepStrandedHotJournalSnapshots,
          getSystemTempDirectory: () => Directory(notADirectory.path),
        ),
        returnsNormally,
      );
    });
  });
}
