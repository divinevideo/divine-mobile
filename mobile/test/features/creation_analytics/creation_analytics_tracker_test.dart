// ABOUTME: Tests creation funnel ordering, dimensions, timing, and abandonment.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => events.add((name: name, parameters: parameters));

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
  group(CreationAnalyticsTracker, () {
    test('records a complete funnel with mode and elapsed time', () async {
      final sink = _RecordingSink();
      var now = DateTime.utc(2026, 8, 8, 12);
      final tracker = CreationAnalyticsTracker(analytics: sink, now: () => now);

      await tracker.cameraOpened(
        mode: VideoRecorderMode.capture,
        entryPoint: 'bottom_nav',
      );
      await tracker.recordingStarted(VideoRecorderMode.capture);
      await tracker.recordingStarted(VideoRecorderMode.capture);
      await tracker.recordingCompleted(
        mode: VideoRecorderMode.capture,
        clipCount: 2,
        duration: const Duration(milliseconds: 6500),
      );
      await tracker.editorOpened(VideoRecorderMode.capture);
      now = now.add(const Duration(seconds: 30));
      await tracker.publishStarted(VideoRecorderMode.capture);
      now = now.add(const Duration(seconds: 5));
      await tracker.publishSucceeded(VideoRecorderMode.capture);

      expect(sink.events.map((event) => event.name), [
        'camera_opened',
        'recording_started',
        'recording_completed',
        'editor_opened',
        'publish_started',
        'publish_succeeded',
      ]);
      for (final event in sink.events) {
        expect(event.parameters['mode'], 'capture');
      }
      expect(sink.events[0].parameters['entry_point'], 'bottom_nav');
      expect(sink.events[2].parameters, containsPair('clip_count', 2));
      expect(sink.events[2].parameters, containsPair('duration_ms', 6500));
      expect(sink.events[4].parameters['time_since_camera_open_ms'], 30000);
      expect(sink.events[5].parameters['time_since_camera_open_ms'], 35000);
      expect(tracker.activeMode, isNull);
    });

    test('records abandonment at the deepest reached stage', () async {
      final sink = _RecordingSink();
      final tracker = CreationAnalyticsTracker(analytics: sink);

      await tracker.cameraOpened(
        mode: VideoRecorderMode.stopMotion,
        entryPoint: 'camera_fab',
      );
      await tracker.recordingStarted(VideoRecorderMode.stopMotion);
      await tracker.creationAbandoned();
      await tracker.creationAbandoned();

      expect(sink.events.last.name, 'creation_abandoned');
      expect(sink.events.last.parameters, {
        'mode': 'stopMotion',
        'last_stage': 'recording',
      });
    });

    test('records publish failure without misclassifying disposal', () async {
      final sink = _RecordingSink();
      final tracker = CreationAnalyticsTracker(analytics: sink);

      await tracker.cameraOpened(
        mode: VideoRecorderMode.classic,
        entryPoint: 'direct',
      );
      await tracker.publishStarted(VideoRecorderMode.classic);
      await tracker.publishFailed(
        mode: VideoRecorderMode.classic,
        reason: 'relay_publish_failed',
      );
      await tracker.creationAbandoned();

      expect(sink.events.last.name, 'publish_failed');
      expect(sink.events.last.parameters['reason'], 'relay_publish_failed');
      expect(
        sink.events.where((event) => event.name == 'creation_abandoned'),
        isEmpty,
      );
    });

    test(
      'records camera when a draft editor opens the recorder later',
      () async {
        final sink = _RecordingSink();
        final tracker = CreationAnalyticsTracker(analytics: sink);

        await tracker.editorOpened(VideoRecorderMode.stopMotion);
        await tracker.cameraOpened(
          mode: VideoRecorderMode.stopMotion,
          entryPoint: 'editor',
        );

        expect(sink.events.map((event) => event.name), [
          'editor_opened',
          'camera_opened',
        ]);
        expect(sink.events.last.parameters, {
          'mode': 'stopMotion',
          'entry_point': 'editor',
        });
      },
    );

    test(
      'omits camera elapsed time entirely for an editor-only draft',
      () async {
        final sink = _RecordingSink();
        var now = DateTime.utc(2026, 8, 8, 12);
        final tracker = CreationAnalyticsTracker(
          analytics: sink,
          now: () => now,
        );

        await tracker.editorOpened(VideoRecorderMode.upload);
        now = now.add(const Duration(minutes: 2));
        await tracker.publishStarted(VideoRecorderMode.upload);
        await tracker.publishSucceeded(VideoRecorderMode.upload);

        // A `0` here would be indistinguishable from an instant publish and
        // would drag the campaign's timing distribution down.
        expect(sink.events.map((event) => event.name), [
          'editor_opened',
          'publish_started',
          'publish_succeeded',
        ]);
        expect(
          sink.events[1].parameters,
          isNot(contains('time_since_camera_open_ms')),
        );
        expect(
          sink.events[2].parameters,
          isNot(contains('time_since_camera_open_ms')),
        );
      },
    );
  });
}
