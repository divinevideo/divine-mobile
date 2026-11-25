// ABOUTME: Both DM tables contribute to one account-scoped delivery state.
import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  const owner = 'sender';
  const id = 'rumor';
  const environment = 'staging';

  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());

  Stream<DmDeliveryState> watch({
    String account = owner,
    String env = environment,
  }) => db.directMessagesDao.watchDeliveryState(
    ownerPubkey: account,
    rumorId: id,
    environment: env,
  );

  Future<void> enqueue() => db.outgoingDmsDao.enqueue(
    OutgoingDm(
      id: id,
      conversationId: 'conversation',
      recipientPubkey: 'peer',
      content: 'share',
      createdAt: 1,
      rumorEventJson: '{}',
      queuedAt: DateTime.utc(2026),
      ownerPubkey: owner,
      environment: environment,
      recipientWrapStatus: OutgoingWrapStatus.pending,
      selfWrapStatus: OutgoingWrapStatus.pending,
    ),
  );

  Future<void> mark(
    OutgoingWrapStatus status, {
    String? wrap,
    String? error,
  }) async {
    await db.outgoingDmsDao.markRecipientWrapStatus(
      id: id,
      status: status,
      eventId: wrap,
      lastError: error,
    );
  }

  group('watchDeliveryState', () {
    test(
      'scope, refused attempt, offline retry, held pool, stopped send',
      () async {
        await enqueue();
        expect(
          await watch(account: 'different').first,
          DmDeliveryState.cancelled,
        );
        expect(await watch(env: 'production').first, DmDeliveryState.cancelled);
        expect(await watch().first, DmDeliveryState.queued);
        await mark(OutgoingWrapStatus.failed, error: outgoingDmOfflineError);
        expect(await watch().first, DmDeliveryState.queued);
        await mark(OutgoingWrapStatus.failed, error: 'refused');
        expect(await watch().first, DmDeliveryState.failed);
        await mark(OutgoingWrapStatus.pending, wrap: 'pool-wrap');
        expect(await watch().first, DmDeliveryState.held);
        await mark(OutgoingWrapStatus.failed);
        expect(await watch().first, DmDeliveryState.held);
        await mark(OutgoingWrapStatus.blocked);
        expect(await watch().first, DmDeliveryState.cancelled);
      },
    );

    test(
      'self-copy stays queued until recipient OK and atomic removal',
      () async {
        await enqueue();
        await db.directMessagesDao.insertMessage(
          id: id,
          conversationId: 'conversation',
          senderPubkey: owner,
          content: 'share',
          createdAt: 1,
          giftWrapId: 'self-wrap',
          ownerPubkey: owner,
        );
        await db.outgoingDmsDao.markSelfWrapStatus(
          id: id,
          status: OutgoingWrapStatus.sent,
        );
        final stream = StreamIterator(watch());
        addTearDown(stream.cancel);
        expect(await stream.moveNext(), isTrue);
        expect(stream.current, DmDeliveryState.queued);
        final next = stream.moveNext();
        await db.transaction(() async {
          await db.outgoingDmsDao.deleteById(id);
          await db.directMessagesDao.markRecipientAccepted(
            ownerPubkey: owner,
            rumorId: id,
            environment: environment,
          );
        });
        expect(await next, isTrue);
        expect(stream.current, DmDeliveryState.accepted);
        expect(await watch(env: 'production').first, DmDeliveryState.cancelled);
        expect(await watch(account: 'peer').first, DmDeliveryState.cancelled);
      },
    );

    test(
      'a recipient ACK counts while the self-wrap is still retrying',
      () async {
        await enqueue();
        await db.outgoingDmsDao.markSelfWrapStatus(
          id: id,
          status: OutgoingWrapStatus.failed,
        );
        await mark(OutgoingWrapStatus.sent, wrap: 'recipient-wrap');
        expect(await watch().first, DmDeliveryState.accepted);
      },
    );
  });
}
