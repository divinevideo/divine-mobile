// ABOUTME: Tests that the importer's state survives a restart and finds an
// ABOUTME: already prepared copy of a source by its hash.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/import_state.dart';

void main() {
  group(ImportState, () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('import_state_test');
    });

    tearDown(() {
      sandbox.deleteSync(recursive: true);
    });

    test('reads back what it saved', () {
      final file = File('${sandbox.path}/state.json');
      ImportState(file, {
        'cc0:a.ogg': ImportRecord(
          status: ImportStatus.prepared,
          sourceSha256: 'source',
          outputSha256: 'output',
          outputBytes: 10,
          durationSeconds: 1.5,
          gainDb: -2,
          changes: ['loudness normalized'],
          uploadedTo: ['https://media.example'],
        ),
        'cc0:b.ogg': ImportRecord(
          status: ImportStatus.rejected,
          reason: 'silent',
        ),
      }).save();

      final restored = ImportState.load(file);

      expect(
        restored.records.map((id, record) => MapEntry(id, record.toJson())),
        equals({
          'cc0:a.ogg': {
            'status': 'prepared',
            'sourceSha256': 'source',
            'outputSha256': 'output',
            'outputBytes': 10,
            'durationSeconds': 1.5,
            'gainDb': -2.0,
            'changes': ['loudness normalized'],
            'uploadedTo': ['https://media.example'],
          },
          'cc0:b.ogg': {'status': 'rejected', 'reason': 'silent'},
        }),
      );
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('starts empty when nothing was saved yet', () {
      expect(
        ImportState.load(File('${sandbox.path}/missing.json')).records,
        isEmpty,
      );
    });

    test('finds the candidate prepared from the same source', () {
      final state = ImportState(File('${sandbox.path}/state.json'), {
        'cc0:copy.ogg': ImportRecord(
          status: ImportStatus.duplicate,
          sourceSha256: 'same',
        ),
        'cc0:original.ogg': ImportRecord(
          status: ImportStatus.prepared,
          sourceSha256: 'same',
        ),
      });

      expect(state.preparedFromSource('same'), equals('cc0:original.ogg'));
      expect(state.preparedFromSource('other'), isNull);
    });
  });
}
