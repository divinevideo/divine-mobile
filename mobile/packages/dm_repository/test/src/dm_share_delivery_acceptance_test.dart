// ABOUTME: What watchDeliveryState reports for a share in a real relay
// ABOUTME: environment: accepted, queued while offline, cancelled off-account.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';

import 'support/share_delivery_harness.dart';

void main() {
  setUpAll(registerShareHarnessFallbacks);

  final owner = ShareDeliveryHarness.owner;
  final recipient = ShareDeliveryHarness.recipient;
  late ShareDeliveryHarness harness;

  setUp(() => harness = ShareDeliveryHarness());

  tearDown(() => harness.dispose());

  Future<DmDeliveryState> stateOf(DmRepository repository, String rumorId) =>
      repository.watchDeliveryState(ownerPubkey: owner, rumorId: rumorId).first;

  /// What the database itself reads for [rumorId] in staging, with no account
  /// or lifecycle check in front of it.
  Future<DmDeliveryState> storedStateOf(String rumorId) =>
      DirectMessagesDao(
            harness.db,
          )
          .watchDeliveryState(
            ownerPubkey: owner,
            rumorId: rumorId,
            environment: 'staging',
          )
          .first;

  Future<String?> acceptedEnvironmentOf(
    String rumorId,
  ) async => (await DirectMessagesDao(
    harness.db,
  ).getMessageById(rumorId, ownerPubkey: owner))?.recipientAcceptedEnvironment;

  group('enqueueSharedVideoBatch', () {
    test('a share the recipient route accepts reads accepted, recorded for '
        'this environment', () async {
      final repository = harness.build();
      final lookups = harness.inboxLookups = Completer<void>();
      final outcomes = await harness.share(repository, [recipient]);
      final rumorId = (outcomes[recipient]! as ShareEnqueueQueued).rumorId;
      // Joins the first delivery, held in its inbox lookup.
      final attempt = repository.recoverFullSend(rumorId: rumorId);
      lookups.complete();

      expect((await attempt).success, isTrue);

      // The outbox row is gone, so only the acceptance mark can say "sent".
      expect(await harness.queue.getById(rumorId), isNull);
      expect(await acceptedEnvironmentOf(rumorId), 'staging');
      expect(await stateOf(repository, rumorId), DmDeliveryState.accepted);
    });
  });

  group('recoverFullSend', () {
    test('a retried share the recipient route accepts reads accepted, '
        'recorded for this environment', () async {
      final rumorId = await harness.parkShare(recipient);
      final retrying = harness.build();

      expect(
        (await retrying.recoverFullSend(rumorId: rumorId)).success,
        isTrue,
      );

      expect(await harness.queue.getById(rumorId), isNull);
      expect(await acceptedEnvironmentOf(rumorId), 'staging');
      expect(await stateOf(retrying, rumorId), DmDeliveryState.accepted);
    });

    test('a retry no relay answers stays queued as offline', () async {
      // Our relays are connected, but the wrap reached none of them.
      harness.answerRecipient = (wrap, _) => PublishOutcome(
        eventId: wrap.id,
        acceptedBy: const [],
        rejectedBy: const {},
        noResponseFrom: const [],
      );
      final rumorId = await harness.parkShare(recipient);
      final retrying = harness.build();

      final result = await retrying.recoverFullSend(rumorId: rumorId);

      expect(result.reachedNoRelay, isTrue);
      final row = (await harness.queue.getById(rumorId))!;
      expect(row.recipientWrapStatus, OutgoingWrapStatus.failed);
      expect(row.recipientWrapLastError, outgoingDmOfflineError);
      expect(await stateOf(retrying, rumorId), DmDeliveryState.queued);
    });
  });

  group('watchDeliveryState', () {
    Future<String> park(DmRepository repository) async =>
        (await repository.enqueueSend(
          recipientPubkey: recipient,
          content: 'queued for later',
        )).queuedRumorId!;

    test(
      'reads cancelled for an account that is no longer signed in',
      () async {
        final repository = harness.build();
        final rumorId = await park(repository);

        harness.switchAccount(repository);

        expect(await storedStateOf(rumorId), DmDeliveryState.queued);
        expect(await stateOf(repository, rumorId), DmDeliveryState.cancelled);
      },
    );

    test('reads cancelled once the repository is stopped', () async {
      final repository = harness.build();
      final rumorId = await park(repository);

      await repository.stopListening();

      expect(await storedStateOf(rumorId), DmDeliveryState.queued);
      expect(await stateOf(repository, rumorId), DmDeliveryState.cancelled);
    });
  });
}
