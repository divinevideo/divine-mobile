// ABOUTME: Verifies the screen hook starts and ends screen_frames visits.
// ABOUTME: Covers closing, routes on top, shell tab switches, background.

import 'dart:ui' show AppLifecycleState, FrameTiming, TimingsCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/screen_frame_trace.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';

import '../helpers/recording_performance_monitor.dart';

class _RecordingMonitoringService extends PerformanceMonitoringService {
  final recorder = RecordingPerformanceMonitor();

  @override
  PerformanceTrace startOperationTrace(String traceName) =>
      recorder.startOperationTrace(traceName);
}

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

  /// Reports frames [first] up to [last], each 2 ms on both threads.
  void reportFrames(int first, int last) {
    final timings = [
      for (var number = first; number <= last; number++)
        FrameTiming(
          vsyncStart: number * 20000,
          buildStart: number * 20000,
          buildFinish: number * 20000 + 2000,
          rasterStart: number * 20000 + 2000,
          rasterFinish: number * 20000 + 4000,
          rasterFinishWallTime: number * 20000 + 4000,
          frameNumber: number,
        ),
    ];
    for (final callback in [...callbacks]) {
      callback(timings);
    }
  }
}

void main() {
  group(ScreenFrameTraceScope, () {
    late _RecordingMonitoringService monitoring;
    late _FakeTimings timings;

    setUp(() {
      monitoring = _RecordingMonitoringService();
      timings = _FakeTimings();
    });

    List<RecordedPerformanceTrace> traces() => monitoring.recorder.traces;

    Widget app(Widget home, {ValueNotifier<bool>? appTickers}) => ProviderScope(
      overrides: [
        performanceMonitoringServiceProvider.overrideWithValue(monitoring),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: appTickers ?? const AlwaysStoppedAnimation(true),
          builder: (_, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: Navigator(
            onGenerateRoute: (_) => PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => home,
            ),
          ),
        ),
      ),
    );

    Widget tracedScreen() => ScreenFrameTraceScope(
      screen: .recorder,
      timings: timings,
      child: const SizedBox.expand(),
    );

    testWidgets('reports the visit when the screen closes', (tester) async {
      tester.view.display.refreshRate = 120;
      addTearDown(tester.view.display.resetRefreshRate);

      await tester.pumpWidget(app(tracedScreen()));

      expect(timings.callbacks, hasLength(1));

      timings.reportFrames(1, 20);
      await tester.pump(const Duration(seconds: 2));
      timings.frameNumber = 21;
      await tester.pumpWidget(const SizedBox());

      expect(traces(), hasLength(1));
      expect(traces().single.attributes, {
        'screen': 'recorder',
        'refresh': '120',
        'end': 'closed',
      });
      expect(traces().single.metrics['frames'], 20);
      expect(timings.callbacks, isEmpty);
    });

    group('routes on top', () {
      testWidgets('ends the visit under an opaque route and resumes after it', (
        tester,
      ) async {
        await tester.pumpWidget(app(tracedScreen()));
        timings.reportFrames(1, 20);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 21;

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        );
        await tester.pumpAndSettle();

        expect(traces(), hasLength(1));
        expect(traces().single.attributes['end'], 'covered');
        expect(timings.callbacks, isEmpty);

        navigator.pop();
        await tester.pumpAndSettle();

        expect(timings.callbacks, hasLength(1));
      });

      testWidgets('keeps the visit under a transparent route', (tester) async {
        await tester.pumpWidget(app(tracedScreen()));
        timings.reportFrames(1, 20);
        await tester.pump(const Duration(seconds: 2));

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, _, _) => const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();

        expect(traces(), isEmpty);
        expect(timings.callbacks, hasLength(1));
      });
    });

    group('tabs of the app shell', () {
      final rootNavigator = GlobalKey<NavigatorState>();
      final homeNavigator = GlobalKey<NavigatorState>();
      final profileNavigator = GlobalKey<NavigatorState>();

      // Two tabs as the shell builds them: a navigator each, with its screen
      // on its first page.
      Widget shell(ValueListenable<int> selectedTab) {
        Widget tab(GlobalKey<NavigatorState> key, TracedScreen screen) =>
            Navigator(
              key: key,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => ScreenFrameTraceScope(
                  screen: screen,
                  timings: timings,
                  child: const SizedBox.expand(),
                ),
              ),
            );
        return ProviderScope(
          overrides: [
            performanceMonitoringServiceProvider.overrideWithValue(
              monitoring,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Navigator(
                key: rootNavigator,
                onGenerateRoute: (_) => PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) => ValueListenableBuilder<int>(
                    valueListenable: selectedTab,
                    builder: (_, index, _) => AppShellBranchContainer(
                      currentIndex: index,
                      children: [
                        tab(homeNavigator, .homeFeed),
                        tab(profileNavigator, .profile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('ends the visit as a tab switch and starts the new tab', (
        tester,
      ) async {
        final selectedTab = ValueNotifier(0);
        addTearDown(selectedTab.dispose);
        await tester.pumpWidget(shell(selectedTab));

        // The hidden tab is mounted but shows no visit.
        expect(timings.callbacks, hasLength(1));

        timings.reportFrames(1, 20);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 21;
        selectedTab.value = 1;
        await tester.pumpAndSettle();

        expect(traces(), hasLength(1));
        expect(traces().single.attributes, {
          'screen': 'home_feed',
          'refresh': '60',
          'end': 'tab_switch',
        });
        expect(traces().single.metrics['frames'], 20);
        expect(timings.callbacks, hasLength(1));

        timings.reportFrames(21, 40);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 41;
        selectedTab.value = 0;
        await tester.pumpAndSettle();

        expect(traces(), hasLength(2));
        expect(traces().last.attributes['screen'], 'profile');
        expect(traces().last.attributes['end'], 'tab_switch');
        expect(traces().last.metrics['frames'], 20);
        expect(timings.callbacks, hasLength(1));
      });

      testWidgets('ends the visit as covered under a route above the shell', (
        tester,
      ) async {
        final selectedTab = ValueNotifier(0);
        addTearDown(selectedTab.dispose);
        await tester.pumpWidget(shell(selectedTab));
        timings.reportFrames(1, 20);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 21;

        rootNavigator.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        );
        await tester.pumpAndSettle();

        expect(traces(), hasLength(1));
        expect(traces().single.attributes['screen'], 'home_feed');
        expect(traces().single.attributes['end'], 'covered');
        expect(timings.callbacks, isEmpty);

        rootNavigator.currentState!.pop();
        await tester.pumpAndSettle();

        expect(timings.callbacks, hasLength(1));
      });

      testWidgets('ends the visit as covered under a route in its own tab', (
        tester,
      ) async {
        final selectedTab = ValueNotifier(0);
        addTearDown(selectedTab.dispose);
        await tester.pumpWidget(shell(selectedTab));
        timings.reportFrames(1, 20);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 21;

        homeNavigator.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        );
        await tester.pumpAndSettle();

        expect(traces(), hasLength(1));
        expect(traces().single.attributes['end'], 'covered');

        // Leaving the tab and coming back keeps the covered screen hidden.
        selectedTab.value = 1;
        await tester.pumpAndSettle();
        timings.reportFrames(21, 40);
        await tester.pump(const Duration(seconds: 2));
        timings.frameNumber = 41;
        selectedTab.value = 0;
        await tester.pumpAndSettle();

        expect(traces(), hasLength(2));
        expect(traces().last.attributes['screen'], 'profile');
        expect(timings.callbacks, isEmpty);
      });
    });

    testWidgets('ends the visit when the app goes to the background', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final appTickers = ValueNotifier(true);
      addTearDown(appTickers.dispose);
      await tester.pumpWidget(app(tracedScreen(), appTickers: appTickers));
      timings.reportFrames(1, 20);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // The app-wide lifecycle widget mutes tickers on Android and iOS.
      appTickers.value = false;
      await tester.pump();
      expect(timings.callbacks, hasLength(1));
      expect(traces(), isEmpty);
      timings
        ..frameNumber = 20
        ..drawingFrame = false;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      expect(traces(), hasLength(1));
      expect(traces().single.attributes['end'], 'background');
      expect(timings.callbacks, isEmpty);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      appTickers.value = true;
      await tester.pump();

      expect(timings.callbacks, hasLength(1));
    });
  });
}
