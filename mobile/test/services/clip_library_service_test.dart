// ABOUTME: Tests for ClipLibraryService - persistent storage for video clips
// ABOUTME: Covers save, load, delete, and thumbnail generation for clips

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group('ClipLibraryService', () {
    late AppDatabase database;
    late ClipLibraryService service;

    setUp(() async {
      database = AppDatabase.test(NativeDatabase.memory());
      service = ClipLibraryService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        clipCategoriesDao: database.clipCategoriesDao,
      );
    });

    tearDown(() async {
      await database.close();
    });

    group('saveClip', () {
      test('saves a clip and retrieves it', () async {
        final clip = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          thumbnailPath: '/tmp/test_thumb.jpg',
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        expect(clips.first.id, 'clip_123');
        // Path uses platform separator, so check filename
        expect(
          await clips.first.requireVideo.safeFilePath(),
          endsWith('test_video.mp4'),
        );
      });

      test(
        'saves a frames-only stop-motion clip and reloads its frames',
        () async {
          final clip = DivineVideoClip(
            id: 'sm_clip',
            stopMotionFrames: const [
              StopMotionClipFrame(
                path: '/tmp/frame0.jpg',
                duration: Duration(milliseconds: 167),
              ),
              StopMotionClipFrame(
                path: '/tmp/frame1.jpg',
                duration: Duration(milliseconds: 167),
              ),
            ],
            thumbnailPath: '/tmp/frame0.jpg',
            duration: const Duration(milliseconds: 334),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          await service.saveClip(clip);
          final clips = await service.getAllClips();

          expect(clips, hasLength(1));
          expect(clips.first.id, 'sm_clip');
          expect(clips.first.isStopMotion, isTrue);
          expect(clips.first.stopMotionFrames, hasLength(2));
          expect(clips.first.video, isNull);
        },
      );

      DivineVideoClip stopMotionClip() => DivineVideoClip(
        id: 'sm_clip',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/tmp/frame0.jpg',
            duration: Duration(milliseconds: 167),
          ),
        ],
        thumbnailPath: '/tmp/frame0.jpg',
        duration: const Duration(milliseconds: 167),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test(
        'stays in the library exactly once through the editor autosave flow',
        () async {
          final draftService = DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );
          final clip = stopMotionClip();

          // 1. Recorder saves the clip to the library.
          await service.saveClip(clip);
          expect(await service.getAllClips(), hasLength(1));

          // 2. Editor autosave persists the clip into the autosave draft
          // (exactly what happens after navigating from the recorder).
          await draftService.saveDraft(
            DivineVideoDraft.create(
              id: VideoEditorConstants.autoSaveId,
              clips: [clip],
              title: '',
              description: '',
              hashtags: const {},
              selectedApproach: '',
            ),
          );

          // 3. It must still be visible in the library.
          final clips = await service.getAllClips();
          expect(clips.map((c) => c.id), equals(['sm_clip']));
        },
      );

      test('updates existing clip with same ID', () async {
        final clip1 = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        final clip2 = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          thumbnailPath: '/tmp/updated_thumb.jpg',
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip1);
        await service.saveClip(clip2);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        // Path uses platform separator, so check filename
        expect(clips.first.thumbnailPath, endsWith('updated_thumb.jpg'));
      });
    });

    group('placeholder clips', () {
      DivineVideoClip placeholder({String id = 'placeholder_1'}) =>
          DivineVideoClip(
            id: id,
            video: EditorVideo.file('/tmp/$id.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
            isPlaceholder: true,
          );

      test('are not listed in the library', () async {
        final real = DivineVideoClip(
          id: 'clip_real',
          video: EditorVideo.file('/tmp/clip_real.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 1,
        );
        await service.saveClip(real);
        await service.saveClip(placeholder());

        final clips = await service.getAllClips();

        // The colour or still holding a detached clip's slot travels with the
        // composition, so the autosave draft stores it — but it is a backdrop
        // the editor generated, not footage, and has no meaning on its own.
        expect(clips.map((c) => c.id), ['clip_real']);
      });

      test('are not listed in the trash either', () async {
        await service.saveClip(placeholder());
        await service.softDelete('placeholder_1');

        expect(await service.getTrashedClips(), isEmpty);
      });
    });

    group('softDelete', () {
      test('hides clip from active queries but keeps row', () async {
        final clip = DivineVideoClip(
          id: 'clip_to_trash',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        final trashed = await service.softDelete('clip_to_trash');
        expect(trashed, isTrue);
        expect(await service.getAllClips(), isEmpty);
        expect(
          (await service.getTrashedClips()).map((c) => c.id),
          contains('clip_to_trash'),
        );
      });

      test('returns false when clip ID not found', () async {
        final result = await service.softDelete('nonexistent_clip');
        expect(result, isFalse);
      });

      test(
        'also trashes the autosave-draft copy so the set does not reappear',
        () async {
          final draftService = DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );
          final clip = DivineVideoClip(
            id: 'sm_set',
            stopMotionFrames: const [
              StopMotionClipFrame(
                path: '/tmp/f0.jpg',
                duration: Duration(milliseconds: 167),
              ),
            ],
            thumbnailPath: '/tmp/f0.jpg',
            duration: const Duration(milliseconds: 167),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          // The two rows a set that went through the editor ends up with:
          // a library row (recorder) and an autosave-draft row (editor).
          await service.saveClip(clip);
          await draftService.saveDraft(
            DivineVideoDraft.create(
              id: VideoEditorConstants.autoSaveId,
              clips: [clip],
              title: '',
              description: '',
              hashtags: const {},
              selectedApproach: '',
            ),
          );
          expect((await service.getAllClips()).length, 1);

          final trashed = await service.softDelete('sm_set');
          expect(trashed, isTrue);
          // Gone for good: the autosave-draft copy is trashed too, so the
          // library reload can't resurrect it.
          expect(await service.getAllClips(), isEmpty);

          // Undo restores both rows.
          await service.restore('sm_set');
          expect(
            (await service.getAllClips()).map((c) => c.id),
            equals(['sm_set']),
          );
        },
      );

      test(
        'trashing a dual-row set with clearDraftId shows once in trash',
        () async {
          final draftService = DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );
          final clip = DivineVideoClip(
            id: 'sm_dup',
            stopMotionFrames: const [
              StopMotionClipFrame(
                path: '/tmp/f0.jpg',
                duration: Duration(milliseconds: 167),
              ),
            ],
            thumbnailPath: '/tmp/f0.jpg',
            duration: const Duration(milliseconds: 167),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          // Library row (recorder) + autosave-draft row (editor).
          await service.saveClip(clip);
          await draftService.saveDraft(
            DivineVideoDraft.create(
              id: VideoEditorConstants.autoSaveId,
              clips: [clip],
              title: '',
              description: '',
              hashtags: const {},
              selectedApproach: '',
            ),
          );

          // The recorder path nulls draft_id on both rows, so both match the
          // trashed (draftId IS NULL) query — the set must still surface once.
          await service.softDelete('sm_dup', clearDraftId: true);

          final trashed = await service.getTrashedClips();
          expect(trashed.map((c) => c.id), ['sm_dup']);
        },
      );

      test(
        'getTrashedClips skips a corrupt clip and returns valid ones',
        () async {
          final validClip = DivineVideoClip(
            id: 'valid_trashed',
            video: EditorVideo.file('/tmp/valid.mp4'),
            duration: const Duration(seconds: 1),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 9 / 16,
          );
          await service.saveClip(validClip);

          // A trashed library row whose JSON has no filePath: fromJson throws,
          // so it must be skipped rather than wiping the whole trash view
          // (regression for #fix/drafts-clips-fail-to-load).
          final corruptData = validClip.toJson()
            ..['id'] = 'corrupt_trashed'
            ..['filePath'] = null;
          await database.clipsDao.upsertClip(
            id: 'corrupt_trashed',
            orderIndex: 0,
            durationMs: 1000,
            recordedAt: DateTime.now(),
            data: jsonEncode(corruptData),
            filePath: null,
            thumbnailPath: null,
          );

          await service.softDelete('valid_trashed');
          await service.softDelete('corrupt_trashed');

          final trashed = await service.getTrashedClips();
          expect(trashed.map((c) => c.id), ['valid_trashed']);
        },
      );
    });

    group('restore', () {
      test('moves clip back from trash to active', () async {
        final clip = DivineVideoClip(
          id: 'roundtrip_clip',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('roundtrip_clip');
        expect(await service.getAllClips(), isEmpty);

        final restored = await service.restore('roundtrip_clip');
        expect(restored, isTrue);
        expect(
          (await service.getAllClips()).map((c) => c.id),
          contains('roundtrip_clip'),
        );
        expect(await service.getTrashedClips(), isEmpty);
      });
    });

    group('hardDelete', () {
      test('removes clip permanently', () async {
        final clip = DivineVideoClip(
          id: 'clip_to_delete',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        await service.hardDelete('clip_to_delete');
        expect((await service.getAllClips()).length, 0);
        expect((await service.getTrashedClips()).length, 0);
      });

      test('does nothing when clip ID not found', () async {
        final clip = DivineVideoClip(
          id: 'existing_clip',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.hardDelete('nonexistent_clip');

        expect((await service.getAllClips()).length, 1);
      });
    });

    group('deleteClipRow', () {
      test('removes the library row for the given id', () async {
        final clip = DivineVideoClip(
          id: 'sm_session',
          stopMotionFrames: const [
            StopMotionClipFrame(
              path: '/tmp/frame0.jpg',
              duration: Duration(milliseconds: 83),
            ),
          ],
          duration: const Duration(milliseconds: 83),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        await service.deleteClipRow('sm_session');

        expect(await service.getAllClips(), isEmpty);
        expect(await service.getTrashedClips(), isEmpty);
      });
    });

    group('purgeExpiredTrash', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      test('hard-deletes trashed clips older than retention', () async {
        final clip = DivineVideoClip(
          id: 'old_trashed',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('old_trashed');

        // Backdate the deleted_at to 31 days ago so it's beyond a 30-day
        // retention window.
        await database.customStatement(
          'UPDATE clips SET deleted_at = ? WHERE id = ?',
          [
            DateTime.now()
                    .subtract(const Duration(days: 31))
                    .millisecondsSinceEpoch ~/
                1000,
            'old_trashed',
          ],
        );

        final purged = await service.purgeExpiredTrash();
        expect(purged, 1);
        expect(await service.getTrashedClips(), isEmpty);
      });

      test('keeps trashed clips within retention window', () async {
        final clip = DivineVideoClip(
          id: 'recent_trashed',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('recent_trashed');

        final purged = await service.purgeExpiredTrash();
        expect(purged, 0);
        expect((await service.getTrashedClips()).length, 1);
      });

      test(
        'purges current owner and legacy trash without deleting other owners',
        () async {
          final serviceA = ClipLibraryService(
            clipsDao: database.clipsDao,
            draftsDao: database.draftsDao,
            clipCategoriesDao: database.clipCategoriesDao,
            ownerPubkey: pubkeyA,
          );
          final serviceB = ClipLibraryService(
            clipsDao: database.clipsDao,
            draftsDao: database.draftsDao,
            clipCategoriesDao: database.clipCategoriesDao,
            ownerPubkey: pubkeyB,
          );

          final clipA = DivineVideoClip(
            id: 'a_expired',
            video: EditorVideo.file('/tmp/a_expired.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 9 / 16,
          );
          final clipB = DivineVideoClip(
            id: 'b_expired',
            video: EditorVideo.file('/tmp/b_expired.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 9 / 16,
          );
          final legacyClip = DivineVideoClip(
            id: 'legacy_expired',
            video: EditorVideo.file('/tmp/legacy_expired.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 9 / 16,
          );

          await serviceA.saveClip(clipA);
          await serviceB.saveClip(clipB);
          await database.clipsDao.upsertClip(
            id: legacyClip.id,
            orderIndex: 0,
            durationMs: legacyClip.duration.inMilliseconds,
            recordedAt: legacyClip.recordedAt,
            data: jsonEncode(legacyClip.toJson()),
            filePath: 'legacy_expired.mp4',
            thumbnailPath: null,
          );

          await serviceA.softDelete(clipA.id);
          await serviceB.softDelete(clipB.id);
          await database.clipsDao.softDeleteClip(
            id: legacyClip.id,
            deletedAt: DateTime.now(),
          );

          await database.customStatement(
            'UPDATE clips SET deleted_at = ? WHERE id IN (?, ?, ?)',
            [
              DateTime.now()
                      .subtract(const Duration(days: 31))
                      .millisecondsSinceEpoch ~/
                  1000,
              clipA.id,
              clipB.id,
              legacyClip.id,
            ],
          );

          final purged = await serviceA.purgeExpiredTrash();

          expect(purged, 2);
          expect(await database.clipsDao.getClipById(clipA.id), isNull);
          expect(await database.clipsDao.getClipById(legacyClip.id), isNull);
          expect(await database.clipsDao.getClipById(clipB.id), isNotNull);
          expect((await serviceB.getTrashedClips()).map((c) => c.id), [
            clipB.id,
          ]);
        },
      );
    });

    group('getAllClips', () {
      test('returns empty list when no clips saved', () async {
        final clips = await service.getAllClips();
        expect(clips, isEmpty);
      });

      test('returns clips sorted by creation date (newest first)', () async {
        final oldClip = DivineVideoClip(
          id: 'old_clip',
          video: EditorVideo.file('/tmp/old.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now().subtract(const Duration(days: 1)),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        final newClip = DivineVideoClip(
          id: 'new_clip',
          video: EditorVideo.file('/tmp/new.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(oldClip);
        await service.saveClip(newClip);

        final clips = await service.getAllClips();
        expect(clips.first.id, 'new_clip');
        expect(clips.last.id, 'old_clip');
      });

      test('skips a corrupt clip and still returns valid ones', () async {
        final validClip = DivineVideoClip(
          id: 'valid_clip',
          video: EditorVideo.file('/tmp/valid.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );
        await service.saveClip(validClip);

        // Insert a corrupt row directly: its JSON has no filePath, so
        // DivineVideoClip.fromJson throws. It must be skipped, not wipe the
        // whole library load (regression for #fix/drafts-clips-fail-to-load).
        final corruptData = validClip.toJson()
          ..['id'] = 'corrupt_clip'
          ..['filePath'] = null;
        await database.clipsDao.upsertClip(
          id: 'corrupt_clip',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime.now(),
          data: jsonEncode(corruptData),
          filePath: null,
          thumbnailPath: null,
        );

        final clips = await service.getAllClips();
        expect(clips.map((c) => c.id), ['valid_clip']);
      });
    });

    group('getClipById', () {
      test('returns clip when found', () async {
        final clip = DivineVideoClip(
          id: 'find_me',
          video: EditorVideo.file('/tmp/test.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        final found = await service.getClipById('find_me');

        expect(found, isNotNull);
        expect(found!.id, 'find_me');
        expect(found.targetAspectRatio, models.AspectRatio.vertical);
      });

      test('returns null when clip not found', () async {
        final found = await service.getClipById('nonexistent');
        expect(found, isNull);
      });

      test('returns null for a corrupt clip row', () async {
        final validClip = DivineVideoClip(
          id: 'corrupt_clip',
          video: EditorVideo.file('/tmp/corrupt.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        // Drop the filePath so DivineVideoClip.fromJson throws. getClipById
        // must skip-and-log and return null instead of throwing out of the
        // lookup, matching the list loaders' behaviour.
        final corruptData = validClip.toJson()..['filePath'] = null;
        await database.clipsDao.upsertClip(
          id: 'corrupt_clip',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime.now(),
          data: jsonEncode(corruptData),
          filePath: null,
          thumbnailPath: null,
        );

        expect(await service.getClipById('corrupt_clip'), isNull);
      });
    });

    group('clearAllClips', () {
      test('removes all clips', () async {
        for (var i = 0; i < 5; i++) {
          await service.saveClip(
            DivineVideoClip(
              id: 'clip_$i',
              video: EditorVideo.file('/tmp/video_$i.mp4'),
              duration: const Duration(seconds: 1),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
        }

        expect((await service.getAllClips()).length, 5);

        await service.clearAllClips();
        expect((await service.getAllClips()).length, 0);
      });

      test('removes trashed clips too', () async {
        final clip = DivineVideoClip(
          id: 'trashed_clip',
          video: EditorVideo.file('/tmp/trashed_clip.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('trashed_clip');

        expect((await service.getTrashedClips()).length, 1);

        await service.clearAllClips();

        expect((await service.getAllClips()).length, 0);
        expect((await service.getTrashedClips()).length, 0);
      });
    });

    group('stop-motion autosave-row cleanup', () {
      // Stop-motion frame paths are persisted as basenames resolved against the
      // documents directory. Use a UNIQUE temp dir per test and mock the path
      // provider to point at it, so this group never touches the shared
      // `/tmp/documents` — otherwise its recursive cleanup races the
      // draft_storage suite's use of the same path when `flutter test` runs the
      // files concurrently.
      late Directory documentsDir;
      late PathProviderPlatform originalPathProvider;
      late DraftStorageService draftService;

      setUp(() {
        documentsDir = Directory.systemTemp.createTempSync('clip_library_sm');
        originalPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = MockPathProviderPlatform()
          ..setApplicationDocumentsPath(documentsDir.path);
        draftService = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );
      });

      tearDown(() {
        PathProviderPlatform.instance = originalPathProvider;
        if (documentsDir.existsSync()) {
          documentsDir.deleteSync(recursive: true);
        }
      });

      File writeFrame(String name) {
        final file = File(p.join(documentsDir.path, name));
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      DivineVideoClip stopMotionSet(
        List<File> frames, {
        String id = 'sm_set',
      }) => DivineVideoClip(
        id: id,
        stopMotionFrames: [
          for (final frame in frames)
            StopMotionClipFrame(
              path: frame.path,
              duration: const Duration(milliseconds: 167),
            ),
        ],
        thumbnailPath: frames.first.path,
        duration: Duration(milliseconds: frames.length * 167),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      // Recreate the two rows a set ends up with after going through the
      // editor: a library row (recorder) and a `<autoSaveId>:<clipId>` row
      // (editor autosave draft).
      Future<void> saveThroughEditor(DivineVideoClip clip) async {
        await service.saveClip(clip);
        await draftService.saveDraft(
          DivineVideoDraft.create(
            id: VideoEditorConstants.autoSaveId,
            clips: [clip],
            title: '',
            description: '',
            hashtags: const {},
            selectedApproach: 'stop_motion',
          ),
        );
      }

      test(
        'hardDelete removes the autosave-draft row and its frame files',
        () async {
          final frame0 = writeFrame('hard_f0.jpg');
          final frame1 = writeFrame('hard_f1.jpg');
          final clip = stopMotionSet([frame0, frame1], id: 'sm_hard');
          final autosaveRowId = '${VideoEditorConstants.autoSaveId}:${clip.id}';

          await saveThroughEditor(clip);
          expect((await service.getAllClips()).length, 1);
          expect(await database.clipsDao.getClipById(autosaveRowId), isNotNull);

          await service.hardDelete(clip.id);

          expect(await service.getAllClips(), isEmpty);
          expect(await database.clipsDao.getClipById(clip.id), isNull);
          expect(
            await database.clipsDao.getClipById(autosaveRowId),
            isNull,
            reason:
                'the mirrored autosave-draft row must not survive '
                'hardDelete',
          );
          expect(
            frame0.existsSync(),
            isFalse,
            reason:
                'with no row left referencing them, the frame files must '
                'be reaped',
          );
          expect(frame1.existsSync(), isFalse);
        },
      );

      test(
        'clearAllClips removes autosave-draft rows and their frame files',
        () async {
          final frame0 = writeFrame('clear_f0.jpg');
          final frame1 = writeFrame('clear_f1.jpg');
          final clip = stopMotionSet([frame0, frame1], id: 'sm_clear');
          final autosaveRowId = '${VideoEditorConstants.autoSaveId}:${clip.id}';

          await saveThroughEditor(clip);
          expect((await service.getAllClips()).length, 1);
          expect(await database.clipsDao.getClipById(autosaveRowId), isNotNull);

          await service.clearAllClips();

          expect(await service.getAllClips(), isEmpty);
          expect(
            await database.clipsDao.getClipById(autosaveRowId),
            isNull,
            reason: 'clearing the library must also drop autosave-backed rows',
          );
          expect(
            frame0.existsSync(),
            isFalse,
            reason: 'clearing the library must not leak the frame files',
          );
          expect(frame1.existsSync(), isFalse);
        },
      );
    });

    group('categories', () {
      DivineVideoClip libraryClip(String id) => DivineVideoClip(
        id: id,
        video: EditorVideo.file('/tmp/$id.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026, 3, 5),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test('createCategory appends after the existing ones', () async {
        final first = await service.createCategory('Travel');
        final second = await service.createCategory('Food');

        expect(first?.orderIndex, 0);
        expect(second?.orderIndex, 1);
        expect((await service.getCategories()).map((c) => c.name), [
          'Travel',
          'Food',
        ]);
      });

      test('createCategory trims the name', () async {
        final created = await service.createCategory('  Travel  ');

        expect(created?.name, 'Travel');
      });

      test('createCategory rejects a blank name', () async {
        expect(await service.createCategory('   '), isNull);
        expect(await service.getCategories(), isEmpty);
      });

      test('renameCategory rejects a blank name', () async {
        final created = await service.createCategory('Travel');

        final renamed = await service.renameCategory(
          id: created!.id,
          rawName: '  ',
        );

        expect(renamed, isFalse);
        expect((await service.getCategories()).single.name, 'Travel');
      });

      test('setClipCategory files a clip and getAllClips reports it', () async {
        final category = await service.createCategory('Travel');
        await service.saveClip(libraryClip('clip_1'));

        await service.setClipCategory(
          clipId: 'clip_1',
          categoryId: category!.id,
        );

        expect((await service.getAllClips()).single.categoryId, category.id);
      });

      test('deleteCategory keeps the clip and unfiles it', () async {
        final category = await service.createCategory('Travel');
        await service.saveClip(libraryClip('clip_1'));
        await service.setClipCategory(
          clipId: 'clip_1',
          categoryId: category!.id,
        );

        final deleted = await service.deleteCategory(category.id);

        expect(deleted, isTrue);
        final clips = await service.getAllClips();
        expect(clips.single.id, 'clip_1');
        expect(clips.single.categoryId, isNull);
      });

      test('setClipArchived marks and clears the clip', () async {
        await service.saveClip(libraryClip('clip_1'));

        await service.setClipArchived(clipId: 'clip_1', archived: true);
        expect((await service.getAllClips()).single.archivedAt, isNotNull);

        await service.setClipArchived(clipId: 'clip_1', archived: false);
        expect((await service.getAllClips()).single.archivedAt, isNull);
      });

      test(
        'saveClip does not unfile or unarchive an already organized clip',
        () async {
          final category = await service.createCategory('Travel');
          final clip = libraryClip('clip_1');
          await service.saveClip(clip);
          await service.setClipCategory(
            clipId: 'clip_1',
            categoryId: category!.id,
          );
          await service.setClipArchived(clipId: 'clip_1', archived: true);

          // Mirrors background asset recovery re-saving the clip.
          await service.saveClip(clip.copyWith(thumbnailPath: '/tmp/t.jpg'));

          final reloaded = (await service.getAllClips()).single;
          expect(reloaded.categoryId, category.id);
          expect(reloaded.archivedAt, isNotNull);
        },
      );

      test(
        'autosave-only organization survives autosave and library-row creation',
        () async {
          final category = await service.createCategory('Travel');
          final clip = libraryClip('clip_1');
          final draftService = DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );
          Future<void> saveAutosaveDraft() {
            return draftService.saveDraft(
              DivineVideoDraft.create(
                id: VideoEditorConstants.autoSaveId,
                clips: [clip],
                title: '',
                description: '',
                hashtags: const {},
                selectedApproach: 'single_clip',
              ),
            );
          }

          await saveAutosaveDraft();
          await service.setClipCategory(
            clipId: clip.id,
            categoryId: category!.id,
          );
          await service.setClipArchived(clipId: clip.id, archived: true);

          await saveAutosaveDraft();
          var reloaded = (await service.getAllClips()).single;
          expect(reloaded.categoryId, category.id);
          expect(reloaded.archivedAt, isNotNull);

          await service.saveClip(clip);
          reloaded = (await service.getAllClips()).single;
          expect(reloaded.categoryId, category.id);
          expect(reloaded.archivedAt, isNotNull);
        },
      );

      test('archiving keeps the clip out of the trash', () async {
        await service.saveClip(libraryClip('clip_1'));

        await service.setClipArchived(clipId: 'clip_1', archived: true);

        expect(await service.getTrashedClips(), isEmpty);
        expect(await service.getAllClips(), hasLength(1));
      });

      test(
        'filing an archived clip into a category keeps it archived',
        () async {
          final category = await service.createCategory('Travel');
          await service.saveClip(libraryClip('clip_1'));
          await service.setClipCategory(
            clipId: 'clip_1',
            categoryId: category!.id,
          );
          await service.setClipArchived(clipId: 'clip_1', archived: true);

          await service.setClipCategory(
            clipId: 'clip_1',
            categoryId: category.id,
          );

          final reloaded = (await service.getAllClips()).single;
          expect(reloaded.categoryId, category.id);
          expect(reloaded.archivedAt, isNotNull);
        },
      );

      test('moving an archived clip keeps it archived', () async {
        final travel = await service.createCategory('Travel');
        final work = await service.createCategory('Work');
        await service.saveClip(libraryClip('clip_1'));
        await service.setClipCategory(
          clipId: 'clip_1',
          categoryId: travel!.id,
        );
        await service.setClipArchived(clipId: 'clip_1', archived: true);

        await service.setClipCategory(
          clipId: 'clip_1',
          categoryId: work!.id,
        );

        final reloaded = (await service.getAllClips()).single;
        expect(reloaded.categoryId, work.id);
        expect(reloaded.archivedAt, isNotNull);
      });

      test('unfiling a clip leaves it archived', () async {
        final category = await service.createCategory('Travel');
        await service.saveClip(libraryClip('clip_1'));
        await service.setClipCategory(
          clipId: 'clip_1',
          categoryId: category!.id,
        );
        await service.setClipArchived(clipId: 'clip_1', archived: true);

        await service.setClipCategory(clipId: 'clip_1', categoryId: null);

        final reloaded = (await service.getAllClips()).single;
        expect(reloaded.categoryId, isNull);
        expect(reloaded.archivedAt, isNotNull);
      });
    });
  });

  group('DivineVideoClip', () {
    test('serializes to and from JSON correctly', () async {
      final original = DivineVideoClip(
        id: 'test_clip',
        video: EditorVideo.file('/path/to/video.mp4'),
        libraryTitle: 'Saved rooftop loop',
        thumbnailPath: '/path/to/thumb.jpg',
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = original.toJson();
      // toJson stores only filenames for iOS compatibility
      expect(json['filePath'], 'video.mp4');
      expect(json['thumbnailPath'], 'thumb.jpg');
      expect(json['libraryTitle'], 'Saved rooftop loop');

      // Roundtrip with same base path restores paths
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.id, original.id);
      expect(restored.libraryTitle, original.libraryTitle);
      // Path uses platform separator, check it ends with filename
      expect(await restored.requireVideo.safeFilePath(), endsWith('video.mp4'));
      expect(restored.thumbnailPath, endsWith('thumb.jpg'));
      expect(restored.duration, original.duration);
      expect(restored.recordedAt, original.recordedAt);
      expect(restored.targetAspectRatio, original.targetAspectRatio);
      expect(restored.originalAspectRatio, original.originalAspectRatio);
      expect(restored.lensMetadata, original.lensMetadata);
    });

    test('handles null thumbnailPath in JSON', () {
      final clip = DivineVideoClip(
        id: 'no_thumb',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.thumbnailPath, isNull);
    });

    test('handles missing libraryTitle in legacy JSON', () {
      final clip = DivineVideoClip(
        id: 'legacy_title',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson()..remove('libraryTitle');
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.libraryTitle, isNull);
    });

    test('durationInSeconds returns correct value', () {
      final clip = DivineVideoClip(
        id: 'test',
        video: EditorVideo.file('/test.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.durationInSeconds, 2.5);
    });
  });
}
