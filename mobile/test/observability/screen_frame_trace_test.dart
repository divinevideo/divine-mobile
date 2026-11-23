// ABOUTME: Verifies screen_frames judges frames by the display's refresh rate.
// ABOUTME: Covers percentiles, visit boundaries, background, covers, single stop.

import 'dart:ui' show AppLifecycleState, FrameTiming, TimingsCallback;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/screen_frame_trace.dart';

import '../helpers/recording_performance_monitor.dart';

class _FakeTimings implements FrameTimingsSource {
  final callbacks = <TimingsCallback>[];

  @override
  int? frameNumber = 0;

  @override
  bool drawingFrame = true;

  @override
  void addTimingsCallback(TimingsCallback callback) => callbacks.add(callback);

  @override
  void removeTimingsCallback(TimingsCallback callback) =>
      callbacks.remove(callback);

  void report(List<FrameTiming> timings) {
    for (final callback in [...callbacks]) {
      callback(timings);
    }
  }
}

/// Frame [number], whose UI thread waited [vsyncWaitUs] after vsync and then
/// built for [buildUs], and which rasterized for [rasterUs].
FrameTiming _frame(
  int number, {
  int vsyncWaitUs = 0,
  int buildUs = 2000,
  int rasterUs = 2000,
}) {
  final vsync = 1000000 + number * 20000;
  final buildStart = vsync + vsyncWaitUs;
  final buildFinish = buildStart + buildUs;
  final rasterFinish = buildFinish + rasterUs;
  return FrameTiming(
    vsyncStart: vsync,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: buildFinish,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
    frameNumber: number,
  );
}

/// Frames [first] up to [last], all drawn alike.
List<FrameTiming> _frames(
  int first,
  int last, {
  int buildUs = 2000,
  int rasterUs = 2000,
}) => [
  for (var number = first; number <= last; number++)
    _frame(number, buildUs: buildUs, rasterUs: rasterUs),
];

void main() {
  group(ScreenFrameTrace, () {
    late RecordingPerformanceMonitor monitor;
    late _FakeTimings timings;

    setUp(() {
      monitor = RecordingPerformanceMonitor();
      timings = _FakeTimings();
    });

    ScreenFrameTrace openTrace({
      double refreshRate = 60,
      TracedScreen screen = TracedScreen.editor,
      bool covered = false,
    }) => ScreenFrameTrace(
      monitor,
      screen: screen,
      refreshRate: () => refreshRate,
      foreground: true,
      covered: covered,
      timings: timings,
    );

    RecordedPerformanceTrace onlyTrace() {
      expect(monitor.traces, hasLength(1));
      return monitor.traces.single;
    }

    group('slow and frozen frames', () {
      // 10 frames that fit 8.3 ms and 5 that need 10 ms on the raster thread.
      List<FrameTiming> mixedFrames() => [
        ..._frames(1, 10, buildUs: 3000, rasterUs: 8000),
        ..._frames(11, 15, buildUs: 3000, rasterUs: 10000),
      ];

      test('counts a 10 ms frame as on time at 60 Hz', () {
        fakeAsync((async) {
          final trace = openTrace(screen: TracedScreen.recorder);
          timings.report(mixedFrames());
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 16;
          trace.close();

          final sample = onlyTrace();
          expect(sample.name, 'screen_frames');
          expect(sample.stops, 1);
          expect(sample.attributes, {
            'screen': 'recorder',
            'refresh': '60',
            'end': 'closed',
          });
          expect(sample.metrics['frames'], 15);
          expect(sample.metrics['slow_frames'], 0);
          expect(sample.metrics['slow_per_mille'], 0);
          expect(sample.metrics['visible_ms'], 2000);
        });
      });

      test('counts the same 10 ms frame as slow at 120 Hz', () {
        fakeAsync((async) {
          final trace = openTrace(refreshRate: 120);
          timings.report(mixedFrames());
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 16;
          trace.close();

          final sample = onlyTrace();
          expect(sample.attributes['refresh'], '120');
          expect(sample.metrics['frames'], 15);
          expect(sample.metrics['slow_frames'], 5);
          expect(sample.metrics['slow_per_mille'], 333);
          expect(sample.metrics['frozen_frames'], 0);
        });
      });

      test('counts a UI isolate still busy at vsync as slow', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report([
            ..._frames(1, 10),
            _frame(11, vsyncWaitUs: 15000),
          ]);
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 12;
          trace.close();

          final metrics = onlyTrace().metrics;
          expect(metrics['slow_frames'], 1);
          expect(metrics['frozen_frames'], 0);
        });
      });

      test('counts frames over 700 ms as frozen and slow', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report([
            ..._frames(1, 10),
            _frame(11, buildUs: 699000),
            _frame(12, rasterUs: 701000),
          ]);
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 13;
          trace.close();

          final metrics = onlyTrace().metrics;
          expect(metrics['frames'], 12);
          expect(metrics['slow_frames'], 2);
          expect(metrics['frozen_frames'], 1);
        });
      });
    });

    group('percentiles', () {
      test('reports the 90th percentile of build and raster time', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report([
            for (var number = 1; number <= 100; number++)
              _frame(
                number,
                buildUs: number <= 90 ? 1999 : 12000,
                rasterUs: number <= 89 ? 999 : 5000,
              ),
          ]);
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 101;
          trace.close();

          final metrics = onlyTrace().metrics;
          // The 90th build frame falls in the 1.75–2 ms bucket.
          expect(metrics['build_p90_us'], 2000);
          // The 90th raster frame is a 5 ms one, the longest of them all.
          expect(metrics['raster_p90_us'], 5000);
        });
      });

      test('keeps 2 ms buckets for frames over 32 ms', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report([
            for (var number = 1; number <= 100; number++)
              _frame(number, rasterUs: number <= 95 ? 40100 : 100000),
          ]);
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 101;
          trace.close();

          expect(onlyTrace().metrics['raster_p90_us'], 42000);
        });
      });
    });

    group('visit boundaries', () {
      test('leaves out frames drawn before the visit started', () {
        fakeAsync((async) {
          timings.frameNumber = 100;
          final trace = openTrace();
          timings.report(_frames(90, 115, buildUs: 30000));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 116;
          trace.close();

          expect(onlyTrace().metrics['frames'], 16);
        });
      });

      test('starts with the next frame when opened between frames', () {
        fakeAsync((async) {
          timings
            ..frameNumber = 100
            ..drawingFrame = false;
          final trace = openTrace();
          timings
            ..drawingFrame = true
            ..report(_frames(95, 115));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 116;
          trace.close();

          expect(onlyTrace().metrics['frames'], 15);
        });
      });

      test('waits for the frames it showed in before reporting', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 15));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 21;
          trace.close();

          expect(monitor.traces, isEmpty);

          timings.report(_frames(16, 25));

          expect(onlyTrace().metrics['frames'], 20);
          expect(timings.callbacks, isEmpty);
        });
      });

      test('reports at once when every frame it showed in arrived', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 20));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 21;
          trace.close();

          expect(onlyTrace().metrics['frames'], 20);
          expect(timings.callbacks, isEmpty);
        });
      });

      test('does not report a visit shorter than a second', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 50));
          async.elapse(const Duration(milliseconds: 900));
          timings.frameNumber = 51;
          trace.close();

          expect(monitor.traces, isEmpty);
          expect(timings.callbacks, isEmpty);
        });
      });

      test('does not report a visit with fewer than ten frames', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 9));
          async.elapse(const Duration(seconds: 5));
          timings.frameNumber = 10;
          trace.close();

          expect(monitor.traces, isEmpty);
        });
      });
    });

    group('background', () {
      test('ends the visit in the background and starts one on return', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 20));
          async.elapse(const Duration(seconds: 2));
          timings
            ..frameNumber = 20
            ..drawingFrame = false;
          trace.setForeground(false);

          expect(onlyTrace().attributes['end'], 'background');
          expect(onlyTrace().metrics['frames'], 20);
          expect(onlyTrace().metrics['visible_ms'], 2000);
          expect(timings.callbacks, isEmpty);

          async.elapse(const Duration(minutes: 5));
          trace.setForeground(true);
          timings
            ..drawingFrame = true
            ..report(_frames(21, 50));
          async.elapse(const Duration(seconds: 3));
          timings.frameNumber = 51;
          trace.close();

          expect(monitor.traces, hasLength(2));
          final second = monitor.traces.last;
          expect(second.attributes['end'], 'closed');
          expect(second.metrics['frames'], 30);
          expect(second.metrics['visible_ms'], 3000);
        });
      });

      test('treats inactive as foreground and hidden as background', () {
        expect(ScreenFrameTrace.isForeground(null), isTrue);
        expect(
          ScreenFrameTrace.isForeground(AppLifecycleState.resumed),
          isTrue,
        );
        expect(
          ScreenFrameTrace.isForeground(AppLifecycleState.inactive),
          isTrue,
        );
        expect(
          ScreenFrameTrace.isForeground(AppLifecycleState.hidden),
          isFalse,
        );
        expect(
          ScreenFrameTrace.isForeground(AppLifecycleState.paused),
          isFalse,
        );
      });
    });

    group('covered', () {
      test('does not count frames drawn while covered', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 20));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 21;
          trace.setCovered(true);

          expect(onlyTrace().attributes['end'], 'covered');

          timings.report(_frames(21, 40, buildUs: 30000));
          async.elapse(const Duration(seconds: 10));
          timings.frameNumber = 41;
          trace.setCovered(false);
          timings.report(_frames(41, 60));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 61;
          trace.close();

          expect(monitor.traces, hasLength(2));
          final second = monitor.traces.last;
          expect(second.metrics['frames'], 20);
          expect(second.metrics['slow_frames'], 0);
          expect(second.metrics['visible_ms'], 2000);
        });
      });

      test('keeps one timings callback while a covered visit drains', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 15));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 21;
          trace.setCovered(true);
          timings.frameNumber = 22;
          trace.setCovered(false);

          expect(timings.callbacks, hasLength(1));

          timings.report(_frames(16, 40));

          // The first visit got the frames it showed in; the second the rest.
          expect(onlyTrace().metrics['frames'], 20);

          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 41;
          trace.close();

          expect(monitor.traces, hasLength(2));
          expect(monitor.traces.last.metrics['frames'], 19);
          expect(timings.callbacks, isEmpty);
        });
      });

      test('starts no visit while it opens covered', () {
        fakeAsync((async) {
          final trace = openTrace(covered: true);

          expect(timings.callbacks, isEmpty);

          timings.frameNumber = 5;
          trace.setCovered(false);

          expect(timings.callbacks, hasLength(1));
        });
      });
    });

    group('close', () {
      test('reports the visit once and ignores later changes', () {
        fakeAsync((async) {
          final trace = openTrace();
          timings.report(_frames(1, 20));
          async.elapse(const Duration(seconds: 2));
          timings.frameNumber = 21;
          trace
            ..close()
            ..close()
            ..setCovered(true)
            ..setCovered(false)
            ..setForeground(false)
            ..setForeground(true);
          timings.report(_frames(21, 40));

          expect(onlyTrace().stops, 1);
          expect(timings.callbacks, isEmpty);
        });
      });
    });

    group('refreshBucket', () {
      test('buckets common display rates and calls the rest other', () {
        expect(ScreenFrameTrace.refreshBucket(59.94), '60');
        expect(ScreenFrameTrace.refreshBucket(90), '90');
        expect(ScreenFrameTrace.refreshBucket(120), '120');
        expect(ScreenFrameTrace.refreshBucket(144), 'other');
        expect(ScreenFrameTrace.refreshBucket(0), 'other');
      });
    });

    group('frameBudgetMicros', () {
      test('falls back to 60 Hz when the rate is unknown', () {
        expect(ScreenFrameTrace.frameBudgetMicros(120), 8333);
        expect(ScreenFrameTrace.frameBudgetMicros(0), 16667);
      });
    });
  });
}
