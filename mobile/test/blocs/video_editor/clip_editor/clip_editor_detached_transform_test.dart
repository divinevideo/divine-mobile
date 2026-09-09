// ABOUTME: Tests for cropping a clip that already left the timeline — the
// ABOUTME: render, the re-proportioned result, and the failure paths

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo, ExportTransform;

DivineVideoClip _detachedClip({
  String? forwardVideoPath,
  ClipChromaKey? chromaKey,
}) => DivineVideoClip(
  id: 'detached-1',
  video: EditorVideo.file('/documents/detached-1.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  forwardVideoPath: forwardVideoPath,
  chromaKey: chromaKey,
);

const _transform = ExportTransform(x: 0, y: 0, width: 400, height: 400);

void main() {
  group('$ClipEditorBloc detached-clip transform', () {
    ClipEditorBloc buildBloc({
      TransformClipFn? transformClip,
      MeasureAspectRatioFn? measureAspectRatio,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        // Defaults to a throwing render so a test that does not wire one up
        // cannot silently pass through the success path.
        transformClip:
            transformClip ??
            ({required sourceClip, required transform, required renderId}) =>
                throw StateError('no render wired up'),
        measureAspectRatio: measureAspectRatio ?? (_) async => 1,
      );
      addTearDown(bloc.close);
      return bloc;
    }

    /// The result of the next detached-clip transform this bloc completes.
    Future<DetachedClipTransformResult> resultOf(ClipEditorBloc bloc) => bloc
        .stream
        .map((state) => state.lastDetachedClipTransformResult)
        .where((result) => result != null)
        .cast<DetachedClipTransformResult>()
        .first;

    test('swaps in the rendered file and the shape it came out', () async {
      final bloc = buildBloc(
        transformClip:
            ({required sourceClip, required transform, required renderId}) =>
                Future.value(EditorVideo.file('/documents/cropped.mp4')),
        measureAspectRatio: (_) async => 1,
      );
      final result = resultOf(bloc);

      bloc.add(
        ClipEditorDetachedClipTransformRequested(
          layerId: 'detached_detached-1',
          clip: _detachedClip(),
          transform: _transform,
        ),
      );

      final success = await result as DetachedClipTransformSuccess;
      expect(success.layerId, 'detached_detached-1');
      expect(success.clip.video?.file?.path, '/documents/cropped.mp4');
      // The layer is re-proportioned from this, so a crop that squared a 9:16
      // clip has to come back as square rather than as the ratio it went in at.
      expect(success.clip.originalAspectRatio, 1);
    });

    test(
      'keeps the old shape when the rendered file cannot be measured',
      () async {
        final bloc = buildBloc(
          transformClip:
              ({required sourceClip, required transform, required renderId}) =>
                  Future.value(EditorVideo.file('/documents/cropped.mp4')),
          measureAspectRatio: (_) async => null,
        );
        final result = resultOf(bloc);

        bloc.add(
          ClipEditorDetachedClipTransformRequested(
            layerId: 'detached_detached-1',
            clip: _detachedClip(),
            transform: _transform,
          ),
        );

        final success = await result as DetachedClipTransformSuccess;
        // An unreadable resolution must not collapse the layer to a default
        // ratio; the crop is still baked into the file either way.
        expect(success.clip.originalAspectRatio, 9 / 16);
      },
    );

    test('drops the caches that describe the pre-crop footage', () async {
      final bloc = buildBloc(
        transformClip:
            ({required sourceClip, required transform, required renderId}) =>
                Future.value(EditorVideo.file('/documents/cropped.mp4')),
      );
      final result = resultOf(bloc);

      bloc.add(
        ClipEditorDetachedClipTransformRequested(
          layerId: 'detached_detached-1',
          clip: _detachedClip(
            forwardVideoPath: '/documents/detached-1.mp4',
            chromaKey: const ClipChromaKey(key: ChromaKey()),
          ),
          transform: _transform,
        ),
      );

      final success = await result as DetachedClipTransformSuccess;
      // Both describe geometry the render just changed: reversing would
      // restore the uncropped file, and re-keying would drop the crop.
      expect(success.clip.forwardVideoPath, isNull);
      expect(success.clip.chromaKey, isNull);
    });

    test('reports a failure when the render throws', () async {
      final bloc = buildBloc();
      final result = resultOf(bloc);

      bloc.add(
        ClipEditorDetachedClipTransformRequested(
          layerId: 'detached_detached-1',
          clip: _detachedClip(),
          transform: _transform,
        ),
      );

      expect(await result, isA<DetachedClipTransformFailure>());
      expect(bloc.state.isTransforming, isFalse);
      expect(bloc.state.transformingClipId, isNull);
    });

    test('reports a failure without rendering when the file is gone', () async {
      var rendered = false;
      final bloc = buildBloc(
        transformClip:
            ({
              required sourceClip,
              required transform,
              required renderId,
            }) async {
              rendered = true;
              return EditorVideo.file('/documents/cropped.mp4');
            },
      );
      final result = resultOf(bloc);

      bloc.add(
        ClipEditorDetachedClipTransformRequested(
          layerId: 'detached_detached-1',
          clip: DivineVideoClip(
            id: 'detached-1',
            // A clip whose media never resolved to a local file: nothing to
            // hand the renderer, and the layer keeps what it has.
            video: EditorVideo.network('https://example.com/detached-1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
          transform: _transform,
        ),
      );

      expect(await result, isA<DetachedClipTransformFailure>());
      expect(rendered, isFalse);
    });

    test('runs the render under a progress id of its own', () async {
      final renderIds = <String>[];
      final bloc = buildBloc(
        transformClip:
            ({
              required sourceClip,
              required transform,
              required renderId,
            }) async {
              renderIds.add(renderId);
              return EditorVideo.file('/documents/cropped.mp4');
            },
      );

      final transforming = bloc.stream
          .map((state) => state.transformingClipId)
          .where((id) => id != null)
          .first;
      final result = resultOf(bloc);

      bloc.add(
        ClipEditorDetachedClipTransformRequested(
          layerId: 'detached_detached-1',
          clip: _detachedClip(),
          transform: _transform,
        ),
      );

      // Namespaced away from a timeline clip's `<clipId>_transform`, so the
      // two cannot share a progress stream or cancel one another.
      expect(await transforming, 'detached-1_detached_transform');
      await result;
      expect(renderIds, ['detached-1_detached_transform']);
    });
  });
}
