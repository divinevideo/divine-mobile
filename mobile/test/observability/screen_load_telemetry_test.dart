// ABOUTME: Tests ScreenLoadTelemetry: one surface_load per start, with the
// ABOUTME: right result, and a superseded load reported dismissed.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/screen_load_telemetry.dart';

import '../helpers/screen_load_recorder.dart';

void main() {
  group(ScreenLoadTelemetry, () {
    late ScreenLoadRecorder recorder;

    setUp(() => recorder = ScreenLoadRecorder());

    group('completeLoaded', () {
      test('reports success with the time until the content showed', () async {
        final telemetry = recorder.telemetry(
          AnalyticsSurface.profile,
          entryPoint: ScreenLoadEntryPoint.otherProfile,
        )..start();
        recorder.now = recorder.now.add(const Duration(milliseconds: 1200));

        telemetry.completeLoaded(itemCount: 12, hasMore: true);
        await pumpEventQueue();

        expect(recorder.loads, [
          {
            AnalyticsParam.surfaceName: AnalyticsSurface.profile,
            AnalyticsParam.result: SurfaceLoadResult.success,
            AnalyticsParam.visibleMs: -1,
            AnalyticsParam.dataMs: 1200,
            AnalyticsParam.totalMs: 1200,
            AnalyticsParam.slowBucket: '1_3s',
            AnalyticsParam.entryPoint: ScreenLoadEntryPoint.otherProfile,
            AnalyticsParam.itemCount: 12,
            AnalyticsParam.hasMore: 1,
          },
        ]);
      });

      test('reports empty when nothing loaded', () async {
        recorder.telemetry(AnalyticsSurface.notifications)
          ..start()
          ..completeLoaded(itemCount: 0);
        await pumpEventQueue();

        expect(recorder.results, [SurfaceLoadResult.empty]);
        expect(
          recorder.loads.single,
          containsPair(AnalyticsParam.itemCount, 0),
        );
      });

      test('reports once per start', () async {
        recorder.telemetry(AnalyticsSurface.inbox)
          ..start()
          ..completeLoaded(itemCount: 3)
          ..completeLoaded(itemCount: 4)
          ..completeFailure()
          ..dismiss();
        await pumpEventQueue();

        expect(recorder.results, [SurfaceLoadResult.success]);
      });

      test('does nothing before a start', () async {
        recorder.telemetry(AnalyticsSurface.inbox).completeLoaded(itemCount: 3);
        await pumpEventQueue();

        expect(recorder.loads, isEmpty);
      });
    });

    group('completeFailure', () {
      test('reports failure', () async {
        recorder.telemetry(AnalyticsSurface.searchResults)
          ..start()
          ..completeFailure();
        await pumpEventQueue();

        expect(recorder.results, [SurfaceLoadResult.failure]);
      });
    });

    group('dismiss', () {
      test('reports a load left before it showed as dismissed', () async {
        recorder.telemetry(AnalyticsSurface.videoDetail)
          ..start()
          ..dismiss();
        await pumpEventQueue();

        expect(recorder.results, [SurfaceLoadResult.dismissed]);
        expect(
          recorder.loads.single,
          containsPair(AnalyticsParam.dataMs, -1),
        );
      });
    });

    group('start', () {
      test('sends the entry point and tab it was given', () async {
        final telemetry =
            recorder.telemetry(
              AnalyticsSurface.explore,
              entryPoint: ScreenLoadEntryPoint.exploreTab,
            )..start(
              entryPoint: ScreenLoadEntryPoint.retry,
              tab: 'popular',
            );

        expect(telemetry.timedTab, 'popular');
        telemetry.completeLoaded(itemCount: 1);
        await pumpEventQueue();

        expect(telemetry.timedTab, isNull);
        expect(
          recorder.loads.single,
          allOf(
            containsPair(
              AnalyticsParam.entryPoint,
              ScreenLoadEntryPoint.retry,
            ),
            containsPair(AnalyticsParam.tab, 'popular'),
          ),
        );
      });

      test('dismisses its own load still being timed', () async {
        recorder.telemetry(AnalyticsSurface.searchResults)
          ..start()
          ..start()
          ..completeLoaded(itemCount: 5);
        await pumpEventQueue();

        expect(recorder.results, [
          SurfaceLoadResult.dismissed,
          SurfaceLoadResult.success,
        ]);
      });

      test('takes the surface over from another screen instance', () async {
        final first = recorder.telemetry(AnalyticsSurface.profile)..start();
        final second = recorder.telemetry(AnalyticsSurface.profile)..start();

        first.completeLoaded(itemCount: 9);
        second.completeLoaded(itemCount: 2);
        await pumpEventQueue();

        expect(first.isTiming, isFalse);
        expect(recorder.loads.map((load) => load[AnalyticsParam.itemCount]), [
          null,
          2,
        ]);
        expect(recorder.results, [
          SurfaceLoadResult.dismissed,
          SurfaceLoadResult.success,
        ]);
      });

      test('leaves other surfaces alone', () async {
        final profile = recorder.telemetry(AnalyticsSurface.profile)..start();
        recorder.telemetry(AnalyticsSurface.inbox).start();

        expect(profile.isTiming, isTrue);
      });
    });
  });
}
