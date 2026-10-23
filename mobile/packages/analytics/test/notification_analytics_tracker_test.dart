import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];
  bool fail = false;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    if (fail) throw StateError('sink unavailable');
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  late _RecordingSink sink;
  late NotificationAnalyticsTracker tracker;
  late bool allowed;
  late String boundary;

  setUp(() {
    sink = _RecordingSink();
    allowed = true;
    boundary = 'first-session';
    tracker = NotificationAnalyticsTracker(
      sink: sink,
      collectionAllowed: () async => allowed,
      privacyBoundary: () => boundary,
    );
  });

  group('opened', () {
    test(
      'records type and entry path without exporting the deduplication key',
      () async {
        await tracker.opened(
          notificationType: 'comment',
          source: NotificationOpenSource.osColdStart,
          deduplicationKey: 'private-local-deduplication-value',
        );

        expect(sink.events.single.name, 'push_notification_opened');
        expect(sink.events.single.parameters, {
          'notification_type': 'comment',
          'open_source': 'os_cold_start',
        });
      },
    );

    test(
      'normalizes arbitrary payload values instead of exporting them',
      () async {
        await tracker.opened(
          notificationType: 'untrusted free text',
          source: NotificationOpenSource.localTap,
        );
        expect(sink.events.single.parameters['notification_type'], 'unknown');
      },
    );

    test(
      'normalizes current sender wire types for messages and new posts',
      () async {
        await tracker.opened(
          notificationType: 'directMessage',
          source: NotificationOpenSource.localTap,
        );
        await tracker.opened(
          notificationType: 'newPost',
          source: NotificationOpenSource.localTap,
        );
        expect(
          sink.events.map((event) => event.parameters['notification_type']),
          ['direct_message', 'new_post'],
        );
      },
    );

    test('records list-add opens under their own routed type', () async {
      await tracker.opened(
        notificationType: 'list_add',
        source: NotificationOpenSource.localTap,
      );
      expect(sink.events.single.parameters['notification_type'], 'list_add');
    });

    test('does not record when collection is disabled', () async {
      allowed = false;
      await tracker.opened(
        notificationType: 'like',
        source: NotificationOpenSource.localTap,
      );
      expect(sink.events, isEmpty);
    });

    test(
      'deduplicates overlapping callbacks while consent is loading',
      () async {
        final consent = Completer<bool>();
        tracker = NotificationAnalyticsTracker(
          sink: sink,
          collectionAllowed: () => consent.future,
          privacyBoundary: () => boundary,
        );
        final first = tracker.opened(
          notificationType: 'like',
          source: NotificationOpenSource.osColdStart,
          deduplicationKey: 'same-delivery',
        );
        final second = tracker.opened(
          notificationType: 'like',
          source: NotificationOpenSource.localColdStart,
          deduplicationKey: 'same-delivery',
        );
        consent.complete(true);
        await Future.wait([first, second]);
        expect(sink.events, hasLength(1));
      },
    );

    test(
      'drops a tap if the privacy boundary changes while consent loads',
      () async {
        final consent = Completer<bool>();
        tracker = NotificationAnalyticsTracker(
          sink: sink,
          collectionAllowed: () => consent.future,
          privacyBoundary: () => boundary,
        );
        final pending = tracker.opened(
          notificationType: 'comment',
          source: NotificationOpenSource.osColdStart,
        );
        boundary = 'another-account-session';
        consent.complete(true);
        await pending;
        expect(sink.events, isEmpty);
      },
    );

    test(
      'does not merge unrelated legacy campaign opens without a delivery key',
      () async {
        for (var index = 0; index < 2; index++) {
          await tracker.opened(
            notificationType: 'campaign',
            source: NotificationOpenSource.localTap,
          );
        }
        expect(sink.events, hasLength(2));
      },
    );

    test(
      'sink failure is best effort and does not prevent a later open',
      () async {
        final logs = LogCaptureService();
        await logs.clearAllLogs();
        sink.fail = true;
        await tracker.opened(
          notificationType: 'mention',
          source: NotificationOpenSource.osBackground,
          deduplicationKey: 'retryable-delivery',
        );
        expect(
          logs
              .getRecentLogs(minLevel: LogLevel.warning)
              .map((entry) => entry.name),
          contains('NotificationAnalyticsTracker'),
        );
        sink.fail = false;
        await tracker.opened(
          notificationType: 'mention',
          source: NotificationOpenSource.osBackground,
          deduplicationKey: 'retryable-delivery',
        );
        expect(sink.events, hasLength(1));
      },
    );
  });
}
