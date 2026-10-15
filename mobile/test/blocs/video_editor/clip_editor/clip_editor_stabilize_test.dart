// ABOUTME: Tests for toggling stabilization on a clip: the steadied render with
// ABOUTME: re-anchored trims, the restore, the green screen on top, failures.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/clip_stabilization.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_editor/clip_stabilization_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _key = ClipChromaKey(key: ChromaKey.greenScreen());

/// A long imported clip, trimmed to its middle: 8 s to 16 s of 20 s. The
/// stabilization window reaches a margin past both trims, 1.7 s to 20 s.
DivineVideoClip _longClip({String? videoPath}) =>
    DivineVideoClip(
      id: 'clip',
      video: EditorVideo.file(videoPath ?? '/documents/clip.mp4'),
      duration: const Duration(seconds: 20),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      recordingSha256: 'abc',
      forwardVideoPath: '/documents/clip_forward.mp4',
    ).copyWith(
      trimStart: const Duration(seconds: 8),
      trimEnd: const Duration(seconds: 4),
    );

/// Renders nothing; hands back the window the real service would render.
Future<StabilizedClipRender> _fakeStabilize({
  required DivineVideoClip sourceClip,
  required String renderId,
  void Function(double progress)? onProgress,
}) async {
  onProgress?.call(0.5);
  return StabilizedClipRender(
    video: EditorVideo.file('/documents/${sourceClip.id}_stabilized.mp4'),
    rawSourcePath:
        (sourceClip.chromaKey == null
            ? null
            : sourceClip.chromaKeySourcePath) ??
        sourceClip.requireVideo.file!.path,
    window: ClipStabilizationService.windowFor(sourceClip),
  );
}

void main() {
  group('$ClipEditorBloc stabilize', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('stabilize_test');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      StabilizeClipFn? stabilize,
      ChromaKeyBakeFn? bakeChromaKey,
      void Function()? onFinalClipInvalidated,
      DeferFileCleanupFn? deferFileCleanup,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
        saveClipToLibrary: ({required clip}) async => false,
        stabilizeClip: stabilize ?? _fakeStabilize,
        bakeChromaKey: bakeChromaKey,
        deferFileCleanup: deferFileCleanup,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    /// Toggles stabilization of [clipId] and waits for its own outcome, not
    /// one left in the state by an earlier toggle.
    Future<ClipEditorState> toggle(
      ClipEditorBloc bloc, {
      String clipId = 'clip',
    }) {
      final before = bloc.state.lastStabilizeResult;
      final done = bloc.stream.firstWhere(
        (state) =>
            !identical(state.lastStabilizeResult, before) &&
            !state.isStabilizing,
      );
      bloc.add(ClipEditorClipStabilizeRequested(clipId: clipId));
      return done;
    }

    test('swaps in the steadied render and re-anchors the trims', () async {
      var invalidated = 0;
      final progress = <double?>[];
      final bloc = seeded(
        [_longClip()],
        onFinalClipInvalidated: () => invalidated++,
      );
      final sub = bloc.stream.listen((s) {
        if (s.isStabilizing) progress.add(s.stabilizeProgress);
      });
      addTearDown(sub.cancel);

      final state = await toggle(bloc);
      final clip = state.clips.single;

      expect(state.lastStabilizeResult, isA<ClipStabilizeSuccess>());
      expect(
        (state.lastStabilizeResult! as ClipStabilizeSuccess).stabilized,
        isTrue,
      );
      expect(state.stabilizeProgress, isNull);
      expect(progress, contains(0.5));
      expect(invalidated, 1);

      expect(clip.video!.file!.path, '/documents/clip_stabilized.mp4');
      expect(clip.duration, const Duration(milliseconds: 18300));
      // The same 8–16 s still shows: 6.3 s into the render, 4 s before its end.
      expect(clip.trimStart, const Duration(milliseconds: 6300));
      expect(clip.trimEnd, const Duration(seconds: 4));
      expect(clip.sourceStartOffset, const Duration(milliseconds: 1700));
      expect(clip.forwardVideoPath, isNull);
      expect(
        clip.stabilization,
        const ClipStabilization(
          rawSourcePath: '/documents/clip.mp4',
          windowStart: Duration(milliseconds: 1700),
          sourceDuration: Duration(seconds: 20),
        ),
      );
      // The render has no manifest; it is signed against the recording.
      expect(clip.derivedFrom, const [
        C2paEditSource(path: '/documents/clip.mp4', recordingSha256: 'abc'),
      ]);
    });

    test('turning it off restores the clip it was steadied from', () async {
      final raw = File('${temp.path}/clip.mp4')..writeAsBytesSync([0]);
      final original = _longClip(videoPath: raw.path);
      final bloc = seeded([original]);

      await toggle(bloc);
      final state = await toggle(bloc);
      final clip = state.clips.single;

      expect(
        (state.lastStabilizeResult! as ClipStabilizeSuccess).stabilized,
        isFalse,
      );
      expect(clip.video!.file!.path, raw.path);
      expect(clip.duration, original.duration);
      expect(clip.trimStart, original.trimStart);
      expect(clip.trimEnd, original.trimEnd);
      expect(clip.sourceStartOffset, Duration.zero);
      expect(clip.stabilization, isNull);
      // The recording is its own source again.
      expect(clip.derivedFrom, isNull);
    });

    test('keeps a trim made after stabilizing when turned off', () async {
      final raw = File('${temp.path}/clip.mp4')..writeAsBytesSync([0]);
      final bloc = seeded([_longClip(videoPath: raw.path)]);
      final steadied = (await toggle(bloc)).clips.single;

      // Shows one more second at the start and half a second less at the end.
      bloc.add(
        ClipEditorClipUpdated(
          clipId: 'clip',
          clip: steadied.copyWith(
            trimStart: steadied.trimStart - const Duration(seconds: 1),
            trimEnd: steadied.trimEnd + const Duration(milliseconds: 500),
          ),
        ),
      );
      final clip = (await toggle(bloc)).clips.single;

      expect(clip.trimStart, const Duration(seconds: 7));
      expect(clip.trimEnd, const Duration(milliseconds: 4500));
    });

    test('applies a baked green screen again on top of the render', () async {
      final keyed = <String>[];
      final bloc = seeded(
        [
          _longClip().copyWith(
            video: EditorVideo.file('/documents/clip_keyed.mp4'),
            chromaKey: _key,
            chromaKeySourcePath: '/documents/clip.mp4',
          ),
        ],
        bakeChromaKey:
            ({
              required sourceClip,
              required chromaKey,
              required renderId,
            }) async {
              keyed.add(sourceClip.chromaKeySourcePath!);
              return (
                video: EditorVideo.file('/documents/clip_rekeyed.mp4'),
                source: sourceClip.chromaKeySourcePath!,
              );
            },
      );

      final clip = (await toggle(bloc)).clips.single;

      // Steadied from the footage under the key, then keyed again.
      expect(keyed, ['/documents/clip_stabilized.mp4']);
      expect(clip.video!.file!.path, '/documents/clip_rekeyed.mp4');
      expect(clip.chromaKey, _key);
      expect(clip.chromaKeySourcePath, '/documents/clip_stabilized.mp4');
      expect(clip.stabilization!.rawSourcePath, '/documents/clip.mp4');
    });

    test('reports a clip without a local file', () async {
      final bloc = seeded([
        DivineVideoClip(
          id: 'remote',
          video: EditorVideo.network('https://example.com/clip.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      ]);
      final done = bloc.stream.firstWhere(
        (s) => s.lastStabilizeResult != null,
      );
      bloc.add(const ClipEditorClipStabilizeRequested(clipId: 'remote'));

      expect((await done).lastStabilizeResult, isA<ClipStabilizeNoLocalFile>());
    });

    test('reports a failed render and leaves the clip as it was', () async {
      final original = _longClip();
      final bloc = seeded(
        [original],
        stabilize: ({required sourceClip, required renderId, onProgress}) =>
            Future.error(Exception('decoder failed')),
      );

      final state = await toggle(bloc);

      expect(state.lastStabilizeResult, isA<ClipStabilizeFailure>());
      expect(state.isStabilizing, isFalse);
      expect(state.clips.single.video!.file!.path, '/documents/clip.mp4');
      expect(state.clips.single.stabilization, isNull);
    });

    test('fails to turn off when the unstabilized footage is gone', () async {
      final bloc = seeded([_longClip(videoPath: '${temp.path}/missing.mp4')]);
      await toggle(bloc);

      final state = await toggle(bloc);

      expect(state.lastStabilizeResult, isA<ClipStabilizeFailure>());
      expect(state.clips.single.stabilization, isNotNull);
    });

    test('drops the render when the clip was removed meanwhile', () async {
      final release = Completer<void>();
      final cleaned = <String?>[];
      final bloc = seeded(
        [_longClip(), _longClip().copyWith(id: 'other')],
        deferFileCleanup: cleaned.addAll,
        stabilize:
            ({required sourceClip, required renderId, onProgress}) async {
              await release.future;
              return _fakeStabilize(sourceClip: sourceClip, renderId: renderId);
            },
      );
      final done = bloc.stream.firstWhere(
        (s) => s.lastStabilizeResult is ClipStabilizeDiscarded,
      );
      bloc.add(const ClipEditorClipStabilizeRequested(clipId: 'clip'));
      await bloc.stream.firstWhere((s) => s.isStabilizing);
      bloc.add(const ClipEditorClipRemoved('clip'));
      await bloc.stream.firstWhere((s) => s.clips.length == 1);
      release.complete();

      final state = await done;
      expect(state.clips.single.id, 'other');
      expect(cleaned, contains('/documents/clip_stabilized.mp4'));
    });
  });
}
