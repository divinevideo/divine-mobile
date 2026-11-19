// ABOUTME: Captures logged analytics events for behavioral assertions.
// ABOUTME: Keeps event names and parameters visible without Firebase.

import 'package:analytics/analytics.dart';

class RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  /// The parameters of every event logged as [name], in order.
  List<Map<String, Object>> parametersOf(String name) => [
    for (final event in events)
      if (event.name == name) event.parameters,
  ];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}
