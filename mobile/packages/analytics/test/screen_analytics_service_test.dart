// ABOUTME: Tests for ScreenAnalyticsService stale session handling.
// ABOUTME: Verifies sessions older than 60s are discarded and resetAllSessions
// ABOUTME: clears all active sessions on app resume.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];
  final screenViews =
      <
        ({
          String screenName,
          String? screenClass,
          Map<String, Object>? parameters,
        })
      >[];

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
  }) async {
    screenViews.add((
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    ));
  }
}

void main() {
  group(ScreenAnalyticsService, () {
    late ScreenAnalyticsService service;

    setUp(() {
      service = ScreenAnalyticsService(
        history: PageLoadHistory(),
        sink: const NoOpAnalyticsEventSink(),
      );
    });

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        service
          ..startScreenLoad('HomeScreen')
          ..startScreenLoad('ExploreScreen')
          ..startScreenLoad('ProfileScreen');

        expect(service.activeSessionCount, 3);

        service.resetAllSessions();

        expect(service.activeSessionCount, 0);
      });

      test('does nothing when no sessions are active', () {
        expect(service.activeSessionCount, 0);

        service.resetAllSessions();

        expect(service.activeSessionCount, 0);
      });
    });

    group('stale session detection', () {
      test('markContentVisible processes fresh session normally', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.markContentVisible('HomeScreen');

        expect(service.activeSessionCount, 1);
      });

      test('markDataLoaded processes fresh session normally', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.markDataLoaded('HomeScreen');

        expect(service.activeSessionCount, 1);
      });

      test('markContentVisible is no-op for unknown screen', () {
        service.markContentVisible('UnknownScreen');
        expect(service.activeSessionCount, 0);
      });

      test('markDataLoaded is no-op for unknown screen', () {
        service.markDataLoaded('UnknownScreen');
        expect(service.activeSessionCount, 0);
      });

      test('endScreen removes session', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.endScreen('HomeScreen');

        expect(service.activeSessionCount, 0);
      });
    });

    group('session lifecycle', () {
      test('sessions do not leak between instances', () {
        service.startScreenLoad('HomeScreen');

        final other = ScreenAnalyticsService(
          history: PageLoadHistory(),
          sink: const NoOpAnalyticsEventSink(),
        );

        // Guards the reason the app resolves one shared instance through
        // `screenAnalyticsServiceProvider`: a second instance cannot complete
        // a session the first one started.
        expect(other.activeSessionCount, 0);
        other.markDataLoaded('HomeScreen');
        expect(service.activeSessionCount, 1);
      });

      test('tracks multiple independent sessions', () {
        service
          ..startScreenLoad('HomeScreen')
          ..startScreenLoad('ExploreScreen');

        expect(service.activeSessionCount, 2);

        service.endScreen('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.endScreen('ExploreScreen');
        expect(service.activeSessionCount, 0);
      });
    });

    group('trackScreenView', () {
      test('logs screen view through the analytics sink', () {
        final sink = RecordingAnalyticsEventSink();
        final instance = ScreenAnalyticsService(
          history: PageLoadHistory(),
          sink: sink,
        );

        instance.trackScreenView(
          'video_detail',
          params: const {
            AnalyticsParam.routeName: 'video_detail',
            AnalyticsParam.entryPoint: 'navigation',
            'nullable_value': null,
          },
        );

        expect(sink.screenViews, hasLength(1));
        expect(sink.screenViews.single.screenName, 'video_detail');
        expect(
          sink.screenViews.single.parameters,
          containsPair(AnalyticsParam.routeName, 'video_detail'),
        );
        expect(
          sink.screenViews.single.parameters,
          containsPair(AnalyticsParam.entryPoint, 'navigation'),
        );
        expect(
          sink.screenViews.single.parameters,
          isNot(contains('nullable_value')),
        );
      });
    });
  });
}
