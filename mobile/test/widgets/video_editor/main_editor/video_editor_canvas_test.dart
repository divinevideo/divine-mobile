import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_history_direction.dart';
import 'package:openvine/models/video_editor/clip_snapshot_sync_op.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show ProVideoController;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  testWidgets('VideoEditorCanvas renders safely with no clips', (tester) async {
    final bodySizeNotifier = ValueNotifier(Size.zero);
    addTearDown(bodySizeNotifier.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => VideoEditorMainBloc()),
              BlocProvider(create: (_) => VideoEditorDrawBloc()),
              BlocProvider(create: (_) => VideoEditorFilterBloc()),
            ],
            child: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              onOpenCamera: () {},
              onAddStickers: () {},
              onOpenClipsEditor: () {},
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              onAddEditTextLayer: ([_]) async => null,
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: bodySizeNotifier,
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              playTimeNotifier: ValueNotifier(Duration.zero),
              playheadAdvancingNotifier: ValueNotifier<bool>(false),
              fromLibrary: false,
              child: const Scaffold(body: VideoEditorCanvas()),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('VideoEditorCanvas.syncPositionAfterTrimRelease', () {
    late _SpyVideoEditorMainBloc mainBloc;
    late ProVideoController controller;

    setUp(() {
      mainBloc = _SpyVideoEditorMainBloc();
      controller = ProVideoController(
        videoPlayer: const SizedBox.shrink(),
        videoDuration: Duration.zero,
        initialResolution: Size.zero,
        fileSize: 0,
      );
    });

    tearDown(() async {
      await mainBloc.close();
    });

    test('dispatches VideoEditorPositionChanged(startPosition) and updates '
        'playTime when the trim-end position was not pre-dispatched', () {
      const startPosition = Duration(seconds: 2);

      VideoEditorCanvas.syncPositionAfterTrimRelease(
        mainBloc: mainBloc,
        proVideoController: controller,
        startPosition: startPosition,
        trimEndAlreadyDispatched: false,
      );

      expect(
        mainBloc.events,
        contains(
          isA<VideoEditorPositionChanged>().having(
            (e) => e.position,
            'position',
            startPosition,
          ),
        ),
      );
      expect(controller.playTimeNotifier.value, equals(startPosition));
    });

    test('skips the bloc dispatch but still updates playTime when the '
        'trim-end position was already pushed pre-await', () {
      const startPosition = Duration(milliseconds: 1500);

      VideoEditorCanvas.syncPositionAfterTrimRelease(
        mainBloc: mainBloc,
        proVideoController: controller,
        startPosition: startPosition,
        trimEndAlreadyDispatched: true,
      );

      expect(mainBloc.events.whereType<VideoEditorPositionChanged>(), isEmpty);
      expect(controller.playTimeNotifier.value, equals(startPosition));
    });
  });

  group('VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack', () {
    test('requires both a selected sound and recorder handoff flag', () {
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: true,
          seedSelectedSoundAsAudioTrack: true,
        ),
        isTrue,
      );
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: true,
          seedSelectedSoundAsAudioTrack: false,
        ),
        isFalse,
      );
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: false,
          seedSelectedSoundAsAudioTrack: true,
        ),
        isFalse,
      );
    });
  });

  group('VideoEditorCanvas.shouldSyncPlayerForClipStateChange', () {
    test('skips split render intermediate clip updates', () {
      final source = _createClip(id: 'source');
      final start = _createClip(id: 'start');
      final previewEnd = _createClip(id: 'end');

      final previous = ClipEditorState(clips: [source], isSplitting: true);
      final current = ClipEditorState(
        clips: [start, previewEnd],
        isSplitting: true,
      );

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: previous,
          current: current,
        ),
        isFalse,
      );
    });

    test('syncs once when split rendering finishes', () {
      final start = _createClip(id: 'start');
      final end = _createClip(id: 'end');
      final clips = [start, end];

      final previous = ClipEditorState(clips: clips, isSplitting: true);
      final current = ClipEditorState(clips: clips);

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: previous,
          current: current,
        ),
        isTrue,
      );
    });

    test('keeps syncing ordinary non-trim clip changes', () {
      final source = _createClip(id: 'source');
      final copy = _createClip(id: 'copy');

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: ClipEditorState(clips: [source]),
          current: ClipEditorState(clips: [source, copy]),
        ),
        isTrue,
      );
    });

    test('skips a thumbnail-only change (poster refresh after a split)', () {
      final clip = _createClip(id: 'end');

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: ClipEditorState(clips: [clip]),
          current: ClipEditorState(
            clips: [clip.copyWith(thumbnailPath: '/thumbs/end.jpg')],
          ),
        ),
        isFalse,
      );
    });

    test('still syncs when a trim changes alongside the thumbnail', () {
      final clip = _createClip(id: 'end');

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: ClipEditorState(clips: [clip]),
          current: ClipEditorState(
            clips: [
              clip.copyWith(
                thumbnailPath: '/thumbs/end.jpg',
                trimStart: const Duration(seconds: 1),
              ),
            ],
          ),
        ),
        isTrue,
      );
    });
  });

  group('VideoEditorCanvas.shouldAcceptPlayerReport', () {
    const target = Duration(seconds: 3, milliseconds: 500);

    test(
      'accepts any report while playing, regardless of a pending target',
      () {
        // Playback owns the play time, so the settle guard never applies.
        expect(
          VideoEditorCanvas.shouldAcceptPlayerReport(
            report: Duration.zero,
            seekTarget: target,
            isPlaying: true,
          ),
          isTrue,
        );
      },
    );

    test('accepts any report when no scrub / swap target is pending', () {
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report: const Duration(seconds: 2),
          seekTarget: null,
          isPlaying: false,
        ),
        isTrue,
      );
    });

    test('accepts a paused report that has converged on the target', () {
      // Within tolerance on either side (frame snapping after an exact seek).
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report: target + const Duration(milliseconds: 40),
          seekTarget: target,
          isPlaying: false,
        ),
        isTrue,
      );
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report: target - const Duration(milliseconds: 40),
          seekTarget: target,
          isPlaying: false,
        ),
        isTrue,
      );
    });

    test(
      'rejects the position-0 reset report a seam swap emits while paused',
      () {
        // The reported regression: a transition finishes rendering, the player
        // loads the seam file and reports position 0. Accepting it would snap the
        // playhead back to the start.
        expect(
          VideoEditorCanvas.shouldAcceptPlayerReport(
            report: Duration.zero,
            seekTarget: target,
            isPlaying: false,
          ),
          isFalse,
        );
      },
    );

    test('rejects a stale paused report from a superseded scrub seek', () {
      // Scrubbed 2s -> 4s -> 3.5s; a late report for the 2s leading seek must
      // not drive the play time back to 2s.
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report: const Duration(seconds: 2),
          seekTarget: target,
          isPlaying: false,
        ),
        isFalse,
      );
    });

    test('accepts a paused report exactly at the tolerance boundary', () {
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report: target + VideoEditorCanvas.seekSettleTolerance,
          seekTarget: target,
          isPlaying: false,
        ),
        isTrue,
      );
      expect(
        VideoEditorCanvas.shouldAcceptPlayerReport(
          report:
              target +
              VideoEditorCanvas.seekSettleTolerance +
              const Duration(milliseconds: 1),
          seekTarget: target,
          isPlaying: false,
        ),
        isFalse,
      );
    });
  });

  group('VideoEditorCanvas.guardClipLoad', () {
    test('returns true when the composition builds', () async {
      final built = await VideoEditorCanvas.guardClipLoad(() async {});

      expect(built, isTrue);
    });

    test(
      'returns false and swallows a COMPOSITION_ERROR rejection (#3410)',
      () async {
        // The iOS player rejects an unbuildable composition for stale draft
        // clips. The rejection must not escape as an unhandled async error and
        // surface as a Crashlytics non-fatal.
        Future<bool> guard() => VideoEditorCanvas.guardClipLoad(
          () async => throw PlatformException(
            code: 'COMPOSITION_ERROR',
            message: 'Video composition has an invalid render size.',
          ),
        );

        await expectLater(guard(), completion(isFalse));
      },
    );

    test('returns false for a NOT_READY timeout from the native player', () {
      expect(
        VideoEditorCanvas.guardClipLoad(
          () async => throw PlatformException(
            code: 'NOT_READY',
            message: 'setClips timed out before player reached STATE_READY',
          ),
        ),
        completion(isFalse),
      );
    });

    test('returns false for a PLAYER_ERROR from the native player', () {
      expect(
        VideoEditorCanvas.guardClipLoad(
          () async => throw PlatformException(
            code: 'PLAYER_ERROR',
            message: 'Decoder failed while loading clips.',
          ),
        ),
        completion(isFalse),
      );
    });

    test('rethrows a non-platform error so genuine bugs still surface', () {
      // A programming-invariant violation (StateError/ArgumentError) is not a
      // composition rejection — it must propagate so it reaches Crashlytics
      // instead of being hidden behind a silent thumbnail fallback.
      expect(
        VideoEditorCanvas.guardClipLoad(
          () async => throw ArgumentError('clips must not be empty'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rethrows unexpected platform errors', () {
      expect(
        VideoEditorCanvas.guardClipLoad(
          () async => throw PlatformException(
            code: 'INVALID_ARGS',
            message: 'clips list required',
          ),
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'INVALID_ARGS',
          ),
        ),
      );
    });
  });

  group('VideoEditorCanvas.shouldPublishClipLoad', () {
    test('publishes the active clip load generation', () {
      expect(
        VideoEditorCanvas.shouldPublishClipLoad(
          generation: 3,
          currentGeneration: 3,
        ),
        isTrue,
      );
    });

    test('rejects a superseded clip load generation', () {
      expect(
        VideoEditorCanvas.shouldPublishClipLoad(
          generation: 3,
          currentGeneration: 4,
        ),
        isFalse,
      );
    });
  });

  group('VideoEditorCanvas.resolveClipSnapshotSync', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('canvas_orphan_sync');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    DivineVideoClip resolvableClip(String id) {
      final path = '${tempDir.path}/$id.mp4';
      File(path).writeAsBytesSync(const [0]);
      return _createClip(id: id, videoPath: path);
    }

    DivineVideoClip orphanClip(String id) =>
        _createClip(id: id, videoPath: '${tempDir.path}/$id-missing.mp4');

    test('syncs only the clips whose source files still exist', () {
      final resolvable = resolvableClip('a');
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: [resolvable, orphanClip('b')],
        direction: ClipHistoryDirection.undo,
        canUndo: true,
        canRedo: false,
        didReverse: false,
      );

      expect(decision.op, ClipSnapshotSyncOp.sync);
      expect(decision.resolvableClips, equals([resolvable]));
      expect(decision.reversed, isFalse);
    });

    test('skips a history entry that carries no clips', () {
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: const [],
        direction: ClipHistoryDirection.none,
        canUndo: true,
        canRedo: true,
        didReverse: false,
      );

      expect(decision.op, ClipSnapshotSyncOp.skip);
      expect(decision.resolvableClips, isEmpty);
    });

    test('steps backward when undo restores only deleted-source clips', () {
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: [orphanClip('a'), orphanClip('b')],
        direction: ClipHistoryDirection.undo,
        canUndo: true,
        canRedo: false,
        didReverse: false,
      );

      expect(decision.op, ClipSnapshotSyncOp.stepBackward);
      expect(decision.resolvableClips, isEmpty);
      expect(decision.reversed, isFalse);
    });

    test('steps forward when redo restores only deleted-source clips', () {
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: [orphanClip('a')],
        direction: ClipHistoryDirection.redo,
        canUndo: false,
        canRedo: true,
        didReverse: false,
      );

      expect(decision.op, ClipSnapshotSyncOp.stepForward);
      expect(decision.reversed, isFalse);
    });

    test(
      'reverses to redo once when an orphan-only state is at the undo boundary',
      () {
        final decision = VideoEditorCanvas.resolveClipSnapshotSync(
          snapshot: [orphanClip('a')],
          direction: ClipHistoryDirection.undo,
          canUndo: false,
          canRedo: true,
          didReverse: false,
        );

        expect(decision.op, ClipSnapshotSyncOp.stepForward);
        expect(decision.reversed, isTrue);
      },
    );

    test(
      'reverses to undo once when an orphan-only state is at the redo boundary',
      () {
        final decision = VideoEditorCanvas.resolveClipSnapshotSync(
          snapshot: [orphanClip('a')],
          direction: ClipHistoryDirection.redo,
          canUndo: true,
          canRedo: false,
          didReverse: false,
        );

        expect(decision.op, ClipSnapshotSyncOp.stepBackward);
        expect(decision.reversed, isTrue);
      },
    );

    test('does not reverse a second time once a reversal already happened', () {
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: [orphanClip('a')],
        direction: ClipHistoryDirection.undo,
        canUndo: false,
        canRedo: true,
        didReverse: true,
      );

      expect(decision.op, ClipSnapshotSyncOp.skip);
    });

    test('skips when an orphan-only history has no reachable neighbour', () {
      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: [orphanClip('a')],
        direction: ClipHistoryDirection.none,
        canUndo: false,
        canRedo: false,
        didReverse: false,
      );

      expect(decision.op, ClipSnapshotSyncOp.skip);
    });

    test(
      'treats a stop-motion clip whose stills exist as resolvable',
      () async {
        // Frames-only clips have no video by design; without the stop-motion
        // branch in hasResolvableVideoFile every history sync would classify
        // them as orphaned and step the history backwards, silently undoing
        // frame edits.
        final framePath = '${tempDir.path}/frame0.jpg';
        File(framePath).writeAsBytesSync(const [0]);
        final clip = DivineVideoClip(
          id: 'sm',
          stopMotionFrames: [
            StopMotionClipFrame(
              path: framePath,
              duration: const Duration(milliseconds: 83),
            ),
          ],
          duration: const Duration(milliseconds: 83),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        final decision = VideoEditorCanvas.resolveClipSnapshotSync(
          snapshot: [clip],
          direction: ClipHistoryDirection.none,
          canUndo: true,
          canRedo: false,
          didReverse: false,
        );

        expect(decision.op, ClipSnapshotSyncOp.sync);
        expect(decision.resolvableClips, [clip]);
      },
    );
  });

  group('VideoEditorCanvas.clipsChanged', () {
    const hold2 = Duration(milliseconds: 83);
    const hold4 = Duration(milliseconds: 167);

    test('is false for equal-content lists (different instances)', () {
      final a = _createStopMotionClip(id: 'sm', holds: [hold2, hold2]);
      final b = _createStopMotionClip(id: 'sm', holds: [hold2, hold2]);

      expect(VideoEditorCanvas.clipsChanged([a], [b]), isFalse);
    });

    test('detects a frame-hold change', () {
      final a = _createStopMotionClip(id: 'sm', holds: [hold2, hold2]);
      final b = _createStopMotionClip(id: 'sm', holds: [hold4, hold4]);

      expect(VideoEditorCanvas.clipsChanged([a], [b]), isTrue);
    });

    test('detects a deleted frame', () {
      final a = _createStopMotionClip(id: 'sm', holds: [hold2, hold2]);
      final b = _createStopMotionClip(id: 'sm', holds: [hold2]);

      expect(VideoEditorCanvas.clipsChanged([a], [b]), isTrue);
    });

    test('detects a clip-count change', () {
      final a = _createStopMotionClip(id: 'sm', holds: [hold2]);

      expect(VideoEditorCanvas.clipsChanged([a], []), isTrue);
    });
  });
}

DivineVideoClip _createClip({required String id, String? videoPath}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(videoPath ?? '/test/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

DivineVideoClip _createStopMotionClip({
  required String id,
  required List<Duration> holds,
}) {
  return DivineVideoClip(
    id: id,
    stopMotionFrames: [
      for (var i = 0; i < holds.length; i++)
        StopMotionClipFrame(path: '/frames/$id-$i.jpg', duration: holds[i]),
    ],
    duration: holds.fold(Duration.zero, (sum, hold) => sum + hold),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

/// Captures every event added to the bloc so tests can assert
/// dispatches that don't change the resulting state value (and would
/// therefore not appear on `bloc.stream`).
class _SpyVideoEditorMainBloc extends VideoEditorMainBloc {
  final List<VideoEditorMainEvent> events = [];

  @override
  void add(VideoEditorMainEvent event) {
    events.add(event);
    super.add(event);
  }
}
