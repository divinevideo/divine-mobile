// ABOUTME: Verifies the clip_postprocess trace times each enrichment phase and
// ABOUTME: waits for a chroma-key bake, ending once with the right outcome.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/clip_postprocess_trace.dart';

import '../helpers/recording_performance_monitor.dart';

void main() {
  group(ClipPostprocessTrace, () {
    late RecordingPerformanceMonitor monitor;

    setUp(() => monitor = RecordingPerformanceMonitor());

    RecordedPerformanceTrace onlyTrace() {
      expect(monitor.traces, hasLength(1));
      return monitor.traces.single;
    }

    test('times each phase and ends with the enrichment', () {
      fakeAsync((async) {
        final trace = ClipPostprocessTrace(monitor, chromaKey: false);
        final copied = Completer<void>();
        final read = Completer<void>();
        final saved = Completer<bool>();
        unawaited(
          trace.timeEnrichment(() async {
            trace.startPhase(ClipPostprocessPhase.copy);
            await copied.future;
            trace.startPhase(ClipPostprocessPhase.duration);
            await read.future;
            trace.startPhase(ClipPostprocessPhase.librarySave);
            trace.librarySaved(saved: await saved.future);
          }),
        );

        async.elapse(const Duration(milliseconds: 40));
        copied.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 60));
        read.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 25));

        expect(onlyTrace().stops, 0);

        saved.complete(true);
        async.flushMicrotasks();

        final sample = onlyTrace();
        expect(sample.name, 'clip_postprocess');
        expect(sample.stops, 1);
        expect(sample.attributes, {'outcome': 'success', 'chroma_key': 'no'});
        expect(sample.metrics, {
          'total_ms': 125,
          'copy_ms': 40,
          'duration_ms': 60,
          'library_save_ms': 25,
        });
      });
    });

    test('waits for the chroma-key bake and times it after the enrichment', () {
      fakeAsync((async) {
        final trace = ClipPostprocessTrace(monitor, chromaKey: true);
        final enriched = Completer<void>();
        final baked = Completer<void>();
        unawaited(
          trace.timeEnrichment(() async {
            trace.startPhase(ClipPostprocessPhase.copy);
            await enriched.future;
            trace.librarySaved(saved: true);
          }),
        );
        unawaited(trace.timeChromaKeyBake(baked.future));

        async.elapse(const Duration(milliseconds: 100));
        enriched.complete();
        async.flushMicrotasks();

        expect(onlyTrace().stops, 0);

        async.elapse(const Duration(milliseconds: 300));
        baked.complete();
        async.flushMicrotasks();

        final sample = onlyTrace();
        expect(sample.stops, 1);
        expect(sample.attributes, {'outcome': 'success', 'chroma_key': 'yes'});
        expect(sample.metrics, {
          'total_ms': 400,
          'copy_ms': 100,
          'chroma_key_bake_ms': 300,
        });
      });
    });

    test('reports a library refusal as save_failed', () async {
      final trace = ClipPostprocessTrace(monitor, chromaKey: false);

      await trace.timeEnrichment(() async {
        trace
          ..startPhase(ClipPostprocessPhase.librarySave)
          ..librarySaved(saved: false);
      });

      expect(onlyTrace().attributes['outcome'], 'save_failed');
    });

    test(
      'reports a take that never reached its library save as superseded',
      () async {
        final trace = ClipPostprocessTrace(monitor, chromaKey: false);

        await trace.timeEnrichment(
          () async => trace.startPhase(ClipPostprocessPhase.copy),
        );

        final sample = onlyTrace();
        expect(sample.stops, 1);
        expect(sample.attributes['outcome'], 'superseded');
        expect(sample.metrics.keys, {'total_ms', 'copy_ms'});
      },
    );

    test('reports a step that threw as an error and passes it on', () async {
      final trace = ClipPostprocessTrace(monitor, chromaKey: false);

      await expectLater(
        trace.timeEnrichment(() async {
          trace.startPhase(ClipPostprocessPhase.thumbnail);
          throw StateError('thumbnail extraction failed');
        }),
        throwsStateError,
      );

      final sample = onlyTrace();
      expect(sample.stops, 1);
      expect(sample.attributes['outcome'], 'error');
      expect(sample.metrics.keys, {'total_ms', 'thumbnail_ms'});
    });
  });
}
