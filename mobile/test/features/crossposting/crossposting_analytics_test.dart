// ABOUTME: Tests the crossposting CTA analytics helper.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

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

  @override
  Future<void> setUserId(String? userId) async {}
}

class _ThrowingSink implements AnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => throw StateError('nope');

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

void main() {
  group(logCrosspostCtaTapped, () {
    test('logs the event with the surface', () async {
      final sink = _RecordingSink();

      await logCrosspostCtaTapped(sink, 'settings');

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'crosspost_cta_tapped');
      expect(sink.events.single.parameters, {'surface': 'settings'});
    });

    test('swallows sink failures', () async {
      await expectLater(
        logCrosspostCtaTapped(_ThrowingSink(), 'share_sheet'),
        completes,
      );
    });
  });
}
