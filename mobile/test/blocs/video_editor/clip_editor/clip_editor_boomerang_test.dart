// ABOUTME: Tests for turning clips into a boomerang: one clip and a selection,
// ABOUTME: the restore, the length limit, speed curves, failures and discards.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_boomerang.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/video_editor_boomerang_service.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        ChromaKey,
        ClipTransition,
        ClipTransitionType,
        EditorVideo,
        ExportTransform,
        VideoSpeedRamp,
        VideoSpeedRampPoint;

const _frame = Duration(microseconds: 33333);

/// A key the clip was recorded with, still waiting to be baked.
const _recordedKey = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);

/// Records every `addError`, the path a failure takes to Crashlytics.
class _RecordingObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

/// A 4 s clip trimmed to 1 s – 3.5 s, so 2.5 s of it plays.
DivineVideoClip _clip({
  String id = 'clip',
  String? videoPath,
  Duration duration = const Duration(seconds: 4),
  Duration trimStart = const Duration(seconds: 1),
  Duration trimEnd = const Duration(milliseconds: 500),
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file(videoPath ?? '/documents/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  trimEnd: trimEnd,
  forwardVideoPath: '/documents/${id}_forward.mp4',
);

/// Renders nothing; hands back what the real service would for [sourceClip].
Future<BoomerangRender> _fakeBoomerang({
  required DivineVideoClip sourceClip,
  required String renderId,
}) async {
  final window = sourceClip.trimmedDuration;
  return (
    video: EditorVideo.file('/documents/${sourceClip.id}_boomerang.mp4'),
    duration: window * 2 - _frame * 2,
    forwardDuration: window,
  );
}

void main() {
  group('$ClipEditorBloc boomerang', () {
    late Directory temp;
    late List<DivineVideoClip> merged;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('boomerang_test');
      merged = [];
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      RenderBoomerangFn? renderBoomerang,
      void Function()? onFinalClipInvalidated,
      DeferFileCleanupFn? deferFileCleanup,
      TransformClipFn? transformClip,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
        saveClipToLibrary: ({required clip}) async => false,
        renderBoomerang: renderBoomerang ?? _fakeBoomerang,
        transformClip: transformClip,
        measureAspectRatio: (_) async => 9 / 16,
        deferFileCleanup: deferFileCleanup,
        mergeClips: ({required clips, required renderId}) async {
          merged = clips;
          return DivineVideoClip(
            id: 'merged',
            video: EditorVideo.file('/documents/merged.mp4'),
            duration: clips.fold(
              Duration.zero,
              (sum, clip) => sum + clip.playbackDuration,
            ),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
        },
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    List<Object> recordBlocErrors() {
      final observer = _RecordingObserver();
      final previousObserver = Bloc.observer;
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previousObserver);
      return observer.errors;
    }

    /// Dispatches [event] and waits for the boomerang outcome it produces.
    Future<ClipEditorState> request(
      ClipEditorBloc bloc,
      ClipEditorEvent event,
    ) {
      final before = bloc.state.lastBoomerangResult;
      final done = bloc.stream.firstWhere(
        (state) =>
            !identical(state.lastBoomerangResult, before) &&
            !state.isBoomeranging,
      );
      bloc.add(event);
      return done;
    }

    Future<ClipEditorState> toggle(ClipEditorBloc bloc, {String id = 'clip'}) =>
        request(bloc, ClipEditorClipBoomerangRequested(clipId: id));

    group('one clip', () {
      test('swaps in the boomerang and records how to undo it', () async {
        var invalidated = 0;
        final renderIds = <String>[];
        final bloc = seeded(
          [_clip()],
          onFinalClipInvalidated: () => invalidated++,
          renderBoomerang: ({required sourceClip, required renderId}) {
            renderIds.add(renderId);
            return _fakeBoomerang(sourceClip: sourceClip, renderId: renderId);
          },
        );

        final state = await toggle(bloc);
        final clip = state.clips.single;

        expect(renderIds, [VideoEditorBoomerangService.renderIdFor('clip')]);
        expect(clip.video!.file!.path, '/documents/clip_boomerang.mp4');
        // The render holds only what played, so the boomerang is untrimmed.
        expect(clip.duration, const Duration(seconds: 5) - _frame * 2);
        expect(clip.trimStart, Duration.zero);
        expect(clip.trimEnd, Duration.zero);
        expect(
          clip.boomerang,
          const ClipBoomerang(
            sourcePath: '/documents/clip.mp4',
            sourceDuration: Duration(seconds: 4),
            sourceTrimStart: Duration(seconds: 1),
            sourceTrimEnd: Duration(milliseconds: 500),
          ),
        );
        // The reverse cache holds the footage before the bounce.
        expect(clip.forwardVideoPath, isNull);
        expect(clip.derivedFrom, const [
          C2paEditSource(path: '/documents/clip.mp4'),
        ]);
        expect(
          state.lastBoomerangResult,
          isA<ClipBoomerangSuccess>()
              .having((r) => r.bounced, 'bounced', isTrue)
              .having((r) => r.clipId, 'clipId', 'clip')
              .having(
                (r) => r.previousClips.single.video!.file!.path,
                'previous video',
                '/documents/clip.mp4',
              ),
        );
        // The widget layer writes the one history entry for it, moving
        // markers and sounds; the invalidation callback would add a second.
        expect(invalidated, 0);
      });

      test('turning it off restores the clip without a render', () async {
        final source = File(p.join(temp.path, 'take.mp4'))
          ..writeAsStringSync('take');
        final bloc = seeded(
          [
            _clip(
              videoPath: '/documents/clip_boomerang.mp4',
              trimStart: Duration.zero,
              trimEnd: Duration.zero,
            ).copyWith(
              boomerang: ClipBoomerang(
                sourcePath: source.path,
                sourceDuration: const Duration(seconds: 4),
                sourceTrimStart: const Duration(seconds: 1),
                sourceTrimEnd: const Duration(milliseconds: 500),
                sourceMinTrimStart: const Duration(seconds: 1),
              ),
            ),
          ],
          renderBoomerang: ({required sourceClip, required renderId}) =>
              throw StateError('turning a boomerang off renders nothing'),
        );

        final state = await toggle(bloc);
        final clip = state.clips.single;

        expect(clip.video!.file!.path, source.path);
        expect(clip.duration, const Duration(seconds: 4));
        expect(clip.trimStart, const Duration(seconds: 1));
        expect(clip.trimEnd, const Duration(milliseconds: 500));
        expect(clip.minTrimStart, const Duration(seconds: 1));
        expect(clip.boomerang, isNull);
        expect(
          state.lastBoomerangResult,
          isA<ClipBoomerangSuccess>().having(
            (r) => r.bounced,
            'bounced',
            isFalse,
          ),
        );
      });

      test('turning it off gives back the sources the clip named', () async {
        final source = File(p.join(temp.path, 'clip.mp4'))
          ..writeAsStringSync('take');
        const sources = [
          C2paEditSource(path: '/documents/take.mp4'),
          C2paEditSource(
            path: '/documents/backdrop.png',
            kind: C2paSourceKind.image,
          ),
        ];
        final bloc = seeded([
          _clip(videoPath: source.path).copyWith(derivedFrom: sources),
        ]);

        expect((await toggle(bloc)).clips.single.boomerang, isNotNull);
        final clip = (await toggle(bloc)).clips.single;

        expect(clip.boomerang, isNull);
        expect(clip.derivedFrom, sources);
      });

      test('turning it off makes footage that was its own source so '
          'again', () async {
        final source = File(p.join(temp.path, 'clip.mp4'))
          ..writeAsStringSync('take');
        final bloc = seeded([_clip(videoPath: source.path)]);

        // The boomerang names the footage it was bounced from.
        final bounced = (await toggle(bloc)).clips.single;
        expect(bounced.derivedFrom, [C2paEditSource(path: source.path)]);
        final clip = (await toggle(bloc)).clips.single;

        expect(clip.boomerang, isNull);
        expect(clip.derivedFrom, isNull);
      });

      test('turning it off takes the sources from the record, not from the '
          'boomerang', () async {
        final source = File(p.join(temp.path, 'take.mp4'))
          ..writeAsStringSync('take');
        const recorded = [C2paEditSource(path: '/documents/take_raw.mp4')];
        final bloc = seeded([
          _clip(
            videoPath: '/documents/clip_boomerang.mp4',
            trimStart: Duration.zero,
            trimEnd: Duration.zero,
          ).copyWith(
            derivedFrom: const [C2paEditSource(path: '/documents/other.mp4')],
            boomerang: ClipBoomerang(
              sourcePath: source.path,
              sourceDuration: const Duration(seconds: 4),
              sourceDerivedFrom: recorded,
            ),
          ),
        ]);

        final clip = (await toggle(bloc)).clips.single;

        expect(clip.boomerang, isNull);
        expect(clip.derivedFrom, recorded);
      });

      test('keeps bouncing when the footage before it is gone', () async {
        final bounced =
            _clip(
              videoPath: '/documents/clip_boomerang.mp4',
            ).copyWith(
              boomerang: ClipBoomerang(
                sourcePath: p.join(temp.path, 'gone.mp4'),
                sourceDuration: const Duration(seconds: 4),
              ),
            );
        final bloc = seeded([bounced]);

        final state = await toggle(bloc);

        expect(state.lastBoomerangResult, isA<ClipBoomerangOriginalMissing>());
        expect(state.clips.single, same(bounced));
      });

      test('refuses footage the export would cut on the way back', () async {
        var rendered = false;
        final bloc = seeded(
          [_clip(trimStart: Duration.zero, trimEnd: Duration.zero)],
          renderBoomerang: ({required sourceClip, required renderId}) {
            rendered = true;
            return _fakeBoomerang(sourceClip: sourceClip, renderId: renderId);
          },
        );

        final state = await toggle(bloc);

        expect(rendered, isFalse);
        expect(
          state.lastBoomerangResult,
          isA<ClipBoomerangTooLong>().having(
            (r) => r.maxSourceDuration,
            'maxSourceDuration',
            const Duration(milliseconds: 3150),
          ),
        );
        expect(state.clips.single.video!.file!.path, '/documents/clip.mp4');
      });

      test('waits for a recorded green screen to bake', () async {
        // Bounced first, the raw take would be keyed later as a boomerang
        // whose record still points at the unkeyed footage.
        var rendered = false;
        final bloc = seeded(
          [_clip().copyWith(captureChromaKey: _recordedKey)],
          renderBoomerang: ({required sourceClip, required renderId}) {
            rendered = true;
            return _fakeBoomerang(sourceClip: sourceClip, renderId: renderId);
          },
        );
        await pumpEventQueue();

        bloc.add(const ClipEditorClipBoomerangRequested(clipId: 'clip'));
        await pumpEventQueue();

        expect(rendered, isFalse);
        expect(bloc.state.isBoomeranging, isFalse);
        expect(
          bloc.state.clips.single.video!.file!.path,
          '/documents/clip.mp4',
        );
        expect(bloc.state.clips.single.boomerang, isNull);
      });

      test('reports a failed render and leaves the clip alone', () async {
        final errors = recordBlocErrors();
        final bloc = seeded(
          [_clip()],
          renderBoomerang: ({required sourceClip, required renderId}) =>
              throw Exception('encoder gave up'),
        );

        final state = await toggle(bloc);

        expect(state.lastBoomerangResult, isA<ClipBoomerangFailure>());
        expect(state.clips.single.video!.file!.path, '/documents/clip.mp4');
        expect(state.clips.single.boomerang, isNull);
        expect(errors, [isA<Exception>()]);
      });

      test('drops the render when the clip was removed meanwhile', () async {
        final release = Completer<void>();
        final cleaned = <String?>[];
        final bloc = seeded(
          [_clip(), _clip(id: 'other')],
          deferFileCleanup: cleaned.addAll,
          renderBoomerang: ({required sourceClip, required renderId}) async {
            await release.future;
            return _fakeBoomerang(sourceClip: sourceClip, renderId: renderId);
          },
        );

        final done = toggle(bloc);
        await bloc.stream.firstWhere((s) => s.isBoomeranging);
        bloc.add(const ClipEditorClipRemoved('clip'));
        await bloc.stream.firstWhere((s) => s.clips.length == 1);
        release.complete();

        final state = await done;
        expect(state.lastBoomerangResult, isA<ClipBoomerangDiscarded>());
        expect(state.clips.single.id, 'other');
        expect(cleaned, contains('/documents/clip_boomerang.mp4'));
      });

      test('mirrors a speed curve onto the way back and gives it back '
          'when turned off, also after the boomerang was trimmed', () async {
        final source = File(p.join(temp.path, 'clip.mp4'))
          ..writeAsStringSync('take');
        const ramp = VideoSpeedRamp([
          VideoSpeedRampPoint(position: 0, speed: 0.5),
          VideoSpeedRampPoint(position: 1, speed: 2),
        ]);
        final bloc = seeded([
          _clip(
            videoPath: source.path,
            trimStart: Duration.zero,
            trimEnd: const Duration(seconds: 2),
          ).copyWith(speedRamp: ramp),
        ]);

        final bounced = (await toggle(bloc)).clips.single.speedRamp!;
        // Slow at both ends, fast on the turn.
        expect(bounced.points.map((point) => point.speed), [0.5, 2, 0.5]);
        expect(bounced.points.first.position, 0);
        expect(bounced.points.last.position, 1);

        // Trimmed shorter than its forward part: the curve is stretched over
        // what is left, not cut.
        final boomerang = bloc.state.clips.single;
        bloc.add(
          ClipEditorClipUpdated(
            clipId: 'clip',
            clip: boomerang.copyWith(
              trimEnd: const Duration(milliseconds: 2200),
            ),
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.clips.single.trimEnd == const Duration(milliseconds: 2200),
        );

        final restored = (await toggle(bloc)).clips.single.speedRamp!;
        expect(restored.points.first.speed, closeTo(0.5, 1e-9));
        expect(restored.points.last.speed, closeTo(2, 1e-9));
      });

      test('a later transform drops the record', () async {
        // Turning the boomerang off swaps the footage before it back in. Kept
        // after a transform, the record would silently undo the crop.
        final bloc = seeded(
          [_clip()],
          transformClip: ({
            required sourceClip,
            required transform,
            required renderId,
          }) async => EditorVideo.file('/documents/clip_transformed.mp4'),
        );
        expect((await toggle(bloc)).clips.single.boomerang, isNotNull);

        final done = bloc.stream.firstWhere(
          (s) => s.lastTransformResult != null && !s.isTransforming,
        );
        bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip',
            transform: ExportTransform(),
          ),
        );
        final clip = (await done).clips.single;

        expect(clip.video!.file!.path, '/documents/clip_transformed.mp4');
        expect(clip.boomerang, isNull);
      });
    });

    group('a selection', () {
      const dissolve = ClipTransition(type: ClipTransitionType.dissolve);

      List<DivineVideoClip> fourClips() => [
        for (final id in ['a', 'b', 'c', 'd'])
          _clip(
            id: id,
            duration: const Duration(seconds: 1),
            trimStart: Duration.zero,
            trimEnd: Duration.zero,
          ),
      ];

      Future<ClipEditorBloc> selecting(
        List<DivineVideoClip> clips,
        List<String> ids, {
        RenderBoomerangFn? renderBoomerang,
      }) async {
        final bloc = seeded(clips, renderBoomerang: renderBoomerang);
        bloc.add(ClipEditorMultiSelectStarted(ids.first));
        for (final id in ids.skip(1)) {
          bloc.add(ClipEditorMultiSelectClipToggled(id));
        }
        await bloc.stream.firstWhere(
          (s) => s.selectedClipIds.length == ids.length,
        );
        return bloc;
      }

      test(
        'bounces neighbouring clips as one boomerang in their place',
        () async {
          final clips = fourClips();
          clips[2] = clips[2].copyWith(transition: dissolve);
          final bloc = await selecting(clips, ['b', 'c']);

          final state = await request(
            bloc,
            const ClipEditorSelectedClipsBoomerangRequested(),
          );

          // The transition out of the selection is rendered by neither the
          // merge nor the bounce: it leads into the clip after them.
          expect(merged.map((c) => c.id), ['b', 'c']);
          expect(merged.last.transition, isNull);
          expect(state.clips.map((c) => c.id), ['a', 'merged', 'd']);
          final boomerang = state.clips[1];
          expect(
            boomerang.video!.file!.path,
            '/documents/merged_boomerang.mp4',
          );
          expect(boomerang.transition, dissolve);
          expect(boomerang.boomerang?.sourcePath, '/documents/merged.mp4');
          expect(state.currentClipIndex, 1);
          expect(state.isMultiSelectMode, isFalse);
          expect(state.selectedClipIds, isEmpty);
          expect(
            state.lastBoomerangResult,
            isA<ClipBoomerangSuccess>()
                .having((r) => r.clipId, 'clipId', 'merged')
                .having((r) => r.previousClips, 'previousClips', hasLength(4)),
          );
        },
      );

      test('bounces a single selected clip without merging it', () async {
        final bloc = await selecting(fourClips(), ['c']);

        final state = await request(
          bloc,
          const ClipEditorSelectedClipsBoomerangRequested(),
        );

        expect(merged, isEmpty);
        expect(state.clips.map((c) => c.id), ['a', 'b', 'c', 'd']);
        expect(state.clips[2].boomerang, isNotNull);
        expect(state.isMultiSelectMode, isFalse);
      });

      test('turns a single selected boomerang off instead of bouncing it '
          'again', () async {
        final source = File(p.join(temp.path, 'take.mp4'))
          ..writeAsStringSync('take');
        // Plays longer than a boomerang may be made from, as a boomerang of a
        // long take does: turning it off must not be refused as too long.
        final bounced =
            _clip(
              id: 'b',
              videoPath: '/documents/b_boomerang.mp4',
              duration: const Duration(seconds: 5),
              trimStart: Duration.zero,
              trimEnd: Duration.zero,
            ).copyWith(
              boomerang: ClipBoomerang(
                sourcePath: source.path,
                sourceDuration: const Duration(seconds: 4),
                sourceTrimStart: const Duration(seconds: 1),
                sourceTrimEnd: const Duration(milliseconds: 500),
              ),
            );
        final bloc = await selecting(
          [_clip(id: 'a'), bounced],
          ['b'],
          renderBoomerang: ({required sourceClip, required renderId}) =>
              throw StateError('turning a boomerang off renders nothing'),
        );

        final state = await request(
          bloc,
          const ClipEditorSelectedClipsBoomerangRequested(),
        );

        final clip = state.clips[1];
        expect(clip.video!.file!.path, source.path);
        expect(clip.duration, const Duration(seconds: 4));
        expect(clip.trimStart, const Duration(seconds: 1));
        expect(clip.trimEnd, const Duration(milliseconds: 500));
        expect(clip.boomerang, isNull);
        expect(
          state.lastBoomerangResult,
          isA<ClipBoomerangSuccess>()
              .having((r) => r.bounced, 'bounced', isFalse)
              .having((r) => r.clipId, 'clipId', 'b'),
        );
        expect(state.isMultiSelectMode, isFalse);
      });

      test('does not bounce a single selected clip whose recorded green '
          'screen is still to bake', () async {
        var rendered = false;
        final clips = fourClips();
        clips[2] = clips[2].copyWith(captureChromaKey: _recordedKey);
        final bloc = await selecting(
          clips,
          ['c'],
          renderBoomerang: ({required sourceClip, required renderId}) {
            rendered = true;
            return _fakeBoomerang(sourceClip: sourceClip, renderId: renderId);
          },
        );
        expect(bloc.state.canBoomerangSelection, isFalse);

        bloc.add(const ClipEditorSelectedClipsBoomerangRequested());
        await pumpEventQueue();

        expect(rendered, isFalse);
        expect(bloc.state.clips[2].boomerang, isNull);
        expect(bloc.state.lastBoomerangResult, isNull);
        expect(bloc.state.isMultiSelectMode, isTrue);
      });

      test('does nothing for clips with a gap between them', () async {
        final bloc = await selecting(fourClips(), ['a', 'c']);
        expect(bloc.state.canBoomerangSelection, isFalse);

        bloc.add(const ClipEditorSelectedClipsBoomerangRequested());
        await pumpEventQueue();

        expect(merged, isEmpty);
        expect(bloc.state.lastBoomerangResult, isNull);
        expect(bloc.state.isMultiSelectMode, isTrue);
      });

      test('keeps the selection when it would run too long', () async {
        final clips = [
          for (final id in ['a', 'b'])
            _clip(
              id: id,
              duration: const Duration(seconds: 2),
              trimStart: Duration.zero,
              trimEnd: Duration.zero,
            ),
        ];
        final bloc = await selecting(clips, ['a', 'b']);

        final state = await request(
          bloc,
          const ClipEditorSelectedClipsBoomerangRequested(),
        );

        expect(state.lastBoomerangResult, isA<ClipBoomerangTooLong>());
        expect(merged, isEmpty);
        expect(state.isMultiSelectMode, isTrue);
        expect(state.selectedClipIds, {'a', 'b'});
      });
    });
  });
}
