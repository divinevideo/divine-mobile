// ABOUTME: Unit tests for DmReactionRetryService — pinned contracts:
// ABOUTME: re-drives failed/interrupted own reactions via retry(), skips when
// ABOUTME: the repo isn't initialized, holds back too-young pending reactions,
// ABOUTME: applies backoff, and stops after maxRetries.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
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
}) => DmReactionRetryTarget(
  rumorId: rumorId,
  targetMessageAuthor: _authorPubkey,
  publishStatus: publishStatus,
  createdAt: createdAt,
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

  setUp(() {
    repository = _MockDmReactionsRepository();
    foregroundController = StreamController<bool>.broadcast();

    // Permissive defaults; each test overrides what it cares about.
    when(() => repository.isInitialized).thenReturn(true);
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
  });

  tearDown(() async {
    await foregroundController.close();
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
  });
}
