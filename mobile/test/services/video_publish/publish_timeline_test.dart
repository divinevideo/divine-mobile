// ABOUTME: Tests for PublishTimeline — phase capture, summary shape, the
// ABOUTME: PUBTIME token contract, and the reported performance breakdown.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:unified_logger/unified_logger.dart';

/// Records what a publish would report to Firebase, without any Firebase.
class _FakePerformanceTrace implements PerformanceTrace {
  final Map<String, int> metrics = {};
  final Map<String, String> attributes = {};
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stopCount++;
}

class _FakePerformanceMonitor implements PerformanceTraceMonitor {
  final List<String> startedOperations = [];
  final _FakePerformanceTrace trace = _FakePerformanceTrace();

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    startedOperations.add(traceName);
    return trace;
  }
}

void main() {
  group(PublishTimeline, () {
    late PublishTimeline timeline;

    setUp(() {
      timeline = PublishTimeline('draft-1');
    });

    group('measure', () {
      test('returns the action result and records the phase', () async {
        final result = await timeline.measure('nostr', () async => 42);

        expect(result, equals(42));
        expect(timeline.phases.map((phase) => phase.name), equals(['nostr']));
      });

      test('records the phase and rethrows when the action throws', () async {
        await expectLater(
          timeline.measure<void>('nostr', () async => throw StateError('boom')),
          throwsA(isA<StateError>()),
        );

        expect(timeline.phases.map((phase) => phase.name), equals(['nostr']));
      });

      test('keeps phases in completion order', () async {
        await timeline.measure('upload', () async {});
        await timeline.measure('nostr', () async {});

        expect(
          timeline.phases.map((phase) => phase.name),
          equals(['upload', 'nostr']),
        );
      });
    });

    group('summaryLine', () {
      test('carries the filter token, draft, outcome and every phase', () {
        timeline
          ..record('upload', const Duration(milliseconds: 900))
          ..record('nostr', const Duration(milliseconds: 120));

        final summary = timeline.summaryLine(outcome: 'success');

        expect(summary, contains(publishTimingToken));
        expect(summary, contains('draft=draft-1'));
        expect(summary, contains('outcome=success'));
        expect(summary, contains('upload=900ms'));
        expect(summary, contains('nostr=120ms'));
        expect(summary, contains('other='));
      });

      test('reports a total even when no phase was recorded', () {
        final summary = timeline.summaryLine(outcome: 'threw');

        expect(summary, contains('outcome=threw'));
        expect(summary, contains('total='));
      });

      test('ignores the nested phases the upload leg emits', () async {
        await timeline.run(() async {
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 700),
          );
        });
        timeline.record(
          PublishPhases.upload,
          const Duration(milliseconds: 900),
        );

        // A nested phase is part of its parent, so counting it in the summary
        // would double it and drive `other` negative.
        final summary = timeline.summaryLine(outcome: 'success');
        expect(summary, contains('upload=900ms'));
        expect(summary, isNot(contains('upload.transfer=')));
      });
    });

    group('run', () {
      test('makes the timeline ambient only for the duration of the '
          'action', () async {
        expect(PublishTimeline.current, isNull);

        await timeline.run(() async {
          expect(PublishTimeline.current, same(timeline));
        });

        expect(PublishTimeline.current, isNull);
      });

      test('stays ambient across an await and inside a parallel leg', () async {
        await timeline.run(() async {
          final leg = Future<PublishTimeline?>(() => PublishTimeline.current);
          await Future<void>.delayed(Duration.zero);
          expect(PublishTimeline.current, same(timeline));
          expect(await leg, same(timeline));
        });
      });
    });

    group('finish', () {
      late _FakePerformanceMonitor monitor;
      late PublishTimeline traced;

      setUp(() {
        monitor = _FakePerformanceMonitor();
        traced = PublishTimeline('draft-1', performanceMonitor: monitor);
      });

      test('starts one publish trace per timeline', () {
        expect(monitor.startedOperations, equals([publishTraceName]));
      });

      test('reports the phases the summary carries', () async {
        await traced.run(() async {
          traced
            ..record(PublishPhases.upload, const Duration(milliseconds: 900))
            ..record(PublishPhases.nostr, const Duration(milliseconds: 120));
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 700),
            bytes: 16572,
          );
          logPublishPhase(
            PublishPhases.uploadThumbnail,
            const Duration(milliseconds: 150),
          );
          logPublishPhase(
            PublishPhases.nostrSign,
            const Duration(milliseconds: 80),
          );
          logPublishPhase(
            PublishPhases.nostrPublish,
            const Duration(milliseconds: 40),
          );
        });

        traced.finish(outcome: 'success');

        expect(
          monitor.trace.metrics,
          allOf([
            containsPair('upload_ms', 900),
            containsPair('nostr_ms', 120),
            containsPair('transfer_ms', 700),
            containsPair('thumbnail_ms', 150),
            containsPair('sign_ms', 80),
            containsPair('nostr_publish_ms', 40),
            containsPair(publishPayloadMetric, 16572),
            contains(publishTotalMetric),
          ]),
        );
        expect(monitor.trace.stopCount, equals(1));
      });

      test('counts a phase it records itself only once', () async {
        // A recorded phase logs its own line rather than going back through
        // logPublishPhase, which would fold it in a second time from the zone.
        await traced.run(() async {
          traced.record(PublishPhases.nostr, const Duration(milliseconds: 120));
        });

        traced.finish(outcome: 'success');

        expect(monitor.trace.metrics['nostr_ms'], equals(120));
      });

      test('adds a retried phase up across its attempts', () async {
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 700),
          );
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 500),
          );
        });

        traced.finish(outcome: 'success');

        expect(monitor.trace.metrics['transfer_ms'], equals(1200));
      });

      test('reports how many legs the summed transfer covers', () async {
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 700),
            bytes: 16572,
          );
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(milliseconds: 500),
            bytes: 16572,
          );
        });

        traced.finish(outcome: 'success');

        // Without this, a publish that resumed after a failure and a genuinely
        // slow one are indistinguishable in the console.
        expect(monitor.trace.metrics[publishTransferLegsMetric], equals(2));
      });

      test('counts one leg however many attempts it took inside', () async {
        // The upload service can burn a whole-file OS attempt, fall back to
        // chunked resumable, iterate servers and retry chunks — all inside the
        // single uploadVideoWithResume call this one phase wraps. The publish
        // layer sees none of that, so the metric must not be read as a count
        // of transport attempts: transfer_legs == 1 means the publish entered
        // the transfer once, not that the file went up in one attempt.
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.uploadTransfer,
            const Duration(minutes: 4),
            bytes: 16572,
          );
        });

        traced.finish(outcome: 'success');

        expect(monitor.trace.metrics[publishTransferLegsMetric], equals(1));
        expect(monitor.trace.metrics['transfer_ms'], equals(240000));
      });

      test('reports the second blurhash pass the Nostr leg made', () async {
        await traced.run(() async {
          traced.record(PublishPhases.nostr, const Duration(seconds: 4));
          logPublishPhase(
            PublishPhases.nostrBlurhash,
            const Duration(milliseconds: 3800),
          );
        });

        traced.finish(outcome: 'success');

        // Unmapped, this decode was 3.8s of `nostr_ms` the console could not
        // attribute to anything.
        expect(monitor.trace.metrics['nostr_blurhash_ms'], equals(3800));
        expect(monitor.trace.metrics['nostr_ms'], equals(4000));
      });

      test('omits the blurhash metric when the upload leg supplied one', () {
        // The Nostr leg emits no phase at all when it reuses the upload's
        // blurhash, so an absent `nostr_blurhash_ms` on a successful publish
        // counts as "the second decode was skipped" rather than zero-cost work.
        traced
          ..record(PublishPhases.nostr, const Duration(milliseconds: 120))
          ..finish(outcome: 'success');

        expect(monitor.trace.metrics['nostr_ms'], equals(120));
        expect(monitor.trace.metrics.containsKey('nostr_blurhash_ms'), isFalse);
      });

      test('leaves the thumbnail sub-phases as log-only detail', () async {
        await traced.run(() async {
          traced.record(
            PublishPhases.uploadThumbnail,
            const Duration(milliseconds: 150),
          );
          logPublishPhase(
            PublishPhases.uploadThumbnailExtract,
            const Duration(milliseconds: 90),
          );
          logPublishPhase(
            PublishPhases.uploadThumbnailBlurhash,
            const Duration(milliseconds: 20),
          );
          logPublishPhase(
            PublishPhases.uploadThumbnailPut,
            const Duration(milliseconds: 40),
          );
        });

        traced.finish(outcome: 'success');

        // Their parent is mapped, so leaving them out hides no time. The whole
        // key set is pinned so mapping any sub-phase under any name trips this.
        expect(
          monitor.trace.metrics.keys,
          unorderedEquals(<String>['thumbnail_ms', publishTotalMetric]),
        );
      });

      test('omits a metric for a phase that never ran', () {
        traced.finish(outcome: 'success');

        expect(monitor.trace.metrics.containsKey('transfer_ms'), isFalse);
        expect(
          monitor.trace.metrics.containsKey(publishPayloadMetric),
          isFalse,
        );
        expect(
          monitor.trace.metrics.containsKey(publishTransferLegsMetric),
          isFalse,
        );
      });

      test('distinguishes a failed publish from a successful one', () {
        traced.finish(outcome: 'error:serverDown');

        expect(monitor.trace.attributes['outcome'], equals('error:serverDown'));
      });

      test(
        "tags a publish that reused a previous attempt's thumbnail",
        () async {
          await traced.run(() async {
            logPublishPhase(
              PublishPhases.uploadThumbnail,
              Duration.zero,
              detail: PublishPhases.reusedDetail,
            );
          });

          traced.finish(outcome: 'success');

          expect(monitor.trace.attributes['thumbnail'], equals('reused'));
        },
      );

      test('tags a publish that generated its own thumbnail', () async {
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.uploadThumbnail,
            const Duration(milliseconds: 150),
          );
        });

        traced.finish(outcome: 'success');

        expect(monitor.trace.attributes['thumbnail'], equals('generated'));
      });

      test('says nothing about a leg the publish never reached', () {
        traced.finish(outcome: 'error:notSignedIn');

        // Claiming `generated` here would put publishes that never touched a
        // thumbnail into the distribution for ones that built a thumbnail.
        expect(monitor.trace.attributes.containsKey('thumbnail'), isFalse);
        expect(monitor.trace.attributes.containsKey('signature'), isFalse);
      });

      test(
        "tags a publish that reused a previous attempt's signature",
        () async {
          await traced.run(() async {
            logPublishPhase(
              PublishPhases.nostrSign,
              Duration.zero,
              detail: PublishPhases.reusedDetail,
            );
          });

          traced.finish(outcome: 'success');

          // A reused signature reports ~0ms, which would drag the signer latency
          // distribution down if it could not be filtered out.
          expect(monitor.trace.attributes['signature'], equals('reused'));
        },
      );

      test('tags a publish that really signed its event', () async {
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.nostrSign,
            const Duration(milliseconds: 800),
            detail: PublishPhases.signedDetail,
          );
        });

        traced.finish(outcome: 'success');

        expect(monitor.trace.attributes['signature'], equals('signed'));
      });

      test('counts a leg as fresh when any attempt did the work', () async {
        await traced.run(() async {
          logPublishPhase(
            PublishPhases.nostrSign,
            const Duration(milliseconds: 800),
            detail: PublishPhases.signedDetail,
          );
          logPublishPhase(
            PublishPhases.nostrSign,
            Duration.zero,
            detail: PublishPhases.reusedDetail,
          );
        });

        traced.finish(outcome: 'success');

        // sign_ms carries the 800ms the first attempt really spent, so this
        // trace belongs in the signer distribution.
        expect(monitor.trace.attributes['signature'], equals('signed'));
      });

      test('still logs the summary line', () {
        traced.record(PublishPhases.upload, const Duration(milliseconds: 900));

        traced.finish(outcome: 'success');

        final summary = LogCaptureService().getRecentLogs(limit: 1).single;
        expect(summary.message, contains('$publishTimingToken summary'));
        expect(summary.message, contains('outcome=success'));
      });

      test('ignores phases emitted outside its own run', () {
        logPublishPhase(
          PublishPhases.uploadTransfer,
          const Duration(milliseconds: 700),
        );

        traced.finish(outcome: 'success');

        expect(monitor.trace.metrics.containsKey('transfer_ms'), isFalse);
      });
    });
  });

  group('logPublishPhase', () {
    test('emits one filterable line carrying phase, duration and detail', () {
      logPublishPhase(
        'upload.transfer',
        const Duration(milliseconds: 5231),
        detail: '8.00MB 1.53MB/s',
      );

      final captured = LogCaptureService().getRecentLogs(limit: 1).single;

      expect(captured.name, equals(publishTimingLogName));
      expect(captured.category, equals(LogCategory.video));
      expect(captured.message, contains(publishTimingToken));
      expect(captured.message, contains('upload.transfer'));
      expect(captured.message, contains('5231ms'));
      expect(captured.message, contains('8.00MB 1.53MB/s'));
    });

    test('renders a transferred payload as size and rate', () {
      logPublishPhase(
        'upload.transfer',
        const Duration(seconds: 4),
        bytes: 8 * 1024 * 1024,
      );

      final captured = LogCaptureService().getRecentLogs(limit: 1).single;

      expect(captured.message, contains('8.00MB 2.00MB/s'));
    });
  });

  group('formatTransferDetail', () {
    test('reports size and rate for a measured transfer', () {
      final detail = formatTransferDetail(
        8 * 1024 * 1024,
        const Duration(seconds: 4),
      );

      expect(detail, equals('8.00MB 2.00MB/s'));
    });

    test('omits the rate when the transfer took no measurable time', () {
      final detail = formatTransferDetail(2 * 1024 * 1024, Duration.zero);

      expect(detail, equals('2.00MB'));
    });

    test('returns nothing when the size is unknown or empty', () {
      expect(formatTransferDetail(null, const Duration(seconds: 1)), isEmpty);
      expect(formatTransferDetail(0, const Duration(seconds: 1)), isEmpty);
    });
  });
}
