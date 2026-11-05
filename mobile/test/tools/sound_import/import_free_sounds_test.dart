// ABOUTME: Exercises event generation through the import CLI without network or keys.
// ABOUTME: Guards pagination timestamps, deduplication and safe underflow failure.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/import_free_sounds.dart' as cli;
import '../../../tools/sound_import/import_state.dart';
import '../../../tools/sound_import/sound_candidate.dart';

void main() {
  group('events command', () {
    late Directory work;

    setUp(() {
      work = Directory.systemTemp.createTempSync('sound-import-test-');
    });
    tearDown(() {
      exitCode = 0;
      work.deleteSync(recursive: true);
    });

    void prepare(int count) {
      final catalog = <Map<String, dynamic>>[];
      final state = ImportState(File('${work.path}/state.json'), {});
      for (var i = 0; i < count; i++) {
        final candidate = SoundCandidate(
          id: 'sound-$i',
          downloadUrl: 'https://source.example/$i.wav',
          sourcePage: 'https://source.example/$i',
          title: 'Sound $i',
          kind: SoundKind.sfx,
          creatorName: 'Test creator',
          creatorUrl: 'https://source.example',
          license: SoundLicense.cc0,
        );
        catalog.add(candidate.toJson());
        state.records[candidate.id] = ImportRecord(
          status: ImportStatus.prepared,
          outputSha256: i.toRadixString(16).padLeft(64, '0'),
        );
      }
      // A second candidate with identical output must not consume a timestamp.
      catalog.insert(1, {...catalog.first, 'id': 'duplicate'});
      state.records['duplicate'] = ImportRecord(
        status: ImportStatus.prepared,
        outputSha256: '0' * 64,
      );
      File('${work.path}/catalog.json').writeAsStringSync(jsonEncode(catalog));
      state.save();
    }

    Future<void> events(int base) => cli.main([
      'events',
      '--work-dir',
      work.path,
      '--blossom',
      'https://media.example',
      '--created-at',
      '$base',
    ]);

    test(
      'all 1001 unique sounds remain reachable by until+limit paging',
      () async {
        prepare(1001);
        await events(2000);
        final file = File('${work.path}/events.jsonl');
        final first = file.readAsStringSync();
        final timestamps = file
            .readAsLinesSync()
            .map(
              (line) =>
                  (jsonDecode(line) as Map<String, dynamic>)['created_at']
                      as int,
            )
            .toList();
        expect(timestamps, hasLength(1001));
        expect(timestamps.first, 2000);
        expect(timestamps.last, 1000);
        var until = 2000;
        final reached = <int>[];
        while (true) {
          final page = timestamps
              .where((time) => time <= until)
              .take(100)
              .toList();
          if (page.isEmpty) break;
          reached.addAll(page);
          until = page.last - 1;
        }
        expect(reached, timestamps);
        expect(reached.toSet(), hasLength(1001));
        await events(2000);
        expect(file.readAsStringSync(), first);
      },
    );

    test(
      'rejects timestamp underflow without replacing reviewed events',
      () async {
        prepare(3);
        final file = File('${work.path}/events.jsonl')
          ..writeAsStringSync('reviewed');
        await events(1);
        expect(exitCode, 64);
        expect(file.readAsStringSync(), 'reviewed');
      },
    );

    test('allows the oldest unique output to have timestamp zero', () async {
      prepare(3);
      await events(2);
      expect(exitCode, 0);
      expect(
        File('${work.path}/events.jsonl').readAsLinesSync().map(
          (line) => (jsonDecode(line) as Map<String, dynamic>)['created_at'],
        ),
        [2, 1, 0],
      );
    });

    test(
      'publish rejects another account cache before any relay connection',
      () async {
        prepare(1);
        await events(10);
        final event = jsonDecode(
          File('${work.path}/events.jsonl').readAsLinesSync().single,
        ) as Map<String, dynamic>;
        event['pubkey'] = 'c' * 64;
        final signedFile = File('${work.path}/signed.json')
          ..writeAsStringSync(jsonEncode({'0' * 64: event}));
        final original = signedFile.readAsStringSync();
        await cli.main([
          'publish',
          '--work-dir',
          work.path,
          '--relay',
          'not-a-websocket-url',
          '--expect-pubkey',
          'b' * 64,
          '--dry-run',
        ]);
        expect(exitCode, 64);
        expect(signedFile.readAsStringSync(), original);
      },
    );
  });
}
