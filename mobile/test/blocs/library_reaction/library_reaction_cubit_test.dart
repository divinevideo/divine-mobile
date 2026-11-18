// ABOUTME: Reaction media preparation, progress, geometry, and file ownership.
// ABOUTME: Uses boundary fakes to verify rendering handoff without native plugins.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/library_reaction/library_reaction_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

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
  group(LibraryReactionCubit, () {
    test(
      'combines in order and publishes progress with correct encoded geometry',
      () async {
        final gate = Completer<DivineVideoClip?>();
        final requested = <String>[];
        final states = <LibraryReactionStatus>[];
        final cubit = LibraryReactionCubit(
          deferFileCleanup: (_) {},
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
  });
}
