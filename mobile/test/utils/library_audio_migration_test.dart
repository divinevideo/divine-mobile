// ABOUTME: Pins the move of imported audio out of draft-owned storage
// ABOUTME: Regression coverage for #8024, including its no-op cases

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:openvine/utils/library_audio_migration.dart';
import 'package:path/path.dart' as p;

void main() {
  group('migrateDraftOwnedAudioImports', () {
    late Directory documents;

    setUp(() {
      documents = Directory.systemTemp.createTempSync('library_audio_');
    });

    tearDown(() {
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });

    Directory oldRoot() =>
        Directory(p.join(documents.path, draftAudioImportsDirName));
    Directory newRoot() =>
        Directory(p.join(documents.path, libraryAudioImportsDirName));

    File seedDraftImport(String draftId, String fileName, List<int> bytes) {
      final dir = Directory(p.join(oldRoot().path, draftId))
        ..createSync(recursive: true);
      return File(p.join(dir.path, fileName))..writeAsBytesSync(bytes);
    }

    test('moves a draft-owned import into library storage', () async {
      seedDraftImport('draft_1', '1700000000000_song.m4a', const [1, 2, 3]);

      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      final moved = File(
        p.join(newRoot().path, 'draft_1', '1700000000000_song.m4a'),
      );
      expect(moved.existsSync(), isTrue);
      expect(moved.readAsBytesSync(), equals([1, 2, 3]));
      expect(oldRoot().existsSync(), isFalse);
    });

    test(
      'keeps the basename, which is what audio reclaim matches on',
      () async {
        seedDraftImport('draft_1', '1700000000000_song.m4a', const [1]);

        await migrateDraftOwnedAudioImports(documentsDirectory: documents);

        final names = newRoot()
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => p.basename(file.path));
        expect(names, equals(['1700000000000_song.m4a']));
      },
    );

    test('moves every draft tree, not just the first', () async {
      seedDraftImport('draft_1', 'a.m4a', const [1]);
      seedDraftImport('draft_2', 'b.m4a', const [2]);

      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      expect(
        File(p.join(newRoot().path, 'draft_1', 'a.m4a')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(newRoot().path, 'draft_2', 'b.m4a')).existsSync(),
        isTrue,
      );
    });

    test('merges into a library root a newer import already created', () async {
      seedDraftImport('draft_1', 'a.m4a', const [1]);
      final root = newRoot()..createSync(recursive: true);
      File(p.join(root.path, '1700000000001_new.m4a')).writeAsBytesSync(
        const [9],
      );

      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      expect(
        File(p.join(root.path, 'draft_1', 'a.m4a')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(root.path, '1700000000001_new.m4a')).existsSync(),
        isTrue,
        reason: 'a file already in library storage must survive the move',
      );
    });

    test('merges into a draft directory the destination already has', () async {
      seedDraftImport('draft_1', 'a.m4a', const [1]);
      seedDraftImport('draft_1', 'b.m4a', const [2]);
      Directory(p.join(newRoot().path, 'draft_1')).createSync(recursive: true);
      File(
        p.join(newRoot().path, 'draft_1', 'c.m4a'),
      ).writeAsBytesSync(const [3]);

      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      // A directory whose name is taken must be merged, not skipped: a
      // persisted path resolves to library storage either way, so a source
      // left behind would be a path pointing at somebody else's file.
      final merged =
          Directory(p.join(newRoot().path, 'draft_1'))
              .listSync()
              .whereType<File>()
              .map((file) => p.basename(file.path))
              .toList()
            ..sort();
      expect(merged, equals(['a.m4a', 'b.m4a', 'c.m4a']));
      expect(oldRoot().existsSync(), isFalse);
    });

    test(
      'leaves a file alone rather than overwrite a same-named one',
      () async {
        seedDraftImport('draft_1', 'a.m4a', const [1]);
        Directory(p.join(newRoot().path, 'draft_1'))
            .createSync(recursive: true);
        File(
          p.join(newRoot().path, 'draft_1', 'a.m4a'),
        ).writeAsBytesSync(const [7]);

        await migrateDraftOwnedAudioImports(documentsDirectory: documents);

        expect(
          File(p.join(newRoot().path, 'draft_1', 'a.m4a')).readAsBytesSync(),
          equals([7]),
          reason: 'the migration must never overwrite what is already there',
        );
        expect(
          File(p.join(oldRoot().path, 'draft_1', 'a.m4a')).readAsBytesSync(),
          equals([1]),
          reason:
              'and it must not delete what it could not move — the old root '
              'stays a known audio root, so the file is still reclaimable',
        );
      },
    );

    test('is a no-op when nothing was ever imported', () async {
      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      expect(oldRoot().existsSync(), isFalse);
      expect(newRoot().existsSync(), isFalse);
    });

    test('running twice changes nothing the second time', () async {
      seedDraftImport('draft_1', 'a.m4a', const [1]);

      await migrateDraftOwnedAudioImports(documentsDirectory: documents);
      await migrateDraftOwnedAudioImports(documentsDirectory: documents);

      expect(
        File(p.join(newRoot().path, 'draft_1', 'a.m4a')).readAsBytesSync(),
        equals([1]),
      );
      expect(oldRoot().existsSync(), isFalse);
    });
  });
}
