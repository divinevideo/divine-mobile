// ABOUTME: Reaction media preparation, progress, geometry, and file ownership.
// ABOUTME: Uses boundary fakes to verify rendering handoff without native plugins.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/library_reaction/library_reaction_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

import '../../mocks/mock_path_provider_platform.dart';

Future<DivineVideoClip> _noBake(DivineVideoClip clip) async => clip;

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 9 / 16,
  videoAspectRatio: 9 / 16,
  thumbnailPath: '/documents/$id.jpg',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LibraryReactionCubit, () {
    test('publishes preparation until extraction completes before allowing a merge', () async {
      var merged = false;
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        bakeCapturedChromaKey: _noBake,
        cleanupFiles: (_) async {},
        mergeTakes: ({required clips, required renderId}) async {
          merged = true;
          return _clip('merged');
        },
        extractThumbnail: (path) async =>
            (path: '$path.jpg', timestamp: Duration.zero),
      );
      addTearDown(cubit.close);
      final gate = Completer<List<DivineVideoClip>>();
      final result = cubit.prepareTakes(() => gate.future);
      expect(cubit.state.status, LibraryReactionStatus.preparing);
      expect(cubit.state.isBusy, isTrue);
      expect(await cubit.combine([_clip('one'), _clip('two')]), isNull);
      expect(merged, isFalse);
      expect(cubit.state.status, LibraryReactionStatus.preparing);
      gate.complete([_clip('one')]);
      expect((await result)!.map((clip) => clip.id), ['one']);
      expect(cubit.state.status, LibraryReactionStatus.idle);
      expect(cubit.state.isBusy, isFalse);
    });

    test('a closed flow never receives a late prepared take', () async {
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        bakeCapturedChromaKey: _noBake,
        cleanupFiles: (_) async {},
      );
      final gate = Completer<List<DivineVideoClip>>();
      final result = cubit.prepareTakes(() => gate.future);
      expect(cubit.state.status, LibraryReactionStatus.preparing);
      await cubit.close();
      gate.complete([_clip('one')]);
      expect(await result, isNull);
    });

    test(
      'library-owned layout survives autosave deletion and real cleanup',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'reaction_layout_',
        );
        final database = AppDatabase.test(NativeDatabase.memory());
        final previousPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = MockPathProviderPlatform()
          ..setApplicationDocumentsPath(directory.path);
        resetCachedDocumentsPath();
        final deferred = <String?>[];
        final cubit = LibraryReactionCubit(
          deferFileCleanup: deferred.addAll,
          bakeCapturedChromaKey: _noBake,
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );
        addTearDown(() async {
          await cubit.close();
          await database.close();
          PathProviderPlatform.instance = previousPathProvider;
          resetCachedDocumentsPath();
          if (directory.existsSync()) directory.deleteSync(recursive: true);
        });
        final video = File(p.join(directory.path, 'layout.mp4'))
          ..writeAsBytesSync([1, 2, 3]);
        final poster = File(p.join(directory.path, 'layout.jpg'))
          ..writeAsBytesSync([4, 5, 6]);
        final layout = _clip('layout').copyWith(
          video: EditorVideo.file(video.path),
          thumbnailPath: poster.path,
        );
        final autosave = DivineVideoDraft.create(
          id: VideoEditorConstants.autoSaveId,
          clips: [layout],
          title: '',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
        );
        expect(autosave.hasBeenEdited, isFalse);
        final drafts = DraftStorageService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
        );
        final library = ClipLibraryService(
          clipsDao: database.clipsDao,
          draftsDao: database.draftsDao,
          clipCategoriesDao: database.clipCategoriesDao,
        );
        await drafts.saveDraft(autosave);
        await library.saveClip(layout);
        await drafts.deleteDraft(VideoEditorConstants.autoSaveId);
        expect(
          await database.draftsDao.getDraftById(
            VideoEditorConstants.autoSaveId,
          ),
          isNull,
        );
        expect(await database.clipsDao.getClipById(layout.id), isNotNull);
        final paths = [video.path, poster.path];
        await cubit.cleanupFiles(paths);
        expect(video.existsSync(), isTrue);
        expect(poster.existsSync(), isTrue);
        expect(deferred, isEmpty);
        await database.clipsDao.deleteClip(layout.id);
        await cubit.cleanupFiles(paths);
        expect(video.existsSync(), isFalse);
        expect(poster.existsSync(), isFalse);
      },
    );

    test(
      'waits for every pending capture key before merging camera cuts',
      () async {
        const key = ClipChromaKey(key: ChromaKey());
        final gate = Completer<DivineVideoClip>();
        final baked = <String>[];
        List<DivineVideoClip>? mergeInputs;
        final one = _clip('one').copyWith(captureChromaKey: key);
        final two = _clip('two').copyWith(captureChromaKey: key);
        DivineVideoClip keyed(DivineVideoClip clip) => clip.copyWith(
          video: EditorVideo.file('/documents/${clip.id}-keyed.mp4'),
          chromaKey: key,
          chromaKeySourcePath: clip.video!.file!.path,
          clearCaptureChromaKey: true,
        );
        final cubit = LibraryReactionCubit(
          deferFileCleanup: (_) {},
          cleanupFiles: (_) async {},
          bakeCapturedChromaKey: (clip) {
            baked.add(clip.id);
            return clip.id == one.id ? gate.future : Future.value(keyed(clip));
          },
          mergeTakes: ({required clips, required renderId}) async {
            mergeInputs = clips;
            return _clip('merged');
          },
          extractThumbnail: (path) async =>
              (path: '$path.jpg', timestamp: Duration.zero),
        );
        addTearDown(cubit.close);
        final result = cubit.combine([one, two]);
        await pumpEventQueue();
        expect(mergeInputs, isNull);
        gate.complete(keyed(one));
        expect(await result, isNotNull);
        expect(baked, ['one', 'two']);
        expect(mergeInputs!.map((clip) => clip.video!.file!.path), [
          '/documents/one-keyed.mp4',
          '/documents/two-keyed.mp4',
        ]);
        expect(
          mergeInputs!.any((clip) => clip.hasPendingCaptureChromaKey),
          isFalse,
        );
      },
    );

    test('does not merge raw cuts when a capture-key bake fails', () async {
      var merged = false;
      final error = StateError('capture bake failed');
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        cleanupFiles: (_) async {},
        bakeCapturedChromaKey: (_) async => throw error,
        mergeTakes: ({required clips, required renderId}) async {
          merged = true;
          return _clip('merged');
        },
      );
      addTearDown(cubit.close);
      expect(
        await cubit.combine([
          _clip('one').copyWith(
            captureChromaKey: const ClipChromaKey(key: ChromaKey()),
          ),
          _clip('two'),
        ]),
        isNull,
      );
      expect(merged, isFalse);
      expect(cubit.state.status, LibraryReactionStatus.failure);
      expect(cubit.state.generatedPaths, isEmpty);
    });

    test(
      'combines in order and publishes progress with correct encoded geometry',
      () async {
        final gate = Completer<DivineVideoClip?>();
        final requested = <String>[];
        final states = <LibraryReactionStatus>[];
        final cubit = LibraryReactionCubit(
          deferFileCleanup: (_) {},
          bakeCapturedChromaKey: _noBake,
          cleanupFiles: (_) async {},
          mergeTakes: ({required clips, required renderId}) {
            requested.addAll(clips.map((clip) => clip.id));
            return gate.future;
          },
          extractThumbnail: (path) async =>
              (path: '$path.jpg', timestamp: Duration.zero),
        );
        final subscription = cubit.stream
            .map((state) => state.status)
            .distinct()
            .listen(states.add);
        final result = cubit.combine([_clip('one'), _clip('two')]);
        expect(cubit.state.status, LibraryReactionStatus.merging);
        gate.complete(
          _clip('merged').copyWith(duration: const Duration(seconds: 4)),
        );
        final merged = await result;
        expect(requested, ['one', 'two']);
        expect(merged!.duration, const Duration(seconds: 4));
        expect(merged.videoAspectRatio, 1);
        expect(merged.originalAspectRatio, 9 / 16);
        expect(merged.thumbnailPath, '/documents/merged.mp4.jpg');
        await cubit.close();
        expect(states, [
          LibraryReactionStatus.merging,
          LibraryReactionStatus.idle,
        ]);
        await subscription.cancel();
      },
    );

    test('abandoned output cleans only generated video and poster', () async {
      final cleaned = <String>[];
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        bakeCapturedChromaKey: _noBake,
        cleanupFiles: (paths) async => cleaned.addAll(paths),
        mergeTakes: ({required clips, required renderId}) async =>
            _clip('merged'),
        extractThumbnail: (path) async =>
            (path: '$path.jpg', timestamp: Duration.zero),
      );
      expect(await cubit.combine([_clip('one'), _clip('two')]), isNotNull);
      await cubit.cleanupGeneratedFiles();
      expect(cleaned, ['/documents/merged.mp4', '/documents/merged.mp4.jpg']);
      await cubit.cleanupGeneratedFiles();
      expect(cleaned, hasLength(2));
      await cubit.close();
    });

    test(
      'adopted output transfers cleanup to the editor before teardown',
      () async {
        final deferred = <String?>[];
        final cleaned = <String>[];
        final cubit = LibraryReactionCubit(
          deferFileCleanup: deferred.addAll,
          bakeCapturedChromaKey: _noBake,
          cleanupFiles: (paths) async => cleaned.addAll(paths),
          mergeTakes: ({required clips, required renderId}) async =>
              _clip('merged'),
          extractThumbnail: (path) async =>
              (path: '$path.jpg', timestamp: Duration.zero),
        );
        expect(await cubit.combine([_clip('one'), _clip('two')]), isNotNull);
        cubit.adoptGeneratedFiles();
        expect(cubit.state.generatedPaths, isEmpty);
        expect(deferred, [
          '/documents/merged.mp4',
          '/documents/merged.mp4.jpg',
        ]);
        await cubit.cleanupGeneratedFiles();
        expect(cleaned, isEmpty);
        await cubit.close();
      },
    );

    test(
      'failed poster aborts the handoff and cleans the generated video',
      () async {
        final cleaned = <String>[];
        final cubit = LibraryReactionCubit(
          deferFileCleanup: (_) {},
          bakeCapturedChromaKey: _noBake,
          cleanupFiles: (paths) async => cleaned.addAll(paths),
          mergeTakes: ({required clips, required renderId}) async =>
              _clip('merged'),
          extractThumbnail: (_) async => null,
        );
        expect(await cubit.combine([_clip('one'), _clip('two')]), isNull);
        expect(cubit.state.status, LibraryReactionStatus.idle);
        await cubit.cleanupGeneratedFiles();
        expect(cleaned, ['/documents/merged.mp4']);
        await cubit.close();
      },
    );

    test('cleans a render that finishes after the flow closed it', () async {
      final gate = Completer<DivineVideoClip?>();
      final cleaned = <String>[];
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        bakeCapturedChromaKey: _noBake,
        cleanupFiles: (paths) async => cleaned.addAll(paths),
        mergeTakes: ({required clips, required renderId}) => gate.future,
        extractThumbnail: (path) async =>
            (path: '$path.jpg', timestamp: Duration.zero),
      );
      final result = cubit.combine([_clip('one'), _clip('two')]);
      await cubit.cleanupGeneratedFiles();
      await cubit.close();
      gate.complete(_clip('merged'));
      expect(await result, isNull);
      expect(cleaned, ['/documents/merged.mp4']);
    });

    test('cleans a poster that finishes after the flow closed it', () async {
      final gate = Completer<ReactionPoster?>();
      final cleaned = <String>[];
      final cubit = LibraryReactionCubit(
        deferFileCleanup: (_) {},
        bakeCapturedChromaKey: _noBake,
        cleanupFiles: (paths) async => cleaned.addAll(paths),
        mergeTakes: ({required clips, required renderId}) async =>
            _clip('merged'),
        extractThumbnail: (_) => gate.future,
      );
      final result = cubit.combine([_clip('one'), _clip('two')]);
      await pumpEventQueue();
      expect(cubit.state.generatedPaths, ['/documents/merged.mp4']);
      await cubit.close();
      gate.complete(
        (path: '/documents/merged.mp4.jpg', timestamp: Duration.zero),
      );
      expect(await result, isNull);
      expect(cleaned, [
        '/documents/merged.mp4',
        '/documents/merged.mp4.jpg',
      ]);
    });
  });
}
