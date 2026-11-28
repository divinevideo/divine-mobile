// ABOUTME: Verifies the editor_ready trace ends once, when the editor is usable.
// ABOUTME: Covers each entry, the stop-motion boundary, failures, and leaving.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/editor_ready_trace.dart';

import '../helpers/recording_performance_monitor.dart';

void main() {
  group(EditorReadyTrace, () {
    late RecordingPerformanceMonitor monitor;

    setUp(() => monitor = RecordingPerformanceMonitor());

    RecordedPerformanceTrace onlyTrace() {
      expect(monitor.traces, hasLength(1));
      return monitor.traces.single;
    }

    group('ready', () {
      test('waits for the video preview to load and show its first frame', () {
        fakeAsync((async) {
          final ready = EditorReadyTrace(monitor, entry: EditorEntry.draft);
          async.elapse(const Duration(milliseconds: 400));
          ready.clipsLoaded(clipCount: 2, stopMotion: false);
          async.elapse(const Duration(milliseconds: 300));
          ready.previewLoaded();

          expect(onlyTrace().stops, 0);

          async.elapse(const Duration(milliseconds: 100));
          ready.previewFirstFrame();

          final trace = onlyTrace();
          expect(trace.name, 'editor_ready');
          expect(trace.stops, 1);
          expect(trace.attributes, {
            'entry': 'draft',
            'outcome': 'ready',
            'clips': '2-3',
            'preview': 'video',
          });
          expect(trace.metrics, {
            'total_ms': 800,
            'clips_loaded_ms': 400,
            'player_ready_ms': 700,
            'first_frame_ms': 800,
          });
          expect(ready.isPending, isFalse);
        });
      });

      test('waits for initialization when the preview loads first', () {
        fakeAsync((async) {
          final ready = EditorReadyTrace(monitor, entry: EditorEntry.recording);
          async.elapse(const Duration(milliseconds: 250));
          ready
            ..previewLoaded()
            ..previewFirstFrame();

          expect(onlyTrace().stops, 0);

          async.elapse(const Duration(milliseconds: 50));
          ready.clipsLoaded(clipCount: 1, stopMotion: false);

          final trace = onlyTrace();
          expect(trace.stops, 1);
          expect(trace.attributes['outcome'], 'ready');
          expect(trace.metrics['total_ms'], 300);
          expect(trace.metrics['first_frame_ms'], 250);
        });
      });

      test('needs no preview player for a stop-motion composition', () {
        final ready = EditorReadyTrace(monitor, entry: EditorEntry.clips)
          ..clipsLoaded(clipCount: 1, stopMotion: true);

        final trace = onlyTrace();
        expect(ready.isPending, isFalse);
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'ready');
        expect(trace.attributes['preview'], 'stop_motion');
        expect(trace.metrics.keys, isNot(contains('player_ready_ms')));
      });

      test('needs no preview player when the editor has no clips', () {
        EditorReadyTrace(
          monitor,
          entry: EditorEntry.draft,
        ).clipsLoaded(clipCount: 0, stopMotion: false);

        final trace = onlyTrace();
        expect(trace.attributes['outcome'], 'ready');
        expect(trace.attributes['clips'], '0');
        expect(trace.attributes['preview'], 'none');
      });
    });

    group('pre_route_ms', () {
      test('adds the time before the route for an editor the recorder '
          'asked for', () {
        fakeAsync((async) {
          final request = EditorOpenRequest();
          async.elapse(const Duration(milliseconds: 450));
          final ready = EditorReadyTrace(
            monitor,
            entry: EditorEntry.recording,
            openRequest: request,
          );
          async.elapse(const Duration(milliseconds: 100));
          ready.clipsLoaded(clipCount: 1, stopMotion: true);

          final trace = onlyTrace();
          expect(trace.metrics['pre_route_ms'], 450);
          expect(trace.metrics['total_ms'], 100);
          expect(trace.attributes['entry'], 'recording');
        });
      });
    });

    group('failed', () {
      test('ends the trace when the preview fails to load', () {
        EditorReadyTrace(monitor, entry: EditorEntry.recording)
          ..clipsLoaded(clipCount: 3, stopMotion: false)
          ..failed();

        final trace = onlyTrace();
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'failed');
        expect(trace.attributes['clips'], '2-3');
      });
    });

    group('left', () {
      test('ends the trace when the editor closes before it is usable', () {
        EditorReadyTrace(monitor, entry: EditorEntry.recording)
          ..clipsLoaded(clipCount: 4, stopMotion: false)
          ..previewLoaded()
          ..left();

        final trace = onlyTrace();
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'left');
        expect(trace.metrics.keys, contains('player_ready_ms'));
        expect(trace.metrics.keys, isNot(contains('first_frame_ms')));
      });

      test('reports unknown clips when a draft closes while loading', () {
        EditorReadyTrace(monitor, entry: EditorEntry.draft).left();

        final trace = onlyTrace();
        expect(trace.attributes, {
          'entry': 'draft',
          'outcome': 'left',
          'clips': 'unknown',
          'preview': 'unknown',
        });
        expect(trace.metrics.keys, ['total_ms']);
      });

      test('does not end a trace that already ended as ready', () {
        EditorReadyTrace(monitor, entry: EditorEntry.clips)
          ..clipsLoaded(clipCount: 1, stopMotion: false)
          ..previewLoaded()
          ..previewFirstFrame()
          ..failed()
          ..left();

        final trace = onlyTrace();
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'ready');
      });
    });
  });

  group('EditorEntry.of', () {
    test('a draft wins over the Library it was opened from', () {
      expect(
        EditorEntry.of(hasDraft: true, fromLibrary: true),
        EditorEntry.draft,
      );
    });

    test('clips from the Library without a draft', () {
      expect(
        EditorEntry.of(hasDraft: false, fromLibrary: true),
        EditorEntry.clips,
      );
    });

    test('the recorder otherwise', () {
      expect(
        EditorEntry.of(hasDraft: false, fromLibrary: false),
        EditorEntry.recording,
      );
    });
  });

  group('EditorReadyTrace.clipCountBucket', () {
    test('groups clip counts into fixed buckets', () {
      expect(
        [null, 0, 1, 2, 3, 4, 6, 7, 35].map(EditorReadyTrace.clipCountBucket),
        ['unknown', '0', '1', '2-3', '2-3', '4-6', '4-6', '7+', '7+'],
      );
    });
  });
}
