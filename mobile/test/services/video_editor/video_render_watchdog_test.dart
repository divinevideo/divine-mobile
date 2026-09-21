// ABOUTME: Tests render timeout, cancellation, and failure reporting
// ABOUTME: Keeps a stalled native render from surviving beside its retry

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';

/// Records every non-fatal so a test can assert the reason it was filed under.
class _RecordingCrashReporter implements CrashReporter {
  final reports = <({Object error, String? reason})>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    reports.add((error: error, reason: reason));
  }
}

void main() {
  group('VideoRenderWatchdog.run', () {
    tearDown(() => VideoRenderWatchdog.crashReporterOverride = null);

    test('times out, cancels, reports, and observes a stalled export', () {
      fakeAsync((async) {
        final hung = Completer<void>();
        Object? failure;
        Object? reportedFailure;
        String? cancelledTaskId;
        VideoRenderWatchdog.crashReporterOverride = (error, stackTrace) =>
            reportedFailure = error;

        unawaited(
          VideoRenderWatchdog.run<void>(
            render: hung.future,
            taskId: 'stalled-final-export',
            cancelTask: (taskId) async => cancelledTaskId = taskId,
          ).then<void>(
            (_) => fail('the stalled export must not complete successfully'),
            onError: (Object error, StackTrace stackTrace) => failure = error,
          ),
        );

        async.elapse(VideoEditorConstants.renderWatchdogTimeout);
        async.flushMicrotasks();

        expect(
          failure,
          isA<VideoRenderFailedException>().having(
            (error) => error.reason,
            'reason',
            VideoRenderFailureReason.timedOut,
          ),
        );
        expect(cancelledTaskId, 'stalled-final-export');
        expect(reportedFailure, same(failure));

        hung.completeError(Exception('late native failure'));
        async.flushMicrotasks();
      });
    });

    test('returns the result and neither cancels nor reports when the export '
        'settles in time', () {
      fakeAsync((async) {
        var cancelled = false;
        var reported = false;
        VideoRenderWatchdog.crashReporterOverride = (_, _) => reported = true;

        int? result;
        unawaited(
          VideoRenderWatchdog.run<int>(
            render: Future<int>.value(7),
            taskId: 'fast-export',
            cancelTask: (_) async => cancelled = true,
          ).then<void>((value) => result = value),
        );

        async.flushMicrotasks();
        // Elapse past the bound to prove the timer was cancelled on success
        // and does not fire a late cancel or report.
        async.elapse(VideoEditorConstants.renderWatchdogTimeout);
        async.flushMicrotasks();

        expect(result, 7);
        expect(cancelled, isFalse);
        expect(reported, isFalse);
      });
    });

    test('reports and throws without cancelling when a stalled export has no '
        'task id', () {
      fakeAsync((async) {
        final hung = Completer<void>();
        var cancelCalled = false;
        Object? reportedFailure;
        VideoRenderWatchdog.crashReporterOverride = (error, _) =>
            reportedFailure = error;

        Object? failure;
        unawaited(
          VideoRenderWatchdog.run<void>(
            render: hung.future,
            taskId: null,
            cancelTask: (_) async => cancelCalled = true,
          ).then<void>(
            (_) => fail('the stalled export must not complete successfully'),
            onError: (Object error, StackTrace _) => failure = error,
          ),
        );

        async.elapse(VideoEditorConstants.renderWatchdogTimeout);
        async.flushMicrotasks();

        expect(
          failure,
          isA<VideoRenderFailedException>().having(
            (error) => error.reason,
            'reason',
            VideoRenderFailureReason.timedOut,
          ),
        );
        expect(cancelCalled, isFalse);
        expect(reportedFailure, same(failure));

        hung.completeError(Exception('late native failure'));
        async.flushMicrotasks();
      });
    });

    test("bounds a preview render by the caller's timeout and files the "
        "timeout under the caller's reason", () {
      final originalCrashReporter = VideoRenderWatchdog.crashReporter;
      final crashReporter = _RecordingCrashReporter();
      VideoRenderWatchdog.crashReporter = crashReporter;
      addTearDown(
        () => VideoRenderWatchdog.crashReporter = originalCrashReporter,
      );

      fakeAsync((async) {
        final hung = Completer<void>();
        Object? failure;
        String? cancelledTaskId;

        unawaited(
          VideoRenderWatchdog.run<void>(
            render: hung.future,
            taskId: 'stalled-preview-render',
            cancelTask: (taskId) async => cancelledTaskId = taskId,
            timeout: VideoEditorConstants.previewRenderWatchdogTimeout,
            reason: 'preview render timed out',
          ).then<void>(
            (_) => fail('the stalled render must not complete successfully'),
            onError: (Object error, StackTrace _) => failure = error,
          ),
        );

        // The preview bound is deliberately shorter than the export's; a
        // render that outlives it must be cut off there, not at the default.
        async.elapse(
          VideoEditorConstants.previewRenderWatchdogTimeout -
              const Duration(seconds: 1),
        );
        async.flushMicrotasks();
        expect(failure, isNull);
        expect(cancelledTaskId, isNull);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(
          failure,
          isA<VideoRenderFailedException>().having(
            (error) => error.reason,
            'reason',
            VideoRenderFailureReason.timedOut,
          ),
        );
        expect(cancelledTaskId, 'stalled-preview-render');
        expect(crashReporter.reports, hasLength(1));
        expect(crashReporter.reports.single.error, same(failure));
        expect(crashReporter.reports.single.reason, 'preview render timed out');

        hung.completeError(Exception('late native failure'));
        async.flushMicrotasks();
      });
    });
  });
}
