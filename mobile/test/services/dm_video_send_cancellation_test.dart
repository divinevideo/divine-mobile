// ABOUTME: Verifies video DM watchdog ownership and cleanup with a fake clock.
// ABOUTME: Completed upload/readiness phases must not leave timers that fail a send.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_send_cancellation.dart';

void main() {
  group(DmVideoSendCancellation, () {
    test(
      'publication gate expires work even before a delayed watchdog runs',
      () {
        fakeAsync((clock) {
          var now = DateTime.utc(2026);
          final attempt = DmVideoSendCancellation(now: () => now);
          now = now.add(const Duration(minutes: 30));
          expect(
            attempt.beginPublication,
            throwsA(isA<DmVideoSendCancelled>()),
          );
          expect(attempt.uploadCancelToken.isCancelled, isTrue);
          attempt.finish();
        });
      },
    );

    test('resumed progress cannot refresh an already expired upload', () {
      fakeAsync((clock) {
        var now = DateTime.utc(2026);
        final attempt = DmVideoSendCancellation(now: () => now);
        attempt.startUpload();
        now = now.add(const Duration(minutes: 2));
        attempt.uploadProgress(0.9);
        expect(attempt.uploadCancelToken.isCancelled, isTrue);
        attempt.finish();
      });
    });

    test('resumed signer readiness still respects its own wait limit', () {
      fakeAsync((clock) {
        var now = DateTime.utc(2026);
        final attempt = DmVideoSendCancellation(now: () => now);
        final ready = Completer<void>();
        Object? failure;
        unawaited(
          attempt.waitForSigner(ready.future).catchError((Object error) {
            failure = error;
          }),
        );
        now = now.add(const Duration(minutes: 2));
        ready.complete();
        clock.flushMicrotasks();
        expect(failure, isA<DmVideoSendCancelled>());
        attempt.finish();
        expect(clock.nonPeriodicTimerCount, 0);
      });
    });

    test('a fallback reset cannot extend the pre-publication deadline', () {
      fakeAsync((clock) {
        final attempt = DmVideoSendCancellation(
          now: () => DateTime.utc(2026).add(clock.elapsed),
        );
        attempt.startUploadAttempt();
        for (var minute = 1; minute <= 29; minute++) {
          clock.elapse(const Duration(minutes: 1));
          attempt.uploadProgress(minute / 100);
        }
        // Rising progress kept the inactivity watchdog from firing.
        expect(attempt.uploadCancelToken.isCancelled, isFalse);
        attempt.startUploadAttempt();
        clock.elapse(const Duration(minutes: 1));
        expect(attempt.uploadCancelToken.isCancelled, isTrue);
        attempt.finish();
        expect(clock.nonPeriodicTimerCount, 0);
      });
    });

    test('completed upload does not expire while the preview is preparing', () {
      fakeAsync((clock) {
        final attempt = DmVideoSendCancellation();
        attempt.startUpload();
        attempt.uploadProgress(1);
        attempt.finishUpload();
        clock.elapse(const Duration(minutes: 29));
        expect(attempt.uploadCancelToken.isCancelled, isFalse);
        clock.elapse(const Duration(minutes: 1));
        expect(attempt.uploadCancelToken.isCancelled, isTrue);
        attempt.finish();
        expect(clock.nonPeriodicTimerCount, 0);
      });
    });

    test(
      'ready signer cancels its wait timer without expiring preparation',
      () {
        fakeAsync((clock) {
          final attempt = DmVideoSendCancellation();
          final ready = Completer<void>();
          var resumed = false;
          unawaited(
            attempt.waitForSigner(ready.future).then((_) => resumed = true),
          );
          ready.complete();
          clock.flushMicrotasks();
          expect(resumed, isTrue);
          clock.elapse(const Duration(minutes: 2));
          expect(attempt.uploadCancelToken.isCancelled, isFalse);
          attempt.finish();
          expect(clock.nonPeriodicTimerCount, 0);
        });
      },
    );
  });
}
