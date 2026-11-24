// ABOUTME: Verifies the recording_start and recording_stop traces end once.
// ABOUTME: Covers countdowns, phases, outcomes, and the take carried between.

import 'dart:async';

import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/observability/recording_traces.dart';

import '../helpers/recording_performance_monitor.dart';

/// Runs a step through [measure] that finishes once [duration] has passed on
/// the fake clock.
void finishStepAfter(
  FakeAsync async,
  Duration duration,
  Future<void> Function(Future<void> Function() step) measure,
) {
  final step = Completer<void>();
  unawaited(measure(() => step.future));
  async.elapse(duration);
  step.complete();
  async.flushMicrotasks();
}

const _context = RecordingTraceContext(
  mode: VideoRecorderMode.classic,
  stabilization: DivineVideoStabilizationMode.cinematic,
  dualCamera: true,
  chromaKey: false,
  reaction: true,
);

void main() {
  group(RecordingTraces, () {
    late RecordingPerformanceMonitor monitor;
    late RecordingTraces traces;

    setUp(() {
      monitor = RecordingPerformanceMonitor();
      traces = RecordingTraces(monitor);
    });

    RecordedPerformanceTrace onlyTrace() {
      expect(monitor.traces, hasLength(1));
      return monitor.traces.single;
    }

    group('start', () {
      test('reports a take that starts, with each phase it timed', () {
        fakeAsync((async) {
          final start = traces.start(_context, countdown: false, sound: true);
          finishStepAfter(
            async,
            const Duration(milliseconds: 120),
            (step) => start.measure(RecordingStartPhase.soundPrep, step),
          );
          finishStepAfter(
            async,
            const Duration(milliseconds: 300),
            (step) => start.measure(RecordingStartPhase.nativeStart, step),
          );
          finishStepAfter(
            async,
            const Duration(milliseconds: 5),
            (step) => start.measure(RecordingStartPhase.wakelock, step),
          );
          start.succeeded();

          final trace = onlyTrace();
          expect(trace.name, 'recording_start');
          expect(trace.stops, 1);
          expect(trace.attributes, {
            'outcome': 'success',
            'sound': 'on',
            'mode': 'classic',
            'stabilization': 'cinematic',
            'dual_camera': 'on',
          });
          expect(trace.metrics, {
            'start_ms': 425,
            'sound_prep_ms': 120,
            'native_start_ms': 300,
            'wakelock_ms': 5,
            'chroma_key': 0,
            'reaction': 1,
          });
        });
      });

      test('keeps the countdown out of the trace and reports it apart', () {
        fakeAsync((async) {
          final start = traces.start(_context, countdown: true, sound: false);
          async.elapse(const Duration(seconds: 3));

          expect(monitor.traces, isEmpty);

          start.countdownEnded();
          async.elapse(const Duration(milliseconds: 250));
          start.succeeded();

          final trace = onlyTrace();
          expect(trace.attributes['sound'], 'off');
          expect(trace.metrics['countdown_ms'], 3000);
          expect(trace.metrics['start_ms'], 250);
        });
      });

      test('reports a start given up during the countdown as aborted', () {
        fakeAsync((async) {
          final start = traces.start(_context, countdown: true, sound: false);
          async.elapse(const Duration(seconds: 2));
          start.aborted();

          final trace = onlyTrace();
          expect(trace.stops, 1);
          expect(trace.attributes['outcome'], 'aborted');
          expect(trace.metrics['countdown_ms'], 2000);
          expect(trace.metrics['start_ms'], 0);
        });
      });

      test('reports a camera that refused to start as failed', () {
        traces.start(_context, countdown: false, sound: false).failed();

        expect(onlyTrace().attributes['outcome'], 'failed');
        expect(onlyTrace().metrics, isNot(contains('countdown_ms')));
      });

      test('stops once, keeping the first outcome', () {
        traces.start(_context, countdown: false, sound: false)
          ..aborted()
          ..succeeded()
          ..errored();

        final trace = onlyTrace();
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'aborted');
      });

      test('ends as error when nothing else ended it', () {
        traces.start(_context, countdown: false, sound: false).errored();

        expect(onlyTrace().attributes['outcome'], 'error');
      });

      test('times a phase that throws and passes the error on', () async {
        final start = traces.start(_context, countdown: false, sound: false);

        await expectLater(
          start.measure<bool>(
            RecordingStartPhase.nativeStart,
            () async => throw StateError('camera gone'),
          ),
          throwsStateError,
        );
        start.errored();

        expect(onlyTrace().metrics, contains('native_start_ms'));
      });
    });

    group('stop', () {
      test('reports the take that ran since the start succeeded', () {
        fakeAsync((async) {
          traces.start(_context, countdown: false, sound: false).succeeded();
          async.elapse(const Duration(milliseconds: 4200));

          final stop = traces.stop(
            _context,
            trigger: RecordingStopTrigger.user,
          );
          finishStepAfter(
            async,
            const Duration(milliseconds: 1600),
            (step) => stop.measure(RecordingStopPhase.nativeStop, step),
          );
          stop.finished(file: true, secondaryFile: true);

          final trace = monitor.traces.last;
          expect(trace.name, 'recording_stop');
          expect(trace.stops, 1);
          expect(trace.attributes, {
            'outcome': 'success',
            'trigger': 'user',
            'mode': 'classic',
            'stabilization': 'cinematic',
            'dual_camera': 'on',
          });
          expect(trace.metrics, {
            'stop_ms': 1600,
            'native_stop_ms': 1600,
            'take_ms': 4200,
            'secondary_file': 1,
            'chroma_key': 0,
            'reaction': 1,
          });
        });
      });

      test('reports a take that ended without a file as no_file', () {
        traces
            .stop(_context, trigger: RecordingStopTrigger.auto)
            .finished(file: false, secondaryFile: false);

        final trace = onlyTrace();
        expect(trace.attributes['outcome'], 'no_file');
        expect(trace.attributes['trigger'], 'auto');
        expect(trace.metrics['secondary_file'], 0);
      });

      test('reports a stop that threw as error', () {
        traces.stop(_context, trigger: RecordingStopTrigger.teardown).errored();

        final trace = onlyTrace();
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'error');
        expect(trace.attributes['trigger'], 'teardown');
      });

      test('has no take length without a take that started', () {
        traces.start(_context, countdown: false, sound: false).failed();
        traces
            .stop(_context, trigger: RecordingStopTrigger.user)
            .finished(file: false, secondaryFile: false);

        expect(monitor.traces.last.metrics, isNot(contains('take_ms')));
      });

      test('reports each take once', () {
        traces.start(_context, countdown: false, sound: false).succeeded();
        traces
            .stop(_context, trigger: RecordingStopTrigger.user)
            .finished(file: true, secondaryFile: false);
        traces
            .stop(_context, trigger: RecordingStopTrigger.auto)
            .finished(file: true, secondaryFile: false);

        expect(monitor.traces[1].metrics, contains('take_ms'));
        expect(monitor.traces[2].metrics, isNot(contains('take_ms')));
      });
    });
  });
}
