// ABOUTME: Tests for FileCleanupService file-existence guard behavior.
// ABOUTME: Keeps cleanup from touching shared database state when no file exists.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftsDao extends Mock implements DraftsDao {}

class _MockClipsDao extends Mock implements ClipsDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  group('FileCleanupService', () {
    late _MockDraftsDao draftsDao;
    late _MockClipsDao clipsDao;

    setUp(() {
      draftsDao = _MockDraftsDao();
      clipsDao = _MockClipsDao();
    });

    test('does not query references when the file is already absent', () async {
      await FileCleanupService.deleteFileIfUnreferenced(
        '/tmp/divine-missing-clip-file.mp4',
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );

      verifyNever(() => clipsDao.isFileReferenced(any()));
      verifyNever(() => draftsDao.isDraftFileReferenced(any()));
    });

    test(
      'deletes chroma-key source and image files when unreferenced',
      () async {
        when(
          () => clipsDao.referencedFilenames(any()),
        ).thenAnswer((_) async => const {});
        when(
          () => draftsDao.isDraftFileReferenced(any()),
        ).thenAnswer((_) async => false);
        final tempDir = Directory.systemTemp.createTempSync(
          'divine_chroma_cleanup',
        );
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        File writeFile(String name) =>
            File(p.join(tempDir.path, name))
              ..writeAsBytesSync(const [0, 1, 2, 3]);

        final keyed = writeFile('keyed.mp4');
        final source = writeFile('pre_key.mp4');
        final background = writeFile('chroma_bg.png');
        final clip = DivineVideoClip(
          id: 'clip_keyed',
          video: EditorVideo.file(keyed.path),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 1,
          chromaKeySourcePath: source.path,
          chromaKey: ClipChromaKey(
            key: ChromaKey(
              backgroundImage: EditorLayerImage.file(background.path),
            ),
          ),
        );

        await FileCleanupService.deleteRecordingClipsFiles(
          [clip],
          draftsDao: draftsDao,
          clipsDao: clipsDao,
        );

        expect(keyed.existsSync(), isFalse);
        expect(source.existsSync(), isFalse);
        expect(background.existsSync(), isFalse);
        final checkedFilenames =
            verify(
                  () => clipsDao.referencedFilenames(captureAny()),
                ).captured.single
                as Set<String>;
        expect(
          checkedFilenames,
          containsAll(['keyed.mp4', 'pre_key.mp4', 'chroma_bg.png']),
        );
      },
    );

    group('deleteDraftAudioFiles', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('divine_audio_cleanup');
      });

      tearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      File writeAudio(String name) {
        final file = File(p.join(tempDir.path, name))
          ..writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      test('deletes a local audio file that nothing references', () async {
        when(
          () => clipsDao.isFileReferenced(any()),
        ).thenAnswer((_) async => false);
        when(
          () => draftsDao.isDraftFileReferenced(any()),
        ).thenAnswer((_) async => false);
        final audio = writeAudio('voice_over_1.m4a');

        await FileCleanupService.deleteDraftAudioFiles(
          [audio.path],
          draftsDao: draftsDao,
          clipsDao: clipsDao,
        );

        expect(audio.existsSync(), isFalse);
      });

      test(
        'keeps audio whose basename is referenced by another draft',
        () async {
          final audio = writeAudio('shared.m4a');

          await FileCleanupService.deleteDraftAudioFiles(
            [audio.path],
            draftsDao: draftsDao,
            clipsDao: clipsDao,
            referencedAudioFilenames: {'shared.m4a'},
          );

          expect(
            audio.existsSync(),
            isTrue,
            reason: 'a basename in referencedAudioFilenames must be kept',
          );
          // The cross-draft guard short-circuits before the indexed lookups.
          verifyNever(() => clipsDao.isFileReferenced(any()));
          verifyNever(() => draftsDao.isDraftFileReferenced(any()));
        },
      );

      test(
        'keeps audio still referenced by the indexed clip/draft backstop',
        () async {
          // No referencedAudioFilenames entry, so the cross-draft guard does not
          // short-circuit and the defensive indexed reference check runs.
          when(
            () => clipsDao.isFileReferenced(any()),
          ).thenAnswer((_) async => true);
          when(
            () => draftsDao.isDraftFileReferenced(any()),
          ).thenAnswer((_) async => false);
          final audio = writeAudio('indexed_ref.m4a');

          await FileCleanupService.deleteDraftAudioFiles(
            [audio.path],
            draftsDao: draftsDao,
            clipsDao: clipsDao,
          );

          expect(
            audio.existsSync(),
            isTrue,
            reason:
                'the indexed reference check must still keep referenced audio',
          );
        },
      );

      test('skips empty paths without querying references', () async {
        await FileCleanupService.deleteDraftAudioFiles(
          [''],
          draftsDao: draftsDao,
          clipsDao: clipsDao,
        );

        verifyNever(() => clipsDao.isFileReferenced(any()));
        verifyNever(() => draftsDao.isDraftFileReferenced(any()));
      });
    });

    // Regression for the multi-set stop-motion frame loss: a stop-motion clip
    // keeps its stills in the row's `data` JSON, not in an indexed file column
    // (only the first still is mirrored into thumbnail_path). Deleting the
    // autosave draft that also held the clip must NOT delete the stills the
    // surviving library row still references — otherwise a saved set silently
    // shrinks to its thumbnail and two sets merge to two frames.
    group('stop-motion frames referenced only in data', () {
      late AppDatabase database;
      late ClipLibraryService libraryService;
      late Directory tempDir;

      setUp(() {
        database = AppDatabase.test(NativeDatabase.memory());
        libraryService = ClipLibraryService(
          clipsDao: database.clipsDao,
          draftsDao: database.draftsDao,
          clipCategoriesDao: database.clipCategoriesDao,
        );
        tempDir = Directory.systemTemp.createTempSync('divine_sm_cleanup');
      });

      tearDown(() async {
        await database.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      DivineVideoClip writeStopMotionSet(String id, int frameCount) {
        final frames = [
          for (var i = 0; i < frameCount; i++)
            StopMotionClipFrame(
              path: (File(
                p.join(tempDir.path, '${id}_frame_$i.jpg'),
              )..writeAsBytesSync(const [1, 2, 3])).path,
              duration: const Duration(microseconds: 41667),
            ),
        ];
        return DivineVideoClip(
          id: id,
          stopMotionFrames: frames,
          duration: const Duration(milliseconds: 125),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          // The recorder uses the first still as the library thumbnail.
          thumbnailPath: frames.first.path,
        );
      }

      test(
        'keeps every still while the library row still references them',
        () async {
          final set = writeStopMotionSet('clip_sm_a', 3);
          await libraryService.saveClip(set);

          // Simulate the autosave-draft delete cleanup running on the same
          // clip while its library row (draftId == null) survives.
          await FileCleanupService.deleteRecordingClipFiles(
            set,
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );

          for (final frame in set.stopMotionFrames!) {
            expect(
              File(frame.path).existsSync(),
              isTrue,
              reason: 'still ${frame.path} is referenced by the library row',
            );
          }
        },
      );

      test(
        'deletes stills once no row references them',
        () async {
          final set = writeStopMotionSet('clip_sm_b', 3);
          // No row saved — nothing references the stills.
          await FileCleanupService.deleteRecordingClipFiles(
            set,
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );

          for (final frame in set.stopMotionFrames!) {
            expect(File(frame.path).existsSync(), isFalse);
          }
        },
      );
    });

    group('reverse caches', () {
      late AppDatabase database;
      late ClipLibraryService libraryService;
      late Directory tempDir;

      setUp(() {
        database = AppDatabase.test(NativeDatabase.memory());
        libraryService = ClipLibraryService(
          clipsDao: database.clipsDao,
          draftsDao: database.draftsDao,
          clipCategoriesDao: database.clipCategoriesDao,
        );
        tempDir = Directory.systemTemp.createTempSync('divine_rev_cleanup');
      });

      tearDown(() async {
        await database.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      File write(String name) =>
          File(p.join(tempDir.path, name))..writeAsBytesSync(const [1, 2, 3]);

      Future<void> saveDraftReferencing(File renderedFile) async {
        DivineVideoClip clip(String id, File file) => DivineVideoClip(
          id: id,
          video: EditorVideo.file(file.path),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );
        final storage = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );

        await storage.saveDraft(
          DivineVideoDraft.create(
            id: 'survivor',
            clips: [clip('timeline', write('timeline.mp4'))],
            title: '',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            finalRenderedClip: clip('rendered', renderedFile),
          ),
        );
      }

      test('deletes the reverse caches of a deleted clip', () async {
        // Reading [DivineVideoClip.ownedFilePaths] widened this delete to the
        // cached forward/reversed renders. They were previously enumerated
        // nowhere, so removing a reversed clip leaked both files.
        final video = write('clip_rev.mp4');
        final forward = write('clip_rev_forward.mp4');
        final reversed = write('clip_rev_reversed.mp4');
        final clip = DivineVideoClip(
          id: 'clip_rev',
          video: EditorVideo.file(video.path),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          forwardVideoPath: forward.path,
          reversedVideoPath: reversed.path,
        );

        await FileCleanupService.deleteRecordingClipFiles(
          clip,
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );

        expect(forward.existsSync(), isFalse);
        expect(reversed.existsSync(), isFalse);
        expect(video.existsSync(), isFalse);
      });

      test('keeps a reverse cache another clip still points at', () async {
        // The reference check reads the JSON blob, which carries
        // `forwardVideoPath` — a duplicated clip shares the cache and must
        // keep it.
        final shared = write('shared_forward.mp4');
        DivineVideoClip clipWithShare(String id, String videoName) =>
            DivineVideoClip(
              id: id,
              video: EditorVideo.file(write(videoName).path),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2024),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
              forwardVideoPath: shared.path,
            );

        await libraryService.saveClip(clipWithShare('keeper', 'keeper.mp4'));

        await FileCleanupService.deleteRecordingClipFiles(
          clipWithShare('goner', 'goner.mp4'),
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );

        expect(
          shared.existsSync(),
          isTrue,
          reason: 'the surviving library clip still points at this cache',
        );
      });

      test('batch cleanup keeps a file referenced by a draft', () async {
        final kept = write('kept.mp4');
        final goner = write('goner.mp4');
        await saveDraftReferencing(kept);
        expect(
          await database.draftsDao.isDraftFileReferenced('kept.mp4'),
          isTrue,
        );
        expect(kept.existsSync(), isTrue);
        expect(goner.existsSync(), isTrue);

        await FileCleanupService.deleteFilesIfUnreferenced(
          [kept.path, goner.path],
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );

        expect(
          kept.existsSync(),
          isTrue,
          reason: 'the surviving draft still points at this rendered file',
        );
        expect(goner.existsSync(), isFalse);
      });

      test('single-file cleanup keeps a file referenced by a draft', () async {
        final kept = write('kept.mp4');
        await saveDraftReferencing(kept);
        expect(
          await database.draftsDao.isDraftFileReferenced('kept.mp4'),
          isTrue,
        );
        expect(kept.existsSync(), isTrue);

        await FileCleanupService.deleteFileIfUnreferenced(
          kept.path,
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );

        expect(
          kept.existsSync(),
          isTrue,
          reason: 'the surviving draft still points at this rendered file',
        );
      });
    });
  });
}
