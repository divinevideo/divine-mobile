// ABOUTME: Unit tests for OutgoingDmRetryService — pinned contracts:
// ABOUTME: dispatches recipient: sent / self: failed rows to recoverSelfWrap,
// ABOUTME: dispatches recipient: failed rows to recoverFullSend,
// ABOUTME: never republishes recipient wraps for already-sent rows,
// ABOUTME: applies per-row backoff.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/outgoing_dm_retry_service_reportable_sites.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

const _ownerPubkey =
    '0000000000000000000000000000000000000000000000000000000000000001';
const _otherOwner =
    '0000000000000000000000000000000000000000000000000000000000000002';
const _recipientPubkey =
    '0000000000000000000000000000000000000000000000000000000000000099';

OutgoingDm _row({
  required String id,
  required OutgoingWrapStatus recipient,
  required OutgoingWrapStatus self,
  int retryCount = 0,
  DateTime? lastAttemptAt,
  String ownerPubkey = _ownerPubkey,
  DateTime? queuedAt,
}) {
  return OutgoingDm(
    id: id,
    conversationId: 'conv:$id',
    recipientPubkey: _recipientPubkey,
    content: 'hello',
    createdAt: 1700000000,
    rumorEventJson: '{}',
    recipientWrapStatus: recipient,
    selfWrapStatus: self,
    queuedAt: queuedAt ?? DateTime.utc(2026),
    ownerPubkey: ownerPubkey,
    retryCount: retryCount,
    lastAttemptAt: lastAttemptAt,
  );
}

NIP17SendResult _successResult(String rumorId) => NIP17SendResult.success(
  rumorEventId: rumorId,
  messageEventId: 'wrap:$rumorId',
  recipientPubkey: _ownerPubkey,
);

NIP17SendResult _failureResult(String reason) =>
    NIP17SendResult.failure(reason);

/// What the repository returns after dropping a queued row addressed to its
/// own sender (#8363).
const _selfAddressedRefusal = NIP17SendResult.blocked(
  'refused: a message cannot be addressed to its own sender',
);

void main() {
  late _MockDmRepository dmRepository;
  late _MockOutgoingDmsDao dao;
  late StreamController<bool> foregroundController;
  late StreamController<void> retryableWorkController;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(OutgoingWrapStatus.pending);
  });

  setUp(() {
    dmRepository = _MockDmRepository();
    dao = _MockOutgoingDmsDao();
    foregroundController = StreamController<bool>.broadcast();
    // Sync so fakeAsync tests deliver nudges without a real-time hop;
    // initialize() subscribes to this stream unconditionally.
    retryableWorkController = StreamController<void>.broadcast(sync: true);
    when(
      () => dmRepository.retryableOutgoingWork,
    ).thenAnswer((_) => retryableWorkController.stream);

    // Permissive defaults so individual tests only stub what they care about.
    when(
      () => dao.getRetryableForOwner(
        ownerPubkey: any(named: 'ownerPubkey'),
        maxRetries: any(named: 'maxRetries'),
      ),
    ).thenAnswer((_) async => const <OutgoingDm>[]);
    when(
      () => dao.getStillPendingForOwner(any()),
    ).thenAnswer((_) async => const <OutgoingDm>[]);
    when(() => dao.incrementRetry(any())).thenAnswer((_) async => true);
    when(
      () => dmRepository.retryableMessageDeletions(),
    ).thenAnswer((_) async => const <DmMessageDeletionRetryTarget>[]);
  });

  tearDown(() async {
    await foregroundController.close();
    await retryableWorkController.close();
  });

  OutgoingDmRetryService buildService({
    OutgoingDmRetryConfig retryConfig = const OutgoingDmRetryConfig(),
    DateTime Function()? now,
    CrashReportingService? crashReporting,
    Stream<void>? retryTriggerStream,
    Future<bool> Function()? isOffline,
  }) {
    return OutgoingDmRetryService(
      dmRepository: dmRepository,
      outgoingDmsDao: dao,
      userPubkey: _ownerPubkey,
      appForegroundStream: foregroundController.stream,
      retryTriggerStream: retryTriggerStream,
      isOffline: isOffline,
      retryConfig: retryConfig,
      now: now ?? () => DateTime.utc(2026, 5, 10, 12),
      crashReporting: crashReporting ?? CrashReportingService(),
    );
  }

  group(OutgoingDmRetryService, () {
    group('initialize', () {
      test('subscribes to the foreground stream', () async {
        final service = buildService();
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(foregroundController.hasListener, isTrue);
        await service.dispose();
      });

      test('is idempotent — second call does not double-subscribe', () async {
        final service = buildService();
        await service.initialize();
        await service.initialize();
        expect(foregroundController.hasListener, isTrue);
        // The second initialize did not throw and the service stayed init.
        expect(service.isInitialized, isTrue);
        await service.dispose();
      });

      test('dispose cancels the foreground subscription', () async {
        final service = buildService();
        await service.initialize();
        await service.dispose();
        expect(foregroundController.hasListener, isFalse);
        expect(service.isInitialized, isFalse);
      });

      test('a retry-trigger event (reconnect) triggers a sweep', () async {
        final triggerController = StreamController<void>.broadcast();
        addTearDown(triggerController.close);

        final service = buildService(
          retryTriggerStream: triggerController.stream,
        );
        await service.initialize();
        triggerController.add(null);
        await pumpEventQueue();

        verify(
          () => dao.getRetryableForOwner(
            ownerPubkey: _ownerPubkey,
            maxRetries: 5,
          ),
        ).called(1);
        await service.dispose();
      });

      test(
        'foreground=true triggers a sweep; foreground=false does not',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => const <OutgoingDm>[]);

          final service = buildService();
          await service.initialize();

          foregroundController.add(false);
          await pumpEventQueue();
          verifyNever(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          );

          foregroundController.add(true);
          await pumpEventQueue();
          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _ownerPubkey,
              maxRetries: 5,
            ),
          ).called(1);

          await service.dispose();
        },
      );
    });

    group('retryable-work nudge bootstraps the follow-up heartbeat', () {
      void verifySweepCount(int count) {
        if (count == 0) {
          verifyNever(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          );
        } else {
          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _ownerPubkey,
              maxRetries: 5,
            ),
          ).called(count);
        }
      }

      test(
        'a nudge while idle arms the 30s follow-up timer, and the sweep '
        'fires when it elapses — the cold-start bootstrap',
        () {
          fakeAsync((async) {
            final service = buildService();
            unawaited(service.initialize());
            async.flushMicrotasks();

            retryableWorkController.add(null);
            async.flushMicrotasks();
            // The nudge only arms the timer — no immediate sweep.
            verifySweepCount(0);

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();
            verifySweepCount(1);

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a second nudge never postpones an armed deadline — one sweep '
        'fires 30s after the FIRST nudge',
        () {
          fakeAsync((async) {
            final service = buildService();
            unawaited(service.initialize());
            async.flushMicrotasks();

            retryableWorkController.add(null);
            async
              ..elapse(const Duration(seconds: 10))
              ..flushMicrotasks();
            retryableWorkController.add(null);
            async
              ..elapse(const Duration(seconds: 19))
              ..flushMicrotasks();
            // 29s after the first nudge: not yet.
            verifySweepCount(0);

            async
              ..elapse(const Duration(seconds: 1))
              ..flushMicrotasks();
            // 30s after the FIRST nudge (20s after the second): exactly one
            // sweep — the second nudge neither postponed nor duplicated it.
            verifySweepCount(1);

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a nudge that lands mid-sweep still arms the follow-up even when '
        'that pass ends with no work remaining',
        () {
          fakeAsync((async) {
            // Park the sweep on a gated DAO read so the nudge arrives while
            // _isSweeping is true.
            final gate = Completer<List<OutgoingDm>>();
            when(
              () => dao.getRetryableForOwner(
                ownerPubkey: any(named: 'ownerPubkey'),
                maxRetries: any(named: 'maxRetries'),
              ),
            ).thenAnswer((_) => gate.future);

            final service = buildService();
            unawaited(service.initialize());
            async.flushMicrotasks();

            unawaited(service.sweep());
            async.flushMicrotasks();
            expect(service.isSweeping, isTrue);

            retryableWorkController.add(null);
            async.flushMicrotasks();

            // The pass ends with an empty queue → workRemains=false → its
            // own scheduling disarms. The buffered nudge must re-arm.
            gate.complete(const <OutgoingDm>[]);
            async.flushMicrotasks();
            expect(service.isSweeping, isFalse);

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();
            verify(
              () => dao.getRetryableForOwner(
                ownerPubkey: _ownerPubkey,
                maxRetries: 5,
              ),
            ).called(2);

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('dispose cancels the armed timer and later nudges are no-ops', () {
        fakeAsync((async) {
          final service = buildService();
          unawaited(service.initialize());
          async.flushMicrotasks();

          retryableWorkController.add(null);
          async.flushMicrotasks();

          unawaited(service.dispose());
          async.flushMicrotasks();

          // The armed timer was cancelled with the service.
          async
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();
          verifySweepCount(0);

          // Post-dispose nudges reach a cancelled subscription — no-op.
          retryableWorkController.add(null);
          async
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();
          verifySweepCount(0);
        });
      });

      test(
        'offline pass keeps re-examining young pending rows: too young to '
        'flip → follow-up armed; aged past the guard → terminalized; '
        'nothing pending → heartbeat disarms',
        () {
          fakeAsync((async) {
            final base = DateTime.utc(2026, 5, 10, 12);
            // Derived from the guard, not restated: the row starts one
            // follow-up gap short of it, so it is too young at t=0 and
            // t=+gap, and exactly old enough at t=+2×gap.
            const gap = Duration(seconds: 30);
            final minAge = OutgoingDmRetryService.interruptedMinAge;
            final row = _row(
              id: 'young-pending',
              recipient: OutgoingWrapStatus.pending,
              self: OutgoingWrapStatus.pending,
              queuedAt: base.subtract(minAge - gap * 2),
            );
            var terminalized = false;
            when(
              () => dao.getStillPendingForOwner(any()),
            ).thenAnswer((_) async => terminalized ? const [] : [row]);
            when(
              () => dao.markRecipientWrapStatus(
                id: any(named: 'id'),
                status: any(named: 'status'),
                lastError: any(named: 'lastError'),
              ),
            ).thenAnswer((_) async {
              terminalized = true;
              return true;
            });
            when(
              () => dao.markSelfWrapStatus(
                id: any(named: 'id'),
                status: any(named: 'status'),
                lastError: any(named: 'lastError'),
              ),
            ).thenAnswer((_) async => true);

            final service = buildService(
              isOffline: () async => true,
              now: () => base.add(async.elapsed),
            );
            unawaited(service.initialize());
            async.flushMicrotasks();

            unawaited(service.sweep());
            async.flushMicrotasks();
            // Two gaps short of the guard: nothing flipped, follow-up armed.
            verifyNever(
              () => dao.markRecipientWrapStatus(
                id: any(named: 'id'),
                status: any(named: 'status'),
                lastError: any(named: 'lastError'),
              ),
            );

            async
              ..elapse(gap)
              ..flushMicrotasks();
            // One gap short of the guard: still young, chain re-armed.
            verifyNever(
              () => dao.markRecipientWrapStatus(
                id: any(named: 'id'),
                status: any(named: 'status'),
                lastError: any(named: 'lastError'),
              ),
            );

            async
              ..elapse(gap)
              ..flushMicrotasks();
            // Guard reached: flipped to failed so it stops looking delivered.
            verify(
              () => dao.markRecipientWrapStatus(
                id: 'young-pending',
                status: OutgoingWrapStatus.failed,
                lastError: any(named: 'lastError'),
              ),
            ).called(1);

            // Nothing pending anymore → the pass reports no remaining work
            // and the heartbeat disarms: three passes ran (t=0, 30, 60),
            // then silence.
            verify(() => dao.getStillPendingForOwner(any())).called(3);
            async
              ..elapse(const Duration(minutes: 5))
              ..flushMicrotasks();
            verifyNever(() => dao.getStillPendingForOwner(any()));

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('offline pass with an empty queue arms no follow-up', () {
        fakeAsync((async) {
          final service = buildService(isOffline: () async => true);
          unawaited(service.initialize());
          async.flushMicrotasks();

          unawaited(service.sweep());
          async.flushMicrotasks();
          verify(() => dao.getStillPendingForOwner(any())).called(1);

          async
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();
          verifyNever(() => dao.getStillPendingForOwner(any()));

          unawaited(service.dispose());
          async.flushMicrotasks();
        });
      });
    });

    group('cancelled batch rows are never re-published', () {
      test(
        'after every sibling row of a partially delivered group send is '
        'cancelled, the sweep publishes nothing',
        () async {
          // Mutable store standing in for outgoing_dms: the surviving
          // siblings of a group send whose winner already persisted — one
          // still pending (old enough for the interrupted arm), one hard
          // failed.
          final now = DateTime.utc(2026, 5, 10, 12);
          final store = <OutgoingDm>[
            _row(
              id: 'sibling-pending',
              recipient: OutgoingWrapStatus.pending,
              self: OutgoingWrapStatus.pending,
              queuedAt: now.subtract(const Duration(minutes: 10)),
            ),
            _row(
              id: 'sibling-failed',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer(
            (_) async => [
              for (final r in store)
                if (r.hasRetryableFailure) r,
            ],
          );
          when(() => dao.getStillPendingForOwner(any())).thenAnswer(
            (_) async => [
              for (final r in store)
                if (r.recipientWrapStatus == OutgoingWrapStatus.pending ||
                    r.selfWrapStatus == OutgoingWrapStatus.pending)
                  r,
            ],
          );
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('recovered'));

          final service = buildService(now: () => now);

          // Control: with the rows live, the sweep re-drives both siblings.
          await service.sweep();
          verify(
            () => dmRepository.recoverFullSend(rumorId: 'sibling-failed'),
          ).called(1);
          verify(
            () => dmRepository.recoverFullSend(rumorId: 'sibling-pending'),
          ).called(1);

          // The user deletes the group message: cancelOutgoingBatch drops
          // every sibling row (pending AND failed).
          store.clear();

          await service.sweep();
          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          );
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
        },
      );
    });

    group('sweep dispatch', () {
      test(
        'dispatches recipient: sent / self: failed rows to recoverSelfWrap',
        () async {
          final row = _row(
            id: 'rumor1',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor1'));

          final service = buildService();
          await service.sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor1'),
          ).called(1);
          // recoverSelfWrap deletes the row on success — no incrementRetry.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'dispatches recipient: failed rows to recoverFullSend (not '
        'recoverSelfWrap)',
        () async {
          final row = _row(
            id: 'rumor2',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor2'));

          final service = buildService();
          await service.sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'rumor2'),
          ).called(1);
          // recoverSelfWrap is reserved for the recipient-sent / self-failed
          // case; recipient-failed rows must go through recoverFullSend so
          // the recipient publish is replayed alongside the self-wrap.
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
          // recoverFullSend's success path finalizes the row by either
          // deleting it (full delivery) or marking recipient sent / self
          // failed (partial). Either way no retry bump is needed.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'soft-unconfirmed recoverFullSend replay of a FAILED row charges no '
        'sweep-side budget and rewrites no wrap status — the row (and its '
        'red bubble) stay exactly as the repository left them',
        () async {
          // The #6046 incident loop: a red offline-failed row re-driven into
          // a zombie socket comes back retryablePending on every pass
          // (full-send-failed=1 forever). The sweep must neither
          // double-charge the budget (the repo's soft finalize already
          // incremented) nor touch wrap statuses (the row must stay failed,
          // never masquerade as pending/sent).
          final row = _row(
            id: 'soft-failed',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure(
              'Message recipient OK unconfirmed',
              retryablePending: true,
            ),
          );

          await buildService().sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'soft-failed'),
          ).called(1);
          verifyNever(() => dao.incrementRetry(any()));
          verifyNever(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
          verifyNever(
            () => dao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'recoverFullSend publish-failure path bumps incrementRetry once',
        () async {
          final row = _row(
            id: 'rumor2b',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: DateTime.utc(2025),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _failureResult('relay still down'));

          await buildService().sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'rumor2b'),
          ).called(1);
          verify(() => dao.incrementRetry('rumor2b')).called(1);
        },
      );

      test(
        'recoverFullSend blocked path is terminal: no incrementRetry',
        () async {
          final row = _row(
            id: 'rumor2c',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: DateTime.utc(2025),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer(
            (_) async => const NIP17SendResult.blocked('blocked by policy'),
          );

          await buildService().sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'rumor2c'),
          ).called(1);
          // A policy block is terminal: recoverFullSend already dropped the
          // row, so the sweep must not re-arm it with a retry bump.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test('publish-failure path bumps incrementRetry once', () async {
        final row = _row(
          id: 'rumor3',
          recipient: OutgoingWrapStatus.sent,
          self: OutgoingWrapStatus.failed,
          retryCount: 1,
          // lastAttemptAt is far enough in the past that backoff doesn't gate.
          lastAttemptAt: DateTime.utc(2025),
        );
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => [row]);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        ).thenAnswer((_) async => _failureResult('relay timeout'));

        final service = buildService();
        await service.sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'rumor3')).called(1);
        verify(() => dao.incrementRetry('rumor3')).called(1);
      });

      // recoverSelfWrap reports a row addressed to its own sender as blocked
      // after dropping it (#8363), so this arm has the same terminal outcome
      // to honour as the recoverFullSend one above.
      test(
        'recoverSelfWrap blocked path is terminal: no incrementRetry',
        () async {
          final row = _row(
            id: 'rumor3b',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: DateTime.utc(2025),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _selfAddressedRefusal);

          await buildService().sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor3b'),
          ).called(1);
          // The row is already gone: a bump would charge a retry budget
          // that nothing will ever spend.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'recoverSelfWrap blocked path is summarised as blocked, not failed',
        () async {
          final logCapture = LogCaptureService();
          await logCapture.clearAllLogs();
          addTearDown(logCapture.clearAllLogs);
          final row = _row(
            id: 'rumor3c',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _selfAddressedRefusal);

          await buildService().sweep();

          // The line support reads to tell a queue that is draining from one
          // that is stuck retrying. Picked by logger name too: the reaction
          // retry service writes the same prefix into this shared capture.
          final summary = logCapture
              .getRecentLogs()
              .where((entry) => entry.name == 'OutgoingDmRetryService')
              .map((entry) => entry.message)
              .singleWhere((message) => message.startsWith('sweep complete:'));
          expect(summary, contains('self-wrap-failed=0 '));
          expect(summary, contains('self-wrap-blocked=1 '));
        },
      );

      test(
        'a pass whose only outcome is a blocked recoverSelfWrap arms no '
        'follow-up sweep',
        () {
          fakeAsync((async) {
            final row = _row(
              id: 'rumor3d',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            );
            // Stands in for the queue: the refusal drops the row.
            var dropped = false;
            when(
              () => dao.getRetryableForOwner(
                ownerPubkey: any(named: 'ownerPubkey'),
                maxRetries: any(named: 'maxRetries'),
              ),
            ).thenAnswer((_) async => dropped ? const [] : [row]);
            when(
              () =>
                  dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
            ).thenAnswer((_) async {
              dropped = true;
              return _selfAddressedRefusal;
            });

            final service = buildService();
            unawaited(service.initialize());
            async.flushMicrotasks();

            unawaited(service.sweep());
            async.flushMicrotasks();
            verify(
              () => dmRepository.recoverSelfWrap(rumorId: 'rumor3d'),
            ).called(1);
            verify(
              () => dao.getRetryableForOwner(
                ownerPubkey: _ownerPubkey,
                maxRetries: 5,
              ),
            ).called(1);

            // Nothing is left to drive, so the heartbeat stays disarmed. A
            // pass that counted the row as failed runs again 30s later.
            async
              ..elapse(const Duration(minutes: 5))
              ..flushMicrotasks();
            verifyNever(
              () => dao.getRetryableForOwner(
                ownerPubkey: any(named: 'ownerPubkey'),
                maxRetries: any(named: 'maxRetries'),
              ),
            );

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('multiple State A rows are processed independently', () async {
        final rows = [
          _row(
            id: 'a',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
          _row(
            id: 'b',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
        ];
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => rows);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        ).thenAnswer((inv) async {
          final id = inv.namedArguments[#rumorId] as String;
          return _successResult(id);
        });

        await buildService().sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
        verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
      });

      test('exits early when getRetryableForOwner is empty', () async {
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => const <OutgoingDm>[]);

        await buildService().sweep();

        verifyNever(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        );
        verifyNever(() => dao.incrementRetry(any()));
      });
    });

    group('per-row backoff', () {
      test(
        'skips a row whose lastAttemptAt + backoff is still in the future',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // retryCount=2 with default config gives backoff 8s. lastAttempt is
          // 1s ago — well within the gate.
          final row = _row(
            id: 'rumor4',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
            retryCount: 2,
            lastAttemptAt: now.subtract(const Duration(seconds: 1)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);

          await buildService(now: () => now).sweep();

          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
        },
      );

      test(
        'dispatches a row whose lastAttemptAt is older than the backoff',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // retryCount=1 → backoff 4s. lastAttempt is 30s ago — over the gate.
          final row = _row(
            id: 'rumor5',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: now.subtract(const Duration(seconds: 30)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor5'));

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor5'),
          ).called(1);
        },
      );

      test(
        'a fresh row (lastAttemptAt == null) is always dispatched',
        () async {
          final row = _row(
            id: 'rumor6',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor6'));

          await buildService().sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor6'),
          ).called(1);
        },
      );
    });

    group('message-deletion sweep', () {
      DmMessageDeletionRetryTarget target(String rumorId) =>
          DmMessageDeletionRetryTarget(
            rumorId: rumorId,
            conversationId: 'conv_1',
            createdAt: 1700000000,
          );

      void stubPending(List<String> rumorIds) {
        when(() => dmRepository.retryableMessageDeletions()).thenAnswer(
          (_) async => rumorIds.map(target).toList(),
        );
      }

      test('re-drives an unconfirmed deletion', () async {
        stubPending(['del1']);
        when(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenAnswer((_) async => DmMessageDeletionOutcome.sent);

        await buildService().sweep();

        verify(
          () => dmRepository.retryMessageDeletion(rumorId: 'del1'),
        ).called(1);
      });

      test('holds a re-attempt back until the backoff elapses', () async {
        final now = DateTime.utc(2026, 5, 10, 12);
        stubPending(['del1']);
        when(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenAnswer((_) async => DmMessageDeletionOutcome.unconfirmed);
        final service = buildService(now: () => now);

        await service.sweep();
        // Same clock: the first attempt's backoff has not elapsed.
        await service.sweep();

        verify(
          () => dmRepository.retryMessageDeletion(rumorId: 'del1'),
        ).called(1);
      });

      test('stops re-driving once the attempt budget is spent', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPending(['del1']);
        when(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenAnswer((_) async => DmMessageDeletionOutcome.unconfirmed);
        final service = buildService(
          retryConfig: const OutgoingDmRetryConfig(maxRetries: 2),
          now: () => clock,
        );

        // Advance well past every backoff so only the budget can stop it.
        for (var i = 0; i < 5; i++) {
          clock = clock.add(const Duration(hours: 1));
          await service.sweep();
        }

        verify(
          () => dmRepository.retryMessageDeletion(rumorId: 'del1'),
        ).called(2);
      });

      test('does not spend budget on a row it could not attempt', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPending(['del1']);
        // `unavailable` means nothing was sent — a row whose stored rumor is
        // missing must not silently consume the budget a real send needs.
        when(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenAnswer((_) async => DmMessageDeletionOutcome.unavailable);
        final service = buildService(
          retryConfig: const OutgoingDmRetryConfig(maxRetries: 2),
          now: () => clock,
        );

        for (var i = 0; i < 4; i++) {
          clock = clock.add(const Duration(hours: 1));
          await service.sweep();
        }

        verify(
          () => dmRepository.retryMessageDeletion(rumorId: 'del1'),
        ).called(4);
      });

      test(
        'forgets a settled deletion instead of leaking its budget',
        () async {
          var clock = DateTime.utc(2026, 5, 10, 12);
          stubPending(['del1']);
          when(
            () => dmRepository.retryMessageDeletion(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenAnswer((_) async => DmMessageDeletionOutcome.unconfirmed);
          final service = buildService(
            retryConfig: const OutgoingDmRetryConfig(maxRetries: 1),
            now: () => clock,
          );

          await service.sweep();
          // Row settles and leaves the worklist...
          stubPending([]);
          clock = clock.add(const Duration(hours: 1));
          await service.sweep();
          // ...then the same id comes back as a NEW deletion of a re-sent
          // message. Stale attempt state would make it exhausted on arrival.
          stubPending(['del1']);
          clock = clock.add(const Duration(hours: 1));
          await service.sweep();

          verify(
            () => dmRepository.retryMessageDeletion(rumorId: 'del1'),
          ).called(2);
        },
      );

      test('a throwing retry does not abort the pass', () async {
        stubPending(['del1']);
        when(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenThrow(StateError('boom'));

        await expectLater(buildService().sweep(), completes);
      });

      test('skips the whole pass while offline', () async {
        stubPending(['del1']);
        when(
          () => dao.getStillPendingForOwner(any()),
        ).thenAnswer((_) async => const <OutgoingDm>[]);

        await buildService(isOffline: () async => true).sweep();

        verifyNever(
          () => dmRepository.retryMessageDeletion(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });
    });

    group('error handling', () {
      test(
        'contains a top-level DAO failure and clears the in-progress flag',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('database locked'));

          final service = buildService();

          await expectLater(service.sweep(), completes);
          expect(service.isSweeping, isFalse);
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'a throwing pass re-arms the 30s heartbeat so a transient DAO error '
        'does not silence it until an external trigger',
        () {
          fakeAsync((async) {
            final crashReporting = _MockCrashReportingService();
            when(
              () => crashReporting.recordError(
                any<dynamic>(),
                any<StackTrace?>(),
                reason: any(named: 'reason'),
              ),
            ).thenAnswer((_) async {});

            var calls = 0;
            when(
              () => dao.getRetryableForOwner(
                ownerPubkey: any(named: 'ownerPubkey'),
                maxRetries: any(named: 'maxRetries'),
              ),
            ).thenAnswer((_) async {
              calls++;
              if (calls == 1) throw StateError('database busy');
              return const <OutgoingDm>[];
            });

            final service = buildService(crashReporting: crashReporting);
            unawaited(service.initialize());
            async.flushMicrotasks();

            unawaited(service.sweep());
            async.flushMicrotasks();
            // The first pass threw before reaching the try-path scheduler;
            // the heartbeat must still be armed by the top-level catch.
            expect(calls, 1);

            async
              ..elapse(const Duration(seconds: 30))
              ..flushMicrotasks();
            // The re-armed follow-up ran a second pass 30s later.
            expect(calls, 2);

            async
              ..elapse(const Duration(minutes: 5))
              ..flushMicrotasks();
            // The successful second pass found an empty queue and
            // self-cancelled — no further passes.
            expect(calls, 2);

            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'StateError aborts the pass; remaining rows are not dispatched',
        () async {
          // Two rows; the first throws StateError. The loop must not advance to
          // the second — auth-not-ready is a per-pass issue, not per-row.
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'a'),
          ).thenThrow(StateError('repo not initialized'));

          await buildService().sweep();

          verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
          verifyNever(() => dmRepository.recoverSelfWrap(rumorId: 'b'));
          // Did not bump retry — no attempt was actually made.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test('ArgumentError skips the row but continues with the next', () async {
        final rows = [
          _row(
            id: 'a',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
          _row(
            id: 'b',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
        ];
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => rows);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: 'a'),
        ).thenThrow(ArgumentError.value('a', 'rumorId', 'no queued row'));
        when(
          () => dmRepository.recoverSelfWrap(rumorId: 'b'),
        ).thenAnswer((_) async => _successResult('b'));

        await buildService().sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
        verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
        // Did not bump retry on the missing-row case — terminal, not
        // "row failed to publish."
        verifyNever(() => dao.incrementRetry('a'));
      });

      test(
        'unexpected throw bumps retry and continues with the next row',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'a'),
          ).thenThrow(Exception('relay disconnected'));
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dao.incrementRetry('a')).called(1);
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
        },
      );
    });

    group('contract: dispatches the correct primitive per row state', () {
      // Pin the strategy table: recipient: sent / self: failed →
      // recoverSelfWrap (never republishes recipient); recipient: failed
      // → recoverFullSend (replays both wraps; safe via NIP-17 receiver
      // dedup). The sweep must never reach for sendMessage /
      // sendGroupMessage / sendPrivateMessage which would mint a fresh
      // rumor and zombify the queue row.
      test(
        'a full pass over assorted retryable rows dispatches each row to '
        'the right primitive',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'c',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((inv) async {
            final id = inv.namedArguments[#rumorId] as String;
            return _successResult(id);
          });
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((inv) async {
            final id = inv.namedArguments[#rumorId] as String;
            return _successResult(id);
          });

          await buildService().sweep();

          // The sweep never mints a fresh rumor via the user-facing send
          // primitives — that would zombify the queue row by enqueueing a
          // new one with a different id.
          verifyNever(
            () => dmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
            ),
          );
          verifyNever(
            () => dmRepository.sendGroupMessage(
              recipientPubkeys: any(named: 'recipientPubkeys'),
              content: any(named: 'content'),
            ),
          );

          // Strategy A: recipient: sent / self: failed → recoverSelfWrap.
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'c')).called(1);
          verifyNever(() => dmRepository.recoverSelfWrap(rumorId: 'b'));

          // Strategy B: recipient: failed → recoverFullSend.
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'a'));
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'c'));
        },
      );

      test(
        'recoverFullSend is never invoked for rows where recipient is '
        'already sent',
        () async {
          // Any row where recipientWrapStatus == sent must route through
          // recoverSelfWrap, never recoverFullSend. recoverFullSend's
          // idempotent guard would defer to recoverSelfWrap internally
          // anyway, but the dispatcher should not even hand it those
          // rows — keeps the strategy table readable.
          final row = _row(
            id: 'sent-row',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('sent-row'));

          await buildService().sweep();

          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          );
        },
      );
    });

    group('recoverFullSend error handling', () {
      test(
        'StateError from recoverFullSend aborts the pass without bumping '
        'retry',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(StateError('repo not initialized'));

          await buildService().sweep();

          verify(() => dmRepository.recoverFullSend(rumorId: 'a')).called(1);
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'b'));
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'ArgumentError from recoverFullSend skips the row and continues',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(ArgumentError.value('a', 'rumorId', 'no queued row'));
          when(
            () => dmRepository.recoverFullSend(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dmRepository.recoverFullSend(rumorId: 'a')).called(1);
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
          verifyNever(() => dao.incrementRetry('a'));
        },
      );

      test(
        'unexpected throw from recoverFullSend bumps retry and continues',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(Exception('relay disconnected'));
          when(
            () => dmRepository.recoverFullSend(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dao.incrementRetry('a')).called(1);
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
        },
      );
    });

    group('re-entrancy', () {
      test(
        'a sweep already in progress short-circuits a second invocation',
        () async {
          final completer = Completer<NIP17SendResult>();
          final row = _row(
            id: 'rumor7',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) => completer.future);

          final service = buildService();
          final first = service.sweep();
          // Yield so the first sweep gets past the in-progress flag set.
          await pumpEventQueue();
          expect(service.isSweeping, isTrue);

          // Second call returns immediately without entering the loop.
          await service.sweep();
          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _ownerPubkey,
              maxRetries: any(named: 'maxRetries'),
            ),
          ).called(1);

          completer.complete(_successResult('rumor7'));
          await first;
          expect(service.isSweeping, isFalse);
        },
      );
    });

    group('account scope', () {
      test(
        'queries getRetryableForOwner with the constructor-provided pubkey',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => const <OutgoingDm>[]);

          // Build with a service for a SPECIFIC user; verify the query is
          // scoped to them. The DAO filter is the account-isolation
          // boundary — pin it here so a future refactor can't drop it.
          final service = OutgoingDmRetryService(
            crashReporting: CrashReportingService(),
            dmRepository: dmRepository,
            outgoingDmsDao: dao,
            userPubkey: _otherOwner,
            appForegroundStream: foregroundController.stream,
          );

          await service.sweep();

          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _otherOwner,
              maxRetries: any(named: 'maxRetries'),
            ),
          ).called(1);
        },
      );
    });

    group('crash reporting', () {
      late _MockCrashReportingService crashReporting;

      setUp(() {
        crashReporting = _MockCrashReportingService();
        when(
          () => crashReporting.recordError(
            any<dynamic>(),
            any<StackTrace?>(),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) async {});
      });

      test(
        'per-row recoverSelfWrap throw reports to CrashReportingService',
        () async {
          final row = _row(
            id: 'rumor-boom',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenThrow(Exception('drift busy'));

          final service = buildService(crashReporting: crashReporting);
          await service.sweep();

          verify(
            () => crashReporting.recordError(
              any<dynamic>(),
              any<StackTrace?>(),
              reason:
                  OutgoingDmRetryServiceReportableSites.perRowUnexpectedThrow,
            ),
          ).called(1);
        },
      );

      test(
        'sweep-level throw reports to CrashReportingService',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('drift connection lost'));

          final service = buildService(crashReporting: crashReporting);
          await service.sweep();

          verify(
            () => crashReporting.recordError(
              any<dynamic>(),
              any<StackTrace?>(),
              reason: OutgoingDmRetryServiceReportableSites.sweepTopLevel,
            ),
          ).called(1);
        },
      );

      test(
        'consecutive sweep-level throws report only once per fault streak',
        () async {
          // A persistently-throwing DAO re-enters the top-level catch every
          // pass. Only the first fault of the streak should escalate to
          // Crashlytics; the re-arm keeps sweeping regardless.
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('drift connection lost'));

          final service = buildService(crashReporting: crashReporting);
          await service.sweep();
          await service.sweep();
          await service.sweep();

          verify(
            () => crashReporting.recordError(
              any<dynamic>(),
              any<StackTrace?>(),
              reason: OutgoingDmRetryServiceReportableSites.sweepTopLevel,
            ),
          ).called(1);
        },
      );

      test(
        'a non-throwing pass resets the streak so a later throw reports again',
        () async {
          final service = buildService(crashReporting: crashReporting);

          // Fault streak begins — reports once.
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('drift connection lost'));
          await service.sweep();

          // DAO heals: a clean pass ends the streak.
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => const <OutgoingDm>[]);
          await service.sweep();

          // New fault after recovery — reports afresh.
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('drift connection lost again'));
          await service.sweep();

          verify(
            () => crashReporting.recordError(
              any<dynamic>(),
              any<StackTrace?>(),
              reason: OutgoingDmRetryServiceReportableSites.sweepTopLevel,
            ),
          ).called(2);
        },
      );
    });

    group('interrupted-send recovery (pending:pending)', () {
      // The retry service's third arm — fulfils epic #3912's "outgoing
      // DM survives the app being killed mid-send" acceptance criterion.
      // recoverFullSend re-wraps the same rumor (rumor.id stable across
      // retries) so NIP-17 receiver dedup makes the replay idempotent.

      test(
        'dispatches stale pending:pending row to recoverFullSend',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final stalePending = _row(
            id: 'interrupted-1',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [stalePending]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('interrupted-1'));

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'interrupted-1'),
          ).called(1);
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
        },
      );

      test(
        'blocked interrupted-send drain is terminal: no incrementRetry',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final stalePending = _row(
            id: 'interrupted-blocked',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [stalePending]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer(
            (_) async => const NIP17SendResult.blocked('blocked by policy'),
          );

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'interrupted-blocked'),
          ).called(1);
          // recoverFullSend already deleted the row; a policy block is
          // terminal, so the interrupted arm must not re-arm it.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'terminalizes an exhausted pending row (retryCount >= maxRetries) to '
        'failed instead of re-driving it forever',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // getStillPendingForOwner has no retry-count cap of its own, so a
          // soft-unconfirmed / interrupted row that never confirms would
          // re-drive on every trigger without this guard.
          final exhausted = _row(
            id: 'exhausted-1',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            retryCount: 5, // == default maxRetries
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [exhausted]);
          when(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => dao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          ).thenAnswer((_) async => true);

          await buildService(now: () => now).sweep();

          // Both wraps are flipped to failed (red bubble + manual-retry
          // candidate); the row is never dispatched to recoverFullSend again.
          verify(
            () => dao.markRecipientWrapStatus(
              id: 'exhausted-1',
              status: OutgoingWrapStatus.failed,
              lastError: any(named: 'lastError'),
            ),
          ).called(1);
          verify(
            () => dao.markSelfWrapStatus(
              id: 'exhausted-1',
              status: OutgoingWrapStatus.failed,
              lastError: any(named: 'lastError'),
            ),
          ).called(1);
          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: 'exhausted-1'),
          );
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'exhausts a sent/pending row by failing ONLY the self wrap — never '
        'flips the delivered recipient wrap to failed',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // The recipient wrap already landed (delivered); only the invisible
          // self-wrap sync never confirmed. Terminalizing both wraps would
          // misrender a delivered message as a red "Not delivered" bubble and
          // let Resend republish it — mirror the offline path's already-sent
          // guard and fail only the self wrap.
          final exhausted = _row(
            id: 'exhausted-sent',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.pending,
            retryCount: 5, // == default maxRetries
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [exhausted]);
          when(
            () => dao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          ).thenAnswer((_) async => true);

          await buildService(now: () => now).sweep();

          verify(
            () => dao.markSelfWrapStatus(
              id: 'exhausted-sent',
              status: OutgoingWrapStatus.failed,
              lastError: any(named: 'lastError'),
            ),
          ).called(1);
          verifyNever(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          );
          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: 'exhausted-sent'),
          );
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'skips a pending row younger than initialDelay (in-flight send '
        'might still complete in-process)',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final freshPending = _row(
            id: 'fresh-1',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            // initialDelay default is 2s; this row is younger.
            queuedAt: now.subtract(const Duration(milliseconds: 500)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [freshPending]);

          await buildService(now: () => now).sweep();

          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          );
        },
      );

      test(
        'does not double-dispatch a row already handled by the failed arm',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // A recipient=failed row with a still-pending self wrap appears in
          // BOTH filters; the failed arm owns the dispatch and the
          // interrupted arm must skip it.
          final dualFilterRow = _row(
            id: 'dual-1',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [dualFilterRow]);
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [dualFilterRow]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _failureResult('relay still down'));

          await buildService(now: () => now).sweep();

          // Exactly one dispatch — the failed arm's.
          verify(
            () => dmRepository.recoverFullSend(rumorId: 'dual-1'),
          ).called(1);
        },
      );

      test(
        'a recipient=pending/self=failed row that matches neither failed-arm '
        'state is picked up by the interrupted arm — never stranded',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // This shape is in getRetryableForOwner (self=failed) but matches
          // neither State A (needs recipient=sent) nor State B (needs
          // recipient=failed). Before the dispatchedIds fix, the interrupted
          // arm skipped every retryable id wholesale, so the row was never
          // dispatched and never terminalized — a permanently sent-looking
          // pending bubble.
          final strandedHybrid = _row(
            id: 'hybrid-1',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.failed,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [strandedHybrid]);
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [strandedHybrid]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('hybrid-1'));

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'hybrid-1'),
          ).called(1);
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
        },
      );

      test(
        'soft-unconfirmed interrupted replay charges no sweep-side budget '
        'and rewrites no wrap status — the repository already recorded the '
        'attempt',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final stalePending = _row(
            id: 'soft-interrupted',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [stalePending]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure(
              'Message recipient OK unconfirmed',
              retryablePending: true,
            ),
          );

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'soft-interrupted'),
          ).called(1);
          // The repo's soft finalize already bumped the counter; a sweep-side
          // bump would double-charge and halve the effective budget.
          verifyNever(() => dao.incrementRetry(any()));
          // And the sweep never rewrites wrap statuses on a soft outcome —
          // the row keeps rendering exactly as the repository left it.
          verifyNever(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
          verifyNever(
            () => dao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'publish-failure path bumps incrementRetry once',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final stalePending = _row(
            id: 'interrupted-fail',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [stalePending]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _failureResult('relay timeout'));

          await buildService(now: () => now).sweep();

          verify(() => dao.incrementRetry('interrupted-fail')).called(1);
        },
      );
    });

    group('offline pass (probe reports no connectivity)', () {
      test(
        'surfaces an aged unconfirmed pending row as failed — both wraps '
        'marked with the offline error, no publish, no budget charge',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final stalePending = _row(
            id: 'offline-stale',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [stalePending]);
          when(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => dao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          ).thenAnswer((_) async => true);

          await buildService(
            now: () => now,
            isOffline: () async => true,
          ).sweep();

          verify(
            () => dao.markRecipientWrapStatus(
              id: 'offline-stale',
              status: OutgoingWrapStatus.failed,
              lastError: 'Message not sent: device offline',
            ),
          ).called(1);
          verify(
            () => dao.markSelfWrapStatus(
              id: 'offline-stale',
              status: OutgoingWrapStatus.failed,
              lastError: 'Message not sent: device offline',
            ),
          ).called(1);
          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          );
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
          verifyNever(() => dao.incrementRetry(any()));
          // The retryable (failed) arm is never enumerated offline — those
          // rows are already red and re-drive on reconnect.
          verifyNever(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          );
        },
      );

      test(
        'leaves a young pending row alone — its own in-flight sendMessage '
        'offline fail-fast owns the failure transition',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final young = _row(
            id: 'offline-young',
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(seconds: 30)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [young]);

          await buildService(
            now: () => now,
            isOffline: () async => true,
          ).sweep();

          verifyNever(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'leaves a delivered row with only the self-wrap outstanding alone — '
        'the recipient already has the message, so no red bubble',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          final delivered = _row(
            id: 'offline-delivered',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.pending,
            queuedAt: now.subtract(const Duration(minutes: 5)),
          );
          when(
            () => dao.getStillPendingForOwner(any()),
          ).thenAnswer((_) async => [delivered]);

          await buildService(
            now: () => now,
            isOffline: () async => true,
          ).sweep();

          verifyNever(
            () => dao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test('probe reporting online runs the normal pass', () async {
        await buildService(isOffline: () async => false).sweep();

        verify(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).called(1);
      });
    });
  });

  group(OutgoingDmRetryConfig, () {
    const cfg = OutgoingDmRetryConfig();

    test('retry 0 returns Duration.zero (no gate on the first attempt)', () {
      expect(cfg.backoffFor(0), Duration.zero);
    });

    test('retry 1 returns initialDelay × multiplier', () {
      expect(cfg.backoffFor(1), const Duration(seconds: 4));
    });

    test('retry growth caps at maxDelay', () {
      // Default config: 2s × 2^N — after enough retries we hit 5min cap.
      expect(cfg.backoffFor(20), cfg.maxDelay);
    });
  });

  // #6586. The DM send budget is assembled from constants in three packages,
  // and nothing but this test connects them. `dm_repository` cannot import
  // `keycast_flutter`, so the app layer — which depends on both — is the only
  // place the full relationship can be asserted.
  //
  // The drift these pin actually happened: #6046 derived the publish backstop
  // from a 12s Keycast per-RPC bound, #6075 raised that bound to 30s without
  // re-deriving it, and the cap silently became smaller than the chain it
  // bounds.
  //
  // Only the first assertion is a regression test — replaying the pre-fix
  // constants (90s backstop, 140s honest chain) turns it red and the other two
  // stay green. The second and third guard the two ways this could break next:
  // tightening the build bound below the transport (the #6046 mistake), and
  // letting the sweep guard fall to or below the backstop.
  group('DM send budget invariants', () {
    test('the backstop exceeds the chain it bounds', () {
      expect(
        DmSendBudget.chainWorstCase,
        lessThan(DmSendBudget.messagePublishTimeout),
        reason:
            'a backstop below its own worst case fires mid-send and '
            'misclassifies an already-delivered message',
      );
    });

    test('the bounded signer floor matches two Keycast round trips', () {
      // A 1:1 send costs four measured signer round trips: nip44Encrypt +
      // signEvent for the seal, per wrap. Sizing the recipient build below
      // two transport bounds would fail requests the transport itself would
      // have allowed — the #6046 mistake that #6075 had to revert.
      //
      // Strictly greater, not >=: the bound also covers the seal
      // construction, ephemeral keypair, NIP-44 encryption and wrap signature
      // that run alongside those round trips. At exactly 2x, two ops each
      // returning just inside the transport bound would still trip it, which
      // is the same no-margin shape #6586 was about.
      //
      // This is the only place the two packages meet: `dm_repository` restates
      // the transport bound as a literal because it cannot import
      // `keycast_flutter`, so re-tuning one side without the other fails here
      // rather than silently under-sizing the build. #7092 moved the transport
      // bound 30s → 20s, dropping the floor 65s → 45s while
      // `recipientWrapBuild` deliberately held at 65s, so its margin over the
      // floor widened from 0s to 20s.
      expect(
        DmSendBudget.boundedSignerFloor,
        KeycastRpc.defaultRequestTimeout * 2 + const Duration(seconds: 5),
      );
      expect(
        DmSendBudget.recipientWrapBuild,
        greaterThan(DmSendBudget.boundedSignerFloor),
      );
    });

    test('the sweep guard outlives the whole backstop', () {
      // `Future.timeout` does not cancel, so an abandoned send keeps running
      // past the cap. A guard at or below it re-drives a rumor that is still
      // in flight and publishes a concurrent duplicate.
      expect(
        OutgoingDmRetryService.interruptedMinAge,
        greaterThan(DmSendBudget.messagePublishTimeout),
      );
    });
  });
}
