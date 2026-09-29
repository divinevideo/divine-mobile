// ABOUTME: Tests for baking the key clips were recorded with in chroma-key
// ABOUTME: mode — the per-clip swap, the skips, and a pass that partly fails.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/captured_chroma_key_baker.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart'
    show ThumbnailFileResult;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _recordedKey = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);

DivineVideoClip _clip(
  String id, {
  ClipChromaKey? captureChromaKey,
  String? videoPath,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file(videoPath ?? '/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/${id}_raw.jpg',
  captureChromaKey: captureChromaKey,
);

/// What the shared bake hands back: the take with its key burned in.
Future<DivineVideoClip> _keyed(DivineVideoClip clip) async => clip.copyWith(
  video: EditorVideo.file('/documents/${clip.id}_keyed.mp4'),
  chromaKey: clip.captureChromaKey,
  chromaKeySourcePath: clip.video!.file!.path,
  clearCaptureChromaKey: true,
  thumbnailPath: '/documents/${clip.id}_keyed.jpg',
);

void main() {
  group('$ClipEditorBloc recorded chroma key', () {
    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      required BakeCapturedChromaKeyFn? bake,
      void Function()? onFinalClipInvalidated,
      DeferFileCleanupFn? deferFileCleanup,
      ChromaKeyBakeFn? bakeChromaKey,
      CapturedChromaKeysBakedFn? onCapturedChromaKeysBaked,
      ExtractPosterFn? extractPoster,
      MergeClipsFn? mergeClips,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
        saveClipToLibrary: ({required clip}) async => false,
        deferFileCleanup: deferFileCleanup,
        bakeCapturedChromaKey: bake,
        bakeChromaKey: bakeChromaKey,
        onCapturedChromaKeysBaked: onCapturedChromaKeysBaked,
        extractPoster:
            extractPoster ??
            ({required videoPath, required timestamp}) async => null,
        mergeClips: mergeClips,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    /// Waits for the pass to report how it ended.
    Future<ClipEditorState> bakeAll(ClipEditorBloc bloc) async {
      final done = bloc.stream.firstWhere(
        (state) => state.lastCapturedChromaKeyBakeResult != null,
      );
      bloc.add(const ClipEditorCapturedChromaKeysBakeRequested());
      return done;
    }

    test('swaps each waiting take for its keyed version', () async {
      final asked = <String>[];
      var invalidated = 0;
      final handedOver = <List<String>>[];
      final bloc = seeded(
        [
          _clip('a', captureChromaKey: _recordedKey),
          _clip('b', captureChromaKey: _recordedKey),
        ],
        bake: (clip) {
          asked.add(clip.id);
          return _keyed(clip);
        },
        onFinalClipInvalidated: () => invalidated++,
        onCapturedChromaKeysBaked: (keyed) =>
            handedOver.add([for (final clip in keyed) clip.id]),
      );

      final state = await bakeAll(bloc);

      expect(asked, ['a', 'b']);
      for (final clip in state.clips) {
        expect(
          clip.video?.file?.path,
          '/documents/${clip.id}_keyed.mp4',
          reason: clip.id,
        );
        // Recorded exactly as a confirmed chroma key screen would, so the clip
        // re-opens on these settings and re-keys from the raw take.
        expect(clip.chromaKey, _recordedKey);
        expect(clip.chromaKeySourcePath, '/documents/${clip.id}.mp4');
        expect(clip.captureChromaKey, isNull);
        // The raw poster shows the wall the key removed.
        expect(clip.thumbnailPath, '/documents/${clip.id}_keyed.jpg');
      }
      expect(state.isBakingCapturedChromaKeys, isFalse);
      expect(state.capturedChromaKeyRenderId, isNull);
      expect(
        state.lastCapturedChromaKeyBakeResult,
        isA<CapturedChromaKeyBakeSuccess>(),
      );
      // Handed over once for the whole pass, to go into the history as part
      // of the starting state rather than as an edit.
      expect(handedOver, [
        ['a', 'b'],
      ]);
      expect(invalidated, 0);
    });

    test('keeps edits the editor made to the clip meanwhile', () async {
      final bloc = seeded(
        [
          _clip(
            'a',
            captureChromaKey: _recordedKey,
          ).copyWith(trimStart: const Duration(milliseconds: 400)),
        ],
        // The shared bake knows the take as the recorder saved it.
        bake: (clip) => _keyed(clip.copyWith(trimStart: Duration.zero)),
      );

      final state = await bakeAll(bloc);

      expect(state.clips.single.trimStart, const Duration(milliseconds: 400));
      expect(state.clips.single.chromaKey, _recordedKey);
    });

    test('covers the editor while a take bakes', () async {
      final gate = Completer<void>();
      final bloc = seeded(
        [_clip('a', captureChromaKey: _recordedKey)],
        bake: (clip) => gate.future.then((_) => _keyed(clip)),
      );
      final done = bakeAll(bloc);
      await pumpEventQueue();

      expect(bloc.state.isBakingCapturedChromaKeys, isTrue);
      expect(
        bloc.state.capturedChromaKeyRenderId,
        ChromaKeyBakeService.renderIdFor('a'),
      );

      gate.complete();
      final state = await done;
      expect(state.isBakingCapturedChromaKeys, isFalse);
    });

    test('leaves clips without a waiting key alone', () async {
      var bakes = 0;
      final alreadyKeyed = _clip(
        'keyed',
        captureChromaKey: _recordedKey,
      ).copyWith(chromaKey: _recordedKey, chromaKeySourcePath: '/raw.mp4');
      final bloc = seeded(
        [_clip('plain'), alreadyKeyed],
        bake: (clip) {
          bakes++;
          return _keyed(clip);
        },
      );
      final emitted = <ClipEditorState>[];
      final subscription = bloc.stream.listen(emitted.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      emitted.clear();

      bloc.add(const ClipEditorCapturedChromaKeysBakeRequested());
      await pumpEventQueue();

      expect(bakes, 0);
      // Nothing to bake is not a pass: no overlay flash, no result to report.
      expect(emitted, isEmpty);
    });

    test('leaves takes raw when nothing is wired to bake them', () async {
      final bloc = seeded([
        _clip('a', captureChromaKey: _recordedKey),
      ], bake: null);
      await pumpEventQueue();

      bloc.add(const ClipEditorCapturedChromaKeysBakeRequested());
      await pumpEventQueue();

      expect(bloc.state.clips.single.captureChromaKey, _recordedKey);
      expect(bloc.state.isBakingCapturedChromaKeys, isFalse);
    });

    test(
      'keeps a failed take raw with its settings and bakes the rest',
      () async {
        final handedOver = <List<String>>[];
        final bloc = seeded(
          [
            _clip('broken', captureChromaKey: _recordedKey),
            _clip('fine', captureChromaKey: _recordedKey),
          ],
          bake: (clip) {
            if (clip.id == 'broken') {
              throw const ChromaKeyBackdropMissingException('/gone.mp4');
            }
            return _keyed(clip);
          },
          onCapturedChromaKeysBaked: (keyed) =>
              handedOver.add([for (final clip in keyed) clip.id]),
        );

        final state = await bakeAll(bloc);

        final broken = state.clips.firstWhere((c) => c.id == 'broken');
        expect(broken.video?.file?.path, '/documents/broken.mp4');
        expect(broken.chromaKey, isNull);
        // Kept so the clip's own chroma key screen opens on these, and the
        // next pass tries again.
        expect(broken.captureChromaKey, _recordedKey);

        final fine = state.clips.firstWhere((c) => c.id == 'fine');
        expect(fine.chromaKey, _recordedKey);

        expect(
          state.lastCapturedChromaKeyBakeResult,
          isA<CapturedChromaKeyBakeFailure>(),
        );
        expect(handedOver, [
          ['fine'],
        ]);
      },
    );

    test(
      'tries a failing take once per pass rather than looping on it',
      () async {
        var attempts = 0;
        final bloc = seeded(
          [_clip('broken', captureChromaKey: _recordedKey)],
          bake: (clip) {
            attempts++;
            throw StateError('render failed');
          },
        );

        await bakeAll(bloc);

        expect(attempts, 1);
      },
    );

    test(
      'does not delete the keyed file of a take removed meanwhile',
      () async {
        final gate = Completer<void>();
        final queued = <String>[];
        final bloc = seeded(
          [_clip('a', captureChromaKey: _recordedKey), _clip('b')],
          bake: (clip) => gate.future.then((_) => _keyed(clip)),
          deferFileCleanup: (paths) => queued.addAll(paths.nonNulls),
        );
        final done = bakeAll(bloc);
        await pumpEventQueue();

        bloc.add(ClipEditorInitialized([_clip('b')]));
        await pumpEventQueue();
        gate.complete();
        final state = await done;

        expect(state.clips.map((c) => c.id), ['b']);
        // The library copy of the take plays it now.
        expect(queued, isNot(contains('/documents/a_keyed.mp4')));
      },
    );

    test(
      'does not bake the recorded key back in once the user keyed the take '
      'by hand and removed that key again',
      () async {
        final documents = Directory.systemTemp.createTempSync('captured_key_');
        addTearDown(() => documents.deleteSync(recursive: true));
        // Removing a key swaps back to the pre-key footage, which must exist.
        final rawPath = '${documents.path}/a.mp4';
        File(rawPath).writeAsBytesSync(const [0]);
        const handKey = ClipChromaKey(key: ChromaKey.blueScreen());
        var recordedBakes = 0;
        final bloc = seeded(
          [_clip('a', captureChromaKey: _recordedKey, videoPath: rawPath)],
          bake: (clip) {
            recordedBakes++;
            return _keyed(clip);
          },
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async => (
                video: EditorVideo.file('${documents.path}/a_hand.mp4'),
                source: rawPath,
              ),
        );
        await pumpEventQueue();

        bloc.add(
          const ClipEditorChromaKeyRequested(clipId: 'a', chromaKey: handKey),
        );
        await pumpEventQueue();
        expect(bloc.state.clips.single.chromaKey, handKey);
        // The confirmed key settles the recorded one.
        expect(bloc.state.clips.single.captureChromaKey, isNull);

        bloc.add(const ClipEditorChromaKeyRemoved('a'));
        await pumpEventQueue();
        bloc.add(const ClipEditorCapturedChromaKeysBakeRequested());
        await pumpEventQueue();

        expect(recordedBakes, 0);
        final clip = bloc.state.clips.single;
        expect(clip.video?.file?.path, rawPath);
        expect(clip.chromaKey, isNull);
        expect(clip.hasPendingCaptureChromaKey, isFalse);
      },
    );

    test(
      'puts a poster of the raw take back when the key is removed',
      () async {
        final documents = Directory.systemTemp.createTempSync('captured_key_');
        addTearDown(() => documents.deleteSync(recursive: true));
        final rawPath = '${documents.path}/a.mp4';
        File(rawPath).writeAsBytesSync(const [0]);
        final keyedTake = await _keyed(
          _clip('a', captureChromaKey: _recordedKey, videoPath: rawPath),
        );
        final bloc = seeded(
          [keyedTake],
          bake: null,
          extractPoster: ({required videoPath, required timestamp}) async =>
              ThumbnailFileResult(
                path: videoPath.replaceAll('.mp4', '_poster.jpg'),
                timestamp: timestamp,
              ),
        );
        await pumpEventQueue();

        bloc.add(const ClipEditorChromaKeyRemoved('a'));
        await pumpEventQueue();

        final clip = bloc.state.clips.single;
        expect(clip.video?.file?.path, rawPath);
        // The keyed poster showed the composite, not the footage now in place.
        expect(clip.thumbnailPath, '${documents.path}/a_poster.jpg');
      },
    );

    test(
      'merges the keyed version of a take still waiting on its key',
      () async {
        List<DivineVideoClip>? merged;
        final bloc = seeded(
          [_clip('a', captureChromaKey: _recordedKey), _clip('b')],
          bake: _keyed,
          mergeClips: ({required clips, required renderId}) async {
            merged = clips;
            return null;
          },
        );
        await pumpEventQueue();

        bloc
          ..add(const ClipEditorMultiSelectStarted('a'))
          ..add(const ClipEditorMultiSelectClipToggled('b'))
          ..add(const ClipEditorSelectedClipsMergeRequested());
        await pumpEventQueue();

        expect(merged?.first.video?.file?.path, '/documents/a_keyed.mp4');
        expect(merged?.last.video?.file?.path, '/documents/b.mp4');
      },
    );
  });
}
