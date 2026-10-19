// ABOUTME: Unit tests for DmReactionRetryService — pinned contracts:
// ABOUTME: re-drives failed/interrupted own reactions via retry(), skips when
// ABOUTME: the repo isn't initialized, holds back too-young pending reactions,
// ABOUTME: applies backoff, and stops after maxRetries.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/dm_reaction_retry_service.dart';

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

const _authorPubkey =
    '0000000000000000000000000000000000000000000000000000000000000099';

DmReactionRetryTarget _target({
  required String rumorId,
  String publishStatus = 'failed',
  int createdAt = 1700000000,
  bool retriesRanOut = false,
}) => DmReactionRetryTarget(
  rumorId: rumorId,
  targetMessageAuthor: _authorPubkey,
  publishStatus: publishStatus,
  createdAt: createdAt,
  retriesRanOut: retriesRanOut,
);

DmReactionPublishResult _ok(String id) =>
    DmReactionPublishResult(success: true, rumorId: id);

DmReactionPublishResult _fail(String id) => DmReactionPublishResult(
  success: false,
  rumorId: id,
  errorMessage: 'relay down',
);

void main() {
  late _MockDmReactionsRepository repository;
  late StreamController<bool> foregroundController;
  late StreamController<void> retryableWorkController;

  setUp(() {
    repository = _MockDmReactionsRepository();
    foregroundController = StreamController<bool>.broadcast();
    retryableWorkController = StreamController<void>.broadcast();

    // Permissive defaults; each test overrides what it cares about.
    when(() => repository.isInitialized).thenReturn(true);
    when(
      () => repository.retryableReactionWork,
    ).thenAnswer((_) => retryableWorkController.stream);
    when(
      repository.retryableReactions,
    ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
    when(
      repository.retryableDeletions,
    ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
    when(
      () => repository.retry(
        rumorId: any(named: 'rumorId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
      ),
    ).thenAnswer((_) async => _ok('r'));
    when(
      () => repository.retryDeletion(
        rumorId: any(named: 'rumorId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
      ),
    ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);
    when(
      () => repository.markDeletionUnconfirmed(
        rumorId: any(named: 'rumorId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.markReactionUnconfirmed(
        rumorId: any(named: 'rumorId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.isAttemptInFlight(
        any(),
        removal: any(named: 'removal'),
      ),
    ).thenReturn(false);
  });

  tearDown(() async {
    await foregroundController.close();
    await retryableWorkController.close();
  });

  DmReactionRetryService buildService({
    DmReactionRetryConfig retryConfig = const DmReactionRetryConfig(),
    DateTime Function()? now,
    Stream<void>? retryTriggerStream,
    OfflineProbe? isOffline,
  }) {
    return DmReactionRetryService(
      crashReporting: CrashReportingService(),
      reactionsRepository: repository,
      appForegroundStream: foregroundController.stream,
      retryTriggerStream: retryTriggerStream,
      isOffline: isOffline,
      retryConfig: retryConfig,
      now: now ?? () => DateTime.utc(2026, 5, 10, 12),
    );
  }

  group(DmReactionRetryService, () {
    test(
      'offline sweeps do not charge a pending removal its retry budget',
      () async {
        // #7319. retryDeletion would hit NIP17MessageService's offline
        // fail-fast and return a plain (non-blocked) failure, which
        // _driveTargets charges unconditionally. maxRetries foreground
        // transitions in airplane mode therefore exhausted the row, and the
        // sweep skipped it for the rest of the process — so the kind-5 never
        // published even after the network returned. The removal is
        // invisible in the thread (watchForConversation filters
        // is_deleted = 1), so unlike the add path there is no chip to re-tap.
        const rumorId = 'deletion-offline';
        var offline = true;
        var clock = DateTime.utc(2026, 5, 10, 12);

        when(
          repository.retryableDeletions,
        ).thenAnswer((_) async => [_target(rumorId: rumorId)]);

        final service = buildService(
          now: () => clock,
          isOffline: () async => offline,
        );

        // Burn more passes than the budget allows, advancing well past the
        // backoff each time so nothing is skipped for being too young.
        const config = DmReactionRetryConfig();
        for (var i = 0; i < config.maxRetries + 1; i++) {
          await service.sweep();
          clock = clock.add(const Duration(minutes: 5));
        }

        verifyNever(
          () => repository.retryDeletion(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );

        // The budget survived the offline session: the row is still driven
        // once the network returns.
        offline = false;
        await service.sweep();

        verify(
          () => repository.retryDeletion(
            rumorId: rumorId,
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);

        await service.dispose();
      },
    );

    test('a throwing offline probe is treated as online', () async {
      // A broken probe must never disable retries outright.
      const rumorId = 'deletion-probe-throws';
      when(
        repository.retryableDeletions,
      ).thenAnswer((_) async => [_target(rumorId: rumorId)]);

      final service = buildService(
        isOffline: () async => throw StateError('probe exploded'),
      );

      await service.sweep();

      verify(
        () => repository.retryDeletion(
          rumorId: rumorId,
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);

      await service.dispose();
    });

    test(
      'initialize subscribes to the foreground stream, dispose cancels',
      () async {
        final service = buildService();
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(foregroundController.hasListener, isTrue);

        await service.dispose();
        expect(service.isInitialized, isFalse);
        expect(foregroundController.hasListener, isFalse);
      },
    );

    test('a foreground transition to true triggers a sweep', () async {
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      final service = buildService();
      await service.initialize();
      foregroundController.add(true);
      // Let the async sweep run.
      await pumpEventQueue();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
      await service.dispose();
    });

    test('re-drives a failed reaction via retry', () async {
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      await buildService().sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test('does nothing when the repository is not initialized', () async {
      when(() => repository.isInitialized).thenReturn(false);

      await buildService().sweep();

      verifyNever(repository.retryableReactions);
      verifyNever(
        () => repository.retry(
          rumorId: any(named: 'rumorId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
        ),
      );
    });

    test(
      'holds back a pending reaction younger than the min-age guard',
      () async {
        final now = DateTime.utc(2026, 5, 10, 12);
        final youngCreatedAt =
            now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
            1000;
        when(repository.retryableReactions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'r1',
              publishStatus: 'pending',
              createdAt: youngCreatedAt,
            ),
          ],
        );

        await buildService(now: () => now).sweep();

        verifyNever(
          () => repository.retry(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );
      },
    );

    test('re-drives a pending reaction older than the min-age guard', () async {
      final now = DateTime.utc(2026, 5, 10, 12);
      final oldCreatedAt =
          now.subtract(const Duration(seconds: 60)).millisecondsSinceEpoch ~/
          1000;
      when(repository.retryableReactions).thenAnswer(
        (_) async => [
          _target(
            rumorId: 'r1',
            publishStatus: 'pending',
            createdAt: oldCreatedAt,
          ),
        ],
      );
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      await buildService(now: () => now).sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test(
      'skips a just-failed reaction while inside the backoff window',
      () async {
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));

        // now is fixed, so the second sweep is inside the backoff window.
        final service = buildService();
        await service.sweep();
        await service.sweep();

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test('stops re-driving a reaction after maxRetries', () async {
      var clock = DateTime.utc(2026, 5, 10, 12);
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _fail('r1'));

      final service = buildService(
        retryConfig: const DmReactionRetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 1),
        ),
        now: () => clock,
      );

      // Three sweeps, each past the (tiny) backoff window — only the first two
      // attempt a retry; the third is dropped as exhausted.
      await service.sweep();
      clock = clock.add(const Duration(seconds: 10));
      await service.sweep();
      clock = clock.add(const Duration(seconds: 10));
      await service.sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(2);
    });

    test(
      'a sweep already in progress short-circuits the next trigger',
      () async {
        final gate = Completer<DmReactionPublishResult>();
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) => gate.future);

        final service = buildService();
        final first = service.sweep();
        // Let the first sweep reach the awaiting retry() call.
        await pumpEventQueue();
        // Second sweep sees _isSweeping and returns immediately.
        await service.sweep();

        gate.complete(_ok('r1'));
        await first;

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test('a retry-trigger event (reconnect) triggers a sweep', () async {
      final triggerController = StreamController<void>.broadcast();
      addTearDown(triggerController.close);
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);

      final service = buildService(
        retryTriggerStream: triggerController.stream,
      );
      await service.initialize();
      triggerController.add(null);
      await pumpEventQueue();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
      await service.dispose();
    });

    test('re-drives a pending removal via retryDeletion', () async {
      when(repository.retryableDeletions).thenAnswer(
        (_) async => [
          _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
        ],
      );
      when(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);

      await buildService().sweep();

      verify(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test('a refused removal does not consume the retry budget', () async {
      when(repository.retryableDeletions).thenAnswer(
        (_) async => [
          _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
        ],
      );
      when(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => DmReactionDeletionOutcome.refused);

      final service = buildService(
        retryConfig: const DmReactionRetryConfig(maxRetries: 1),
      );
      await service.sweep();
      await service.sweep();

      verify(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(2);
    });

    test(
      'a removal is re-driven regardless of the pending min-age guard',
      () async {
        final now = DateTime.utc(2026, 5, 10, 12);
        final youngCreatedAt =
            now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
            1000;
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'd1',
              publishStatus: 'deletion_pending',
              createdAt: youngCreatedAt,
            ),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);

        await buildService(now: () => now).sweep();

        // Unlike an add, a 'deletion_pending' row is never in-flight for the
        // sweep, so the min-age guard must not hold it back.
        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'add-phase retry exhaustion does NOT starve the later removal — the '
      'attempt budget is namespaced per phase (add vs del) even though the '
      'row keeps its rumor id across the failed -> deletion_pending flip',
      () async {
        var clock = DateTime.utc(2026, 5, 10, 12);

        // Phase 1: the reaction fails its full add-retry budget.
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'x1')]);
        when(
          () => repository.retry(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('x1'));

        final service = buildService(
          retryConfig: const DmReactionRetryConfig(
            maxRetries: 2,
            initialDelay: Duration(milliseconds: 1),
          ),
          now: () => clock,
        );

        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep(); // third add attempt dropped as exhausted

        verify(
          () => repository.retry(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(2);

        // Phase 2: the user removes that reaction. The row keeps rumor id
        // 'x1' but is now a 'deletion_pending' removal. Its kind-5 must
        // re-drive with a FRESH budget — a bare-id budget would inherit the
        // exhausted add count and skip the removal for the rest of the
        // session, leaving the counterparty with a reaction you removed.
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(rumorId: 'x1', publishStatus: 'deletion_pending'),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);

        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verify(
          () => repository.retryDeletion(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    group('a removal whose retry budget runs out (#8390)', () {
      const twoAttempts = DmReactionRetryConfig(
        maxRetries: 2,
        initialDelay: Duration(milliseconds: 1),
      );

      void stubPendingRemoval() {
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
          ],
        );
      }

      void stubRemovalOutcome(DmReactionDeletionOutcome outcome) {
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => outcome);
      }

      test('is marked unconfirmed after its last attempt fails, not '
          'before', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPendingRemoval();
        stubRemovalOutcome(DmReactionDeletionOutcome.unconfirmed);
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        verifyNever(
          () => repository.markDeletionUnconfirmed(rumorId: 'd1'),
        );

        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        verify(
          () => repository.markDeletionUnconfirmed(rumorId: 'd1'),
        ).called(1);

        // Later passes skip the spent row without marking it again.
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        verifyNever(
          () => repository.markDeletionUnconfirmed(rumorId: 'd1'),
        );
        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(2);
      });

      test('is marked unconfirmed when its last attempt throws', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPendingRemoval();
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenThrow(StateError('signer gone'));
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verify(
          () => repository.markDeletionUnconfirmed(rumorId: 'd1'),
        ).called(1);
      });

      test('is not marked when the removal is delivered on its last '
          'attempt', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPendingRemoval();
        stubRemovalOutcome(DmReactionDeletionOutcome.unconfirmed);
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        stubRemovalOutcome(DmReactionDeletionOutcome.sent);
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verifyNever(
          () => repository.markDeletionUnconfirmed(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });

      test('is not marked when send policy refuses it', () async {
        stubPendingRemoval();
        stubRemovalOutcome(DmReactionDeletionOutcome.refused);

        // One attempt is the whole budget, so a refusal charged like a
        // failure would mark it here.
        await buildService(
          retryConfig: const DmReactionRetryConfig(maxRetries: 1),
        ).sweep();

        verifyNever(
          () => repository.markDeletionUnconfirmed(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });

      test('marks a reaction whose own budget ran out as a reaction, not a '
          'removal', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(2);
        verify(
          () => repository.markReactionUnconfirmed(rumorId: 'r1'),
        ).called(1);
        verifyNever(
          () => repository.markDeletionUnconfirmed(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });

      test(
        'a failure to mark it does not stop the removals after it',
        () async {
          when(repository.retryableDeletions).thenAnswer(
            (_) async => [
              _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
              _target(rumorId: 'd2', publishStatus: 'deletion_pending'),
            ],
          );
          when(
            () => repository.retryDeletion(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: _authorPubkey,
            ),
          ).thenAnswer((_) async => DmReactionDeletionOutcome.unconfirmed);
          when(
            () => repository.markDeletionUnconfirmed(rumorId: 'd1'),
          ).thenThrow(StateError('database closed'));

          await buildService(
            retryConfig: const DmReactionRetryConfig(maxRetries: 1),
          ).sweep();

          verify(
            () => repository.retryDeletion(
              rumorId: 'd2',
              targetMessageAuthor: _authorPubkey,
            ),
          ).called(1);
          verify(
            () => repository.markDeletionUnconfirmed(rumorId: 'd2'),
          ).called(1);
        },
      );
    });

    group('a reaction whose retry budget runs out (#8516)', () {
      const twoAttempts = DmReactionRetryConfig(
        maxRetries: 2,
        initialDelay: Duration(milliseconds: 1),
      );

      void stubPendingReaction(String id) {
        when(repository.retryableReactions).thenAnswer(
          (_) async => [
            _target(rumorId: id, publishStatus: 'pending', createdAt: 0),
          ],
        );
      }

      test('is marked unconfirmed after its last attempt fails, not '
          'before', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPendingReaction('r1');
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        verifyNever(
          () => repository.markReactionUnconfirmed(rumorId: 'r1'),
        );

        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        verify(
          () => repository.markReactionUnconfirmed(rumorId: 'r1'),
        ).called(1);

        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        verifyNever(
          () => repository.markReactionUnconfirmed(rumorId: 'r1'),
        );
      });

      test('is not marked when it is delivered on its last attempt', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        stubPendingReaction('r1');
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _ok('r1'));
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verifyNever(
          () => repository.markReactionUnconfirmed(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });

      test(
        'a failure to mark it does not stop the reactions after it',
        () async {
          when(repository.retryableReactions).thenAnswer(
            (_) async => [_target(rumorId: 'r1'), _target(rumorId: 'r2')],
          );
          when(
            () => repository.retry(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: _authorPubkey,
            ),
          ).thenAnswer((_) async => _fail('r'));
          when(
            () => repository.markReactionUnconfirmed(rumorId: 'r1'),
          ).thenThrow(StateError('database closed'));

          await buildService(
            retryConfig: const DmReactionRetryConfig(maxRetries: 1),
          ).sweep();

          verify(
            () => repository.retry(
              rumorId: 'r2',
              targetMessageAuthor: _authorPubkey,
            ),
          ).called(1);
          verify(
            () => repository.markReactionUnconfirmed(rumorId: 'r2'),
          ).called(1);
        },
      );
    });

    group('a row whose retries ran out in an earlier session (#8516)', () {
      test('gets one automatic try, not a full set, as a reaction', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(repository.retryableReactions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'r1',
              publishStatus: 'unconfirmed',
              retriesRanOut: true,
            ),
          ],
        );
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));
        final service = buildService(now: () => clock);

        for (var pass = 0; pass < 3; pass++) {
          await service.sweep();
          clock = clock.add(const Duration(minutes: 10));
        }

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
        verify(
          () => repository.markReactionUnconfirmed(rumorId: 'r1'),
        ).called(1);
      });

      test('gets one automatic try, not a full set, as a removal', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'd1',
              publishStatus: 'deletion_unconfirmed',
              retriesRanOut: true,
            ),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => DmReactionDeletionOutcome.unconfirmed);
        final service = buildService(now: () => clock);

        for (var pass = 0; pass < 3; pass++) {
          await service.sweep();
          clock = clock.add(const Duration(minutes: 10));
        }

        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      });

      test('a try that reached no relay leaves it its one try', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(repository.retryableReactions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'r1',
              publishStatus: 'unconfirmed',
              retriesRanOut: true,
            ),
          ],
        );
        var calls = 0;
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer(
          (_) async => DmReactionPublishResult(
            success: false,
            rumorId: 'r1',
            reachedNoRelay: calls++ == 0,
          ),
        );
        final service = buildService(now: () => clock);

        for (var pass = 0; pass < 3; pass++) {
          await service.sweep();
          clock = clock.add(const Duration(minutes: 10));
        }

        expect(calls, 2);
      });
    });

    group('a pass that reached no relay (#8516)', () {
      const twoAttempts = DmReactionRetryConfig(
        maxRetries: 2,
        initialDelay: Duration(milliseconds: 1),
      );

      test('does not use up a reaction retry', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: false,
            rumorId: 'r1',
            reachedNoRelay: true,
          ),
        );
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        for (var pass = 0; pass < 4; pass++) {
          await service.sweep();
          clock = clock.add(const Duration(seconds: 10));
        }

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(4);
      });

      test('does not use up a removal retry', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => DmReactionDeletionOutcome.notSent);
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        for (var pass = 0; pass < 4; pass++) {
          await service.sweep();
          clock = clock.add(const Duration(seconds: 10));
        }

        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(4);
        verifyNever(
          () => repository.markDeletionUnconfirmed(
            rumorId: any(named: 'rumorId'),
          ),
        );
      });

      test('arms no heartbeat for it', () {
        fakeAsync((async) {
          when(repository.retryableDeletions).thenAnswer(
            (_) async => [
              _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
            ],
          );
          when(
            () => repository.retryDeletion(
              rumorId: 'd1',
              targetMessageAuthor: _authorPubkey,
            ),
          ).thenAnswer((_) async => DmReactionDeletionOutcome.notSent);
          final service = buildService(
            now: async.getClock(DateTime.utc(2026, 10, 7, 12)).now,
          );
          unawaited(service.initialize());

          unawaited(service.sweep());
          async.flushMicrotasks();

          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'a relay connecting wakes it, not the 30-second follow-up',
          );
          unawaited(service.dispose());
          async.flushMicrotasks();
        });
      });
    });

    group('a row whose own attempt is still in flight (#10044)', () {
      const twoAttempts = DmReactionRetryConfig(
        maxRetries: 2,
        initialDelay: Duration(milliseconds: 1),
      );

      test('does not use up a removal retry', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        var inFlight = true;
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
          ],
        );
        when(
          () => repository.isAttemptInFlight('d1', removal: true),
        ).thenAnswer((_) => inFlight);
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => DmReactionDeletionOutcome.unconfirmed);
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        verifyNever(
          () => repository.retryDeletion(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );

        inFlight = false;
        for (var pass = 0; pass < 3; pass++) {
          clock = clock.add(const Duration(seconds: 10));
          await service.sweep();
        }

        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(twoAttempts.maxRetries);
      });

      test('does not use up a reaction retry', () async {
        var clock = DateTime.utc(2026, 5, 10, 12);
        var inFlight = true;
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.isAttemptInFlight('r1', removal: false),
        ).thenAnswer((_) => inFlight);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));
        final service = buildService(
          retryConfig: twoAttempts,
          now: () => clock,
        );

        await service.sweep();
        verifyNever(
          () => repository.retry(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );

        inFlight = false;
        for (var pass = 0; pass < 3; pass++) {
          clock = clock.add(const Duration(seconds: 10));
          await service.sweep();
        }

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(twoAttempts.maxRetries);
      });

      test('is checked when the row is driven, not when it was listed, so '
          'an attempt started mid-pass is not joined', () async {
        var r2InFlight = false;
        when(repository.retryableReactions).thenAnswer(
          (_) async => [_target(rumorId: 'r1'), _target(rumorId: 'r2')],
        );
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async {
          // The person taps Retry on r2 while the pass is busy with r1.
          r2InFlight = true;
          return _fail('r1');
        });
        when(
          () => repository.isAttemptInFlight('r2', removal: false),
        ).thenAnswer((_) => r2InFlight);

        await buildService().sweep();

        verifyNever(
          () => repository.retry(
            rumorId: 'r2',
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );
      });

      test('keeps the heartbeat armed for it', () {
        fakeAsync((async) {
          when(repository.retryableDeletions).thenAnswer(
            (_) async => [
              _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
            ],
          );
          when(
            () => repository.isAttemptInFlight('d1', removal: true),
          ).thenReturn(true);
          final service = buildService(
            now: async.getClock(DateTime.utc(2026, 10, 7, 12)).now,
          );
          unawaited(service.initialize());

          unawaited(service.sweep());
          async.flushMicrotasks();

          expect(async.pendingTimers, hasLength(1));
          unawaited(service.dispose());
          async.flushMicrotasks();
        });
      });
    });

    group('follow-up heartbeat (#7327)', () {
      final start = DateTime.utc(2026, 10, 7, 12);
      const gap = Duration(seconds: 30);

      /// Builds the service on the fake clock of [async] and runs the
      /// cold-start foreground sweep, the one trigger a stable session gets.
      DmReactionRetryService startService(
        FakeAsync async, {
        DmReactionRetryConfig retryConfig = const DmReactionRetryConfig(),
        OfflineProbe? isOffline,
      }) {
        final service = buildService(
          now: async.getClock(start).now,
          retryConfig: retryConfig,
          isOffline: isOffline,
        );
        unawaited(service.initialize());
        foregroundController.add(true);
        async.flushMicrotasks();
        return service;
      }

      test(
        're-drives a soft-failed reaction without a foreground or connectivity '
        'event, then goes quiet once it is delivered',
        () {
          fakeAsync((async) {
            var attempts = 0;
            when(repository.retryableReactions).thenAnswer(
              (_) async => attempts >= 2
                  ? const <DmReactionRetryTarget>[]
                  : [_target(rumorId: 'r1', publishStatus: 'pending')],
            );
            when(
              () => repository.retry(
                rumorId: 'r1',
                targetMessageAuthor: _authorPubkey,
              ),
            ).thenAnswer((_) async {
              attempts++;
              return attempts == 1 ? _fail('r1') : _ok('r1');
            });

            final service = startService(async);
            expect(attempts, 1);
            expect(
              async.pendingTimers,
              hasLength(1),
              reason: 'a pass that leaves work behind arms the heartbeat',
            );

            async.elapse(gap);

            expect(attempts, 2);
            expect(
              async.pendingTimers,
              isEmpty,
              reason: 'a drained queue arms no further pass',
            );
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        're-drives an unconfirmed removal without a foreground or '
        'connectivity event',
        () {
          fakeAsync((async) {
            var attempts = 0;
            when(repository.retryableDeletions).thenAnswer(
              (_) async => attempts >= 2
                  ? const <DmReactionRetryTarget>[]
                  : [_target(rumorId: 'd1', publishStatus: 'deletion_pending')],
            );
            when(
              () => repository.retryDeletion(
                rumorId: 'd1',
                targetMessageAuthor: _authorPubkey,
              ),
            ).thenAnswer((_) async {
              attempts++;
              return attempts == 1
                  ? DmReactionDeletionOutcome.unconfirmed
                  : DmReactionDeletionOutcome.sent;
            });

            final service = startService(async);
            expect(attempts, 1);
            expect(async.pendingTimers, hasLength(1));

            async.elapse(gap);

            expect(attempts, 2);
            expect(async.pendingTimers, isEmpty);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        're-drives a pending reaction that was too young for the first pass '
        'once it has aged past the guard',
        () {
          fakeAsync((async) {
            final createdAt =
                start
                    .subtract(const Duration(seconds: 5))
                    .millisecondsSinceEpoch ~/
                1000;
            var delivered = false;
            when(repository.retryableReactions).thenAnswer(
              (_) async => delivered
                  ? const <DmReactionRetryTarget>[]
                  : [
                      _target(
                        rumorId: 'r1',
                        publishStatus: 'pending',
                        createdAt: createdAt,
                      ),
                    ],
            );
            when(
              () => repository.retry(
                rumorId: 'r1',
                targetMessageAuthor: _authorPubkey,
              ),
            ).thenAnswer((_) async {
              delivered = true;
              return _ok('r1');
            });

            final service = startService(async);
            verifyNever(
              () => repository.retry(
                rumorId: any(named: 'rumorId'),
                targetMessageAuthor: any(named: 'targetMessageAuthor'),
              ),
            );
            expect(async.pendingTimers, hasLength(1));

            async.elapse(gap);

            expect(delivered, isTrue);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'stops once every row has spent its retry budget, so the budget is '
        'not extended',
        () {
          fakeAsync((async) {
            const maxRetries = 5;
            var attempts = 0;
            when(
              repository.retryableReactions,
            ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
            // This stub never nudges, so only the pass's own decision can arm
            // the heartbeat. The next test adds the nudge the real repository
            // sends.
            when(
              () => repository.retry(
                rumorId: 'r1',
                targetMessageAuthor: _authorPubkey,
              ),
            ).thenAnswer((_) async {
              attempts++;
              return _fail('r1');
            });

            final service = startService(async);
            // Step through the session until the last attempt the budget
            // allows has run.
            for (var i = 0; i < 600 && attempts < maxRetries; i++) {
              async.elapse(const Duration(seconds: 1));
            }

            expect(attempts, maxRetries);
            expect(
              async.pendingTimers,
              isEmpty,
              reason: 'the pass that spends the budget leaves nothing to retry',
            );
            async.elapse(const Duration(minutes: 10));
            expect(attempts, maxRetries);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'the nudge from the failure that spends the budget buys at most one '
        'more pass, and that pass attempts nothing',
        () {
          fakeAsync((async) {
            final maxRetries = const DmReactionRetryConfig().maxRetries;
            var attempts = 0;
            var passes = 0;
            when(repository.retryableReactions).thenAnswer((_) async {
              passes++;
              return [_target(rumorId: 'r1')];
            });
            when(
              () => repository.retry(
                rumorId: 'r1',
                targetMessageAuthor: _authorPubkey,
              ),
            ).thenAnswer((_) async {
              attempts++;
              // DmReactionsRepository.retry nudges on every failure it leaves
              // on the worklist, the one that spends the budget included. The
              // nudge lands mid-pass, so it arms a follow-up.
              retryableWorkController.add(null);
              return _fail('r1');
            });

            final service = startService(async);
            for (var i = 0; i < 600 && attempts < maxRetries; i++) {
              async.elapse(const Duration(seconds: 1));
            }
            expect(attempts, maxRetries);
            final passesWhenSpent = passes;

            async.elapse(const Duration(minutes: 10));

            expect(attempts, maxRetries);
            expect(passes - passesWhenSpent, lessThanOrEqualTo(1));
            expect(async.pendingTimers, isEmpty);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('arms nothing when no reaction or removal is retryable', () {
        fakeAsync((async) {
          final service = startService(async);

          expect(async.pendingTimers, isEmpty);
          unawaited(service.dispose());
          async.flushMicrotasks();
        });
      });

      test('arms nothing after a removal the send policy refused', () {
        fakeAsync((async) {
          when(repository.retryableDeletions).thenAnswer(
            (_) async => [
              _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
            ],
          );
          when(
            () => repository.retryDeletion(
              rumorId: 'd1',
              targetMessageAuthor: _authorPubkey,
            ),
          ).thenAnswer((_) async => DmReactionDeletionOutcome.refused);

          final service = startService(async);

          expect(async.pendingTimers, isEmpty);
          unawaited(service.dispose());
          async.flushMicrotasks();
        });
      });

      test(
        'arms nothing on an offline pass; the connectivity trigger owns that '
        'edge',
        () {
          fakeAsync((async) {
            when(
              repository.retryableReactions,
            ).thenAnswer((_) async => [_target(rumorId: 'r1')]);

            final service = startService(async, isOffline: () async => true);

            expect(async.pendingTimers, isEmpty);
            verifyNever(repository.retryableReactions);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a repository nudge arms the heartbeat when none is armed, and the '
        'pass it runs reads the repository',
        () {
          fakeAsync((async) {
            final service = buildService(now: async.getClock(start).now);
            unawaited(service.initialize());
            async.flushMicrotasks();
            expect(async.pendingTimers, isEmpty);

            retryableWorkController.add(null);
            async.flushMicrotasks();
            expect(async.pendingTimers, hasLength(1));
            verifyNever(repository.retryableReactions);

            async.elapse(gap);

            verify(repository.retryableReactions).called(1);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a burst of nudges does not postpone a heartbeat that is already '
        'armed',
        () {
          fakeAsync((async) {
            final service = buildService(now: async.getClock(start).now);
            unawaited(service.initialize());
            retryableWorkController.add(null);
            async.flushMicrotasks();

            async.elapse(const Duration(seconds: 20));
            retryableWorkController.add(null);
            async.flushMicrotasks();
            async.elapse(const Duration(seconds: 10));

            verify(repository.retryableReactions).called(1);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a nudge that lands during a pass still arms a follow-up, even when '
        'that pass saw no work',
        () {
          fakeAsync((async) {
            final listed = Completer<List<DmReactionRetryTarget>>();
            when(repository.retryableReactions)
                .thenAnswer((_) => listed.future);

            final service = startService(async);
            expect(service.isSweeping, isTrue);

            retryableWorkController.add(null);
            async.flushMicrotasks();
            listed.complete(const <DmReactionRetryTarget>[]);
            async.flushMicrotasks();

            expect(service.isSweeping, isFalse);
            expect(
              async.pendingTimers,
              hasLength(1),
              reason: 'the row this pass never listed must not strand',
            );
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a heartbeat that fires while another pass runs asks for a follow-up '
        'instead of being lost',
        () {
          fakeAsync((async) {
            final service = buildService(now: async.getClock(start).now);
            unawaited(service.initialize());
            retryableWorkController.add(null); // arm the heartbeat
            async.flushMicrotasks();

            final listed = Completer<List<DmReactionRetryTarget>>();
            when(repository.retryableReactions)
                .thenAnswer((_) => listed.future);
            foregroundController.add(true); // a pass is now in flight
            async.flushMicrotasks();
            expect(service.isSweeping, isTrue);

            async.elapse(gap); // the heartbeat fires into the running pass
            listed.complete(const <DmReactionRetryTarget>[]);
            async.flushMicrotasks();

            expect(async.pendingTimers, hasLength(1));
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('dispose cancels an armed heartbeat', () {
        fakeAsync((async) {
          final service = buildService(now: async.getClock(start).now);
          unawaited(service.initialize());
          retryableWorkController.add(null);
          async.flushMicrotasks();
          expect(async.pendingTimers, hasLength(1));

          unawaited(service.dispose());

          expect(async.pendingTimers, isEmpty);
          async.flushMicrotasks();
        });
      });

      test('dispose cancels the nudge subscription', () async {
        final service = buildService();
        await service.initialize();
        expect(retryableWorkController.hasListener, isTrue);

        await service.dispose();

        expect(retryableWorkController.hasListener, isFalse);
      });

      test(
        'keeps retrying a pass that throws, but only up to the retry budget '
        'so a persistent fault cannot loop',
        () {
          fakeAsync((async) {
            when(repository.retryableReactions)
                .thenThrow(StateError('db down'));

            final service = startService(async);
            async.elapse(const Duration(minutes: 10));

            verify(
              repository.retryableReactions,
            ).called(const DmReactionRetryConfig().maxRetries);
            expect(async.pendingTimers, isEmpty);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'a clean pass resets the fault count, so a later outage gets its '
        'full budget of follow-ups',
        () {
          fakeAsync((async) {
            var failing = true;
            var calls = 0;
            when(repository.retryableReactions).thenAnswer((_) async {
              calls++;
              if (failing) throw StateError('db down');
              return const <DmReactionRetryTarget>[];
            });

            final service = startService(async);
            async.elapse(gap * 2); // three faulting passes: 0s, 30s, 60s
            expect(calls, 3);

            failing = false;
            async.elapse(gap); // the fourth pass is clean and stops the chain
            expect(calls, 4);
            expect(async.pendingTimers, isEmpty);

            failing = true;
            foregroundController.add(true);
            async.flushMicrotasks();
            async.elapse(const Duration(minutes: 10));

            // A full budget again: 5 passes, not the 2 left from before.
            expect(calls, 4 + const DmReactionRetryConfig().maxRetries);
            unawaited(service.dispose());
            async.flushMicrotasks();
          });
        },
      );
    });
  });
}
