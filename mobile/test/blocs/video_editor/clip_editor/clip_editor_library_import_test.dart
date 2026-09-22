// ABOUTME: Tests for adding clips picked in the library to the composition —
// ABOUTME: stop-motion sets merge into a frames clip or render into a video one

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, RenderCanceledException;

DivineVideoClip _videoClip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

/// A stop-motion set of [frameCount] stills, each held for a whole second so
/// durations stay readable, with the still files written under [dir] so
/// [StopMotionFrameOps.sanitizedClip] keeps them.
DivineVideoClip _stopMotionSet(
  String id, {
  required Directory dir,
  int frameCount = 2,
}) {
  final frames = <StopMotionClipFrame>[];
  for (var i = 0; i < frameCount; i++) {
    final file = File('${dir.path}/$id-$i.jpg')..writeAsBytesSync([1, 2, 3]);
    frames.add(
      StopMotionClipFrame(
        path: file.path,
        duration: const Duration(seconds: 1),
      ),
    );
  }
  return DivineVideoClip(
    id: id,
    stopMotionFrames: frames,
    duration: Duration(seconds: frameCount),
    recordedAt: DateTime(2026),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

/// The rendered clip a test's materializer hands back for [set]: a plain
/// video clip under the set's id, the way the real materializer returns it.
DivineVideoClip _renderedFor(DivineVideoClip set) => set.copyWith(
  video: EditorVideo.file('/documents/stop_motion_${set.id}.mp4'),
  clearStopMotionFrames: true,
);

void main() {
  group('$ClipEditorBloc library import', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('clip_editor_import');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    ClipEditorBloc buildBloc({
      MaterializeStopMotionClipFn? materializeStopMotionClip,
      DeferFileCleanupFn? deferFileCleanup,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        deferFileCleanup: deferFileCleanup,
        // Defaults to a failing render so a test that does not wire one up
        // cannot silently pass a set it never rendered.
        materializeStopMotionClip:
            materializeStopMotionClip ?? (clip, {taskId}) async => null,
      );
      addTearDown(bloc.close);
      return bloc;
    }

    Future<ClipEditorBloc> seeded(
      List<DivineVideoClip> clips, {
      MaterializeStopMotionClipFn? materializeStopMotionClip,
      DeferFileCleanupFn? deferFileCleanup,
    }) async {
      final bloc = buildBloc(
        materializeStopMotionClip: materializeStopMotionClip,
        deferFileCleanup: deferFileCleanup,
      )..add(ClipEditorInitialized(clips));
      await bloc.stream.first;
      return bloc;
    }

    group('into a stop-motion composition', () {
      test('merges the picked sets into the single frames clip', () async {
        final session = _stopMotionSet('session', dir: tempDir);
        final picked = _stopMotionSet('picked', dir: tempDir, frameCount: 3);
        final bloc = await seeded([session]);

        bloc.add(ClipEditorLibraryClipsImportRequested([picked]));
        final state = await bloc.stream.first;

        // The frame-first editor edits exactly one frames list, so the set
        // lands as more stills on the session's clip rather than a second one.
        expect(state.clips, hasLength(1));
        expect(state.clips.single.id, 'session');
        expect(state.clips.single.stopMotionFrames, hasLength(5));
        expect(state.clips.single.duration, const Duration(seconds: 5));
        expect(state.isImportingLibraryClips, isFalse);
        final result = state.lastLibraryImportResult;
        expect(result, isA<ClipLibraryImportSuccess>());
        expect(
          (result! as ClipLibraryImportSuccess).previousClips.map((c) => c.id),
          ['session'],
        );
      });

      test('never renders: a merge costs no encode', () async {
        var rendered = false;
        final bloc = await seeded(
          [_stopMotionSet('session', dir: tempDir)],
          materializeStopMotionClip: (clip, {taskId}) async {
            rendered = true;
            return _renderedFor(clip);
          },
        );

        bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _stopMotionSet('picked', dir: tempDir),
          ]),
        );
        await bloc.stream.first;

        expect(rendered, isFalse);
      });
    });

    group('into a video composition', () {
      test('appends a picked video clip as it is', () async {
        final bloc = await seeded([_videoClip('a')]);

        bloc.add(ClipEditorLibraryClipsImportRequested([_videoClip('b')]));
        final state = await bloc.stream.first;

        expect(state.clips.map((c) => c.id), ['a', 'b']);
        expect(state.isImportingLibraryClips, isFalse);
        expect(state.lastLibraryImportResult, isA<ClipLibraryImportSuccess>());
      });

      test('renders a picked stop-motion set into a clip first', () async {
        final picked = _stopMotionSet('picked', dir: tempDir);
        final taskIds = <String?>[];
        final bloc = await seeded(
          [_videoClip('a')],
          materializeStopMotionClip: (clip, {taskId}) async {
            taskIds.add(taskId);
            return _renderedFor(clip);
          },
        );

        bloc.add(ClipEditorLibraryClipsImportRequested([picked]));
        final states = await bloc.stream.take(2).toList();

        // The overlay keys its progress stream on the id the render ran under.
        final inFlight = states.first;
        expect(inFlight.isImportingLibraryClips, isTrue);
        expect(inFlight.libraryImportRenderId, isNotNull);
        expect(taskIds, [inFlight.libraryImportRenderId]);

        final landed = states.last;
        expect(landed.isImportingLibraryClips, isFalse);
        expect(landed.libraryImportRenderId, isNull);
        expect(landed.clips.map((c) => c.id), ['a', 'picked']);
        // The session stays a video session: what joined is a video clip.
        expect(landed.clips.last.isStopMotion, isFalse);
        expect(landed.clips.last.video, isNotNull);
        final result = landed.lastLibraryImportResult;
        expect(result, isA<ClipLibraryImportSuccess>());
        expect(
          (result! as ClipLibraryImportSuccess).previousClips.map((c) => c.id),
          ['a'],
        );
      });

      test(
        'keeps selection order across a mixed pick, one render per set',
        () async {
          final first = _stopMotionSet('first', dir: tempDir);
          final second = _stopMotionSet('second', dir: tempDir);
          final taskIds = <String?>[];
          final bloc = await seeded(
            [_videoClip('a')],
            materializeStopMotionClip: (clip, {taskId}) async {
              taskIds.add(taskId);
              return _renderedFor(clip);
            },
          );

          bloc.add(
            ClipEditorLibraryClipsImportRequested([
              first,
              _videoClip('b'),
              second,
            ]),
          );
          final states = await bloc.stream.take(3).toList();

          expect(states.last.clips.map((c) => c.id), [
            'a',
            'first',
            'b',
            'second',
          ]);
          // Each set ran under its own id, and the state followed each in turn,
          // so the overlay tracked the render actually running.
          expect(taskIds, hasLength(2));
          expect(taskIds.toSet(), hasLength(2));
          expect(
            states.take(2).map((s) => s.libraryImportRenderId),
            taskIds,
          );
        },
      );

      test('drops a set whose stills are gone before rendering', () async {
        final missing = DivineVideoClip(
          id: 'missing',
          stopMotionFrames: [
            StopMotionClipFrame(
              path: '${tempDir.path}/never-written.jpg',
              duration: const Duration(seconds: 1),
            ),
          ],
          duration: const Duration(seconds: 1),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        var rendered = false;
        final bloc = await seeded(
          [_videoClip('a')],
          materializeStopMotionClip: (clip, {taskId}) async {
            rendered = true;
            return _renderedFor(clip);
          },
        );

        bloc.add(ClipEditorLibraryClipsImportRequested([missing]));
        await pumpEventQueue();

        // Nothing readable was picked, so there is no import to report and
        // no assembly to fail on a missing file.
        expect(rendered, isFalse);
        expect(bloc.state.clips.map((c) => c.id), ['a']);
        expect(bloc.state.lastLibraryImportResult, isNull);
      });

      test('leaves the timeline alone when a render fails', () async {
        final bloc = await seeded([_videoClip('a')]);

        bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _stopMotionSet('picked', dir: tempDir),
          ]),
        );
        final states = await bloc.stream.take(2).toList();

        expect(states.last.clips.map((c) => c.id), ['a']);
        expect(states.last.isImportingLibraryClips, isFalse);
        expect(states.last.libraryImportRenderId, isNull);
        expect(
          states.last.lastLibraryImportResult,
          isA<ClipLibraryImportFailure>(),
        );
      });

      test(
        'queues the mp4s already rendered for cleanup when a later set fails',
        () async {
          final ok = _stopMotionSet('ok', dir: tempDir);
          final bad = _stopMotionSet('bad', dir: tempDir);
          final deferred = <String?>[];
          final bloc = await seeded(
            [_videoClip('a')],
            materializeStopMotionClip: (clip, {taskId}) async =>
                clip.id == 'bad' ? null : _renderedFor(clip),
            deferFileCleanup: deferred.addAll,
          );

          bloc.add(ClipEditorLibraryClipsImportRequested([ok, bad]));
          final states = await bloc.stream.take(3).toList();

          // The pick lands as a whole or not at all, and no clip will ever
          // reference the first set's render, so it must not be left behind.
          expect(states.last.clips.map((c) => c.id), ['a']);
          expect(deferred, ['/documents/stop_motion_ok.mp4']);
          expect(
            states.last.lastLibraryImportResult,
            isA<ClipLibraryImportFailure>(),
          );
        },
      );

      test('discards a render the editor teardown cancelled', () async {
        final bloc = await seeded(
          [_videoClip('a')],
          materializeStopMotionClip: (clip, {taskId}) async =>
              throw const RenderCanceledException(),
        );

        bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _stopMotionSet('picked', dir: tempDir),
          ]),
        );
        final states = await bloc.stream.take(2).toList();

        expect(states.last.clips.map((c) => c.id), ['a']);
        expect(states.last.isImportingLibraryClips, isFalse);
        expect(
          states.last.lastLibraryImportResult,
          isA<ClipLibraryImportDiscarded>(),
        );
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reports an invariant failure and leaves the timeline alone',
        build: () => buildBloc(
          materializeStopMotionClip: (clip, {taskId}) async =>
              throw StateError('assembler boom'),
        ),
        seed: () => ClipEditorState(clips: [_videoClip('a')]),
        act: (bloc) => bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _stopMotionSet('picked', dir: tempDir),
          ]),
        ),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.clips.map((c) => c.id), ['a']);
          expect(bloc.state.isImportingLibraryClips, isFalse);
          expect(
            bloc.state.lastLibraryImportResult,
            isA<ClipLibraryImportFailure>(),
          );
        },
      );
    });
  });
}
