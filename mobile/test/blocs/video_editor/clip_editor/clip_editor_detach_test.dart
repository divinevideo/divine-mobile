// ABOUTME: Tests for detaching a clip from the timeline onto the canvas —
// ABOUTME: slot removal, placeholder fill, and the failure paths

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_placeholder_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(String id, {Duration? duration}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: duration ?? const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

DivineVideoClip _placeholderClip() => DivineVideoClip(
  id: 'placeholder-1',
  video: EditorVideo.file('/documents/placeholder-1.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  volume: 0,
);

void main() {
  group('$ClipEditorBloc detach', () {
    late List<DivineVideoClip> clips;

    setUp(() {
      clips = [_clip('a'), _clip('b'), _clip('c')];
    });

    ClipEditorBloc buildBloc({
      RenderClipPlaceholderFn? renderClipPlaceholder,
      void Function()? onFinalClipInvalidated,
    }) => ClipEditorBloc(
      onFinalClipInvalidated: onFinalClipInvalidated ?? () {},
      saveClipToLibrary: ({required clip}) async => false,
      // Defaults to a failing render so a test that does not wire one up
      // cannot silently pass a placeholder path it never exercised.
      renderClipPlaceholder:
          renderClipPlaceholder ??
          ({required fill, required source, taskId}) async => null,
    );

    ClipEditorBloc seeded({
      RenderClipPlaceholderFn? renderClipPlaceholder,
      void Function()? onFinalClipInvalidated,
      List<DivineVideoClip>? withClips,
    }) {
      final bloc = buildBloc(
        renderClipPlaceholder: renderClipPlaceholder,
        onFinalClipInvalidated: onFinalClipInvalidated,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(withClips ?? clips));
    }

    group('with no replacement', () {
      test('drops the clip and closes the gap', () async {
        final bloc = seeded();
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        final state = await bloc.stream.first;

        expect(state.clips.map((c) => c.id), ['a', 'c']);
        expect(state.lastDetachResult, isA<ClipDetachSuccess>());
      });

      test('reports the clip that came off and the list before it', () async {
        final bloc = seeded();
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        final state = await bloc.stream.first;

        final result = state.lastDetachResult! as ClipDetachSuccess;
        // The widget layer needs both: the clip to put on the canvas, and the
        // old list to rebase timeline markers against.
        expect(result.detachedClip.id, 'b');
        expect(result.previousClips.map((c) => c.id), ['a', 'b', 'c']);
        expect(result.placeholder, isNull);
      });

      test('leaves editing mode so the action bar closes', () async {
        final bloc = seeded();
        await bloc.stream.first;
        bloc.add(const ClipEditorEditingStarted());
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        final state = await bloc.stream.first;

        expect(state.isEditing, isFalse);
      });

      test('never renders a placeholder', () async {
        var rendered = false;
        final bloc = seeded(
          renderClipPlaceholder:
              ({required fill, required source, taskId}) async {
                rendered = true;
                return _placeholderClip();
              },
        );
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'b'));
        await bloc.stream.first;

        // Closing the gap costs no encode; paying for one would make the
        // cheapest option the slowest.
        expect(rendered, isFalse);
      });

      test('refuses to leave the composition with no clips', () async {
        final bloc = seeded(withClips: [_clip('only')]);
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'only'));
        await pumpEventQueue();

        // The sheet hides the option for a lone clip; this is the half that
        // holds if anything else dispatches the event.
        expect(bloc.state.clips.map((c) => c.id), ['only']);
        expect(bloc.state.lastDetachResult, isNull);
      });

      test('keeps the selection inside the shortened list', () async {
        final bloc = seeded();
        await bloc.stream.first;
        bloc.add(const ClipEditorClipSelected(2));
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'c'));
        final state = await bloc.stream.first;

        expect(state.currentClipIndex, lessThan(state.clips.length));
      });
    });

    group('with a replacement fill', () {
      test('swaps the clip for the rendered still', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _placeholderClip(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        await bloc.stream.firstWhere((s) => s.lastDetachResult != null);

        // The slot keeps its place in the order — a swap, not a
        // remove-and-append.
        expect(bloc.state.clips.map((c) => c.id), ['a', 'placeholder-1', 'c']);
      });

      test('passes the fill and the source clip to the renderer', () async {
        ClipPlaceholderFill? seenFill;
        DivineVideoClip? seenSource;
        final bloc = seeded(
          renderClipPlaceholder:
              ({required fill, required source, taskId}) async {
                seenFill = fill;
                seenSource = source;
                return _placeholderClip();
              },
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderImageFill('/tmp/still.png'),
          ),
        );
        await bloc.stream.firstWhere((s) => s.lastDetachResult != null);

        expect(seenFill, isA<ClipPlaceholderImageFill>());
        expect(seenSource?.id, 'b');
      });

      test('reports the placeholder alongside the detached clip', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _placeholderClip(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );

        final result = state.lastDetachResult! as ClipDetachSuccess;
        expect(result.detachedClip.id, 'b');
        expect(result.placeholder?.id, 'placeholder-1');
      });

      test('marks the clip busy while the still renders', () async {
        final gate = Completer<DivineVideoClip?>();
        final bloc = seeded(
          renderClipPlaceholder: ({required fill, required source, taskId}) =>
              gate.future,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        final busy = await bloc.stream.first;

        // The action bar reads both to show the spinner on the right clip.
        expect(busy.isDetaching, isTrue);
        expect(busy.detachingClipId, 'b');

        gate.complete(_placeholderClip());
        final done = await bloc.stream.firstWhere((s) => !s.isDetaching);
        expect(done.detachingClipId, isNull);
      });

      test('leaves the timeline untouched when the render fails', () async {
        final bloc = seeded(
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => null,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );

        // A detach that silently dropped the slot would shorten the video the
        // user asked to keep the same length.
        expect(state.lastDetachResult, isA<ClipDetachFailure>());
        expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
        expect(state.isDetaching, isFalse);
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
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );

        expect(state.lastDetachResult, isA<ClipDetachFailure>());
        expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
      });

      test('discards the result when the clip is deleted meanwhile', () async {
        final gate = Completer<DivineVideoClip?>();
        final bloc = seeded(
          renderClipPlaceholder: ({required fill, required source, taskId}) =>
              gate.future,
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'b',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        await bloc.stream.first;
        bloc.add(const ClipEditorClipRemoved('b'));
        await bloc.stream.first;

        gate.complete(_placeholderClip());
        final state = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );

        expect(state.lastDetachResult, isA<ClipDetachDiscarded>());
        expect(state.clips.map((c) => c.id), ['a', 'c']);
      });

      test('does detach a lone clip when something replaces it', () async {
        final bloc = seeded(
          withClips: [_clip('only')],
          renderClipPlaceholder: ({
            required fill,
            required source,
            taskId,
          }) async => _placeholderClip(),
        );
        await bloc.stream.first;

        bloc.add(
          const ClipEditorClipDetachRequested(
            clipId: 'only',
            replacement: ClipPlaceholderColorFill(Color(0xFF112233)),
          ),
        );
        final state = await bloc.stream.firstWhere(
          (s) => s.lastDetachResult != null,
        );

        // The composition still has a track, so there is nothing to refuse.
        expect(state.lastDetachResult, isA<ClipDetachSuccess>());
        expect(state.clips.map((c) => c.id), ['placeholder-1']);
      });
    });

    group('with an unknown clip', () {
      test('does nothing at all', () async {
        final bloc = seeded();
        await bloc.stream.first;

        bloc.add(const ClipEditorClipDetachRequested(clipId: 'nope'));
        await pumpEventQueue();

        expect(bloc.state.clips.map((c) => c.id), ['a', 'b', 'c']);
        expect(bloc.state.lastDetachResult, isNull);
      });
    });
  });
}
