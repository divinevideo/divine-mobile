// ABOUTME: What a share batch reports per recipient once its rows commit: a
// ABOUTME: malformed recipient is refused, a later local failure loses nothing.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/share_delivery_harness.dart';

/// A conversation store whose writes fail, as on a full or locked disk.
class _UnwritableConversations extends ConversationsDao {
  _UnwritableConversations(super.attachedDatabase);

  int upserts = 0;

  @override
  Future<void> upsertConversation({
    required String id,
    required String participantPubkeys,
    required bool isGroup,
    required int createdAt,
    String? lastMessageContent,
    int? lastMessageTimestamp,
    int? lastMessageCreatedAt,
    String? lastMessageSenderPubkey,
    String? subject,
    bool isRead = true,
    bool currentUserHasSent = false,
    String? ownerPubkey,
    String? dmProtocol,
    bool forceUpdateLastMessage = false,
    bool isNewMessage = false,
  }) async {
    upserts++;
    throw StateError('database or disk is full');
  }
}

void main() {
  setUpAll(registerShareHarnessFallbacks);

  final owner = ShareDeliveryHarness.owner;
  final recipient = ShareDeliveryHarness.recipient;
  final secondRecipient = ShareDeliveryHarness.secondRecipient;
  late ShareDeliveryHarness harness;

  setUp(() => harness = ShareDeliveryHarness());

  tearDown(() => harness.dispose());

  group('enqueueSharedVideoBatch', () {
    test(
      'refuses a malformed recipient and queues the valid one alone',
      () async {
        final repository = harness.build();
        // The session ends at the commit, so no delivery removes the row.
        harness.queue.afterCommit = repository.stopListening;

        // The bad key first, so the valid one must survive past it.
        final outcomes = await harness.share(repository, [
          'not-a-key',
          recipient,
        ]);

        expect(outcomes[recipient], isA<ShareEnqueueQueued>());
        expect(outcomes['not-a-key'], isA<ShareEnqueueRefused>());
        final rows = await harness.queue.getAllForOwner(owner);
        expect(rows.single.recipientPubkey, recipient);
      },
    );

    test('a conversation store that fails after the commit still reports '
        'every recipient queued and keeps every row', () async {
      final conversations = _UnwritableConversations(harness.db);
      final reports = <String>[];
      final repository = harness.build(
        conversations: conversations,
        errorReporter: (_, _, {required site}) => reports.add(site),
      );
      // Delivery waits on the inbox lookup, so the rows can only be what the
      // batch left behind.
      final lookups = harness.inboxLookups = Completer<void>();

      final outcomes = await harness.share(repository, [
        recipient,
        secondRecipient,
      ]);

      // Each share tried to surface its thread and failed.
      expect(conversations.upserts, greaterThanOrEqualTo(2));
      expect(outcomes.keys, unorderedEquals([recipient, secondRecipient]));
      expect(outcomes.values, everyElement(isA<ShareEnqueueQueued>()));
      final rows = await harness.queue.getStillPendingForOwner(owner);
      expect(
        rows.map((row) => row.id),
        unorderedEquals([
          for (final outcome in outcomes.values.cast<ShareEnqueueQueued>())
            outcome.rumorId,
        ]),
      );
      // A failing disk is an operational failure, not a defect to report.
      expect(reports, isEmpty);

      final deliveries = [
        for (final outcome in outcomes.values.cast<ShareEnqueueQueued>())
          repository.recoverFullSend(rumorId: outcome.rumorId),
      ];
      lookups.complete();
      await Future.wait(deliveries);
    });
  });
}
