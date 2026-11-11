// ABOUTME: Tests for putting a detached clip back onto the timeline — into
// ABOUTME: its placeholder's slot, or at the playhead once that is gone, with
// ABOUTME: the color mask it had baked in

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_thumbnail_service.dart'
    show ThumbnailFileResult;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 2),
  double originalAspectRatio = 9 / 16,
  model.AspectRatio targetAspectRatio = .vertical,
  bool isPlaceholder = false,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: targetAspectRatio,
  originalAspectRatio: originalAspectRatio,
  isPlaceholder: isPlaceholder,
);

void main() {
  group('$ClipEditorBloc reattach', () {
    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      MeasureAspectRatioFn? measureAspectRatio,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        measureAspectRatio: measureAspectRatio ?? (_) async => 9 / 16,
        extractPoster: ({required videoPath, required timestamp}) async =>
            ThumbnailFileResult(
              path: videoPath.replaceAll('.mp4', '_poster.jpg'),
              timestamp: timestamp,
            ),
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    test('takes the slot its placeholder still holds', () async {
      final bloc = seeded([
        _clip('a'),
        _clip('placeholder_1', isPlaceholder: true),
        _clip('c'),
      ]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          // The playhead points elsewhere; the slot wins.
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
      final result = state.lastDetachedClipReattachResult!;
      // The widget layer removes this layer and rebases markers against the
      // list as it was.
      expect(result.layerId, 'detached_b');
      expect(result.previousClips.map((c) => c.id), [
        'a',
        'placeholder_1',
        'c',
      ]);
    });

    test('joins at the playhead once its placeholder is gone', () async {
      final bloc = seeded([_clip('a'), _clip('c')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: const Duration(seconds: 3),
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      // The playhead sits inside `c`, so the clip goes in right after it.
      expect(state.clips.map((c) => c.id), ['a', 'c', 'b']);
      expect(state.currentClipIndex, 2);
    });

    test('brings back only the stretch its layer showed', () async {
      final bloc = seeded([_clip('a')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b', duration: const Duration(seconds: 4)),
          playhead: const Duration(seconds: 2),
          sourceOffset: const Duration(seconds: 1),
          window: const Duration(seconds: 2),
        ),
      );
      final state = await bloc.stream.first;

      final clip = state.clips.last;
      expect(clip.trimStart, const Duration(seconds: 1));
      expect(clip.playbackDuration, const Duration(seconds: 2));
    });

    test('fits its frames by the shape the file has now', () async {
      final bloc = seeded([
        _clip('a'),
      ], measureAspectRatio: (_) async => 1);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: const Duration(seconds: 2),
        ),
      );
      final state = await bloc.stream.first;

      // Cropped square on the canvas: the preview has to cover the frame with
      // square frames, not stretch them to the recording's 9:16.
      expect(state.clips.last.videoAspectRatio, 1);
    });

    test('keeps the canvas shape when it lands in front', () async {
      final bloc = seeded([
        _clip('placeholder_1', isPlaceholder: true),
        _clip('c'),
      ]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          // A canvas crop rewrote this clip's ratio to its own square shape.
          clip: _clip('b', originalAspectRatio: 1),
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      // The first clip's ratio is the canvas coordinate system; taking the
      // square one would move every other layer.
      expect(state.clips.first.id, 'b');
      expect(state.clips.first.originalAspectRatio, 9 / 16);
    });

    test('takes the shape the video has now, which a switch between square '
        'and 9:16 can have changed since it left', () async {
      final bloc = seeded([
        _clip(
          'placeholder_1',
          isPlaceholder: true,
          targetAspectRatio: .square,
        ),
        _clip('c', targetAspectRatio: .square),
      ]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          // Detached while the video was still 9:16.
          clip: _clip('b'),
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      // In front, the 9:16 it left with would switch the video back.
      expect(state.clips.first.id, 'b');
      expect(state.clips.first.targetAspectRatio, model.AspectRatio.square);
    });

    test('gives a second copy of the same clip its own id', () async {
      final bloc = seeded([_clip('a'), _clip('b')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b_copy',
          // A duplicated layer carries the id of the clip already back.
          clip: _clip('b'),
          playhead: const Duration(seconds: 4),
        ),
      );
      final state = await bloc.stream.first;

      expect(state.clips, hasLength(3));
      expect(state.clips.map((c) => c.id).toSet(), hasLength(3));
    });

    test(
      'ignores a repeat request for a layer whose clip is already back',
      () async {
        final bloc = seeded([
          _clip('a'),
          _clip('placeholder_1', isPlaceholder: true),
          _clip('c'),
        ]);
        await bloc.stream.first;
        final request = ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        );

        // Two taps before the layer has left the canvas: the second request is
        // queued behind the first, so it arrives with the clip already back.
        bloc
          ..add(request)
          ..add(request);
        await pumpEventQueue();

        expect(bloc.state.clips.map((c) => c.id), ['a', 'b', 'c']);
      },
    );

    test(
      'takes the same layer again once its clip has left the timeline',
      () async {
        final before = [
          _clip('a'),
          _clip('placeholder_1', isPlaceholder: true),
          _clip('c'),
        ];
        final bloc = seeded(before);
        await bloc.stream.first;
        final request = ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        );

        bloc.add(request);
        await pumpEventQueue();
        expect(bloc.state.clips.map((c) => c.id), ['a', 'b', 'c']);

        // Undo puts the layer back on the canvas and the slot back on the
        // timeline, so sending it back again is a new request, not a repeat.
        bloc.add(ClipEditorInitialized(before));
        await pumpEventQueue();
        expect(bloc.state.clips.map((c) => c.id), ['a', 'placeholder_1', 'c']);

        bloc.add(request);
        await pumpEventQueue();

        expect(bloc.state.clips.map((c) => c.id), ['a', 'b', 'c']);
      },
    );

    group('with a color mask taken off on detach', () {
      const key = ClipChromaKey(key: ChromaKey.greenScreen());
      late Directory documents;
      late String sourcePath;
      late String bakedPath;

      setUp(() async {
        documents = await Directory.systemTemp.createTemp('reattach_chroma');
        sourcePath = '${documents.path}/b_unkeyed.mp4';
        bakedPath = '${documents.path}/b_keyed.mp4';
        await File(sourcePath).writeAsBytes(const [0]);
        await File(bakedPath).writeAsBytes(const [0]);
      });

      tearDown(() async {
        if (documents.existsSync()) await documents.delete(recursive: true);
      });

      /// The clip as the layer plays it: the footage the key was baked from.
      DivineVideoClip unkeyed() => _clip('b').copyWith(
        video: EditorVideo.file(sourcePath),
        thumbnailPath: '${documents.path}/b_unkeyed_poster.jpg',
        derivedFrom: [C2paEditSource(path: sourcePath)],
      );

      DetachedClipBakedChromaKey baked() => DetachedClipBakedChromaKey(
        videoPath: bakedPath,
        sourcePath: sourcePath,
        chromaKey: key,
        thumbnailPath: '${documents.path}/b_keyed_poster.jpg',
      );

      Future<DivineVideoClip> reattach({
        DivineVideoClip? clip,
        ClipChromaKey? chromaKey = key,
      }) async {
        final bloc = seeded([_clip('a')]);
        await bloc.stream.first;
        bloc.add(
          ClipEditorDetachedClipReattachRequested(
            layerId: 'detached_b',
            clip: clip ?? unkeyed(),
            playhead: const Duration(seconds: 2),
            chromaKey: chromaKey,
            bakedChromaKey: baked(),
          ),
        );
        final state = await bloc.stream.first;
        return state.clips.last;
      }

      test('swaps the baked file back in', () async {
        final clip = await reattach();

        // A timeline clip only carries a key baked in, and the layer kept the
        // file that has it, so nothing is rendered again.
        expect(clip.video?.file?.path, bakedPath);
        expect(clip.chromaKey, key);
        expect(clip.chromaKeySourcePath, sourcePath);
        expect(clip.thumbnailPath, '${documents.path}/b_keyed_poster.jpg');
        expect(clip.derivedFrom, [C2paEditSource(path: sourcePath)]);
      });

      test('brings back the baked key when the live one was changed', () async {
        final clip = await reattach(
          chromaKey: key.withKeySettings(similarity: 0.6),
        );

        // The changed settings would need a render; the baked key is the
        // nearest the clip can carry without one.
        expect(clip.video?.file?.path, bakedPath);
        expect(clip.chromaKey, key);
      });

      test('comes back without a key once the layer lost its key', () async {
        final clip = await reattach(chromaKey: null);

        expect(clip.video?.file?.path, sourcePath);
        expect(clip.chromaKey, isNull);
      });

      test(
        'comes back without a key once a crop replaced the footage',
        () async {
          final cropped = unkeyed().copyWith(
            video: EditorVideo.file('${documents.path}/b_cropped.mp4'),
          );

          final clip = await reattach(clip: cropped);

          // The baked file still shows the uncropped frame.
          expect(clip.video?.file?.path, '${documents.path}/b_cropped.mp4');
          expect(clip.chromaKey, isNull);
        },
      );

      test('comes back without a key when the baked file is gone', () async {
        await File(bakedPath).delete();

        final clip = await reattach();

        expect(clip.video?.file?.path, sourcePath);
        expect(clip.chromaKey, isNull);
      });

      test('round-trips a detached clip through its layer', () async {
        final keyed = _clip('b').copyWith(
          video: EditorVideo.file(bakedPath),
          thumbnailPath: '${documents.path}/b_keyed_poster.jpg',
          chromaKey: key,
          chromaKeySourcePath: sourcePath,
          derivedFrom: [C2paEditSource(path: sourcePath)],
        );
        final bloc = seeded([_clip('a'), keyed, _clip('c')]);
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        final detached = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );
        final result = detached.lastDetachResult! as ClipDetachSuccess;
        // What the scaffold writes onto the layer, read back the way a draft
        // reopens it.
        final meta = DetachedClipLayerData(
          clip: result.detachedClip,
          layerId: 'detached_b',
          chromaKey: result.bakedChromaKey?.chromaKey,
          bakedChromaKey: result.bakedChromaKey,
        ).toMeta();
        final layer = DetachedClipLayerData.fromMeta(meta, documents.path)!;
        expect(layer.clip.video?.file?.path, sourcePath);
        expect(layer.chromaKey, key);

        bloc.add(
          ClipEditorDetachedClipReattachRequested(
            layerId: 'detached_b',
            clip: layer.clip,
            playhead: const Duration(seconds: 2),
            chromaKey: layer.chromaKey,
            bakedChromaKey: layer.bakedChromaKey,
          ),
        );
        final back = await bloc.stream.firstWhere(
          (s) => s.lastDetachedClipReattachResult != null,
        );

        final clip = back.clips[1];
        expect(back.clips.map((c) => c.id), ['a', 'b', 'c']);
        expect(clip.video?.file?.path, bakedPath);
        expect(clip.chromaKey, key);
        expect(clip.chromaKeySourcePath, sourcePath);
        expect(clip.thumbnailPath, '${documents.path}/b_keyed_poster.jpg');
        expect(clip.derivedFrom, keyed.derivedFrom);
      });

      test('puts an image backdrop back among the clip sources', () async {
        final backdrop = '${documents.path}/backdrop.jpg';
        final imageKey = key.withImageBackground(backdrop);
        final footage = C2paEditSource(path: sourcePath);
        final image = C2paEditSource(
          path: backdrop,
          kind: C2paSourceKind.image,
        );
        final keyed = _clip('b').copyWith(
          video: EditorVideo.file(bakedPath),
          chromaKey: imageKey,
          chromaKeySourcePath: sourcePath,
          derivedFrom: [footage, image],
        );
        final bloc = seeded([_clip('a'), keyed, _clip('c')]);
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        final detached = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );
        final result = detached.lastDetachResult! as ClipDetachSuccess;
        // The image fill moves onto the layer with the key, so the footage
        // the layer plays is made from the take alone.
        expect(result.detachedClip.video?.file?.path, sourcePath);
        expect(result.detachedClip.derivedFrom, [footage]);

        bloc.add(
          ClipEditorDetachedClipReattachRequested(
            layerId: 'detached_b',
            clip: result.detachedClip,
            playhead: const Duration(seconds: 2),
            chromaKey: result.bakedChromaKey?.chromaKey,
            bakedChromaKey: result.bakedChromaKey,
          ),
        );
        final back = await bloc.stream.firstWhere(
          (s) => s.lastDetachedClipReattachResult != null,
        );

        final clip = back.clips[1];
        expect(clip.video?.file?.path, bakedPath);
        expect(clip.chromaKey, imageKey);
        expect(clip.derivedFrom, [footage, image]);
      });
    });
  });
}
