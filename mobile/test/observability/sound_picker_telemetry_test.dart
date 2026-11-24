// ABOUTME: Tests the sound picker's tab-load, search and pick telemetry.
// ABOUTME: Pins the reported values to their fixed vocabulary.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/sound_picker_telemetry.dart';
import 'package:sounds_repository/sounds_repository.dart'
    show SoundSearchRelays, SoundSearchSource;

import '../helpers/recording_analytics_event_sink.dart';
import '../helpers/recording_performance_monitor.dart';

class _FailingAnalyticsEventSink extends RecordingAnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => throw StateError('analytics unavailable');
}

void main() {
  group(SoundPickerTelemetry, () {
    late RecordingAnalyticsEventSink sink;
    late RecordingPerformanceMonitor monitor;
    late DateTime now;
    late SoundPickerTelemetry telemetry;

    void elapse(Duration duration) => now = now.add(duration);

    List<Map<String, Object>> surfaceLoads() =>
        sink.parametersOf('surface_load');

    setUp(() {
      sink = RecordingAnalyticsEventSink();
      monitor = RecordingPerformanceMonitor();
      now = DateTime(2026, 11, 18, 12);
      telemetry = SoundPickerTelemetry(
        surfaceTracker: SurfacePerformanceTracker(
          history: PageLoadHistory(),
          sink: sink,
          now: () => now,
        ),
        analytics: sink,
        performanceMonitor: monitor,
      );
    });

    group('tab loads', () {
      test('reports the time until a tab shows its list', () async {
        telemetry.startTabLoad(SoundPickerTab.forYou, isFirstTab: true);
        elapse(const Duration(milliseconds: 40));
        telemetry.markTabVisible(SoundPickerTab.forYou);
        elapse(const Duration(milliseconds: 1460));
        telemetry.completeTabLoad(
          SoundPickerTab.forYou,
          itemCount: 12,
          hasMore: true,
          wasLoaded: false,
        );
        await pumpEventQueue();

        expect(surfaceLoads(), [
          {
            AnalyticsParam.surfaceName: AnalyticsSurface.soundPicker,
            AnalyticsParam.result: SurfaceLoadResult.success,
            AnalyticsParam.visibleMs: 40,
            AnalyticsParam.dataMs: 1500,
            AnalyticsParam.totalMs: 1500,
            AnalyticsParam.slowBucket: '1_3s',
            AnalyticsParam.tab: 'for_you',
            AnalyticsParam.entryPoint: 'sheet_open',
            AnalyticsParam.itemCount: 12,
            AnalyticsParam.initialCount: 0,
            AnalyticsParam.hasMore: 1,
          },
        ]);
      });

      test('reports a list loaded before the tab opened with its count as '
          'the initial count', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.popular, isFirstTab: false)
          ..completeTabLoad(
            SoundPickerTab.popular,
            itemCount: 30,
            wasLoaded: true,
          );
        await pumpEventQueue();

        final load = surfaceLoads().single;
        expect(load, containsPair(AnalyticsParam.tab, 'popular'));
        expect(load, containsPair(AnalyticsParam.entryPoint, 'tab_switch'));
        expect(load, containsPair(AnalyticsParam.itemCount, 30));
        expect(load, containsPair(AnalyticsParam.initialCount, 30));
        expect(load, isNot(contains(AnalyticsParam.hasMore)));
      });

      test('reports an empty list as empty', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.mySounds, isFirstTab: false)
          ..completeTabLoad(
            SoundPickerTab.mySounds,
            itemCount: 0,
            wasLoaded: true,
          );
        await pumpEventQueue();

        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.empty),
        );
        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.tab, 'my_sounds'),
        );
      });

      test('reports a list that failed to load', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.newest, isFirstTab: false)
          ..failTabLoad(SoundPickerTab.newest);
        await pumpEventQueue();

        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.failure),
        );
        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.tab, 'newest'),
        );
      });

      test('reports a tab left before its list showed as dismissed', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.newest, isFirstTab: false)
          ..startTabLoad(SoundPickerTab.popular, isFirstTab: false)
          ..completeTabLoad(
            SoundPickerTab.newest,
            itemCount: 5,
            wasLoaded: false,
          );
        await pumpEventQueue();

        expect(surfaceLoads(), hasLength(1));
        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.dismissed),
        );
        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.tab, 'newest'),
        );
      });

      test('dismisses a loading tab when another tab that already showed '
          'opens', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.forYou, isFirstTab: true)
          ..completeTabLoad(
            SoundPickerTab.forYou,
            itemCount: 3,
            wasLoaded: false,
          )
          ..startTabLoad(SoundPickerTab.newest, isFirstTab: false);

        expect(
          telemetry.startTabLoad(SoundPickerTab.forYou, isFirstTab: false),
          isFalse,
        );
        await pumpEventQueue();

        expect(
          surfaceLoads().map((load) => load[AnalyticsParam.result]),
          [SurfaceLoadResult.success, SurfaceLoadResult.dismissed],
        );
      });

      test('times a tab only until its list first shows', () async {
        expect(
          telemetry.startTabLoad(SoundPickerTab.forYou, isFirstTab: true),
          isTrue,
        );
        telemetry.completeTabLoad(
          SoundPickerTab.forYou,
          itemCount: 3,
          wasLoaded: false,
        );

        expect(
          telemetry.startTabLoad(SoundPickerTab.forYou, isFirstTab: false),
          isFalse,
        );
        telemetry.completeTabLoad(
          SoundPickerTab.forYou,
          itemCount: 3,
          wasLoaded: true,
        );
        await pumpEventQueue();

        expect(surfaceLoads(), hasLength(1));
      });

      test('dismisses the loading tab for one that is not timed, and times '
          'it again once it reopens', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.popular, isFirstTab: true)
          ..dismissTabLoad();
        await pumpEventQueue();

        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.dismissed),
        );
        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.tab, 'popular'),
        );
        expect(
          telemetry.startTabLoad(SoundPickerTab.popular, isFirstTab: false),
          isTrue,
        );
      });

      test('dismisses the loading tab on dispose', () async {
        telemetry
          ..startTabLoad(SoundPickerTab.popular, isFirstTab: true)
          ..dispose();
        await pumpEventQueue();

        expect(
          surfaceLoads().single,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.dismissed),
        );
      });
    });

    group('search', () {
      test('times a search until its results arrive', () {
        telemetry
          ..startSearch()
          ..completeSearch(
            23,
            source: SoundSearchSource.relays,
            relays: SoundSearchRelays.answered,
          );

        final trace = monitor.traces.single;
        expect(trace.name, 'sound_search');
        expect(trace.attributes, {
          'outcome': 'results',
          'source': 'relays',
          'result_bucket': '11_50',
        });
        expect(trace.metrics, {'result_count': 23});
        expect(trace.stops, 1);
      });

      test('buckets the result count', () {
        for (final count in [0, 1, 10, 11, 50, 51]) {
          telemetry
            ..startSearch()
            ..completeSearch(
              count,
              source: SoundSearchSource.relays,
              relays: SoundSearchRelays.answered,
            );
        }

        expect(
          monitor.traces.map((trace) => trace.attributes['result_bucket']),
          ['0', '1_10', '1_10', '11_50', '11_50', 'over_50'],
        );
        expect(monitor.traces.first.attributes['outcome'], 'empty');
      });

      test('reports cached matches standing in for the relays as a '
          'fallback, never as results', () {
        for (final relays in [
          SoundSearchRelays.timedOut,
          SoundSearchRelays.noRelays,
          SoundSearchRelays.failed,
          SoundSearchRelays.notAsked,
        ]) {
          telemetry
            ..startSearch()
            ..completeSearch(
              3,
              source: SoundSearchSource.relays,
              relays: relays,
            );
        }

        expect(monitor.traces.map((trace) => trace.attributes), [
          {
            'outcome': 'fallback',
            'source': 'relays',
            'reason': 'timed_out',
            'result_bucket': '1_10',
          },
          {
            'outcome': 'fallback',
            'source': 'relays',
            'reason': 'no_relays',
            'result_bucket': '1_10',
          },
          {
            'outcome': 'fallback',
            'source': 'relays',
            'reason': 'relay_error',
            'result_bucket': '1_10',
          },
          {
            'outcome': 'fallback',
            'source': 'relays',
            'reason': 'not_asked',
            'result_bucket': '1_10',
          },
        ]);
        expect(
          monitor.traces.map((trace) => trace.metrics),
          everyElement({'result_count': 3}),
        );
      });

      test('reports a fallback with no cached matches as a fallback', () {
        telemetry
          ..startSearch()
          ..completeSearch(
            0,
            source: SoundSearchSource.relays,
            relays: SoundSearchRelays.timedOut,
          );

        expect(monitor.traces.single.attributes, {
          'outcome': 'fallback',
          'source': 'relays',
          'reason': 'timed_out',
          'result_bucket': '0',
        });
      });

      test('reports a Funnelcake answer as results, not a fallback', () {
        // Funnelcake answering is why the relays were not searched.
        for (final count in [4, 0]) {
          telemetry
            ..startSearch()
            ..completeSearch(
              count,
              source: SoundSearchSource.funnelcake,
              relays: SoundSearchRelays.notAsked,
            );
        }

        expect(monitor.traces.map((trace) => trace.attributes), [
          {
            'outcome': 'results',
            'source': 'funnelcake',
            'result_bucket': '1_10',
          },
          {'outcome': 'empty', 'source': 'funnelcake', 'result_bucket': '0'},
        ]);
      });

      test('reports a failed search', () {
        telemetry
          ..startSearch()
          ..failSearch();

        expect(monitor.traces.single.attributes, {'outcome': 'failure'});
        expect(monitor.traces.single.metrics, isEmpty);
        expect(monitor.traces.single.stops, 1);
      });

      test('reports a search replaced before it answered as abandoned', () {
        telemetry
          ..startSearch()
          ..startSearch();

        expect(monitor.traces, hasLength(2));
        expect(monitor.traces.first.attributes, {'outcome': 'abandoned'});
        expect(monitor.traces.first.stops, 1);
        expect(monitor.traces.last.stops, 0);
      });

      test('abandons the search in flight on dispose', () {
        telemetry
          ..startSearch()
          ..dispose();

        expect(monitor.traces.single.attributes, {'outcome': 'abandoned'});
        expect(monitor.traces.single.stops, 1);
      });

      test('reports nothing while no search is in flight', () {
        telemetry
          ..completeSearch(
            4,
            source: SoundSearchSource.funnelcake,
            relays: SoundSearchRelays.notAsked,
          )
          ..failSearch()
          ..abandonSearch();

        expect(monitor.traces, isEmpty);
      });
    });

    group('picks', () {
      test('reports how a pick ended', () async {
        telemetry.reportPick(
          source: SoundPickSource.newest,
          outcome: SoundPickOutcome.reuseBlocked,
          searched: true,
        );
        await pumpEventQueue();

        expect(sink.events.single.name, 'sound_selected');
        expect(sink.events.single.parameters, {
          'source': 'newest',
          'outcome': 'reuse_blocked',
          'searched': 1,
        });
      });

      test('reports every source and outcome with its own value', () async {
        for (final source in SoundPickSource.values) {
          telemetry.reportPick(
            source: source,
            outcome: SoundPickOutcome.attached,
            searched: false,
          );
        }
        for (final outcome in SoundPickOutcome.values) {
          telemetry.reportPick(
            source: SoundPickSource.popular,
            outcome: outcome,
            searched: false,
          );
        }
        await pumpEventQueue();

        final picks = sink.parametersOf('sound_selected');
        expect(
          picks.take(SoundPickSource.values.length).map((p) => p['source']),
          ['for_you', 'popular', 'newest', 'songs', 'my_sounds', 'import'],
        );
        expect(
          picks.skip(SoundPickSource.values.length).map((p) => p['outcome']),
          ['attached', 'reuse_blocked', 'download_failed', 'failed'],
        );
        expect(picks.first['searched'], 0);
      });

      test('contains a failing analytics sink', () async {
        final failing = SoundPickerTelemetry(
          surfaceTracker: SurfacePerformanceTracker(
            history: PageLoadHistory(),
            sink: sink,
          ),
          analytics: _FailingAnalyticsEventSink(),
          performanceMonitor: monitor,
        );

        failing.reportPick(
          source: SoundPickSource.forYou,
          outcome: SoundPickOutcome.attached,
          searched: false,
        );
        await pumpEventQueue();

        // Positive control: the same call on a working sink is recorded, so
        // the absence of an error above is not a call that never logged.
        telemetry.reportPick(
          source: SoundPickSource.forYou,
          outcome: SoundPickOutcome.attached,
          searched: false,
        );
        await pumpEventQueue();
        expect(sink.parametersOf('sound_selected'), hasLength(1));
      });
    });
  });
}
