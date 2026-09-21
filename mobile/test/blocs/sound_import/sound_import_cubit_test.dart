// ABOUTME: Unit tests for the private sound import cubit's lifecycle.
// ABOUTME: Covers copy, retry, cleanup, account guard, and close behaviour.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/sound_import/sound_import_cubit.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';

void main() {
  group(SoundImportCubit, () {
    late Directory root;
    late Directory storageDir;
    late File source;
    late List<String> reclaimed;
    late int saveCalls;
    late String? lastSavedLabel;
    late String? accountId;
    late Future<Duration?> Function(File file) durationFn;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('sound_import_cubit_test_');
      storageDir = Directory('${root.path}/storage')..createSync();
      source = File('${root.path}/pick.mp3')..writeAsBytesSync([1, 2, 3]);
      reclaimed = <String>[];
      saveCalls = 0;
      lastSavedLabel = null;
      accountId = 'account-a';
      durationFn = (_) async => const Duration(seconds: 3);
    });

    tearDown(() async {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    SoundImportCubit build({
      AudioImportFilePicker? pickFile,
      SavedSoundSaver? saveSound,
      AudioImportReclaimer? reclaim,
      ViewerAccountIdReader? viewerAccountId,
    }) {
      return SoundImportCubit(
        importService: LocalAudioImportService(
          storageRootProvider: () async => storageDir,
          durationResolver: durationFn,
          clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
        pickFile:
            pickFile ??
            () async =>
                AudioImportPickedFile(path: source.path, name: 'pick.mp3'),
        saveSound:
            saveSound ??
            (audio, {String? personalLabel}) async {
              saveCalls++;
              lastSavedLabel = personalLabel;
              return SavedSoundSaveResult.saved;
            },
        reclaimAudio:
            reclaim ??
            (path) async {
              reclaimed.add(path);
            },
        viewerAccountId: viewerAccountId ?? () => accountId,
      );
    }

    group('pickFileAndImport', () {
      test('copies the picked file and becomes ready to save', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, SoundImportStatus.ready);
        expect(cubit.state.audio, isNotNull);
        expect(
          await File(cubit.state.audio!.localFilePath!).readAsBytes(),
          equals([1, 2, 3]),
        );
        expect(reclaimed, isEmpty);
      });

      test('a cancelled pick returns to idle without reclaiming', () async {
        final cubit = build(pickFile: () async => null);
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, SoundImportStatus.idle);
        expect(reclaimed, isEmpty);
      });

      test('an unsupported extension reports an unsupported format', () async {
        final cubit = build(
          pickFile: () async =>
              AudioImportPickedFile(path: source.path, name: 'notes.txt'),
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(cubit.state.status, SoundImportStatus.failure);
        expect(
          cubit.state.failureReason,
          SoundImportFailureReason.unsupportedFormat,
        );
      });

      test(
        'a decoder failure reports undecodable and leaves no copy',
        () async {
          durationFn = (_) async => throw const FormatException('bad audio');
          final cubit = build();
          addTearDown(cubit.close);

          await cubit.pickFileAndImport();

          expect(
            cubit.state.failureReason,
            SoundImportFailureReason.undecodable,
          );
          expect(storageDir.listSync(recursive: true), isEmpty);
          expect(reclaimed, isEmpty);
        },
      );

      test('an account change abandons and reclaims the copy', () async {
        durationFn = (_) async {
          accountId = 'account-b';
          return const Duration(seconds: 3);
        };
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();

        expect(
          cubit.state.failureReason,
          SoundImportFailureReason.accountChanged,
        );
        expect(reclaimed, hasLength(1));
        expect(cubit.state.audio, isNull);
      });
    });

    group('save', () {
      test('persists with a trimmed private name', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save(personalLabel: '  My loop  ');

        expect(cubit.state.status, SoundImportStatus.saved);
        expect(cubit.state.savedResult, SavedSoundSaveResult.saved);
        expect(lastSavedLabel, 'My loop');
        expect(reclaimed, isEmpty);
      });

      test('a blank name is passed through as no label', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save(personalLabel: '   ');

        expect(lastSavedLabel, isNull);
      });

      test('a failed save keeps the copy and can be retried', () async {
        var attempts = 0;
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) async {
            attempts++;
            if (attempts == 1) throw StateError('disk full');
            return SavedSoundSaveResult.saved;
          },
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save();

        expect(cubit.state.failureReason, SoundImportFailureReason.saveFailed);
        // The copy must survive so Retry writes the same file, not a new pick.
        expect(cubit.state.audio, isNotNull);
        expect(reclaimed, isEmpty);

        await cubit.save();

        expect(cubit.state.status, SoundImportStatus.saved);
        expect(reclaimed, isEmpty);
      });

      test('an account change before save abandons the copy', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        accountId = 'account-b';
        await cubit.save();

        expect(
          cubit.state.failureReason,
          SoundImportFailureReason.accountChanged,
        );
        expect(reclaimed, hasLength(1));
      });

      test('a second save while one is in flight is ignored', () async {
        final completer = Completer<SavedSoundSaveResult>();
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) {
            saveCalls++;
            return completer.future;
          },
        );
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        final first = cubit.save();
        final second = cubit.save();

        expect(saveCalls, 1);

        completer.complete(SavedSoundSaveResult.saved);
        await first;
        await second;
        expect(cubit.state.status, SoundImportStatus.saved);
      });

      test('saving before a file is copied is a no-op', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.save();

        expect(saveCalls, 0);
        expect(cubit.state.status, SoundImportStatus.idle);
      });
    });

    group('discardUnsavedImport', () {
      test('reclaims the copy and returns to idle', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.discardUnsavedImport();

        expect(cubit.state.status, SoundImportStatus.idle);
        expect(cubit.state.audio, isNull);
        expect(reclaimed, hasLength(1));
      });

      test('does not reclaim a sound that was already saved', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.pickFileAndImport();
        await cubit.save();
        await cubit.discardUnsavedImport();

        expect(reclaimed, isEmpty);
      });
    });

    group('close', () {
      test('reclaims an unsaved copy', () async {
        final cubit = build();
        await cubit.pickFileAndImport();

        await cubit.close();

        expect(reclaimed, hasLength(1));
      });

      test('does not reclaim a saved sound', () async {
        final cubit = build();
        await cubit.pickFileAndImport();
        await cubit.save();

        await cubit.close();

        expect(reclaimed, isEmpty);
      });

      test('reclaims the copy when the in-flight save then fails', () async {
        final completer = Completer<SavedSoundSaveResult>();
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) => completer.future,
        );

        await cubit.pickFileAndImport();
        final copiedPath = cubit.state.audio!.localFilePath;
        final save = cubit.save();
        // close() hands ownership of the copy to the in-flight save.
        await cubit.close();

        completer.completeError(StateError('disk full'));
        await save;

        // The save never took ownership, so nothing else will ever reclaim it.
        expect(reclaimed, equals([copiedPath]));
      });

      test('does not reclaim a copy whose save is still in flight', () async {
        final completer = Completer<SavedSoundSaveResult>();
        final cubit = build(
          saveSound: (audio, {String? personalLabel}) => completer.future,
        );

        await cubit.pickFileAndImport();
        final save = cubit.save();
        await cubit.close();

        completer.complete(SavedSoundSaveResult.saved);
        await save;

        expect(reclaimed, isEmpty);
      });
    });
  });
}
