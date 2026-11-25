// ABOUTME: Tests the durable version-two product analytics retry queue.
// ABOUTME: Verifies immutable payloads, account boundaries, retries, and purging.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/product_event_queue.dart';

class _MockPendingProductEventsDao extends Mock
    implements PendingProductEventsDao {}

class _MockAnalyticsIngestClient extends Mock
    implements AnalyticsIngestClient {}

void main() {
  const owner =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() => registerFallbackValue(_pendingProductEventFallback()));

  group(ProductEventQueue, () {
    late _MockPendingProductEventsDao dao;
    late _MockAnalyticsIngestClient client;
    late ProductEventQueue queue;

    setUp(() {
      dao = _MockPendingProductEventsDao();
      client = _MockAnalyticsIngestClient();
      queue = ProductEventQueue(
        dao: dao,
        ingestClient: client,
        retryConfig: const ProductEventRetryConfig(
          initialDelay: Duration(seconds: 1),
        ),
        now: () => DateTime.utc(2026, 8, 20),
        currentOwnerPubkey: () => owner,
        sendingEnabled: true,
      );
      when(
        () => dao.prune(
          cutoff: any(named: 'cutoff'),
          maxRecords: any(named: 'maxRecords'),
        ),
      ).thenAnswer((_) async => 0);
    });

    test(
      'enqueue stores the exact version-two event without sending it',
      () async {
        when(() => dao.enqueue(any())).thenAnswer((_) async {});
        final event = _event('event-a');

        await queue.enqueue(event, ownerPubkey: owner);

        final row =
            verify(() => dao.enqueue(captureAny())).captured.single
                as PendingProductEvent;
        expect(row.id, 'event-a');
        expect(row.eventName, 'content_impression_recorded');
        expect(row.ownerPubkey, owner);
        expect(jsonDecode(row.payloadJson), event.toJson());
        verify(
          () => dao.prune(
            cutoff: DateTime.utc(2026, 8, 13),
            maxRecords: 500,
          ),
        ).called(1);
        verifyNever(
          () => client.publishBatch(
            any(),
            subjectPubkey: any(named: 'subjectPubkey'),
          ),
        );
        verifyNever(() => client.publishAnonymousBatch(any()));
      },
    );

    test(
      'a queued share tap from an older build is dropped before signing',
      () async {
        final kept = _row('kept', ownerPubkey: owner);
        final legacy = PendingProductEvent(
          id: 'legacy',
          ownerPubkey: owner,
          createdAt: DateTime.utc(2026),
          status: PendingProductEventStatus.pending,
          eventName: 'engagement_recorded',
          payloadJson: jsonEncode({
            'event_name': 'engagement_recorded',
            'properties': {'action': 'share_tapped', 'content_id': 'a' * 64},
          }),
        );
        when(
          () => dao.getRetryable(
            now: any(named: 'now'),
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (call) async =>
              call.namedArguments[#ownerPubkey] == owner ? [legacy, kept] : [],
        );
        when(() => dao.markPublishing(any())).thenAnswer((_) async => true);
        when(() => dao.deleteById(any())).thenAnswer((_) async => 1);
        when(() => client.publishBatch(any(), subjectPubkey: owner))
            .thenAnswer((_) async => const AnalyticsIngestAccepted());
        await queue.flush();
        final sent = verify(
          () => client.publishBatch(captureAny(), subjectPubkey: owner),
        ).captured.single;
        expect(sent, [jsonDecode(kept.payloadJson)]);
        verify(() => dao.deleteById('legacy')).called(1);
        verify(() => dao.deleteById('kept')).called(1);
      },
    );

    test('anonymous events remain ownerless', () async {
      when(() => dao.enqueue(any())).thenAnswer((_) async {});

      await queue.enqueue(_event('event-anonymous'));

      final row =
          verify(() => dao.enqueue(captureAny())).captured.single
              as PendingProductEvent;
      expect(row.ownerPubkey, isNull);
    });

    test('does not read or send while delivery is disabled', () async {
      queue.setSendingEnabled(false);

      await queue.recoverPublishingAndFlush();
      await queue.flush();

      verifyNever(() => dao.resetPublishingToPending());
      verifyNever(
        () => dao.getRetryable(
          now: any(named: 'now'),
          limit: any(named: 'limit'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
      verifyNever(() => client.publishAnonymousBatch(any()));
      verifyNever(
        () => client.publishBatch(
          any(),
          subjectPubkey: any(named: 'subjectPubkey'),
        ),
      );
    });

    test('defaults to sending disabled when the argument is omitted', () async {
      final defaultQueue = ProductEventQueue(
        dao: dao,
        ingestClient: client,
        now: () => DateTime.utc(2026, 8, 20),
      );

      await defaultQueue.recoverPublishingAndFlush();
      await defaultQueue.flush();

      verifyNever(() => dao.resetPublishingToPending());
      verifyNever(() => client.publishAnonymousBatch(any()));
      verifyNever(
        () => client.publishBatch(
          any(),
          subjectPubkey: any(named: 'subjectPubkey'),
        ),
      );
    });

    test(
      'flush sends anonymous and current-account batches separately',
      () async {
        when(
          () => dao.getRetryable(
            now: any(named: 'now'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [_row('anonymous')]);
        when(
          () => dao.getRetryable(
            now: any(named: 'now'),
            limit: any(named: 'limit'),
            ownerPubkey: owner,
          ),
        ).thenAnswer((_) async => [_row('signed', ownerPubkey: owner)]);
        when(() => dao.markPublishing(any())).thenAnswer((_) async => true);
        when(
          () => client.publishAnonymousBatch(any()),
        ).thenAnswer((_) async => const AnalyticsIngestAccepted());
        when(
          () => client.publishBatch(any(), subjectPubkey: owner),
        ).thenAnswer((_) async => const AnalyticsIngestAccepted());
        when(() => dao.deleteById(any())).thenAnswer((_) async => 1);

        await queue.flush();

        final anonymousPayload =
            verify(
                  () => client.publishAnonymousBatch(captureAny()),
                ).captured.single
                as List<Map<String, Object?>>;
        final signedPayload =
            verify(
                  () => client.publishBatch(captureAny(), subjectPubkey: owner),
                ).captured.single
                as List<Map<String, Object?>>;
        expect(anonymousPayload.single['event_id'], 'anonymous');
        expect(signedPayload.single['event_id'], 'signed');
        verify(() => dao.deleteById('anonymous')).called(1);
        verify(() => dao.deleteById('signed')).called(1);
      },
    );

    test(
      'a temporary failure retains the original event ID for retry',
      () async {
        final row = _row('event-a', ownerPubkey: owner);
        when(
          () => dao.getRetryable(
            now: any(named: 'now'),
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((invocation) async {
          final selected = invocation.namedArguments[#ownerPubkey];
          return selected == owner ? [row] : <PendingProductEvent>[];
        });
        when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
        when(
          () => client.publishBatch(any(), subjectPubkey: owner),
        ).thenAnswer(
          (_) async => const AnalyticsIngestTransientFailure('timeout'),
        );
        when(
          () => dao.markFailed(
            'event-a',
            'timeout',
            nextAttemptAt: any(named: 'nextAttemptAt'),
          ),
        ).thenAnswer((_) async => true);

        await queue.flush();

        final sent =
            verify(
                  () => client.publishBatch(captureAny(), subjectPubkey: owner),
                ).captured.single
                as List<Map<String, Object?>>;
        expect(sent.single['event_id'], 'event-a');
        verify(
          () => dao.markFailed(
            'event-a',
            'timeout',
            nextAttemptAt: DateTime.utc(2026, 8, 20, 0, 0, 1),
          ),
        ).called(1);
      },
    );

    test('a temporary failure remains retryable after many attempts', () async {
      final row = _row(
        'event-a',
        ownerPubkey: owner,
        attemptCount: 2,
        status: PendingProductEventStatus.failed,
      );
      when(
        () => dao.getRetryable(
          now: any(named: 'now'),
          limit: any(named: 'limit'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((invocation) async {
        final selected = invocation.namedArguments[#ownerPubkey];
        return selected == owner ? [row] : <PendingProductEvent>[];
      });
      when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
      when(
        () => client.publishBatch(any(), subjectPubkey: owner),
      ).thenAnswer(
        (_) async => const AnalyticsIngestTransientFailure('network_error'),
      );
      when(
        () => dao.markFailed(
          'event-a',
          'network_error',
          nextAttemptAt: any(named: 'nextAttemptAt'),
        ),
      ).thenAnswer((_) async => true);

      await queue.flush();

      verify(
        () => dao.markFailed(
          'event-a',
          'network_error',
          nextAttemptAt: DateTime.utc(2026, 8, 20, 0, 0, 4),
        ),
      ).called(1);
      verifyNever(() => dao.markDeadLetter('event-a', any()));
    });

    test('permanent rejection dead-letters the batch', () async {
      when(
        () => dao.getRetryable(
          now: any(named: 'now'),
          limit: any(named: 'limit'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#ownerPubkey] == owner
            ? [_row('event-a', ownerPubkey: owner)]
            : <PendingProductEvent>[];
      });
      when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
      when(
        () => client.publishBatch(any(), subjectPubkey: owner),
      ).thenAnswer(
        (_) async => const AnalyticsIngestRejected(
          statusCode: 422,
          reason: 'schema rejected',
        ),
      );
      when(
        () => dao.markDeadLetter('event-a', 'schema rejected'),
      ).thenAnswer((_) async => true);

      await queue.flush();

      verify(() => dao.markDeadLetter('event-a', 'schema rejected')).called(1);
    });

    test('clear purges all private queued data', () async {
      when(() => dao.deleteAll()).thenAnswer((_) async => 2);

      await queue.clear();

      verify(() => dao.deleteAll()).called(1);
    });
  });
}

ProductAnalyticsV2Event _event(String id) {
  return ProductAnalyticsV2ContentImpressionRecordedEvent(
    envelope: ProductAnalyticsV2Envelope(
      eventId: id,
      schemaVersion: 2,
      occurredAt: DateTime.utc(2026, 8, 20),
      anonymousId: '22222222-2222-4222-8222-222222222222',
      sessionId: '33333333-3333-4333-8333-333333333333',
      source: ProductAnalyticsV2Source.mobile,
      platform: ProductAnalyticsV2Platform.ios,
      release: '1.2.3',
      consentCategory: ProductAnalyticsV2ConsentCategory.productAnalytics,
    ),
    properties: const ProductAnalyticsV2ContentImpressionRecordedProperties(
      contentId: 'content-a',
      surface: ProductAnalyticsV2Surface.feed,
      position: 1,
      visibleMs: 1000,
    ),
  );
}

PendingProductEvent _row(
  String id, {
  String? ownerPubkey,
  int attemptCount = 0,
  PendingProductEventStatus status = PendingProductEventStatus.pending,
}) {
  return PendingProductEvent(
    id: id,
    eventName: 'content_impression_recorded',
    payloadJson: jsonEncode(_event(id).toJson()),
    status: status,
    attemptCount: attemptCount,
    createdAt: DateTime.utc(2026, 8, 20),
    ownerPubkey: ownerPubkey,
  );
}

PendingProductEvent _pendingProductEventFallback() => _row('fallback');
