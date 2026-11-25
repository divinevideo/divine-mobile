// ABOUTME: recoverFullSend leaves rows it does not own alone: another relay
// ABOUTME: environment's, and the old account's after a switch mid-retry.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

import 'support/share_delivery_harness.dart';

/// Holds the first acceptance mark, which a recovered send writes inside its
/// persist transaction, until the test lets it through.
class _HeldAcceptanceMark extends DirectMessagesDao {
  _HeldAcceptanceMark(super.attachedDatabase);

  final reached = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> markRecipientAccepted({
    required String ownerPubkey,
    required String rumorId,
    required String environment,
  }) async {
    if (!reached.isCompleted) {
      reached.complete();
      await resume.future;
    }
    return super.markRecipientAccepted(
      ownerPubkey: ownerPubkey,
      rumorId: rumorId,
      environment: environment,
    );
  }
}

void main() {
  setUpAll(registerShareHarnessFallbacks);

  final owner = ShareDeliveryHarness.owner;
  final recipient = ShareDeliveryHarness.recipient;
  late ShareDeliveryHarness harness;

  setUp(() => harness = ShareDeliveryHarness());

  tearDown(() async {
    await harness.dispose();
    // LogCaptureService is process-global; later suites must not read these.
    await LogCaptureService().clearAllLogs();
  });

  void verifyNothingPublished() => verifyNever(
    () => harness.client.publishEventAwaitOk(
      any(),
      targetRelays: any(named: 'targetRelays'),
      timeout: any(named: 'timeout'),
      diagnosticTag: any(named: 'diagnosticTag'),
    ),
  );

  Future<DirectMessageRow?> storedMessage(String rumorId) =>
      DirectMessagesDao(harness.db).getMessageById(rumorId, ownerPubkey: owner);

  group('recoverFullSend', () {
    test('leaves a row queued in another environment untouched', () async {
      final service = NIP17MessageService(
        signer: LocalNostrSigner(ShareDeliveryHarness.ownerKey),
        senderPublicKey: owner,
        nostrService: harness.client,
      );
      final rumor = service.buildRumor(
        recipientPubkey: recipient,
        content: 'queued on production',
      );
      await harness.queue.enqueue(
        OutgoingDm(
          id: rumor.id,
          conversationId: DmRepository.computeConversationId(
            [owner, recipient]..sort(),
          ),
          recipientPubkey: recipient,
          content: 'queued on production',
          createdAt: rumor.createdAt,
          rumorEventJson: jsonEncode(rumor.toJson()),
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.utc(2026, 11, 25),
          ownerPubkey: owner,
          environment: 'production',
        ),
      );
      final staging = harness.build();

      final result = await staging.recoverFullSend(rumorId: rumor.id);

      expect(result.retryablePending, isTrue);
      expect(result.queuedRumorId, rumor.id);
      final row = (await harness.queue.getById(rumor.id))!;
      expect(row.environment, 'production');
      expect(row.recipientWrapStatus, OutgoingWrapStatus.pending);
      expect(row.selfWrapStatus, OutgoingWrapStatus.pending);
      expect(row.retryCount, 0);
      expect(row.lastAttemptAt, isNull);
      expect(row.recipientWrapLastError, isNull);
      verifyNothingPublished();
    });

    test('an account change while the retry waits for its OK writes nothing '
        "for the old account's send", () async {
      final rumorId = await harness.parkShare(recipient);
      final retrying = harness.build();
      final publishing = Completer<void>();
      final answer = Completer<void>();
      harness.holdRecipientPublish = () {
        publishing.complete();
        return answer.future;
      };

      final attempt = retrying.recoverFullSend(rumorId: rumorId);
      await publishing.future;
      harness.switchAccount(retrying);
      answer.complete();
      final result = await attempt;

      // The relay took the wrap, but the old account's session is over.
      expect(harness.recipientPublishes, hasLength(1));
      expect(result.retryablePending, isTrue);
      expect(result.queuedRumorId, rumorId);
      final row = (await harness.queue.getById(rumorId))!;
      expect(row.ownerPubkey, owner);
      expect(row.recipientWrapStatus, OutgoingWrapStatus.pending);
      expect(row.retryCount, 0);
      expect(await storedMessage(rumorId), isNull);
    });

    test('an account change inside the persist transaction rolls it back and '
        'logs the rollback, not a persist failure', () async {
      final messages = _HeldAcceptanceMark(harness.db);
      final rumorId = await harness.parkShare(recipient);
      final retrying = harness.build(messages: messages);
      await LogCaptureService().clearAllLogs();

      final attempt = retrying.recoverFullSend(rumorId: rumorId);
      // The message is written and the outbox row about to be finalized.
      await messages.reached.future;
      harness.switchAccount(retrying);
      messages.resume.complete();
      await attempt;

      final row = (await harness.queue.getById(rumorId))!;
      expect(row.ownerPubkey, owner);
      expect(row.recipientWrapStatus, OutgoingWrapStatus.pending);
      // Not charged: the old account may still deliver it in its own session.
      expect(row.retryCount, 0);
      expect(await storedMessage(rumorId), isNull);
      final lines = LogCaptureService()
          .getRecentLogs()
          .map((entry) => entry.message)
          .toList();
      expect(
        lines,
        contains(startsWith('Recovered send for $rumorId was rolled back')),
      );
      expect(
        lines.where(
          (line) => line.startsWith('Failed to persist recovered send locally'),
        ),
        isEmpty,
      );
    });
  });
}
