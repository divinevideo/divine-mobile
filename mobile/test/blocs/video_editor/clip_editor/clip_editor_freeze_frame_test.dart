// ABOUTME: Tests for freezing the frame under the playhead — where the still
// ABOUTME: lands on the timeline, and the failure and discard paths

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  ClipTransition? transition,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: duration,
  trimStart: trimStart,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  transition: transition,
);

DivineVideoClip _freeze() => DivineVideoClip(
  id: 'freeze-1',
  video: EditorVideo.file('/documents/freeze-1.mp4'),
  duration: const Duration(milliseconds: 6300),
  trimEnd: const Duration(milliseconds: 5800),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/freeze-1.jpg',
  isFreezeFrame: true,
  volume: 0,
);

void main() {
  group('$ClipEditorBloc freeze frame', () {
    late List<DivineVideoClip> clips;
    late List<Iterable<String?>> deferredPaths;

    setUp(() {
      clips = [_clip('a'), _clip('b'), _clip('c')];
      deferredPaths = [];
    });

    ClipEditorBloc seeded({
      RenderFreezeFrameFn? renderFreezeFrame,
      List<DivineVideoClip>? withClips,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        deferFileCleanup: deferredPaths.add,
        renderFreezeFrame:
            renderFreezeFrame ??
            ({required source, required framePosition, taskId}) async =>
                _freeze(),
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(withClips ?? clips));
    }

    Future<ClipEditorState> freeze(
      ClipEditorBloc bloc, {
      required String clipId,
      required Duration position,
    }) async {
      await bloc.stream.first;
      bloc.add(
        ClipEditorFreezeFrameRequested(clipId: clipId, position: position),
      );
      return bloc.stream.firstWhere((s) => s.lastFreezeFrameResult != null);
    }

    test('cuts the clip and holds the frame between the halves', () async {
      Duration? seenPosition;
      final bloc = seeded(
        withClips: [
          _clip('a', trimStart: const Duration(milliseconds: 500)),
          _clip('b'),
        ],
        renderFreezeFrame:
            ({required source, required framePosition, taskId}) async {
              seenPosition = framePosition;
              return _freeze();
            },
      );

      final state = await freeze(
        bloc,
        clipId: 'a',
        position: const Duration(seconds: 1),
      );

      expect(seenPosition, const Duration(milliseconds: 1500));
      expect(state.clips, hasLength(4));
      final [start, held, end, next] = state.clips;
      expect(start.trimStart, const Duration(milliseconds: 500));
      expect(start.trimmedDuration, const Duration(seconds: 1));
      expect(held.id, 'freeze-1');
      // The end half picks up exactly where the freeze was taken.
      expect(end.trimStart, const Duration(milliseconds: 1500));
      expect(end.minTrimStart, const Duration(milliseconds: 1500));
      expect(end.thumbnailPath, '/documents/freeze-1.jpg');
      expect(next.id, 'b');
      expect(state.lastSplit?.sourceClipId, 'a');
    });

    test('selects the freeze so its trim handles are ready', () async {
      final bloc = seeded();

      final state = await freeze(
        bloc,
        clipId: 'b',
        position: const Duration(seconds: 1),
      );

      expect(state.clips[state.currentClipIndex].id, 'freeze-1');
      expect(state.isEditing, isTrue);
      expect(state.isFreezingFrame, isFalse);
      final result = state.lastFreezeFrameResult! as ClipFreezeFrameSuccess;
      expect(result.freezeClipId, 'freeze-1');
      expect(result.previousClips.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('puts the freeze in front of a clip at its first frame', () async {
      final bloc = seeded();

      final state = await freeze(bloc, clipId: 'b', position: Duration.zero);

      expect(state.clips.map((c) => c.id), ['a', 'freeze-1', 'b', 'c']);
    });

    test(
      'moves the outgoing transition onto a freeze after the clip',
      () async {
        const dissolve = ClipTransition(
          type: ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 300),
        );
        final bloc = seeded(
          withClips: [
            _clip('a', transition: dissolve),
            _clip('b'),
          ],
        );

        final state = await freeze(
          bloc,
          clipId: 'a',
          position: const Duration(seconds: 3),
        );

        expect(state.clips.map((c) => c.id), ['a', 'freeze-1', 'b']);
        // The cut into the freeze is hard; the blend into the next clip now
        // starts from the held frame.
        expect(state.clips[0].transition, isNull);
        expect(state.clips[1].transition, dissolve);
      },
    );

    test('leaves the timeline alone when the render fails', () async {
      final bloc = seeded(
        renderFreezeFrame: ({
          required source,
          required framePosition,
          taskId,
        }) async => null,
      );

      final state = await freeze(
        bloc,
        clipId: 'b',
        position: const Duration(seconds: 1),
      );

      expect(state.lastFreezeFrameResult, isA<ClipFreezeFrameFailure>());
      expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
      expect(state.isFreezingFrame, isFalse);
    });

    test('treats a thrown render as a failure', () async {
      final bloc = seeded(
        renderFreezeFrame: ({
          required source,
          required framePosition,
          taskId,
        }) => Future.error(Exception('decoder gone')),
      );
      final state = await freeze(
        bloc,
        clipId: 'b',
        position: const Duration(seconds: 1),
      );

      expect(state.lastFreezeFrameResult, isA<ClipFreezeFrameFailure>());
      expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('drops the still when the clip is removed mid-render', () async {
      final release = Completer<void>();
      final bloc = seeded(
        renderFreezeFrame:
            ({required source, required framePosition, taskId}) async {
              await release.future;
              return _freeze();
            },
      );
      await bloc.stream.first;

      bloc.add(
        const ClipEditorFreezeFrameRequested(
          clipId: 'b',
          position: Duration(seconds: 1),
        ),
      );
      await bloc.stream.firstWhere((s) => s.isFreezingFrame);
      bloc.add(const ClipEditorClipRemoved('b'));
      await bloc.stream.firstWhere((s) => s.clips.length == 2);
      release.complete();
      final state = await bloc.stream.firstWhere(
        (s) => s.lastFreezeFrameResult != null,
      );

      expect(state.lastFreezeFrameResult, isA<ClipFreezeFrameDiscarded>());
      expect(state.clips.map((c) => c.id), ['a', 'c']);
      // Rendered files nothing points at go to the reaper.
      expect(
        deferredPaths.expand((paths) => paths),
        containsAll(['/documents/freeze-1.mp4', '/documents/freeze-1.jpg']),
      );
    });
  });
}
