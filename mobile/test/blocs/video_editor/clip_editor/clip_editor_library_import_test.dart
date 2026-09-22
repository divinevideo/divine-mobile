// ABOUTME: Tests for adding clips picked in the library to the composition —
// ABOUTME: stop-motion sets merge into a frames clip or render into a video one

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, RenderCanceledException;

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

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

/// The stills a test's sampler hands back for [clip]: one per hold across
/// the clip, on files that need not exist — the sampler is past sanitizing.
List<StopMotionClipFrame> _sampledFor(
  DivineVideoClip clip, {
  required int framesPerImage,
}) {
  final hold = StopMotionFrameOps.framesPerImageToDuration(framesPerImage);
  final count = clip.trimmedDuration.inMicroseconds ~/ hold.inMicroseconds;
  return [
    for (var i = 0; i < count; i++)
      StopMotionClipFrame(path: '/documents/${clip.id}-$i.jpg', duration: hold),
  ];
}

/// A stop-motion set whose stills are held for [framesPerImage] output
/// frames each — the shape that decides a session's hold.
DivineVideoClip _stopMotionSetOnHold(
  String id, {
  required Directory dir,
  required int framesPerImage,
  int frameCount = 2,
}) {
  final hold = StopMotionFrameOps.framesPerImageToDuration(framesPerImage);
  final frames = <StopMotionClipFrame>[];
  for (var i = 0; i < frameCount; i++) {
    final file = File('${dir.path}/$id-$i.jpg')..writeAsBytesSync([1, 2, 3]);
    frames.add(StopMotionClipFrame(path: file.path, duration: hold));
  }
  return DivineVideoClip(
    id: id,
    stopMotionFrames: frames,
    duration: hold * frameCount,
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

    late _MockAudioExtractionService audioExtractionService;
    late List<String> cleanedSampledPaths;

    setUp(() {
      audioExtractionService = _MockAudioExtractionService();
      cleanedSampledPaths = [];
      when(() => audioExtractionService.cleanupAudioFile(any()))
          .thenAnswer((_) async {});
    });

    ClipEditorBloc buildBloc({
      MaterializeStopMotionClipFn? materializeStopMotionClip,
      SampleStopMotionFramesFn? sampleStopMotionFrames,
      DeferFileCleanupFn? deferFileCleanup,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        audioExtractionService: audioExtractionService,
        deferFileCleanup: deferFileCleanup,
        // Both conversions default to failing so a test that does not wire
        // one up cannot silently pass a clip it never converted.
        materializeStopMotionClip:
            materializeStopMotionClip ?? (clip, {taskId}) async => null,
        sampleStopMotionFrames:
            sampleStopMotionFrames ??
            (clip, {required framesPerImage, taskId, onProgress}) async => null,
        cleanupSampledFrames: (paths) async =>
            cleanedSampledPaths.addAll(paths),
      );
      addTearDown(bloc.close);
      return bloc;
    }

    Future<ClipEditorBloc> seeded(
      List<DivineVideoClip> clips, {
      MaterializeStopMotionClipFn? materializeStopMotionClip,
      SampleStopMotionFramesFn? sampleStopMotionFrames,
      DeferFileCleanupFn? deferFileCleanup,
    }) async {
      final bloc = buildBloc(
        materializeStopMotionClip: materializeStopMotionClip,
        sampleStopMotionFrames: sampleStopMotionFrames,
        deferFileCleanup: deferFileCleanup,
      )..add(ClipEditorInitialized(clips));
      await bloc.stream.first;
      return bloc;
    }

    /// A sampler that answers every clip with [_sampledFor] and records the
    /// hold and task id each request carried.
    SampleStopMotionFramesFn recordingSampler(
      List<({String clipId, int framesPerImage, String? taskId})> requests,
    ) => (clip, {required framesPerImage, taskId, onProgress}) async {
      requests.add((
        clipId: clip.id,
        framesPerImage: framesPerImage,
        taskId: taskId,
      ));
      return _sampledFor(clip, framesPerImage: framesPerImage);
    };

    void stubAudio({double duration = 2}) {
      when(
        () => audioExtractionService.extractAudioForDraft(
          videoPath: any(named: 'videoPath'),
          speed: any(named: 'speed'),
        ),
      ).thenAnswer(
        (invocation) async => AudioExtractionResult(
          audioFilePath: '${invocation.namedArguments[#videoPath]}.m4a',
          duration: duration,
          fileSize: 1,
          sha256Hash: 'sha',
          mimeType: 'audio/mp4',
        ),
      );
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

      test('never converts a set: a merge costs no encode', () async {
        var converted = false;
        final bloc = await seeded(
          [_stopMotionSet('session', dir: tempDir)],
          materializeStopMotionClip: (clip, {taskId}) async {
            converted = true;
            return _renderedFor(clip);
          },
          sampleStopMotionFrames:
              (clip, {required framesPerImage, taskId, onProgress}) async {
                converted = true;
                return _sampledFor(clip, framesPerImage: framesPerImage);
              },
        );

        bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _stopMotionSet('picked', dir: tempDir),
          ]),
        );
        await bloc.stream.first;

        expect(converted, isFalse);
      });

      test(
        'samples a picked video clip at the session hold and appends it',
        () async {
          stubAudio();
          final requests =
              <({String clipId, int framesPerImage, String? taskId})>[];
          // Two stills on threes: the session runs at 10 stills a second.
          final session = _stopMotionSetOnHold(
            'session',
            dir: tempDir,
            framesPerImage: 3,
          );
          final bloc = await seeded([
            session,
          ], sampleStopMotionFrames: recordingSampler(requests));

          bloc.add(
            ClipEditorLibraryClipsImportRequested([
              _videoClip('footage'),
            ], audioTitle: 'Clip Audio'),
          );
          final states = await bloc.stream.take(2).toList();

          final inFlight = states.first;
          expect(inFlight.isImportingLibraryClips, isTrue);
          expect(requests.single.clipId, 'footage');
          expect(requests.single.framesPerImage, 3);
          expect(requests.single.taskId, inFlight.libraryImportRenderId);

          final landed = states.last;
          expect(landed.isImportingLibraryClips, isFalse);
          expect(landed.libraryImportRenderId, isNull);
          // Still one frames clip, the session's, with the footage's twenty
          // stills (two seconds on threes) after the session's own two.
          expect(landed.clips, hasLength(1));
          expect(landed.clips.single.id, 'session');
          expect(landed.clips.single.isStopMotion, isTrue);
          final frames = landed.clips.single.stopMotionFrames!;
          expect(frames, hasLength(22));
          expect(
            frames.take(2).map((f) => f.path),
            session.stopMotionFrames!.map((f) => f.path),
          );
          expect(frames[2].path, '/documents/footage-0.jpg');
          expect(frames.skip(2).map((f) => f.duration).toSet(), {
            StopMotionFrameOps.framesPerImageToDuration(3),
          });

          // The footage's sound rides over exactly its stills: it starts
          // where the session's two stills end and runs for the twenty.
          final result =
              landed.lastLibraryImportResult! as ClipLibraryImportSuccess;
          expect(result.previousClips.map((c) => c.id), ['session']);
          final audio = result.audioTracks.single;
          expect(audio.isLocalExtracted, isTrue);
          expect(audio.url, '/documents/footage.mp4.m4a');
          expect(audio.title, 'Clip Audio');
          expect(audio.startTime, session.duration);
          expect(
            audio.endTime,
            session.duration +
                StopMotionFrameOps.framesPerImageToDuration(3) * 20,
          );
          expect(audio.startOffset, Duration.zero);
        },
      );

      test("carries the sampler's progress for the overlay", () async {
        stubAudio();
        final bloc = await seeded(
          [_stopMotionSet('session', dir: tempDir)],
          sampleStopMotionFrames:
              (clip, {required framesPerImage, taskId, onProgress}) async {
                onProgress?.call(0.5);
                onProgress?.call(1);
                return _sampledFor(clip, framesPerImage: framesPerImage);
              },
        );

        bloc.add(ClipEditorLibraryClipsImportRequested([_videoClip('a')]));
        final states = await bloc.stream
            .takeWhile((s) => s.lastLibraryImportResult == null)
            .toList();

        // The decoder reports with its frames, not on the plugin's progress
        // stream, so the state is the only place the overlay can read it.
        expect(states.map((s) => s.libraryImportProgress), [0, 0.5, 1]);
        expect(bloc.state.libraryImportProgress, isNull);
      });

      test('keeps the stills of a clip that has no sound', () async {
        when(
          () => audioExtractionService.extractAudioForDraft(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenThrow(const AudioExtractionException('no audio track'));
        final bloc = await seeded([
          _stopMotionSet('session', dir: tempDir),
        ], sampleStopMotionFrames: recordingSampler([]));

        bloc.add(ClipEditorLibraryClipsImportRequested([_videoClip('mute')]));
        final states = await bloc.stream.take(2).toList();

        final result =
            states.last.lastLibraryImportResult! as ClipLibraryImportSuccess;
        expect(result.audioTracks, isEmpty);
        expect(
          states.last.clips.single.stopMotionFrames!.length,
          greaterThan(2),
        );
      });

      test('keeps selection order across sets and footage', () async {
        stubAudio();
        final requests =
            <({String clipId, int framesPerImage, String? taskId})>[];
        final session = _stopMotionSetOnHold(
          'session',
          dir: tempDir,
          framesPerImage: 1,
        );
        final set = _stopMotionSetOnHold(
          'set',
          dir: tempDir,
          framesPerImage: 1,
          frameCount: 3,
        );
        final bloc = await seeded([
          session,
        ], sampleStopMotionFrames: recordingSampler(requests));

        bloc.add(
          ClipEditorLibraryClipsImportRequested([
            _videoClip('first'),
            set,
            _videoClip('second'),
          ]),
        );
        // One in-flight state per sampled clip (the set in between costs no
        // decode and so no state), then the landed one.
        final states = await bloc.stream.take(3).toList();

        final frames = states.last.clips.single.stopMotionFrames!;
        final hold = StopMotionFrameOps.framesPerImageToDuration(1);
        final perClip = _sampledFor(
          _videoClip('first'),
          framesPerImage: 1,
        ).length;
        expect(frames, hasLength(2 + perClip + 3 + perClip));
        expect(frames[2].path, '/documents/first-0.jpg');
        expect(frames[2 + perClip].path, set.stopMotionFrames!.first.path);
        expect(frames[2 + perClip + 3].path, '/documents/second-0.jpg');
        // Each clip ran under its own id, in order, and the second sound
        // starts after the set that sits between the two clips.
        expect(requests.map((r) => r.clipId), ['first', 'second']);
        expect(requests.map((r) => r.taskId).toSet(), hasLength(2));
        final result =
            states.last.lastLibraryImportResult! as ClipLibraryImportSuccess;
        expect(result.audioTracks, hasLength(2));
        expect(result.audioTracks.first.startTime, hold * 2);
        expect(result.audioTracks.last.startTime, hold * (2 + perClip + 3));
      });

      test(
        'leaves the timeline alone and cleans up when sampling fails',
        () async {
          stubAudio();
          final bloc = await seeded(
            [_stopMotionSet('session', dir: tempDir)],
            sampleStopMotionFrames:
                (clip, {required framesPerImage, taskId, onProgress}) async =>
                    clip.id == 'bad'
                    ? null
                    : _sampledFor(clip, framesPerImage: framesPerImage),
          );

          bloc.add(
            ClipEditorLibraryClipsImportRequested([
              _videoClip('ok'),
              _videoClip('bad'),
            ]),
          );
          final states = await bloc.stream.take(3).toList();

          // The pick lands as a whole or not at all: the first clip's stills
          // and its extracted sound go, since no history entry names them.
          expect(states.last.clips.single.stopMotionFrames, hasLength(2));
          expect(states.last.isImportingLibraryClips, isFalse);
          expect(
            states.last.lastLibraryImportResult,
            isA<ClipLibraryImportFailure>(),
          );
          expect(cleanedSampledPaths, isNotEmpty);
          expect(cleanedSampledPaths.first, '/documents/ok-0.jpg');
          verify(
            () => audioExtractionService.cleanupAudioFile(
              '/documents/ok.mp4.m4a',
            ),
          ).called(1);
        },
      );

      test('discards a sampling the editor teardown cancelled', () async {
        final bloc = await seeded(
          [_stopMotionSet('session', dir: tempDir)],
          sampleStopMotionFrames: (
            clip, {
            required framesPerImage,
            taskId,
            onProgress,
          }) async => throw const RenderCanceledException(),
        );

        bloc.add(ClipEditorLibraryClipsImportRequested([_videoClip('a')]));
        final states = await bloc.stream.take(2).toList();

        expect(states.last.clips.single.stopMotionFrames, hasLength(2));
        expect(
          states.last.lastLibraryImportResult,
          isA<ClipLibraryImportDiscarded>(),
        );
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
          expect(states.take(2).map((s) => s.libraryImportRenderId), taskIds);
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

        // Nothing readable was picked, so there is no assembly to fail on a
        // missing file, but the user still hears why nothing was added.
        expect(rendered, isFalse);
        expect(bloc.state.clips.map((c) => c.id), ['a']);
        expect(
          bloc.state.lastLibraryImportResult,
          isA<ClipLibraryImportStillsMissing>(),
        );
        expect(bloc.state.isImportingLibraryClips, isFalse);
      });

      test('reports nothing for an empty pick', () async {
        final bloc = await seeded([_videoClip('a')]);

        bloc.add(const ClipEditorLibraryClipsImportRequested([]));
        await pumpEventQueue();

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

      test(
        'queues the rendered mp4 for cleanup when the editor closes mid-render',
        () async {
          final render = Completer<DivineVideoClip?>();
          final started = Completer<void>();
          final deferred = <String?>[];
          final bloc = await seeded(
            [_videoClip('a')],
            materializeStopMotionClip: (clip, {taskId}) {
              started.complete();
              return render.future;
            },
            deferFileCleanup: deferred.addAll,
          );

          bloc.add(
            ClipEditorLibraryClipsImportRequested([
              _stopMotionSet('picked', dir: tempDir),
            ]),
          );
          await started.future;
          final closing = bloc.close();
          render.complete(_renderedFor(_stopMotionSet('picked', dir: tempDir)));
          await closing;
          await pumpEventQueue();

          // No clip will ever reference the render the closed editor could
          // not land, so it must be reclaimed rather than left on disk.
          expect(deferred, ['/documents/stop_motion_picked.mp4']);
        },
      );

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
