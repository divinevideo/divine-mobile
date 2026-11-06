import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

void main() {
  tearDown(() => FeedPlaybackTelemetry.configure(enabled: false));

  test(
    'terminal failure is one shot and never reaches success stream',
    () async {
      FeedPlaybackTelemetry.configure(enabled: true);
      final terminals = <Map<String, Object?>>[];
      final successes = <FeedFirstFrameMetric>[];
      final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
      final successSub = FeedFirstFrameMetrics.events.listen(successes.add);
      FeedFirstFrameMetrics.start(videoId: 'private', index: 0)
        ..finish(
          outcome: FeedPlaybackOutcome.error,
          errorCategory: FeedPlaybackError.initialization,
        )
        ..complete(loadedFromCache: false);
      expect(terminals, hasLength(1));
      expect(terminals.single['outcome'], 'error');
      expect(terminals.single['error_category'], 'initialization');
      expect(terminals.single, isNot(contains('video_id')));
      expect(terminals.single, isNot(contains('ttff_ms')));
      expect(successes, isEmpty);
      await sub.cancel();
      await successSub.cancel();
    },
  );

  test('uninitialized collection and revoked attempts cannot escape', () async {
    final terminals = <Map<String, Object?>>[];
    final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
    final before = FeedFirstFrameMetrics.start(videoId: 'private', index: 0);
    FeedPlaybackTelemetry.configure(enabled: true);
    before.complete(loadedFromCache: false);
    final revoked = FeedFirstFrameMetrics.start(videoId: 'private', index: 0);
    FeedPlaybackTelemetry.configure(enabled: true, reset: true);
    revoked.complete(loadedFromCache: false);
    expect(terminals, isEmpty);
    await sub.cancel();
  });

  test(
    'new attempts reject pre-boundary loads and late network callbacks',
    () async {
      FeedPlaybackTelemetry.configure(enabled: true);
      final oldLoad = FeedPlaybackTelemetry.startLoad(networkSupported: true)!;
      FeedPlaybackTelemetry.configure(enabled: true, reset: true);
      oldLoad.observeNetwork({
        'load_id': oldLoad.id,
        'request_id': 'old',
        'network_outcome': 'complete',
        'network_duration_ms': 3,
        'network_bytes': 7,
      });
      final events = <Map<String, Object?>>[];
      final sub = FeedPlaybackTelemetry.events.listen(events.add);
      FeedFirstFrameMetrics.start(videoId: 'private', index: 0)
        ..attachLoad(oldLoad)
        ..complete(loadedFromCache: false);
      expect(events.single, isNot(contains('load_id')));
      expect(events.single, isNot(contains('network_bytes')));
      expect(events.single['network_coverage'], 'unknown');
      await sub.cancel();
    },
  );

  test('no-frame timeout terminates without fabricating first frame', () {
    fakeAsync((async) {
      FeedPlaybackTelemetry.configure(enabled: true);
      final terminals = <Map<String, Object?>>[];
      final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
      final timer = FeedFirstFrameMetrics.start(videoId: 'private', index: 0);
      async.elapse(const Duration(seconds: 60));
      timer.complete(loadedFromCache: false);
      expect(terminals.single['outcome'], 'no_frame');
      expect(terminals.single['error_category'], 'timeout');
      unawaited(sub.cancel());
    });
  });

  test(
    'observed requests report independent timing '
    'without adding cache bytes',
    () async {
      FeedPlaybackTelemetry.configure(enabled: true);
      final terminals = <Map<String, Object?>>[];
      final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
      final load = FeedPlaybackTelemetry.startLoad()!;
      load.observeNetwork({
        'load_id': load.id,
        'request_id': 'request-a',
        'network_headers_ms': 17,
        'network_duration_ms': 31,
        'network_bytes': 3,
        'network_outcome': 'complete',
      });
      FeedFirstFrameMetrics.start(videoId: 'private', index: 0)
        ..attachLoad(load)
        ..complete(loadedFromCache: false);
      expect(terminals.single['network_coverage'], 'observed');
      expect(terminals.single['network_headers_ms'], 17);
      expect(terminals.single['network_bytes'], 3);
      expect(terminals.single, isNot(contains('request_id')));
      await sub.cancel();
    },
  );

  test(
    'complete without duration cannot make an invalid operational sample',
    () async {
      FeedPlaybackTelemetry.configure(enabled: true);
      final terminals = <Map<String, Object?>>[];
      final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
      final load = FeedPlaybackTelemetry.startLoad(networkSupported: true)!;
      load.observeNetwork({
        'load_id': load.id,
        'request_id': 'request',
        'network_outcome': 'complete',
        'network_bytes': 9,
      });
      FeedFirstFrameMetrics.start(videoId: 'private', index: 0)
        ..attachLoad(load)
        ..complete(loadedFromCache: false);
      expect(terminals.single['network_outcome'], 'unavailable');
      expect(terminals.single['network_coverage'], 'unknown');
      expect(terminals.single['network_bytes'], isNull);
      await sub.cancel();
    },
  );

  test(
    'success whitelists measured fields and rotates attempts per activation',
    () async {
      FeedPlaybackTelemetry.configure(enabled: true);
      final terminals = <Map<String, Object?>>[];
      final sub = FeedPlaybackTelemetry.events.listen(terminals.add);
      final load = FeedPlaybackTelemetry.startLoad();
      for (var i = 0; i < 2; i++) {
        FeedFirstFrameMetrics.start(videoId: 'private', index: i)
          ..attachLoad(load)
          ..markSourceReady()
          ..complete(loadedFromCache: true);
      }
      final a = terminals.first;
      final b = terminals.last;
      expect(a['load_id'], b['load_id']);
      expect(a['attempt_id'], isNot(b['attempt_id']));
      expect(
        a['attempt_id'],
        matches(
          RegExp(
            '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(a['ttff_ms'], a['elapsed_ms']);
      expect(a['network_coverage'], 'cache');
      expect(a['network_bytes'], isNull);
      expect(
        a.keys,
        unorderedEquals([
          'event_id',
          'attempt_id',
          'load_id',
          'occurred_at_ms',
          'cohort',
          'outcome',
          'local_cache',
          'network_coverage',
          'elapsed_ms',
          'ttff_ms',
          'source_ready_ms',
          'network_outcome',
          'error_category',
        ]),
      );
      await sub.cancel();
    },
  );
}
