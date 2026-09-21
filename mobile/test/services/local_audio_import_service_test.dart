import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group(LocalAudioImportService, () {
    late Directory tempDir;
    late Directory sourceDir;
    late Directory storageDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_import_test_');
      sourceDir = Directory('${tempDir.path}/source')..createSync();
      storageDir = Directory('${tempDir.path}/storage')..createSync();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'copies picked audio into library storage and returns local AudioEvent',
      () async {
        final source = File('${sourceDir.path}/My Sound.MP3');
        await source.writeAsBytes([1, 2, 3, 4]);
        final service = LocalAudioImportService(
          storageRootProvider: () async => storageDir,
          durationResolver: (_) async => const Duration(milliseconds: 2500),
          clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );

        final event = await service.importAudioFile(
          sourcePath: source.path,
          displayName: 'My Sound.MP3',
        );

        expect(event.id, startsWith('local_import_1700000000000000_'));
        expect(event.title, equals('My Sound'));
        expect(event.mimeType, equals('audio/mpeg'));
        expect(event.duration, equals(2.5));
        expect(event.localFilePath, isNot(equals(source.path)));
        // No draft segment: an imported track can be saved to My Sounds and
        // outlive whichever draft was open when it was picked (#8024).
        expect(p.dirname(event.localFilePath!), equals(storageDir.path));
        expect(
          await File(event.localFilePath!).readAsBytes(),
          equals([1, 2, 3, 4]),
        );
      },
    );

    test('rejects unsupported audio extensions without copying', () async {
      final source = File('${sourceDir.path}/notes.txt');
      await source.writeAsString('not audio');
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: source.path,
          displayName: 'notes.txt',
        ),
        throwsA(isA<LocalAudioImportException>()),
      );

      expect(storageDir.listSync(recursive: true), isEmpty);
    });

    test('rejects missing source files', () async {
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: '${sourceDir.path}/missing.mp3',
          displayName: 'missing.mp3',
        ),
        throwsA(isA<LocalAudioImportException>()),
      );
    });

    test('deletes the copy when the audio cannot be decoded', () async {
      final source = File('${sourceDir.path}/broken.mp3');
      await source.writeAsBytes([1, 2, 3]);
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
        durationResolver: (_) async => throw const FormatException('bad audio'),
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: source.path,
          displayName: 'broken.mp3',
        ),
        throwsA(
          isA<LocalAudioImportException>().having(
            (error) => error.reason,
            'reason',
            LocalAudioImportFailureReason.decodeFailed,
          ),
        ),
      );

      // A failed import must not strand its copied file, and must never touch
      // the file the user picked.
      expect(storageDir.listSync(recursive: true), isEmpty);
      expect(source.existsSync(), isTrue);
    });

    test(
      'two imports in the same clock tick get distinct identities',
      () async {
        final first = File('${sourceDir.path}/first.mp3')
          ..writeAsBytesSync([1]);
        final second = File('${sourceDir.path}/second.mp3')
          ..writeAsBytesSync([2]);
        final service = LocalAudioImportService(
          storageRootProvider: () async => storageDir,
          durationResolver: (_) async => const Duration(seconds: 1),
          clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
        );

        final firstEvent = await service.importAudioFile(
          sourcePath: first.path,
          displayName: 'first.mp3',
        );
        final secondEvent = await service.importAudioFile(
          sourcePath: second.path,
          displayName: 'second.mp3',
        );

        expect(firstEvent.id, isNot(equals(secondEvent.id)));
        expect(
          firstEvent.localFilePath,
          isNot(equals(secondEvent.localFilePath)),
        );
      },
    );

    test('an unsupported extension reports its own failure reason', () async {
      final source = File('${sourceDir.path}/notes.txt');
      await source.writeAsString('not audio');
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: source.path,
          displayName: 'notes.txt',
        ),
        throwsA(
          isA<LocalAudioImportException>().having(
            (error) => error.reason,
            'reason',
            LocalAudioImportFailureReason.unsupportedType,
          ),
        ),
      );
    });
  });
}
