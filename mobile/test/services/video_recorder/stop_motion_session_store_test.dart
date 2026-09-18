// ABOUTME: Tests for StopMotionSessionStore — the serialized library writes
// ABOUTME: behind a stop-motion capture session and its discard cleanup.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
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
