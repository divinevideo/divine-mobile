// ABOUTME: Tests for changing the backdrop a placeholder clip holds after a
// ABOUTME: detach — the in-place swap, the recorded fill, and the failures

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_placeholder_fill.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

const _blue = ClipPlaceholderColorFill(Color(0xFF112233));
const _red = ClipPlaceholderColorFill(Color(0xFFAA0000));

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

DivineVideoClip _placeholder({
  String id = 'placeholder-1',
  ClipPlaceholderFill? fill = _blue,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/$id.png',
  isPlaceholder: true,
  placeholderFill: fill,
  volume: 0,
);

/// What a re-render hands back: a clip carrying the new file, under the fresh
/// id the render service always mints.
DivineVideoClip _rendered({String id = 'placeholder-2'}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/$id.png',
  isPlaceholder: true,
  volume: 0,
);

void main() {
  group('$ClipEditorBloc placeholder fill', () {
    late List<DivineVideoClip> clips;

    setUp(() {
      clips = [_clip('a'), _placeholder(), _clip('c')];
    });

    ClipEditorBloc seeded({
      RenderClipPlaceholderFn? renderClipPlaceholder,
      void Function()? onFinalClipInvalidated,
      DeferFileCleanupFn? deferFileCleanup,
      List<DivineVideoClip>? withClips,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
        saveClipToLibrary: ({required clip}) async => false,
        deferFileCleanup: deferFileCleanup,
        // Defaults to a failing render so a test that does not wire one up
        // cannot silently pass a path it never exercised.
        renderClipPlaceholder:
            renderClipPlaceholder ??
            ({required fill, required source, taskId}) async => null,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(withClips ?? clips));
    }

    group('on success', () {
      test('keeps the slot in place and swaps only its file', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _rendered(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        // The rendered clip's own id is discarded: the timeline, the selection
        // and any duplicate still refer to the slot's.
        expect(bloc.state.clips.map((c) => c.id), [
          'a',
          'placeholder-1',
          'c',
        ]);
        final refilled = bloc.state.clips[1];
        expect(refilled.video?.file?.path, '/documents/placeholder-2.mp4');
        expect(refilled.thumbnailPath, '/documents/placeholder-2.png');
        expect(refilled.isPlaceholder, isTrue);
        expect(
          bloc.state.lastPlaceholderFillResult,
          isA<ClipPlaceholderFillSuccess>(),
        );
      });

      test('records the new fill so the next edit can reopen on it', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _rendered(),
        );
        await bloc.stream.first;
        expect(bloc.state.clips[1].placeholderFill, _blue);

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        expect(bloc.state.clips[1].placeholderFill, _red);
      });

      test('renders from the slot itself, so the length is kept', () async {
        DivineVideoClip? seenSource;
        ClipPlaceholderFill? seenFill;
        final bloc = seeded(
          renderClipPlaceholder:
              ({required fill, required source, taskId}) async {
                seenSource = source;
                seenFill = fill;
                return _rendered();
              },
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: ClipPlaceholderImageFill('/documents/shot.png'),
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        // The still inherits its duration and aspect from the clip it
        // replaces, so the composition does not change length.
        expect(seenSource?.id, 'placeholder-1');
        expect(seenSource?.duration, const Duration(seconds: 3));
        expect(seenFill, isA<ClipPlaceholderImageFill>());
      });

      test('commits the new clip list to editor history', () async {
        var invalidated = 0;
        final bloc = seeded(
          onFinalClipInvalidated: () => invalidated++,
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _rendered(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        // Without this the swap survives only until the next history sync
        // overwrites the clip list, and undo has nothing to go back to.
        expect(invalidated, 1);
      });

      test('queues the still it replaced for cleanup', () async {
        final deferred = <String>[];
        final bloc = seeded(
          deferFileCleanup: (paths) => deferred.addAll(paths.nonNulls),
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _rendered(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        expect(deferred, contains('/documents/placeholder-1.mp4'));
        expect(deferred, contains('/documents/placeholder-1.png'));
        // The file the slot now plays must survive the sweep.
        expect(deferred, isNot(contains('/documents/placeholder-2.mp4')));
      });

      test('marks the clip busy while the still renders', () async {
        final gate = Completer<DivineVideoClip?>();
        final bloc = seeded(
          renderClipPlaceholder: ({required fill, required source, taskId}) =>
              gate.future,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        final busy = await bloc.stream.first;

        // The action bar reads both to put the spinner on the right clip, and
        // the overlay reads the render id to show real progress.
        expect(busy.isRefillingPlaceholder, isTrue);
        expect(busy.refillingPlaceholderClipId, 'placeholder-1');
        expect(busy.refillingPlaceholderRenderId, 'placeholder-1_placeholder');

        gate.complete(_rendered());
        final done = await bloc.stream.firstWhere(
          (s) => !s.isRefillingPlaceholder,
        );
        expect(done.refillingPlaceholderClipId, isNull);
      });
    });

    group('on failure', () {
      test('leaves the backdrop it had when the render fails', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => null,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        expect(
          state.lastPlaceholderFillResult,
          isA<ClipPlaceholderFillFailure>(),
        );
        expect(
          state.clips[1].video?.file?.path,
          '/documents/placeholder-1.mp4',
        );
        expect(state.clips[1].placeholderFill, _blue);
        expect(state.isRefillingPlaceholder, isFalse);
      });

      test('surfaces a thrown render as a failure, not a crash', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => throw StateError('encoder gone'),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        expect(
          state.lastPlaceholderFillResult,
          isA<ClipPlaceholderFillFailure>(),
        );
        expect(state.clips.map((c) => c.id), ['a', 'placeholder-1', 'c']);
      });

      test('discards the result when the slot is deleted meanwhile', () async {
        final deferred = <String>[];
        final gate = Completer<DivineVideoClip?>();
        final bloc = seeded(
          deferFileCleanup: (paths) => deferred.addAll(paths.nonNulls),
          renderClipPlaceholder: ({required fill, required source, taskId}) =>
              gate.future,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(
            clipId: 'placeholder-1',
            fill: _red,
          ),
        );
        await bloc.stream.first;
        bloc.add(const ClipEditorClipRemoved('placeholder-1'));
        await bloc.stream.first;

        gate.complete(_rendered());
        final state = await bloc.stream.firstWhere(
          (s) => s.lastPlaceholderFillResult != null,
        );

        expect(
          state.lastPlaceholderFillResult,
          isA<ClipPlaceholderFillDiscarded>(),
        );
        expect(state.clips.map((c) => c.id), ['a', 'c']);
        // The render landed on disk with nothing to attach it to.
        expect(deferred, contains('/documents/placeholder-2.mp4'));
      });
    });

    group('with a clip that has no backdrop', () {
      test('refuses an ordinary clip', () async {
        var rendered = false;
        final bloc = seeded(
          renderClipPlaceholder:
              ({required fill, required source, taskId}) async {
                rendered = true;
                return _rendered();
              },
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(clipId: 'a', fill: _red),
        );
        await pumpEventQueue();

        // The action bar only offers this on a placeholder; this is the half
        // that holds if anything else dispatches the event. Replacing footage
        // with a still is a different operation nobody asked for.
        expect(rendered, isFalse);
        expect(bloc.state.clips[0].video?.file?.path, '/documents/a.mp4');
        expect(bloc.state.lastPlaceholderFillResult, isNull);
      });

      test('does nothing for an unknown clip', () async {
        final bloc = seeded();
        await bloc.stream.first;

        bloc.add(
          const ClipEditorPlaceholderFillRequested(clipId: 'nope', fill: _red),
        );
        await pumpEventQueue();

        expect(bloc.state.clips.map((c) => c.id), ['a', 'placeholder-1', 'c']);
        expect(bloc.state.lastPlaceholderFillResult, isNull);
      });
    });
  });
}
