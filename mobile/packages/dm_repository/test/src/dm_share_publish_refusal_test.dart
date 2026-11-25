// ABOUTME: A block or account change that lands while a share is being signed
// ABOUTME: stops its publish, on the first delivery and on a retry alike.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;

import 'support/share_delivery_harness.dart';

void main() {
  setUpAll(registerShareHarnessFallbacks);

  final recipient = ShareDeliveryHarness.recipient;
  late ShareDeliveryHarness harness;
  late Set<String> hidden;

  setUp(() {
    harness = ShareDeliveryHarness();
    hidden = {};
  });

  tearDown(() => harness.dispose());

  void verifyNothingPublished() {
    verifyNever(
      () => harness.client.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
        diagnosticTag: any(named: 'diagnosticTag'),
      ),
    );
    verifyNever(
      () => harness.client.publishEvent(
        any(),
        targetRelays: any(named: 'targetRelays'),
      ),
    );
  }

  Future<OutgoingDm> rowOf(String rumorId) async =>
      (await harness.queue.getById(rumorId))!;

  // The connectivity probe runs inside sendRumor after the enqueue-time and
  // retry-time eligibility checks and before the gift wrap is built, so
  // whatever happens in it happens while the signer is busy.

  group('enqueueSharedVideoBatch', () {
    /// Shares with [recipient] and joins the first delivery, which runs
    /// [duringProbe] and then waits in the probe until the join is in place.
    Future<(String, NIP17SendResult)> shareInterruptedBy(
      void Function(DmRepository repository) duringProbe,
    ) async {
      late final DmRepository repository;
      final probed = Completer<void>();
      final resume = Completer<bool>();
      repository = harness.build(
        isHidden: hidden.contains,
        isOffline: () {
          if (!probed.isCompleted) {
            duringProbe(repository);
            probed.complete();
          }
          return resume.future;
        },
      );
      final outcomes = await harness.share(repository, [recipient]);
      final rumorId = (outcomes[recipient]! as ShareEnqueueQueued).rumorId;
      await probed.future;
      // The first delivery holds the rumor's recovery key, so this joins it.
      final attempt = repository.recoverFullSend(rumorId: rumorId);
      resume.complete(false);
      return (rumorId, await attempt);
    }

    test('delivers a share nobody blocks while it is signed', () async {
      final (_, result) = await shareInterruptedBy((_) {});

      expect(result.success, isTrue);
      expect(harness.recipientPublishes, hasLength(1));
    });

    test('a block that lands while the share is signed leaves it blocked '
        'and unpublished', () async {
      final (rumorId, result) = await shareInterruptedBy(
        (_) => hidden.add(recipient),
      );

      expect(result.blocked, isTrue);
      expect(
        (await rowOf(rumorId)).recipientWrapStatus,
        OutgoingWrapStatus.blocked,
      );
      verifyNothingPublished();
    });

    test('an account change while the share is signed publishes nothing '
        'and keeps it queued', () async {
      final (rumorId, result) = await shareInterruptedBy(
        harness.switchAccount,
      );

      expect(result.retryablePending, isTrue);
      expect(result.queuedRumorId, rumorId);
      final row = await rowOf(rumorId);
      expect(row.ownerPubkey, ShareDeliveryHarness.owner);
      expect(row.recipientWrapStatus, OutgoingWrapStatus.pending);
      verifyNothingPublished();
    });
  });

  group('recoverFullSend', () {
    /// Retries a parked share with [recipient] on a fresh repository whose
    /// probe runs [duringProbe].
    Future<(String, NIP17SendResult)> retryInterruptedBy(
      void Function(DmRepository repository) duringProbe,
    ) async {
      final rumorId = await harness.parkShare(recipient);
      late final DmRepository retrying;
      retrying = harness.build(
        isHidden: hidden.contains,
        isOffline: () async {
          duringProbe(retrying);
          return false;
        },
      );
      return (rumorId, await retrying.recoverFullSend(rumorId: rumorId));
    }

    test('delivers a retried share nobody blocks while it is signed', () async {
      final (_, result) = await retryInterruptedBy((_) {});

      expect(result.success, isTrue);
      expect(harness.recipientPublishes, hasLength(1));
    });

    test('a block that lands while a retried share is signed leaves it '
        'blocked and unpublished', () async {
      final (rumorId, result) = await retryInterruptedBy(
        (_) => hidden.add(recipient),
      );

      expect(result.blocked, isTrue);
      expect(
        (await rowOf(rumorId)).recipientWrapStatus,
        OutgoingWrapStatus.blocked,
      );
      verifyNothingPublished();
    });

    test('an account change while a retried share is signed publishes '
        'nothing and keeps it queued', () async {
      final (rumorId, result) = await retryInterruptedBy(
        harness.switchAccount,
      );

      expect(result.retryablePending, isTrue);
      expect(result.queuedRumorId, rumorId);
      final row = await rowOf(rumorId);
      expect(row.ownerPubkey, ShareDeliveryHarness.owner);
      expect(row.recipientWrapStatus, OutgoingWrapStatus.pending);
      expect(row.retryCount, 0);
      verifyNothingPublished();
    });
  });
}
