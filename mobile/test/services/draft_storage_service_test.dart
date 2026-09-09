// ABOUTME: TDD tests for DraftStorageService - persistent storage for vine drafts
// ABOUTME: Tests save, load, delete, clear, and migration operations using Drift

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio, AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group('DraftStorageService', () {
    const documentsPath = '/tmp/documents';
    late AppDatabase database;
    late DraftStorageService service;
    late PathProviderPlatform originalPathProviderInstance;

    void createDocumentFile(String basename) {
      final file = File(p.join(documentsPath, basename));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync([0]);
    }

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPlatform = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documentsPath);
      PathProviderPlatform.instance = mockPlatform;

      // Start with clean in-memory database for each test
      database = AppDatabase.test(NativeDatabase.memory());
      service = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );

      const documentBasenames = [
        'video.mp4',
        'video1.mp4',
        'video2.mp4',
        'clip_valid.mp4',
        'clip_corrupt.mp4',
        'a1.mp4',
        'a2.mp4',
        'b1.mp4',
        'old_video.mp4',
      ];
      documentBasenames.forEach(createDocumentFile);
    });

    tearDown(() async {
      final docsDir = Directory(documentsPath);
      if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      PathProviderPlatform.instance = originalPathProviderInstance;
      await database.close();
    });

    group('saveDraft', () {
      test('should save a draft to storage', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: 'A test description',
          hashtags: {'test', 'vine'},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft.id);
        expect(drafts.first.title, 'Test Vine');
        expect(drafts.first.description, 'A test description');
        expect(drafts.first.hashtags, ['test', 'vine']);
        expect(drafts.first.selectedApproach, 'hybrid');
      });

      test('should save multiple drafts', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First Vine',
          description: 'First',
          hashtags: {'first'},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second Vine',
          description: 'Second',
          hashtags: {'second'},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
        expect(drafts[0].title, 'First Vine');
        expect(drafts[1].title, 'Second Vine');
      });

      test('should update existing draft if ID matches', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Original Title',
          description: 'Original',
          hashtags: {'original'},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final updated = draft.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );

        await service.saveDraft(updated);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.title, 'Updated Title');
        expect(drafts.first.description, 'Updated description');
      });
    });

    group('getAllDrafts', () {
      test('should return empty list when no drafts exist', () async {
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should return all saved drafts', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
      });

      test('keeps each draft own lastModified when reading the list', () async {
        final savedAt = DateTime(2026, 5, 4, 3, 2, 1);
        final draft = DivineVideoDraft(
          id: 'draft_old',
          clips: [
            DivineVideoClip(
              id: 'clip_old',
              video: EditorVideo.file('/path/to/old_video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: savedAt,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Old draft',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: savedAt,
          lastModified: savedAt,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft);

        final drafts = await service.getAllDrafts();
        expect(drafts.single.lastModified, savedAt);
      });

      test('should return empty when database is empty', () async {
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should remove corrupted drafts with 0 clips', () async {
        // Insert a draft row directly via DAO (no clips)
        await database.draftsDao.upsertDraft(
          id: 'corrupted_draft',
          title: 'Corrupted',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{"title":"Corrupted","description":""}',
        );

        // Verify draft row exists
        final row = await database.draftsDao.getDraftById('corrupted_draft');
        expect(row, isNotNull);

        // getAllDrafts should skip it and delete it
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);

        // Draft row should be deleted from DB
        final rowAfter = await database.draftsDao.getDraftById(
          'corrupted_draft',
        );
        expect(rowAfter, isNull);
      });

      test(
        'skips a draft with a corrupt clip and keeps valid drafts',
        () async {
          final now = DateTime.now();
          DivineVideoDraft draftWith(String draftId, String clipId) =>
              DivineVideoDraft(
                id: draftId,
                clips: [
                  DivineVideoClip(
                    id: clipId,
                    video: EditorVideo.file('/path/to/$clipId.mp4'),
                    duration: const Duration(seconds: 6),
                    recordedAt: now,
                    targetAspectRatio: AspectRatio.square,
                    originalAspectRatio: 9 / 16,
                  ),
                ],
                title: draftId,
                description: '',
                hashtags: {},
                selectedApproach: 'hybrid',
                createdAt: now,
                lastModified: now,
                publishStatus: PublishStatus.draft,
                publishAttempts: 0,
              );

          await service.saveDraft(draftWith('draft_valid', 'clip_valid'));
          await service.saveDraft(draftWith('draft_corrupt', 'clip_corrupt'));

          // Corrupt the clip row of draft_corrupt: drop its filePath so
          // DivineVideoClip.fromJson throws when the draft is reconstructed.
          // That draft must be skipped while draft_valid still loads
          // (regression for #fix/drafts-clips-fail-to-load).
          final corruptData = draftWith(
            'draft_corrupt',
            'clip_corrupt',
          ).clips.first.toJson()..['filePath'] = null;
          await database.clipsDao.upsertClip(
            id: 'clip_corrupt',
            draftId: 'draft_corrupt',
            orderIndex: 0,
            durationMs: 6000,
            recordedAt: now,
            data: jsonEncode(corruptData),
            filePath: null,
            thumbnailPath: null,
          );

          final drafts = await service.getAllDrafts();
          expect(drafts.map((d) => d.id), ['draft_valid']);
        },
      );

      test('hides drafts whose clip source files are missing', () async {
        final now = DateTime(2025);
        createDocumentFile('present.mp4');
        final playableDraft = DivineVideoDraft(
          id: 'draft_playable',
          clips: [
            DivineVideoClip(
              id: 'clip_present',
              video: EditorVideo.file('/path/to/present.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Playable',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );
        final brokenDraft = DivineVideoDraft(
          id: 'draft_broken',
          clips: [
            DivineVideoClip(
              id: 'clip_missing',
              video: EditorVideo.file('/path/to/missing-split-output.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Broken',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(playableDraft);
        await service.saveDraft(brokenDraft);

        final drafts = await service.getAllDrafts();
        expect(drafts.map((draft) => draft.id), ['draft_playable']);

        // The row is left intact so a future recovery path or support tooling
        // can still inspect it; the playable library just stops offering it.
        expect(
          await database.draftsDao.getDraftById('draft_broken'),
          isNotNull,
        );
      });

      test('clears missing final rendered clip references', () async {
        final savedAt = DateTime(2026, 5, 4, 3, 2, 1);
        final draft = DivineVideoDraft(
          id: 'draft_rendered',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime(2025),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Rendered Draft',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
          createdAt: savedAt,
          lastModified: savedAt,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
          finalRenderedClip: DivineVideoClip(
            id: 'rendered_clip',
            video: EditorVideo.file('/path/to/missing-render.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        );

        await service.saveDraft(draft);

        final drafts = await service.getAllDrafts();
        expect(drafts, hasLength(1));
        expect(drafts.single.finalRenderedClip, isNull);
        // Dropping the dangling render does not take the draft out of play:
        // publish re-renders it from its clips and editor state.
        expect(drafts.single.canPost, isTrue);
        // ...and it is not an edit either, so the timestamp stays put.
        expect(drafts.single.lastModified, savedAt);
      });
    });

    group('getDraftById', () {
      test('returns null for a draft with a corrupt clip', () async {
        final now = DateTime.now();
        final draft = DivineVideoDraft(
          id: 'draft_corrupt',
          clips: [
            DivineVideoClip(
              id: 'clip_corrupt',
              video: EditorVideo.file('/path/to/clip_corrupt.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'draft_corrupt',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );
        await service.saveDraft(draft);

        // Drop the clip's filePath so DivineVideoClip.fromJson throws when
        // the single draft is reconstructed. getDraftById must skip-and-log
        // and return null rather than throwing out of the lookup.
        final corruptData = draft.clips.first.toJson()..['filePath'] = null;
        await database.clipsDao.upsertClip(
          id: 'clip_corrupt',
          draftId: 'draft_corrupt',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: now,
          data: jsonEncode(corruptData),
          filePath: null,
          thumbnailPath: null,
        );

        expect(await service.getDraftById('draft_corrupt'), isNull);
      });
    });

    group('getValidatedDraftById', () {
      test('keeps the stored lastModified', () async {
        final savedAt = DateTime(2026, 5, 4, 3, 2, 1);
        final draft = DivineVideoDraft(
          id: 'draft_validated',
          clips: [
            DivineVideoClip(
              id: 'clip_validated',
              video: EditorVideo.file('/path/to/old_video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: savedAt,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Validated draft',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: savedAt,
          lastModified: savedAt,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft);

        final loaded = await service.getValidatedDraftById('draft_validated');
        expect(loaded?.lastModified, savedAt);
      });
    });

    group('account ownership', () {
      const pubkeyA =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      const pubkeyB =
          'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

      DraftStorageService serviceFor(String? ownerPubkey) =>
          DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
            ownerPubkey: ownerPubkey,
          );

      DivineVideoDraft draftWithId(String id) {
        final now = DateTime.now();
        return DivineVideoDraft(
          id: id,
          clips: [
            DivineVideoClip(
              id: 'clip_$id',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: id,
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );
      }

      test("getDraftById does not read another account's draft", () async {
        await serviceFor(pubkeyA).saveDraft(draftWithId('draft_a'));

        expect(await serviceFor(pubkeyA).getDraftById('draft_a'), isNotNull);
        expect(await serviceFor(pubkeyB).getDraftById('draft_a'), isNull);
      });

      test('isDraftOwnedByAnotherAccount flags a foreign draft', () async {
        await serviceFor(pubkeyA).saveDraft(draftWithId('draft_a'));

        expect(
          await serviceFor(pubkeyB).isDraftOwnedByAnotherAccount('draft_a'),
          isTrue,
        );
        expect(
          await serviceFor(pubkeyA).isDraftOwnedByAnotherAccount('draft_a'),
          isFalse,
        );
      });

      test('isDraftOwnedByAnotherAccount is false for an unknown id', () async {
        expect(
          await serviceFor(pubkeyA).isDraftOwnedByAnotherAccount('nope'),
          isFalse,
        );
      });

      test('deleteDraft removes a row whoever owns it', () async {
        await serviceFor(pubkeyA).saveDraft(draftWithId('draft_a'));

        // Deletion is keyed on the primary key, so it must not depend on the
        // caller's ownerPubkey — a service holding a stale one (e.g. captured
        // before sign-in) would otherwise silently leak every row it deletes.
        await serviceFor(pubkeyB).deleteDraft('draft_a');

        expect(await serviceFor(pubkeyA).getDraftById('draft_a'), isNull);
      });

      test('draftExists sees a row owned by another account', () async {
        await serviceFor(pubkeyA).saveDraft(draftWithId('draft_a'));

        expect(await serviceFor(pubkeyB).draftExists('draft_a'), isTrue);
        expect(await serviceFor(pubkeyB).draftExists('nope'), isFalse);
      });

      test('updatePublishStatus leaves the row with its owner', () async {
        await serviceFor(pubkeyA).saveDraft(draftWithId('draft_a'));
        await serviceFor(
          pubkeyA,
        ).updatePublishStatus(draftId: 'draft_a', status: PublishStatus.failed);

        // Parking an abandoned upload runs through whichever service the
        // BackgroundPublishBloc captured, which is not necessarily the one
        // that owns the row. The write is keyed on the primary key and must
        // never re-attribute the draft — otherwise parking a video would move
        // it to the account that happened to be signed in.
        await serviceFor(
          pubkeyB,
        ).updatePublishStatus(draftId: 'draft_a', status: PublishStatus.draft);

        expect(
          await serviceFor(
            pubkeyA,
          ).getDraftsByPublishStatuses({PublishStatus.draft}),
          hasLength(1),
        );
        expect(
          await serviceFor(
            pubkeyB,
          ).getDraftsByPublishStatuses({PublishStatus.draft}),
          isEmpty,
        );
      });

      test(
        'isDraftOwnedByAnotherAccount is false for a legacy draft',
        () async {
          await serviceFor(null).saveDraft(draftWithId('draft_legacy'));

          expect(
            await serviceFor(
              pubkeyA,
            ).isDraftOwnedByAnotherAccount('draft_legacy'),
            isFalse,
          );
        },
      );
    });

    group('deleteDraft', () {
      test('should delete draft by ID', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.deleteDraft(draft1.id);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft2.id);
        expect(drafts.first.title, 'Second');
      });

      test('should do nothing if draft ID does not exist', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);
        await service.deleteDraft('nonexistent-id');

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
      });
    });

    group('stop-motion frame-only drafts', () {
      late Directory docsDir;

      setUp(() {
        docsDir = Directory(documentsPath)..createSync(recursive: true);
      });

      tearDown(() {
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      File writeFrame(String name) {
        final file = File(p.join(documentsPath, name));
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      DivineVideoClip framesOnlyClip({
        required List<File> frames,
        String id = 'stop_motion_clip',
      }) {
        return DivineVideoClip(
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
          targetAspectRatio: AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );
      }

      test(
        'deleting a draft keeps frame files referenced by a library clip',
        () async {
          final frame0 = writeFrame('draft_shared_frame0.jpg');
          final frame1 = writeFrame('draft_shared_frame1.jpg');
          final clip = framesOnlyClip(frames: [frame0, frame1]);
          final libraryService = ClipLibraryService(
            clipsDao: database.clipsDao,
            draftsDao: database.draftsDao,
            clipCategoriesDao: database.clipCategoriesDao,
          );

          await libraryService.saveClip(clip);
          await service.saveDraft(
            DivineVideoDraft.create(
              id: 'draft_stop_motion',
              clips: [clip],
              title: 'Stop motion',
              description: '',
              hashtags: const {},
              selectedApproach: 'stop_motion',
            ),
          );

          await service.deleteDraft('draft_stop_motion');

          expect(frame0.existsSync(), isTrue);
          expect(
            frame1.existsSync(),
            isTrue,
            reason:
                'all library stop-motion frame paths live in JSON, not only '
                'indexed thumbnail/file columns',
          );
        },
      );

      test('deleting a draft removes its unreferenced frame files', () async {
        final frame0 = writeFrame('draft_only_frame0.jpg');
        final frame1 = writeFrame('draft_only_frame1.jpg');
        final clip = framesOnlyClip(frames: [frame0, frame1]);

        await service.saveDraft(
          DivineVideoDraft.create(
            id: 'draft_only_stop_motion',
            clips: [clip],
            title: 'Stop motion',
            description: '',
            hashtags: const {},
            selectedApproach: 'stop_motion',
          ),
        );

        await service.deleteDraft('draft_only_stop_motion');

        // No surviving row references the stills, so the frames are reaped.
        // Before deleteDraft removed the draft's clip rows, they lingered
        // (the FK cascade never fires) and kept the frames pinned on disk.
        expect(frame0.existsSync(), isFalse);
        expect(frame1.existsSync(), isFalse);
      });

      test('clearing all drafts removes unreferenced frame files', () async {
        final frame0 = writeFrame('clear_frame0.jpg');
        final frame1 = writeFrame('clear_frame1.jpg');
        final clip = framesOnlyClip(frames: [frame0, frame1], id: 'clear_clip');

        await service.saveDraft(
          DivineVideoDraft.create(
            id: 'draft_clear_stop_motion',
            clips: [clip],
            title: 'Stop motion',
            description: '',
            hashtags: const {},
            selectedApproach: 'stop_motion',
          ),
        );

        await service.clearAllDrafts();

        expect(frame0.existsSync(), isFalse);
        expect(frame1.existsSync(), isFalse);
      });

      test('validated autosave keeps frame-only stop-motion clips', () async {
        final frame0 = writeFrame('autosave_frame0.jpg');
        final frame1 = writeFrame('autosave_frame1.jpg');
        final clip = framesOnlyClip(frames: [frame0, frame1]);

        await service.saveDraft(
          DivineVideoDraft.create(
            id: VideoEditorConstants.autoSaveId,
            clips: [clip],
            title: 'Autosave',
            description: '',
            hashtags: const {},
            selectedApproach: 'stop_motion',
          ),
        );

        final autosave = await service.getAutosaveDraft();

        expect(autosave, isNotNull);
        expect(autosave!.clips, hasLength(1));
        expect(autosave.clips.single.isStopMotion, isTrue);
      });

      test(
        'keeps a stop-motion draft, dropping only the unreadable still',
        () async {
          final frame0 = writeFrame('salvage_frame0.jpg');
          final frame1 = writeFrame('salvage_frame1.jpg');
          final clip = framesOnlyClip(
            frames: [frame0, frame1],
            id: 'sm_salvage',
          );

          await service.saveDraft(
            DivineVideoDraft.create(
              id: 'draft_salvage',
              clips: [clip],
              title: 'Stop motion',
              description: '',
              hashtags: const {},
              selectedApproach: 'stop_motion',
            ),
          );

          // One still goes missing after the draft was persisted (file cleanup
          // reaped it). getAllDrafts validation must salvage the clip per-frame
          // instead of hiding the whole draft before restore can recover it.
          frame1.deleteSync();

          final drafts = await service.getAllDrafts();
          expect(drafts.map((draft) => draft.id), ['draft_salvage']);
          final restored = drafts.single.clips.single;
          expect(restored.isStopMotion, isTrue);
          expect(restored.stopMotionFrames, hasLength(1));
          expect(
            restored.stopMotionFrames!.single.path,
            endsWith('salvage_frame0.jpg'),
          );
        },
      );

      test(
        'reaps a still removed from an existing session on the next save',
        () async {
          final frame0 = writeFrame('resave_frame0.jpg');
          final frame1 = writeFrame('resave_frame1.jpg');
          final frame2 = writeFrame('resave_frame2.jpg');

          DivineVideoDraft draftWithFrames(List<File> frames) =>
              DivineVideoDraft.create(
                id: 'draft_resave',
                clips: [framesOnlyClip(frames: frames, id: 'sm_resave')],
                title: 'Stop motion',
                description: '',
                hashtags: const {},
                selectedApproach: 'stop_motion',
              );

          await service.saveDraft(draftWithFrames([frame0, frame1, frame2]));

          // The user deletes the middle still in the editor; the session
          // autosaves. The removed still is no longer referenced by the draft
          // and must be queued for cleanup (and reaped when no sink defers it).
          await service.saveDraft(draftWithFrames([frame0, frame2]));

          expect(
            frame1.existsSync(),
            isFalse,
            reason:
                'a still removed from the clip is orphaned and must be cleaned '
                'up on the next save',
          );
          expect(frame0.existsSync(), isTrue);
          expect(frame2.existsSync(), isTrue);
        },
      );
    });

    group('clearAllDrafts', () {
      test('should remove all drafts from storage', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should handle clearing when no drafts exist', () async {
        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });
    });

    group('updatePublishStatus', () {
      test('should update publish status of an existing draft', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final updated = await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.publishing,
        );
        expect(updated, isTrue);

        // updatePublishStatus updates the column used for filtering
        final publishing = await service.getDraftsByPublishStatuses({
          PublishStatus.publishing,
        });
        expect(publishing, hasLength(1));
        expect(publishing.first.id, equals(draft.id));

        final drafts = await service.getDraftsByPublishStatuses({
          PublishStatus.draft,
        });
        expect(drafts, isEmpty);
      });

      test('returns false when the draft row is missing', () async {
        final updated = await service.updatePublishStatus(
          draftId: 'missing',
          status: PublishStatus.draft,
        );

        expect(updated, isFalse);
      });

      test('surfaces the new status to readers of the draft', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        // The publish flow writes `publishing` through a full save, then only
        // ever touches the row columns.
        await service.saveDraft(
          draft.copyWith(publishStatus: PublishStatus.publishing),
        );
        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.failed,
          publishError: 'Network error',
          publishAttempts: 2,
        );

        // A `publishing` draft is filtered out of the library, so reading the
        // stale blob strands the video: the user never sees it again.
        final loaded = await service.getAllDrafts();
        expect(loaded.single.publishStatus, PublishStatus.failed);
        expect(loaded.single.publishError, 'Network error');
        expect(loaded.single.publishAttempts, 2);
      });

      test('should update publish status with error message', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.failed,
          publishError: 'Network error',
        );

        final failed = await service.getDraftsByPublishStatuses({
          PublishStatus.failed,
        });
        expect(failed, hasLength(1));

        // Verify error stored at DB row level
        final row = await database.draftsDao.getDraftById(draft.id);
        expect(row, isNotNull);
        expect(row!.publishError, equals('Network error'));
      });

      test('should transition through multiple statuses', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.publishing,
        );
        var matches = await service.getDraftsByPublishStatuses({
          PublishStatus.publishing,
        });
        expect(matches, hasLength(1));

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.failed,
          publishError: 'Timeout',
        );
        matches = await service.getDraftsByPublishStatuses({
          PublishStatus.failed,
        });
        expect(matches, hasLength(1));

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.draft,
        );
        matches = await service.getDraftsByPublishStatuses({
          PublishStatus.draft,
        });
        expect(matches, hasLength(1));
      });
    });

    group('getDraftsByPublishStatuses', () {
      DivineVideoDraft createDraftWithStatus(String id, PublishStatus status) {
        final now = DateTime.now();
        createDocumentFile('$id.mp4');
        return DivineVideoDraft(
          id: id,
          clips: [
            DivineVideoClip(
              id: 'clip_$id',
              video: EditorVideo.file('/path/to/$id.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Draft $id',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: status,
          publishAttempts: 0,
        );
      }

      test(
        'should return only drafts matching the requested statuses',
        () async {
          await service.saveDraft(
            createDraftWithStatus('d1', PublishStatus.draft),
          );
          await service.saveDraft(
            createDraftWithStatus('d2', PublishStatus.publishing),
          );
          await service.saveDraft(
            createDraftWithStatus('d3', PublishStatus.failed),
          );

          final results = await service.getDraftsByPublishStatuses({
            PublishStatus.publishing,
            PublishStatus.failed,
          });

          expect(results, hasLength(2));
          final ids = results.map((d) => d.id).toSet();
          expect(ids, containsAll(['d2', 'd3']));
        },
      );

      test('should return empty list when no drafts match', () async {
        await service.saveDraft(
          createDraftWithStatus('d1', PublishStatus.draft),
        );

        final results = await service.getDraftsByPublishStatuses({
          PublishStatus.failed,
        });

        expect(results, isEmpty);
      });

      test('should remove corrupted drafts with 0 clips', () async {
        // Insert a draft row directly via DAO (no clips)
        await database.draftsDao.upsertDraft(
          id: 'corrupted',
          title: 'Corrupted',
          description: '',
          publishStatus: 'failed',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{"title":"Corrupted","description":""}',
        );

        final results = await service.getDraftsByPublishStatuses({
          PublishStatus.failed,
        });

        expect(results, isEmpty);

        // Corrupted row should be deleted
        final row = await database.draftsDao.getDraftById('corrupted');
        expect(row, isNull);
      });

      test(
        'skips a draft with a corrupt clip and keeps valid matching drafts',
        () async {
          final validDraft = createDraftWithStatus(
            'valid_failed',
            PublishStatus.failed,
          );
          final corruptDraft = createDraftWithStatus(
            'corrupt_failed',
            PublishStatus.failed,
          );
          await service.saveDraft(validDraft);
          await service.saveDraft(corruptDraft);

          final corruptClipData = corruptDraft.clips.first.toJson()
            ..['filePath'] = null;
          await database.clipsDao.upsertClip(
            id: 'clip_corrupt_failed',
            draftId: 'corrupt_failed',
            orderIndex: 0,
            durationMs: 6000,
            recordedAt: DateTime.now(),
            data: jsonEncode(corruptClipData),
            filePath: null,
            thumbnailPath: null,
          );

          final results = await service.getDraftsByPublishStatuses({
            PublishStatus.failed,
          });

          expect(results.map((draft) => draft.id), ['valid_failed']);
        },
      );

      test('should return drafts for a single status', () async {
        await service.saveDraft(
          createDraftWithStatus('d1', PublishStatus.failed),
        );
        await service.saveDraft(
          createDraftWithStatus('d2', PublishStatus.failed),
        );
        await service.saveDraft(
          createDraftWithStatus('d3', PublishStatus.draft),
        );

        final results = await service.getDraftsByPublishStatuses({
          PublishStatus.failed,
        });

        expect(results, hasLength(2));
        expect(
          results.every((d) => d.publishStatus == PublishStatus.failed),
          isTrue,
        );
      });
    });

    group('migrateOldDrafts', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(SharedPreferences.resetStatic);

      Map<String, dynamic> buildClipJson({
        required String id,
        String filePath = 'video.mp4',
        int durationMs = 6000,
        DateTime? recordedAt,
      }) {
        return {
          'id': id,
          'filePath': filePath,
          'durationMs': durationMs,
          'recordedAt': (recordedAt ?? DateTime(2025)).toIso8601String(),
          'targetAspectRatio': 'square',
        };
      }

      Map<String, dynamic> buildDraftJson({
        required String id,
        required List<Map<String, dynamic>> clips,
        String title = 'Test Draft',
        String description = '',
        String publishStatus = 'draft',
        DateTime? createdAt,
        DateTime? lastModified,
      }) {
        final now = createdAt ?? DateTime(2025);
        return {
          'id': id,
          'clips': clips,
          'title': title,
          'description': description,
          'hashtags': <String>[],
          'selectedApproach': 'hybrid',
          'createdAt': now.toIso8601String(),
          'lastModified': (lastModified ?? now).toIso8601String(),
          'publishStatus': publishStatus,
          'publishAttempts': 0,
        };
      }

      test('does nothing when no legacy data exists', () async {
        SharedPreferences.setMockInitialValues({});

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('does nothing when legacy key is empty string', () async {
        SharedPreferences.setMockInitialValues({'vine_drafts': ''});

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('migrates a single draft with one clip', () async {
        final draftJson = buildDraftJson(
          id: 'draft_1',
          clips: [buildClipJson(id: 'clip_1')],
          title: 'My First Vine',
          description: 'A test description',
        );
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draftJson]),
        });

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, hasLength(1));
        expect(drafts.first.id, equals('draft_1'));
        expect(drafts.first.title, equals('My First Vine'));
        expect(drafts.first.description, equals('A test description'));
        expect(drafts.first.clips, hasLength(1));
        expect(drafts.first.clips.first.id, equals('clip_1'));

        // Legacy key should be removed
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('vine_drafts'), isNull);
      });

      test('migrates multiple drafts with multiple clips', () async {
        final draft1 = buildDraftJson(
          id: 'draft_a',
          clips: [
            buildClipJson(id: 'clip_a1', filePath: 'a1.mp4'),
            buildClipJson(id: 'clip_a2', filePath: 'a2.mp4'),
          ],
          title: 'Draft A',
        );
        final draft2 = buildDraftJson(
          id: 'draft_b',
          clips: [buildClipJson(id: 'clip_b1', filePath: 'b1.mp4')],
          title: 'Draft B',
        );
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draft1, draft2]),
        });

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, hasLength(2));

        final draftA = drafts.firstWhere((d) => d.id == 'draft_a');
        expect(draftA.clips, hasLength(2));

        final draftB = drafts.firstWhere((d) => d.id == 'draft_b');
        expect(draftB.clips, hasLength(1));

        // Legacy key removed after full success
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('vine_drafts'), isNull);
      });

      test('preserves clip order after migration', () async {
        createDocumentFile('first.mp4');
        createDocumentFile('second.mp4');
        createDocumentFile('third.mp4');
        final draftJson = buildDraftJson(
          id: 'draft_order',
          clips: [
            buildClipJson(id: 'first', filePath: 'first.mp4'),
            buildClipJson(id: 'second', filePath: 'second.mp4'),
            buildClipJson(id: 'third', filePath: 'third.mp4'),
          ],
        );
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draftJson]),
        });

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts.first.clips.map((c) => c.id), [
          'first',
          'second',
          'third',
        ]);
      });

      test('preserves publish status through migration', () async {
        final draftJson = buildDraftJson(
          id: 'draft_pub',
          clips: [buildClipJson(id: 'clip_pub')],
          publishStatus: 'failed',
        );
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draftJson]),
        });

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts.first.publishStatus, equals(PublishStatus.failed));
      });

      test('keeps failed drafts in SharedPreferences for retry', () async {
        final goodDraft = buildDraftJson(
          id: 'draft_good',
          clips: [buildClipJson(id: 'clip_good')],
          title: 'Good Draft',
        );
        // Malformed draft (missing required fields) — will fail fromJson
        final badDraft = <String, dynamic>{
          'id': 'draft_bad',
          'title': 'Bad Draft',
          // Missing 'clips', 'description', 'hashtags', etc.
        };

        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([goodDraft, badDraft]),
        });

        await service.migrateOldDrafts();

        // Good draft should be in database
        final drafts = await service.getAllDrafts();
        expect(drafts, hasLength(1));
        expect(drafts.first.id, equals('draft_good'));

        // Failed draft stays in SharedPreferences for retry
        final prefs = await SharedPreferences.getInstance();
        final remaining = prefs.getString('vine_drafts');
        expect(remaining, isNotNull);

        final remainingList = json.decode(remaining!) as List<dynamic>;
        expect(remainingList, hasLength(1));
        expect(
          (remainingList.first as Map<String, dynamic>)['id'],
          equals('draft_bad'),
        );
      });

      test('is idempotent — re-running migrates without duplicates', () async {
        final draftJson = buildDraftJson(
          id: 'draft_idem',
          clips: [buildClipJson(id: 'clip_idem')],
        );
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draftJson]),
        });

        await service.migrateOldDrafts();

        // Re-populate SharedPreferences to simulate a partial retry
        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([draftJson]),
        });
        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        // Upsert should not duplicate
        expect(drafts, hasLength(1));
        expect(drafts.first.id, equals('draft_idem'));
      });

      test('migrates old single-clip format with videoFilePath', () async {
        // Legacy format before multi-clip support
        final legacyDraft = {
          'id': 'draft_legacy',
          'videoFilePath': 'old_video.mp4',
          'title': 'Legacy Vine',
          'description': 'Old format',
          'hashtags': <String>[],
          'selectedApproach': 'hybrid',
          'createdAt': DateTime(2024).toIso8601String(),
          'lastModified': DateTime(2024).toIso8601String(),
          'aspectRatio': 'square',
          'publishStatus': 'draft',
          'publishAttempts': 0,
        };

        SharedPreferences.setMockInitialValues({
          'vine_drafts': json.encode([legacyDraft]),
        });

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, hasLength(1));
        expect(drafts.first.id, equals('draft_legacy'));
        expect(drafts.first.title, equals('Legacy Vine'));
        // Old format creates a single clip
        expect(drafts.first.clips, hasLength(1));
      });

      // Regression for #4852: migrated drafts must be written together with
      // their clips in a single transaction. A draft row persisted without
      // its clip rows is treated as corrupted and permanently deleted on the
      // next read (see the "removes corrupted drafts with 0 clips" tests),
      // which silently wipes the user's drafts after an app update.
      test(
        'commits clip rows with the draft so reads do not delete it',
        () async {
          final draftJson = buildDraftJson(
            id: 'draft_atomic',
            clips: [
              buildClipJson(id: 'clip_atomic_1', filePath: 'a1.mp4'),
              buildClipJson(id: 'clip_atomic_2', filePath: 'a2.mp4'),
            ],
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });

          await service.migrateOldDrafts();

          // The migrated draft must have its clip rows persisted, otherwise the
          // corrupted-draft sweep in getAllDrafts would delete it.
          final clipRows = await database.clipsDao.getClipsByDraftId(
            'draft_atomic',
          );
          expect(clipRows, hasLength(2));

          // Running the destructive read twice must not remove the draft.
          await service.getAllDrafts();
          final drafts = await service.getAllDrafts();
          expect(drafts, hasLength(1));
          expect(drafts.first.id, equals('draft_atomic'));
          expect(drafts.first.clips, hasLength(2));
        },
      );
    });

    group('custom cover file hygiene', () {
      late Directory docsDir;

      setUp(() {
        docsDir = Directory(documentsPath)..createSync(recursive: true);
      });

      tearDown(() {
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      File writeCover(String name) {
        final file = File(p.join(documentsPath, name));
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      DivineVideoDraft draftWithCover(String coverPath) =>
          DivineVideoDraft.create(
            id: 'draft_cover',
            clips: [
              DivineVideoClip(
                id: 'clip_cover',
                video: EditorVideo.file('/path/to/video.mp4'),
                duration: const Duration(seconds: 6),
                recordedAt: DateTime(2025),
                targetAspectRatio: AspectRatio.square,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Cover draft',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            customThumbnailPath: coverPath,
          );

      test('preserves the active cover file across a re-save', () async {
        final cover = writeCover('cover.jpg');
        await service.saveDraft(draftWithCover(cover.path));

        // An autosave after an unrelated edit re-saves the same draft.
        await service.saveDraft(
          draftWithCover(cover.path).copyWith(title: 'Updated'),
        );

        expect(
          cover.existsSync(),
          isTrue,
          reason:
              're-saving a draft must keep its still-referenced custom cover',
        );
      });

      test('deletes the previous cover when a new one is selected', () async {
        final oldCover = writeCover('old_cover.jpg');
        final newCover = writeCover('new_cover.jpg');

        await service.saveDraft(draftWithCover(oldCover.path));
        await service.saveDraft(draftWithCover(newCover.path));

        expect(
          oldCover.existsSync(),
          isFalse,
          reason: 'the replaced cover is orphaned and must be cleaned up',
        );
        expect(
          newCover.existsSync(),
          isTrue,
          reason: 'the newly selected cover must be kept',
        );
      });

      test('deletes the cover file when the draft is deleted', () async {
        final cover = writeCover('cover.jpg');
        final draft = draftWithCover(cover.path);
        await service.saveDraft(draft);

        await service.deleteDraft(draft.id);

        expect(
          cover.existsSync(),
          isFalse,
          reason: 'deleting a draft must remove its user-selected cover',
        );
      });

      test('keeps a cover referenced by a saved draft when autosave is '
          'deleted', () async {
        final cover = writeCover('shared_cover.jpg');
        final autosave = draftWithCover(
          cover.path,
        ).copyWith(id: 'draft_autosave');
        final savedDraft = draftWithCover(
          cover.path,
        ).copyWith(id: 'draft_named');

        await service.saveDraft(autosave);
        await service.saveDraft(savedDraft);

        await service.deleteDraft(autosave.id);

        expect(
          cover.existsSync(),
          isTrue,
          reason:
              'custom cover paths are draft references even when they are not '
              'mirrored on finalRenderedClip',
        );
      });

      test('deletes custom cover files when all drafts are cleared', () async {
        final cover = writeCover('clear_all_cover.jpg');
        await service.saveDraft(draftWithCover(cover.path));

        await service.clearAllDrafts();

        expect(
          cover.existsSync(),
          isFalse,
          reason: 'clearing all drafts should not leak custom cover files',
        );
      });
    });

    group('deferred orphan cleanup', () {
      late Directory docsDir;

      setUp(() {
        docsDir = Directory(documentsPath)..createSync(recursive: true);
      });

      tearDown(() {
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      File writeVideo(String name) {
        final file = File(p.join(documentsPath, name));
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      DivineVideoDraft draftWithClip(
        String videoPath, {
        String? forwardVideoPath,
        String? reversedVideoPath,
      }) => DivineVideoDraft.create(
        id: 'draft_defer',
        clips: [
          DivineVideoClip(
            id: 'clip_${p.basenameWithoutExtension(videoPath)}',
            video: EditorVideo.file(videoPath),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
            forwardVideoPath: forwardVideoPath,
            reversedVideoPath: reversedVideoPath,
          ),
        ],
        title: 'Defer draft',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
      );

      DivineVideoDraft draftWithKeyedClip({
        required String videoPath,
        required String sourcePath,
        required String backgroundPath,
      }) => DivineVideoDraft.create(
        id: 'draft_defer',
        clips: [
          DivineVideoClip(
            id: 'clip_keyed',
            video: EditorVideo.file(videoPath),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
            chromaKeySourcePath: sourcePath,
            chromaKey: ClipChromaKey(
              key: ChromaKey(
                backgroundImage: EditorLayerImage.file(backgroundPath),
              ),
            ),
          ),
        ],
        title: 'Defer draft',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
      );

      test(
        'keeps an orphaned clip file alive and hands its path to the sink',
        () async {
          final oldVideo = writeVideo('old.mp4');
          final newVideo = writeVideo('new.mp4');

          await service.saveDraft(draftWithClip(oldVideo.path));

          final deferred = <String>[];
          await service.saveDraft(
            draftWithClip(newVideo.path),
            deferOrphanCleanup: (paths) =>
                deferred.addAll(paths.whereType<String>()),
          );

          expect(
            oldVideo.existsSync(),
            isTrue,
            reason:
                'a deferred orphan must survive the save so undo can '
                'restore the clip whose source it is',
          );
          expect(
            deferred,
            contains(oldVideo.path),
            reason: 'the orphan path must reach the caller for later cleanup',
          );
        },
      );

      test('deletes the orphaned clip file when no sink is provided', () async {
        final oldVideo = writeVideo('old.mp4');
        final newVideo = writeVideo('new.mp4');

        await service.saveDraft(draftWithClip(oldVideo.path));
        await service.saveDraft(draftWithClip(newVideo.path));

        expect(
          oldVideo.existsSync(),
          isFalse,
          reason: 'without deferral the replaced clip file is reaped as before',
        );
        expect(
          newVideo.existsSync(),
          isTrue,
          reason: 'the currently-referenced clip file must be kept',
        );
      });

      test('keeps detached clip media across a draft save', () async {
        final detachedVideo = writeVideo('detached.mp4');
        final detachedThumbnail = writeVideo('detached.jpg');
        final timelineVideo = writeVideo('timeline.mp4');
        final detachedClip = DivineVideoClip(
          id: 'detached',
          video: EditorVideo.file(detachedVideo.path),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 1,
          thumbnailPath: detachedThumbnail.path,
        );
        final timelineClip = DivineVideoClip(
          id: 'timeline',
          video: EditorVideo.file(timelineVideo.path),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 1,
        );
        final original = DivineVideoDraft.create(
          id: 'draft_defer',
          clips: [detachedClip, timelineClip],
          title: 'Detach draft',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        );
        await service.saveDraft(original);

        final meta = DetachedClipLayerData(
          clip: detachedClip,
          layerId: 'detached-layer',
        ).toMeta();
        await service.saveDraft(
          original.copyWith(
            clips: [timelineClip],
            editorStateHistory: {
              'history': [
                {
                  'layers': [meta],
                },
              ],
            },
          ),
        );

        expect(detachedVideo.existsSync(), isTrue);
        expect(detachedThumbnail.existsSync(), isTrue);
        expect(
          await database.draftsDao.isDraftFileReferenced('detached.mp4'),
          isTrue,
        );
        expect(
          await database.draftsDao.isDraftFileReferenced('detached.jpg'),
          isTrue,
        );
      });

      test('reclaims a reverse cache the clip stopped pointing at', () async {
        // A transform clears both reverse caches. Until this sweep read
        // [DivineVideoClip.ownedFilePaths] it enumerated only the video, the
        // stills, the thumbnail and the chroma-key pair — so the cached
        // forward/reversed renders were invisible to every cleanup path and
        // leaked one file per transform.
        final video = writeVideo('clip.mp4');
        final forward = writeVideo('forward.mp4');
        final reversed = writeVideo('reversed.mp4');

        await service.saveDraft(
          draftWithClip(
            video.path,
            forwardVideoPath: forward.path,
            reversedVideoPath: reversed.path,
          ),
        );
        await service.saveDraft(draftWithClip(video.path));

        expect(
          forward.existsSync(),
          isFalse,
          reason: 'the cached forward render is unreachable once cleared',
        );
        expect(
          reversed.existsSync(),
          isFalse,
          reason: 'the cached reversed render is unreachable once cleared',
        );
        expect(
          video.existsSync(),
          isTrue,
          reason: 'the clip still plays its video — it must survive',
        );
      });

      test(
        'hands cleared chroma-key source and image paths to the cleanup sink',
        () async {
          final keyedVideo = writeVideo('keyed.mp4');
          final transformedVideo = writeVideo('transformed.mp4');
          final source = writeVideo('pre_key.mp4');
          final background = writeVideo('chroma_bg.png');

          await service.saveDraft(
            draftWithKeyedClip(
              videoPath: keyedVideo.path,
              sourcePath: source.path,
              backgroundPath: background.path,
            ),
          );

          final deferred = <String>[];
          await service.saveDraft(
            draftWithClip(transformedVideo.path),
            deferOrphanCleanup: (paths) =>
                deferred.addAll(paths.whereType<String>()),
          );

          expect(
            deferred,
            containsAll([keyedVideo.path, source.path, background.path]),
          );
          expect(source.existsSync(), isTrue);
          expect(background.existsSync(), isTrue);
        },
      );

      test(
        'deletes cleared chroma-key source and image paths without a sink',
        () async {
          final keyedVideo = writeVideo('keyed_delete.mp4');
          final transformedVideo = writeVideo('transformed_delete.mp4');
          final source = writeVideo('pre_key_delete.mp4');
          final background = writeVideo('chroma_bg_delete.png');

          await service.saveDraft(
            draftWithKeyedClip(
              videoPath: keyedVideo.path,
              sourcePath: source.path,
              backgroundPath: background.path,
            ),
          );

          await service.saveDraft(draftWithClip(transformedVideo.path));

          expect(keyedVideo.existsSync(), isFalse);
          expect(source.existsSync(), isFalse);
          expect(background.existsSync(), isFalse);
          expect(transformedVideo.existsSync(), isTrue);
        },
      );
    });

    group('draft-local audio file hygiene', () {
      late Directory docsDir;

      setUp(() {
        docsDir = Directory(documentsPath)..createSync(recursive: true);
      });

      tearDown(() {
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      File writeAudio(String relativePath) {
        final file = File(p.join(documentsPath, relativePath));
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      Map<String, dynamic> historyWithLocalAudio(String audioPath, String id) {
        final track = AudioEvent.fromLocalImport(
          id: id,
          filePath: audioPath,
          createdAt: 1700000000,
          title: 'Local audio',
          mimeType: 'audio/mp4',
        );
        return {
          'position': 0,
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
          ],
        };
      }

      DivineVideoDraft draftWithAudio({
        required String id,
        required String audioPath,
        required String audioId,
      }) => DivineVideoDraft.create(
        id: id,
        clips: [
          DivineVideoClip(
            id: 'clip_$id',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Audio draft',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
        editorStateHistory: historyWithLocalAudio(audioPath, audioId),
      );

      test('deletes imported audio when the draft is deleted', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_audio', 'imported.m4a'),
        );
        final draft = draftWithAudio(
          id: 'draft_audio',
          audioPath: audio.path,
          audioId: 'local_import_1',
        );
        await service.saveDraft(draft);

        await service.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isFalse,
          reason: 'deleting a draft must remove its imported audio file',
        );
      });

      test('deletes a committed voice-over recording when the draft is '
          'deleted', () async {
        final audio = writeAudio(
          p.join('voice_over_recordings', 'voice_over_1.m4a'),
        );
        final draft = draftWithAudio(
          id: 'draft_voice',
          audioPath: audio.path,
          audioId: 'local_import_voice_over_1',
        );
        await service.saveDraft(draft);

        await service.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isFalse,
          reason: 'deleting a draft must remove its voice-over recording',
        );
      });

      test('keeps audio referenced by another draft (publish copy) when one '
          'draft is deleted', () async {
        final audio = writeAudio(
          p.join('voice_over_recordings', 'shared_voice_over.m4a'),
        );
        final draft = draftWithAudio(
          id: 'draft_source',
          audioPath: audio.path,
          audioId: 'local_import_voice_over_2',
        );
        // The publish flow copies editorStateHistory onto a new draft id, so
        // both drafts reference the same local audio file.
        final publishCopy = draft.copyWith(id: 'draft_publish_copy');

        await service.saveDraft(draft);
        await service.saveDraft(publishCopy);

        await service.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isTrue,
          reason:
              'audio shared with a surviving draft must not be deleted until '
              'the last referencing draft is gone',
        );
      });

      test(
        'keeps audio held only in a surviving completed-editor snapshot',
        () async {
          final audio = writeAudio(
            p.join('voice_over_recordings', 'completed_shared.m4a'),
          );
          final track = AudioEvent.fromLocalImport(
            id: 'local_import_completed_shared',
            filePath: audio.path,
            createdAt: 1700000000,
            title: 'Local audio',
            mimeType: 'audio/mp4',
          );
          final owner = draftWithAudio(
            id: 'draft_snapshot_owner',
            audioPath: audio.path,
            audioId: track.id,
          );
          final survivor = DivineVideoDraft.create(
            id: 'draft_snapshot_survivor',
            clips: [
              DivineVideoClip(
                id: 'clip_snapshot_survivor',
                video: EditorVideo.file('/path/to/video.mp4'),
                duration: const Duration(seconds: 6),
                recordedAt: DateTime(2025),
                targetAspectRatio: AspectRatio.square,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Snapshot survivor',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            editorEditingParameters: {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
          );

          await service.saveDraft(owner);
          await service.saveDraft(survivor);

          await service.deleteDraft(owner.id);

          expect(
            audio.existsSync(),
            isTrue,
            reason:
                'audio in a surviving completed-editor snapshot must outlive '
                'the deleted draft that shared it',
          );
        },
      );

      test('still deletes the target audio when a sibling draft has a corrupt '
          'data blob', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_target', 'imported.m4a'),
        );
        final draft = draftWithAudio(
          id: 'draft_target',
          audioPath: audio.path,
          audioId: 'local_import_4',
        );
        await service.saveDraft(draft);

        // A sibling row whose data blob can't be parsed back into a draft.
        // The reference scan runs after the target row is already deleted, so
        // an unguarded throw here would leak the deleted draft's audio file.
        await database.draftsDao.upsertDraft(
          id: 'draft_corrupt_sibling',
          title: 'corrupt',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          data: 'not-json',
          renderedFilePath: null,
          renderedThumbnailPath: null,
        );

        await service.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isFalse,
          reason: 'a corrupt sibling draft must not block audio cleanup',
        );
      });

      test('keeps audio a saved sound still points at', () async {
        // Importing audio from the Library still writes it under whichever
        // draft was open (`draft_audio_imports/<draftId>/`), so deleting that
        // draft would otherwise reclaim a file My Sounds depends on. Unlike a
        // stale path, a deleted file cannot be healed on load (#7977).
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_autosave', 'imported.m4a'),
        );
        SavedSoundsService.resetLegacyMigrationClaimForTesting();
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        await SavedSoundsService(
          preferences,
          documentsPath: documentsPath,
        ).saveSound(
          AudioEvent.fromLocalImport(
            id: 'local_import_saved',
            filePath: audio.path,
            createdAt: 1700000000,
            title: 'Saved sound',
            mimeType: 'audio/mp4',
          ),
        );
        final guardedService = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
          preferences: preferences,
        );
        final draft = draftWithAudio(
          id: 'draft_autosave',
          audioPath: audio.path,
          audioId: 'local_import_saved',
        );
        await guardedService.saveDraft(draft);

        await guardedService.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isTrue,
          reason: 'a file My Sounds still references must survive the delete',
        );
      });

      test('deletes audio no saved sound points at', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_unsaved', 'imported.m4a'),
        );
        SavedSoundsService.resetLegacyMigrationClaimForTesting();
        SharedPreferences.setMockInitialValues({});
        final guardedService = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
          preferences: await SharedPreferences.getInstance(),
        );
        final draft = draftWithAudio(
          id: 'draft_unsaved',
          audioPath: audio.path,
          audioId: 'local_import_unsaved',
        );
        await guardedService.saveDraft(draft);

        await guardedService.deleteDraft(draft.id);

        expect(
          audio.existsSync(),
          isFalse,
          reason: 'the saved-sound guard must not keep every audio file alive',
        );
      });

      test(
        'keeps audio a saved sound points at when all drafts are cleared',
        () async {
          final audio = writeAudio(
            p.join('draft_audio_imports', 'draft_cleared', 'imported.m4a'),
          );
          SavedSoundsService.resetLegacyMigrationClaimForTesting();
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          await SavedSoundsService(
            preferences,
            documentsPath: documentsPath,
          ).saveSound(
            AudioEvent.fromLocalImport(
              id: 'local_import_saved_clear',
              filePath: audio.path,
              createdAt: 1700000000,
              title: 'Saved sound',
              mimeType: 'audio/mp4',
            ),
          );
          final guardedService = DraftStorageService(
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
            preferences: preferences,
          );
          await guardedService.saveDraft(
            draftWithAudio(
              id: 'draft_cleared',
              audioPath: audio.path,
              audioId: 'local_import_saved_clear',
            ),
          );

          await guardedService.clearAllDrafts();

          expect(
            audio.existsSync(),
            isTrue,
            reason: 'My Sounds survives a clear-all, so its audio must too',
          );
        },
      );

      test('deletes audio files when all drafts are cleared', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_clear', 'imported.m4a'),
        );
        final draft = draftWithAudio(
          id: 'draft_clear',
          audioPath: audio.path,
          audioId: 'local_import_3',
        );
        await service.saveDraft(draft);

        await service.clearAllDrafts();

        expect(
          audio.existsSync(),
          isFalse,
          reason: 'clearing all drafts should not leak local audio files',
        );
      });
    });

    group('clip ghost-frame file hygiene', () {
      late Directory docsDir;

      setUp(() {
        docsDir = Directory(documentsPath)..createSync(recursive: true);
      });

      tearDown(() {
        if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
      });

      File writeGhost(String basename) {
        final file = File(p.join(documentsPath, basename));
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      DivineVideoDraft draftWithGhost({
        required String id,
        required String? ghostPath,
      }) => DivineVideoDraft.create(
        id: id,
        clips: [
          DivineVideoClip(
            id: 'clip_$id',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
            ghostFramePath: ghostPath,
          ),
        ],
        title: 'Ghost draft',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
      );

      test('deletes a clip ghost frame when the draft is deleted', () async {
        final ghost = writeGhost('ghost_only.jpg');
        final draft = draftWithGhost(id: 'draft_ghost', ghostPath: ghost.path);
        await service.saveDraft(draft);

        await service.deleteDraft(draft.id);

        expect(
          ghost.existsSync(),
          isFalse,
          reason:
              'deleting the only draft that references a ghost frame must '
              'remove its file',
        );
      });

      test('keeps a ghost frame shared with a duplicate when the source draft '
          'is deleted', () async {
        final ghost = writeGhost('ghost_shared.jpg');
        final source = draftWithGhost(
          id: 'draft_source',
          ghostPath: ghost.path,
        );
        // duplicate() shares the source's clip objects (including
        // ghostFramePath) with a fresh draft id — the flagship "copy then edit
        // independently" flow.
        final copy = source.duplicate(title: 'Copy');

        await service.saveDraft(source);
        await service.saveDraft(copy);

        await service.deleteDraft(source.id);

        expect(
          ghost.existsSync(),
          isTrue,
          reason:
              'a ghost frame shared with a surviving duplicate must not be '
              'deleted until the last referencing draft is gone',
        );
      });

      test('keeps a ghost frame still referenced by a trashed clip when the '
          'draft is deleted', () async {
        final ghost = writeGhost('ghost_trashed_shared.jpg');
        final draft = draftWithGhost(
          id: 'draft_trashed_sibling',
          ghostPath: ghost.path,
        );
        await service.saveDraft(draft);

        // A soft-deleted clip that still references the same ghost frame.
        // It can be restored from trash, so its ghost file must survive the
        // draft deletion. Clip data blobs store the ghost basename.
        await database.clipsDao.upsertClip(
          id: 'trashed_sharing_clip',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: DateTime(2025),
          data: json.encode({'ghostFramePath': 'ghost_trashed_shared.jpg'}),
          filePath: null,
          thumbnailPath: null,
        );
        await database.clipsDao.softDeleteClip(
          id: 'trashed_sharing_clip',
          deletedAt: DateTime(2025, 6),
        );

        await service.deleteDraft(draft.id);

        expect(
          ghost.existsSync(),
          isTrue,
          reason:
              'a ghost frame still referenced by a trashed (restorable) clip '
              'must not be deleted when a sharing draft is removed',
        );
      });

      test('keeps a ghost frame referenced by a surviving library clip when '
          'all drafts are cleared', () async {
        final ghost = writeGhost('ghost_cleared_shared.jpg');
        final draft = draftWithGhost(
          id: 'draft_cleared',
          ghostPath: ghost.path,
        );
        await service.saveDraft(draft);

        // A library clip (no draftId) survives clearAllDrafts and still
        // references the same ghost frame. Clip data blobs store the basename.
        await database.clipsDao.upsertClip(
          id: 'surviving_library_clip',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: DateTime(2025),
          data: json.encode({'ghostFramePath': 'ghost_cleared_shared.jpg'}),
          filePath: null,
          thumbnailPath: null,
        );

        await service.clearAllDrafts();

        expect(
          ghost.existsSync(),
          isTrue,
          reason:
              'clearing all drafts must not delete a ghost frame a surviving '
              'library clip still references',
        );
      });

      // The case above survives even a ghost-frame scan that returns nothing:
      // `deleteGhostFrameFiles` then falls back to `deleteFileIfUnreferenced`,
      // whose clip JSON scan also covers `ghostFramePath` and keeps the file.
      // This one takes that backstop away, leaving the scan as the only
      // protection — so a scan that drops library clips deletes the frame
      // (#6581).
      test('keeps a surviving library clip ghost frame when the indexed '
          'reference backstop misses it', () async {
        final ghost = writeGhost('ghost_backstop_blind.jpg');
        final blindService = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: _BackstopBlindClipsDao(database),
        );
        final draft = draftWithGhost(
          id: 'draft_backstop_blind',
          ghostPath: ghost.path,
        );
        await blindService.saveDraft(draft);

        await database.clipsDao.upsertClip(
          id: 'library_clip_backstop_blind',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: DateTime(2025),
          data: json.encode({'ghostFramePath': 'ghost_backstop_blind.jpg'}),
          filePath: null,
          thumbnailPath: null,
        );

        await blindService.clearAllDrafts();

        expect(
          ghost.existsSync(),
          isTrue,
          reason:
              'the ghost-frame scan must include library clips, whose draftId '
              'is NULL, when no draft is excluded',
        );
      });

      test('still deletes the target ghost frame when a sibling clip row has a '
          'corrupt data blob', () async {
        final ghost = writeGhost('ghost_target.jpg');
        final draft = draftWithGhost(id: 'draft_target', ghostPath: ghost.path);
        await service.saveDraft(draft);

        // A sibling clip row whose data blob can't be parsed. The ghost-frame
        // reference scan runs after the target draft's rows are deleted, so an
        // unguarded throw here would leak the deleted draft's ghost file.
        // The blob is truncated rather than arbitrary text so it still reaches
        // the decode step — the scan pre-filters on the serialized
        // `ghostFramePath` key.
        await database.clipsDao.upsertClip(
          id: 'corrupt_sibling_clip',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: DateTime(2025),
          data: '{"ghostFramePath":"ghost_target.jpg"',
          filePath: null,
          thumbnailPath: null,
        );

        await service.deleteDraft(draft.id);

        expect(
          ghost.existsSync(),
          isFalse,
          reason: 'a corrupt sibling clip must not block ghost-frame cleanup',
        );
      });

      // [ClipsDao.getClipsWithGhostFrames] pre-filters clip blobs on a literal
      // serialized key instead of an indexed column, so it is only correct for
      // as long as it agrees with what [DivineVideoClip.toJson] writes. The
      // deletion tests above cannot catch a drift between the two: when the
      // filter matches nothing, `FileCleanupService.deleteGhostFrameFiles`
      // falls back to `deleteFileIfUnreferenced`, whose JSON scan already
      // covers `ghostFramePath` via `ClipsDao` and keeps the file alive
      // anyway. These two go straight at the filter, through the real save
      // path, so either half drifting turns them red instead of silently
      // emptying the scan.
      group('ghost-frame filter encoding', () {
        test('matches a clip persisted with a ghost frame', () async {
          final draft = draftWithGhost(
            id: 'draft_encoding_match',
            ghostPath: writeGhost('ghost_encoding_match.jpg').path,
          );
          await service.saveDraft(draft);

          final rows = await database.clipsDao.getClipsWithGhostFrames();

          expect(
            rows.map((row) => row.draftId),
            contains(draft.id),
            reason:
                'the SQL pre-filter must still match the encoding '
                'DivineVideoClip.toJson produces for a set ghost frame',
          );
        });

        test('skips a clip persisted without a ghost frame', () async {
          final draft = draftWithGhost(
            id: 'draft_encoding_skip',
            ghostPath: null,
          );
          await service.saveDraft(draft);

          final rows = await database.clipsDao.getClipsWithGhostFrames();

          expect(
            rows,
            isEmpty,
            reason:
                'a null ghost frame serializes to "ghostFramePath":null, so a '
                'filter that matched it would keep every ghost file forever',
          );
        });
      });
    });
  });
}

/// A [ClipsDao] that never reports a filename as referenced, standing in for a
/// clip-side reference check that no longer covers `ghostFramePath`.
///
/// `FileCleanupService` treats that check as a defensive backstop behind the
/// caller-supplied ghost-frame set; removing it leaves that set as the only
/// thing keeping a shared ghost file alive.
///
/// Both query entry points are overridden. `ClipsDao.isFileReferenced` happens
/// to delegate to [referencedFilenames] today, but nothing pins that: if it
/// ever queried directly, a single override would quietly restore the backstop
/// and the test would pass for the wrong reason.
class _BackstopBlindClipsDao extends ClipsDao {
  _BackstopBlindClipsDao(super.attachedDatabase);

  @override
  Future<Set<String>> referencedFilenames(Set<String> filenames) async =>
      const {};

  @override
  Future<bool> isFileReferenced(String filename) async => false;
}
