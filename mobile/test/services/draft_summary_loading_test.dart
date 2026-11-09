// ABOUTME: Regression coverage for Library reads that must not decode histories.
// ABOUTME: Exercises real SQLite projections and media validation.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/draft_summary.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group('Library draft summaries', () {
    late AppDatabase db;
    late Directory directory;
    late PathProviderPlatform originalPaths;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('draft-summary-');
      originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(directory.path);
      db = AppDatabase.test(NativeDatabase.memory());
      await File('${directory.path}/clip.mp4').writeAsBytes([0]);
    });
    tearDown(() async {
      await db.close();
      PathProviderPlatform.instance = originalPaths;
      await directory.delete(recursive: true);
    });

    Future<void> seed({String history = 'opaque, not a history map'}) =>
        db.draftsDao.saveDraftWithClips(
          id: 'draft',
          title: 'Saved title',
          description: '',
          publishStatus: 'failed',
          createdAt: DateTime(2026),
          lastModified: DateTime(2026, 2),
          data: jsonEncode({'editorStateHistory': history}),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          customThumbnailPath: 'cover.jpg',
          clipDataList: [
            DraftClipData(
              id: 'clip',
              orderIndex: 0,
              durationMs: 6000,
              recordedAt: DateTime(2026),
              filePath: 'clip.mp4',
              data: jsonEncode({
                'id': 'clip',
                'filePath': 'clip.mp4',
                'durationMs': 6000,
                'recordedAt': DateTime(2026).toIso8601String(),
              }),
            ),
          ],
        );

    test('lists scalar metadata without decoding editor history', () async {
      await seed();
      final summaries = await DraftStorageService(
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      ).getDraftSummaries();
      expect(summaries, hasLength(1));
      expect(summaries.single.title, 'Saved title');
      expect(summaries.single.clipCount, 1);
      expect(summaries.single.canPost, isTrue);
      expect(
        summaries.single.coverThumbnailPath,
        '${directory.path}/cover.jpg',
      );
    });

    test('deletes a listed draft even when its history cannot load', () async {
      await seed();
      await File('${directory.path}/cover.jpg').writeAsBytes([0]);
      final service = DraftStorageService(
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      );
      expect(await service.getDraftSummaries(), hasLength(1));
      expect(await service.getDraftById('draft'), isNull);

      await service.deleteDraft('draft');

      expect(await db.draftsDao.getDraftById('draft'), isNull);
      expect(await db.clipsDao.getClipsByDraftId('draft'), isEmpty);
      expect(await service.getDraftSummaries(), isEmpty);
      expect(File('${directory.path}/clip.mp4').existsSync(), isFalse);
      expect(File('${directory.path}/cover.jpg').existsSync(), isFalse);
    });

    test("deleting an unreadable draft keeps another draft's media", () async {
      await seed();
      final service = DraftStorageService(
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      );
      final clip = DivineVideoClip(
        id: 'shared-clip',
        video: EditorVideo.file('${directory.path}/clip.mp4'),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2026),
        originalAspectRatio: 1,
        targetAspectRatio: .square,
      );
      await service.saveDraft(
        DivineVideoDraft.create(
          id: 'survivor',
          clips: [clip],
          title: 'Survivor',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
        ),
      );
      expect(await service.getDraftSummaries(), hasLength(2));

      await service.deleteDraft('draft');

      expect(await db.draftsDao.getDraftById('draft'), isNull);
      expect(await service.getValidatedDraftById('survivor'), isNotNull);
      expect(File('${directory.path}/clip.mp4').existsSync(), isTrue);
    });

    for (final scenario in [
      'source',
      'rendered',
      'stale',
      'missing-render',
      'custom',
      'stop-motion',
    ]) {
      test(
        'matches full-draft media and cover validation for $scenario',
        () async {
          for (final name in [
            'source.jpg',
            'render.mp4',
            'render.jpg',
            'still.jpg',
          ]) {
            await File('${directory.path}/$name').writeAsBytes([0]);
          }
          final service = DraftStorageService(
            draftsDao: db.draftsDao,
            clipsDao: db.clipsDao,
          );
          final clip = DivineVideoClip(
            id: 'clip',
            video: scenario == 'stop-motion'
                ? null
                : EditorVideo.file('${directory.path}/clip.mp4'),
            stopMotionFrames: scenario == 'stop-motion'
                ? [
                    StopMotionClipFrame(
                      path: '${directory.path}/missing.jpg',
                      duration: const Duration(seconds: 1),
                    ),
                    StopMotionClipFrame(
                      path: '${directory.path}/still.jpg',
                      duration: const Duration(seconds: 1),
                    ),
                  ]
                : null,
            thumbnailPath: '${directory.path}/source.jpg',
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2026),
            originalAspectRatio: 1,
            targetAspectRatio: .square,
          );
          final rendered = DivineVideoClip(
            id: 'render',
            video: EditorVideo.file('${directory.path}/render.mp4'),
            thumbnailPath: '${directory.path}/render.jpg',
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2026),
            originalAspectRatio: 1,
            targetAspectRatio: .square,
          );
          final draft =
              DivineVideoDraft.create(
                id: 'draft',
                clips: [clip],
                title: 'Saved title',
                description: '',
                hashtags: {},
                selectedApproach: 'video',
                finalRenderedClip: scenario == 'source' ? null : rendered,
                customThumbnailPath: scenario == 'custom'
                    ? '${directory.path}/custom.jpg'
                    : null,
              ).copyWith(
                finalRenderVersion: scenario == 'stale'
                    ? 1
                    : DivineVideoDraft.currentFinalRenderVersion,
              );
          await service.saveDraft(draft);
          if (scenario == 'missing-render') {
            await File('${directory.path}/render.mp4').delete();
          }
          final full = (await service.getAllDrafts()).single;
          final summary = (await service.getDraftSummaries()).single;
          expect(summary, DraftSummary.fromDraft(full));
        },
      );
    }

    test('hides missing media without deleting the saved draft', () async {
      await seed();
      await File('${directory.path}/clip.mp4').delete();
      expect(
        await DraftStorageService(
          draftsDao: db.draftsDao,
          clipsDao: db.clipsDao,
        ).getDraftSummaries(),
        isEmpty,
      );
      expect(await db.draftsDao.getDraftById('draft'), isNotNull);
    });
  });
}
