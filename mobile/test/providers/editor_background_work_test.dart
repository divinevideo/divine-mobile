// ABOUTME: Tests the editor background-work fixed-point completion boundary
// ABOUTME: Verifies work spawned by tracked operations also settles

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/editor_background_work.dart';

void main() {
  group('EditorBackgroundWork', () {
    test('settle waits for work started by a tracked operation', () async {
      final backgroundWork = EditorBackgroundWork();
      final startSecondOperation = Completer<void>();
      final finishSecondOperation = Completer<void>();

      backgroundWork.track(() async {
        await startSecondOperation.future;
        backgroundWork.track(finishSecondOperation.future);
      }());
      expect(backgroundWork.isNotEmptyForTest, isTrue);

      var settled = false;
      final settling = backgroundWork.settle().then((_) => settled = true);
      startSecondOperation.complete();
      await startSecondOperation.future;
      expect(settled, isFalse);

      finishSecondOperation.complete();
      await settling;
      expect(settled, isTrue);
      expect(backgroundWork.isNotEmptyForTest, isFalse);
    });

    test('settle drains spawned work before rethrowing an error', () async {
      final backgroundWork = EditorBackgroundWork();
      final startFailingOperation = Completer<void>();
      final finishSpawnedOperation = Completer<void>();

      backgroundWork.track(() async {
        await startFailingOperation.future;
        backgroundWork.track(finishSpawnedOperation.future);
        throw StateError('tracked operation failed');
      }());

      var settlingFinished = false;
      final settling = backgroundWork.settle();
      settling.then<void>(
        (_) => settlingFinished = true,
        onError: (Object _, StackTrace _) => settlingFinished = true,
      );
      final errorExpectation = expectLater(
        settling,
        throwsA(isA<StateError>()),
      );

      startFailingOperation.complete();
      await pumpEventQueue();
      expect(
        settlingFinished,
        isFalse,
        reason: 'settle must keep draining work spawned by a failed batch',
      );

      finishSpawnedOperation.complete();
      await errorExpectation;
      expect(backgroundWork.isNotEmptyForTest, isFalse);
    });
  });
}
