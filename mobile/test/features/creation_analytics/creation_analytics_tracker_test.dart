// ABOUTME: Tests creation funnel ordering, dimensions, timing, and abandonment.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];
  Completer<void>? abandonment;
  Completer<void>? editorOpening;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
    if (name == 'creation_abandoned') await abandonment?.future;
    if (name == 'editor_opened') await editorOpening?.future;
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

    test('records a sound and a color mask on recording_completed as 1 or 0, '
        'the numbers Firebase accepts', () async {
      final sink = _RecordingSink();
      final tracker = CreationAnalyticsTracker(analytics: sink);

      await tracker.recordingCompleted(
        mode: VideoRecorderMode.capture,
        clipCount: 1,
        duration: const Duration(seconds: 2),
        hasSound: true,
      );

      expect(sink.events.single.parameters, containsPair('has_sound', 1));
      expect(sink.events.single.parameters, containsPair('has_color_mask', 0));
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

    test(
      'a pending abandonment event does not block the next camera',
      () async {
        final sink = _RecordingSink()..abandonment = Completer<void>();
        final tracker = CreationAnalyticsTracker(analytics: sink);

        await tracker.cameraOpened(mode: .capture, entryPoint: 'library');
        await tracker.recordingStarted(.capture);
        final abandonment = tracker.creationAbandoned();
        await tracker.cameraOpened(mode: .capture, entryPoint: 'bottom_nav');
        await tracker.recordingStarted(.capture);
        sink.abandonment!.complete();
        await abandonment;

        expect(sink.events.map((event) => event.name), [
          'camera_opened',
          'recording_started',
          'creation_abandoned',
          'camera_opened',
          'recording_started',
        ]);
        expect(sink.events[3].parameters['entry_point'], 'bottom_nav');
        expect(tracker.activeMode, VideoRecorderMode.capture);
      },
    );

    test(
      'late library recorder events cannot end or change a new funnel',
      () async {
        final sink = _RecordingSink();
        final tracker = CreationAnalyticsTracker(analytics: sink);
        final reaction = CreationAnalyticsSession();

        await tracker.cameraOpened(
          mode: .capture,
          entryPoint: 'library',
          session: reaction,
        );
        await tracker.cameraOpened(mode: .classic, entryPoint: 'bottom_nav');
        await tracker.creationAbandoned(session: reaction);
        await tracker.cameraOpened(
          mode: .stopMotion,
          entryPoint: 'library',
          session: reaction,
        );
        tracker.modeChanged(.stopMotion, session: reaction);
        await tracker.recordingStarted(.stopMotion, session: reaction);
        await tracker.recordingStarted(.classic);

        expect(sink.events.map((event) => event.name), [
          'camera_opened',
          'creation_abandoned',
          'camera_opened',
          'recording_started',
        ]);
        expect(tracker.activeMode, VideoRecorderMode.classic);
        expect(sink.events.last.parameters, {'mode': 'classic'});
      },
    );

    test(
      'leaving a reaction that never opened cannot end another funnel',
      () async {
        final sink = _RecordingSink();
        final tracker = CreationAnalyticsTracker(analytics: sink);
        final reaction = CreationAnalyticsSession();

        await tracker.cameraOpened(mode: .classic, entryPoint: 'bottom_nav');
        await tracker.creationAbandoned(session: reaction);
        await tracker.recordingStarted(.classic);

        expect(sink.events.map((event) => event.name), [
          'camera_opened',
          'recording_started',
        ]);
        expect(tracker.activeMode, VideoRecorderMode.classic);
      },
    );

    test('an editor recorder opened before editor initialization joins the reaction', () async {
      final sink = _RecordingSink()..editorOpening = Completer<void>();
      var now = DateTime.utc(2026, 11, 19);
      final tracker = CreationAnalyticsTracker(analytics: sink, now: () => now);
      final reaction = CreationAnalyticsSession();

      await tracker.cameraOpened(
        mode: .capture,
        entryPoint: 'library',
        session: reaction,
      );
      await tracker.recordingStarted(.capture, session: reaction);
      final mount = tracker.claimEditorSession(reaction);
      now = now.add(const Duration(seconds: 8));

      // The editor has mounted and Add clip is usable. Its provider is still
      // initializing, so the old editorOpened callback has not run yet.
      await tracker.cameraOpened(
        mode: .capture,
        entryPoint: 'editor',
        continuesEditorSession: true,
      );
      await tracker.recordingStarted(.capture);
      sink.editorOpening!.complete();
      await mount;
      await tracker.publishStarted(.capture);

      expect(sink.events.map((event) => event.name), [
        'camera_opened',
        'recording_started',
        'editor_opened',
        'publish_started',
      ]);
      expect(sink.events.last.parameters['time_since_camera_open_ms'], 8000);
    });

    test('a normal camera opening before reaction editor disposal owns a new funnel', () async {
      final sink = _RecordingSink();
      final tracker = CreationAnalyticsTracker(analytics: sink);
      final reaction = CreationAnalyticsSession();
      await tracker.cameraOpened(
        mode: .capture,
        entryPoint: 'library',
        session: reaction,
      );
      await tracker.recordingStarted(.capture, session: reaction);
      await tracker.claimEditorSession(reaction);

      // A replacement route can mount before the old editor is disposed.
      await tracker.cameraOpened(mode: .classic, entryPoint: 'bottom_nav');
      await tracker.recordingStarted(.classic);
      await tracker.abandonEditorSession(reaction);

      expect(sink.events.map((event) => event.name), [
        'camera_opened',
        'recording_started',
        'editor_opened',
        'creation_abandoned',
        'camera_opened',
        'recording_started',
      ]);
      expect(sink.events[4].parameters['entry_point'], 'bottom_nav');
      expect(tracker.activeMode, VideoRecorderMode.classic);
    });

    test(
      'a late reaction editor release leaves the next camera live',
      () async {
        final sink = _RecordingSink();
        final tracker = CreationAnalyticsTracker(analytics: sink);
        final reaction = CreationAnalyticsSession();

        await tracker.cameraOpened(
          mode: .capture,
          entryPoint: 'library',
          session: reaction,
        );
        await tracker.claimEditorSession(reaction);
        await tracker.abandonEditorSession(reaction);
        await tracker.cameraOpened(mode: .classic, entryPoint: 'bottom_nav');
        await tracker.claimEditorSession(reaction);
        await tracker.abandonEditorSession(reaction);
        await tracker.recordingStarted(.classic);

        expect(sink.events.map((event) => event.name), [
          'camera_opened',
          'editor_opened',
          'creation_abandoned',
          'camera_opened',
          'recording_started',
        ]);
        expect(sink.events[2].parameters['last_stage'], 'editor');
        expect(tracker.activeMode, VideoRecorderMode.classic);
      },
    );

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
