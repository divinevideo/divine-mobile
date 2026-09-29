// ABOUTME: Regression tests for deleting a library clip that another clip's
// ABOUTME: chroma key still plays as its backdrop video

import 'dart:io';
import 'dart:ui' show Size;

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

/// Answers metadata reads so a render task can be built without the plugin.
class _FakeProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: nothing in these tests follows render progress.
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async => VideoMetadata(
    duration: const Duration(seconds: 3),
    extension: 'mp4',
    fileSize: 1024,
    resolution: const Size(1080, 1920),
    rotation: 0,
    bitrate: 1000,
  );
}

void main() {
  group(ClipLibraryService, () {
    late Directory documentsDir;
    late PathProviderPlatform originalPathProvider;
    late ProVideoEditor originalProVideoEditor;
    late AppDatabase database;
    late ClipLibraryService service;

    setUp(() {
      documentsDir = Directory.systemTemp.createTempSync('backdrop_video');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documentsDir.path);
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _FakeProVideoEditor();
      database = AppDatabase.test(NativeDatabase.memory());
      service = ClipLibraryService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        clipCategoriesDao: database.clipCategoriesDao,
      );
    });

    tearDown(() async {
      await database.close();
      ProVideoEditor.instance = originalProVideoEditor;
      PathProviderPlatform.instance = originalPathProvider;
      if (documentsDir.existsSync()) {
        documentsDir.deleteSync(recursive: true);
      }
    });

    File writeVideo(String name) {
      final file = File(p.join(documentsDir.path, name));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(const [0, 1, 2, 3]);
      return file;
    }

    DivineVideoClip libraryClip(
      String id,
      File video, {
      ClipChromaKey? chromaKey,
      String? chromaKeySourcePath,
      ClipChromaKey? captureChromaKey,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file(video.path),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      chromaKey: chromaKey,
      chromaKeySourcePath: chromaKeySourcePath,
      captureChromaKey: captureChromaKey,
    );

    /// A library clip picked as a chroma-key backdrop, and a take recorded in
    /// chroma key mode in front of it whose key has not been baked yet.
    Future<({File backdrop, DivineVideoClip backdropClip, String takeId})>
    savePendingTakeWithVideoBackdrop() async {
      final backdrop = writeVideo('backdrop.mp4');
      final backdropClip = libraryClip('backdrop_clip', backdrop);
      final take = libraryClip(
        'chroma_take',
        writeVideo('chroma_take_raw.mp4'),
        captureChromaKey: const ClipChromaKey(
          key: ChromaKey.greenScreen(),
        ).withVideoBackground(backdrop.path),
      );
      await service.saveClip(backdropClip);
      await service.saveClip(take);

      final stored = await service.getClipById(take.id);
      expect(stored!.hasPendingCaptureChromaKey, isTrue);
      expect(stored.captureChromaKey!.backgroundVideoPath, backdrop.path);
      expect(backdrop.existsSync(), isTrue);
      return (backdrop: backdrop, backdropClip: backdropClip, takeId: take.id);
    }

    group('hardDelete', () {
      test(
        'keeps the video a pending recorded key plays behind the subject',
        () async {
          final (:backdrop, :backdropClip, :takeId) =
              await savePendingTakeWithVideoBackdrop();

          await service.hardDelete(backdropClip.id);

          expect(await service.getClipById(backdropClip.id), isNull);
          expect(
            backdrop.existsSync(),
            isTrue,
            reason:
                'the take $takeId still waits to bake its recorded key over '
                'this video',
          );
        },
      );

      test(
        'leaves the pending recorded key bakeable once its backdrop clip is '
        'deleted',
        () async {
          final (:backdrop, :backdropClip, :takeId) =
              await savePendingTakeWithVideoBackdrop();

          await service.hardDelete(backdropClip.id);

          final take = await service.getClipById(takeId);
          await expectLater(
            ChromaKeyBakeService.buildTask(
              renderId: ChromaKeyBakeService.renderIdFor(takeId),
              sourceClip: take!,
              inputVideo: take.video!,
              chromaKey: take.captureChromaKey!,
            ),
            completion(
              isA<VideoRenderData>().having(
                (task) => task.composition?.layers,
                'composition layers',
                hasLength(2),
              ),
            ),
          );
        },
      );

      test(
        'keeps the video a baked key was rendered over, for re-keying',
        () async {
          final backdrop = writeVideo('backdrop.mp4');
          final backdropClip = libraryClip('backdrop_clip', backdrop);
          final raw = writeVideo('keyed_take_raw.mp4');
          final keyedTake = libraryClip(
            'keyed_take',
            writeVideo('keyed_take_chromakey.mp4'),
            chromaKey: const ClipChromaKey(
              key: ChromaKey.greenScreen(),
            ).withVideoBackground(backdrop.path),
            chromaKeySourcePath: raw.path,
          );
          await service.saveClip(backdropClip);
          await service.saveClip(keyedTake);
          expect(
            (await service.getClipById(
              keyedTake.id,
            ))!.chromaKey!.backgroundVideoPath,
            backdrop.path,
          );

          await service.hardDelete(backdropClip.id);

          expect(await service.getClipById(backdropClip.id), isNull);
          expect(
            backdrop.existsSync(),
            isTrue,
            reason:
                're-keying ${keyedTake.id} from its raw source renders this '
                'video behind the subject again',
          );
        },
      );
    });

    group('purgeExpiredTrash', () {
      test(
        'keeps the video a pending recorded key plays behind the subject',
        () async {
          final (:backdrop, :backdropClip, :takeId) =
              await savePendingTakeWithVideoBackdrop();

          // An ordinary delete, then the retention window runs out.
          expect(await service.softDelete(backdropClip.id), isTrue);
          await database.customStatement(
            'UPDATE clips SET deleted_at = ? WHERE id = ?',
            [
              DateTime.now()
                      .subtract(
                        ClipLibraryService.trashRetention +
                            const Duration(days: 1),
                      )
                      .millisecondsSinceEpoch ~/
                  1000,
              backdropClip.id,
            ],
          );

          expect(await service.purgeExpiredTrash(), 1);
          expect(
            backdrop.existsSync(),
            isTrue,
            reason:
                'the take $takeId still waits to bake its recorded key over '
                'this video',
          );
        },
      );
    });
  });
}
