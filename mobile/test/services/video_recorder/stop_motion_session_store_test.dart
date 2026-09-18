// ABOUTME: Tests for StopMotionSessionStore — the serialized library writes
// ABOUTME: behind a stop-motion capture session and its discard cleanup.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/services/video_recorder/stop_motion_session_store.dart';

class _MockClipManager extends Mock implements ClipManagerNotifier {}

void main() {
  group(StopMotionSessionStore, () {
    late _MockClipManager clipManager;
    late StopMotionSessionStore store;
    late Directory frameDir;
    late String frameA;
    late String frameB;

    setUpAll(() {
      registerFallbackValue(model.AspectRatio.square);
      registerFallbackValue(Duration.zero);
      registerFallbackValue(<StopMotionClipFrame>[]);
      registerFallbackValue(
        DivineVideoClip(
          id: 'fallback',
          duration: Duration.zero,
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 1,
          stopMotionFrames: const [],
        ),
      );
    });

    setUp(() {
      clipManager = _MockClipManager();
      store = StopMotionSessionStore(readClipManager: () => clipManager);
      frameDir = Directory.systemTemp.createTempSync('sm_store');
      frameA = '${frameDir.path}/a.jpg';
      frameB = '${frameDir.path}/b.jpg';
      for (final path in [frameA, frameB]) {
        File(path).writeAsBytesSync(const [0]);
      }
    });

    tearDown(() => frameDir.deleteSync(recursive: true));

    void stubSessionSave(Future<bool> Function() answer) {
      when(
        () => clipManager.saveStopMotionSessionToLibrary(
          id: any(named: 'id'),
          frames: any(named: 'frames'),
          originalAspectRatio: any(named: 'originalAspectRatio'),
          targetAspectRatio: any(named: 'targetAspectRatio'),
          duration: any(named: 'duration'),
          thumbnailPath: any(named: 'thumbnailPath'),
          lensMetadata: any(named: 'lensMetadata'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('sessionId is stable while the session grows', () {
      expect(
        StopMotionSessionStore.sessionId(frameA),
        StopMotionSessionStore.sessionId(frameA),
      );
      expect(StopMotionSessionStore.sessionId(frameA), 'clip_sm_a');
    });

    test('runs library writes in order and a failed write does not block '
        'the next', () async {
      final calls = <String>[];
      final firstSave = Completer<bool>();
      var saves = 0;
      stubSessionSave(() {
        saves++;
        if (saves == 1) {
          calls.add('save-start');
          return firstSave.future;
        }
        calls.add('save-2');
        return Future.value(true);
      });
      when(
        () => clipManager.removeStopMotionSessionFromLibrary(any()),
      ).thenAnswer((_) async => calls.add('remove'));

      unawaited(
        store.persistSession([frameA], aspectRatio: model.AspectRatio.square),
      );
      unawaited(store.removeSession(frameA));
      final second = store.persistSession(
        [frameA, frameB],
        aspectRatio: model.AspectRatio.square,
      );
      await pumpEventQueue();
      expect(calls, ['save-start']);

      firstSave.completeError(StateError('library gone'));
      await second;
      await store.idle;

      expect(calls, ['save-start', 'remove', 'save-2']);
    });

    test('discardSession deletes the stills before dropping the row', () async {
      final removed = <String>[];
      when(
        () => clipManager.removeStopMotionSessionFromLibrary(any()),
      ).thenAnswer((invocation) async {
        expect(File(frameA).existsSync(), isFalse);
        expect(File(frameB).existsSync(), isFalse);
        removed.add(invocation.positionalArguments.single as String);
      });

      await store.discardSession([frameA, frameB]);

      expect(removed, ['clip_sm_a']);
    });

    group('ingest', () {
      late String missing;

      DivineVideoClip clipWith(String id, {String? libraryTitle}) =>
          DivineVideoClip(
            id: id,
            duration: const Duration(seconds: 1),
            recordedAt: DateTime(2026),
            targetAspectRatio: model.AspectRatio.square,
            originalAspectRatio: 1,
            libraryTitle: libraryTitle,
            stopMotionFrames: const [],
          );

      setUp(() {
        missing = '${frameDir.path}/missing.jpg';
        when(
          () => clipManager.addStopMotionClip(
            id: any(named: 'id'),
            frames: any(named: 'frames'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            duration: any(named: 'duration'),
            thumbnailPath: any(named: 'thumbnailPath'),
            lensMetadata: any(named: 'lensMetadata'),
          ),
        ).thenAnswer(
          (invocation) =>
              clipWith(invocation.namedArguments[#id] as String? ?? 'fallback'),
        );
        when(() => clipManager.clips).thenReturn(const []);
        when(() => clipManager.saveClipToLibrary(any())).thenAnswer(
          (_) async => true,
        );
      });

      test('drops unreadable stills and holds the ones that survive', () {
        store.ingest(
          [missing, frameA, frameB],
          aspectRatio: model.AspectRatio.square,
        );

        final frames =
            verify(
                  () => clipManager.addStopMotionClip(
                    id: any(named: 'id'),
                    frames: captureAny(named: 'frames'),
                    originalAspectRatio: any(named: 'originalAspectRatio'),
                    targetAspectRatio: any(named: 'targetAspectRatio'),
                    duration: any(named: 'duration'),
                    thumbnailPath: any(named: 'thumbnailPath'),
                    lensMetadata: any(named: 'lensMetadata'),
                  ),
                ).captured.single
                as List<StopMotionClipFrame>;

        expect(frames.map((f) => f.path), [frameA, frameB]);
        // The hold stretches a short session to a minimum length, so it must
        // count only the stills that made it into the clip.
        expect(frames.first.duration, StopMotionFrameOps.initialHold(2));
        expect(frames.first.duration, isNot(StopMotionFrameOps.initialHold(3)));
      });

      test('keeps the capture session id when its first still is gone', () {
        store.ingest(
          [missing, frameA, frameB],
          aspectRatio: model.AspectRatio.square,
        );

        // Keyed on the session's original first still, not the first surviving
        // one, so the row written during capture is updated rather than
        // duplicated.
        final id =
            verify(
                  () => clipManager.addStopMotionClip(
                    id: captureAny(named: 'id'),
                    frames: any(named: 'frames'),
                    originalAspectRatio: any(named: 'originalAspectRatio'),
                    targetAspectRatio: any(named: 'targetAspectRatio'),
                    duration: any(named: 'duration'),
                    thumbnailPath: any(named: 'thumbnailPath'),
                    lensMetadata: any(named: 'lensMetadata'),
                  ),
                ).captured.single
                as String;

        expect(id, StopMotionSessionStore.sessionId(missing));
        expect(id, isNot(StopMotionSessionStore.sessionId(frameA)));
      });

      test('queues the clip manager\'s own copy of the clip', () async {
        final stored = clipWith('clip_sm_a', libraryTitle: 'from manager');
        when(() => clipManager.clips).thenReturn([stored]);

        final returned = store.ingest(
          [frameA],
          aspectRatio: model.AspectRatio.square,
        );
        await store.idle;

        // Re-read after the add so the queued save carries whatever the
        // manager actually holds, not the pre-insert value.
        final saved =
            verify(
                  () => clipManager.saveClipToLibrary(captureAny()),
                ).captured.single
                as DivineVideoClip;
        expect(saved.libraryTitle, 'from manager');
        expect(returned.libraryTitle, isNull);
      });
    });

    test('ingest refuses a session with no readable still', () {
      expect(
        () => store.ingest(
          ['${frameDir.path}/missing.jpg'],
          aspectRatio: model.AspectRatio.square,
        ),
        throwsStateError,
      );
      verifyNever(
        () => clipManager.addStopMotionClip(
          id: any(named: 'id'),
          frames: any(named: 'frames'),
          originalAspectRatio: any(named: 'originalAspectRatio'),
          targetAspectRatio: any(named: 'targetAspectRatio'),
          duration: any(named: 'duration'),
          thumbnailPath: any(named: 'thumbnailPath'),
          lensMetadata: any(named: 'lensMetadata'),
        ),
      );
    });
  });
}
