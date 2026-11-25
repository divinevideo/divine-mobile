// ABOUTME: Builds ScreenLoadTelemetry over a recording sink and a fixed clock,
// ABOUTME: so tests can read back the surface_load events a screen reported.

import 'package:analytics/analytics.dart';
import 'package:openvine/observability/screen_load_telemetry.dart';

import 'recording_analytics_event_sink.dart';

/// Records the `surface_load` events of the telemetry it creates.
class ScreenLoadRecorder {
  /// The time the tracker reads; advance it to give a load a duration.
  DateTime now = DateTime(2026, 11, 24, 12);

  final sink = RecordingAnalyticsEventSink();

  late final tracker = SurfacePerformanceTracker(
    history: PageLoadHistory(),
    sink: sink,
    now: () => now,
  );

  /// Telemetry for [surface] that reports [entryPoint] by default.
  ScreenLoadTelemetry telemetry(
    String surface, {
    String entryPoint = 'test_entry',
  }) => ScreenLoadTelemetry(
    tracker: tracker,
    surface: surface,
    entryPoint: entryPoint,
  );

  /// The parameters of every `surface_load` reported, in order.
  List<Map<String, Object>> get loads => sink.parametersOf('surface_load');

  /// The `result` of every `surface_load` reported, in order.
  List<Object?> get results => [
    for (final load in loads) load[AnalyticsParam.result],
  ];
}
