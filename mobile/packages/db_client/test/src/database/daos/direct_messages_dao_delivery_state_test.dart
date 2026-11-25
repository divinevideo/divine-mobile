// ABOUTME: Tests the share-delivery state DirectMessagesDao derives from the
// ABOUTME: outbox row and the recipient acknowledgment on the sender's message.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DirectMessagesDao dao;

  final owner = 'a' * 64;
  final peer = 'd' * 64;
  final otherAccount = 'e' * 64;
  final rumorId = '1' * 64;
  const conversationId = 'conversation';
  const environment = 'staging';

  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    dao = db.directMessagesDao;
  });
  tearDown(() => db.close());

  Stream<DmDeliveryState> watch({String? account, String env = environment}) =>
      dao.watchDeliveryState(
        ownerPubkey: account ?? owner,
        rumorId: rumorId,
        environment: env,
      );

  Future<void> enqueue({
    OutgoingWrapStatus status = OutgoingWrapStatus.pending,
    String? heldWrap,
    String? lastError,
  }) => db.outgoingDmsDao.enqueue(
    OutgoingDm(
      id: rumorId,
      conversationId: conversationId,
      recipientPubkey: peer,
      content: 'share',
      createdAt: 1,
      rumorEventJson: '{}',
      queuedAt: DateTime.utc(2026),
      ownerPubkey: owner,
      environment: environment,
      recipientWrapStatus: status,
      selfWrapStatus: OutgoingWrapStatus.pending,
      recipientWrapEventId: heldWrap,
      recipientWrapLastError: lastError,
    ),
  );

  Future<void> insertMessage({String? sender, String? account}) =>
      dao.insertMessage(
        id: rumorId,
        conversationId: conversationId,
        senderPubkey: sender ?? owner,
        content: 'share',
        createdAt: 1,
        giftWrapId: 'self-wrap-${account ?? owner}',
        ownerPubkey: account ?? owner,
      );

  Future<void> markAccepted({String env = environment}) =>
      dao.markRecipientAccepted(
        ownerPubkey: owner,
        rumorId: rumorId,
        environment: env,
      );

  Future<String?> acceptedEnvironmentOf(String account) async {
    final row = await (db.select(
      db.directMessages,
    )..where((m) => m.ownerPubkey.equals(account))).getSingle();
    return row.recipientAcceptedEnvironment;
  }

  group(DirectMessagesDao, () {
    group('watchDeliveryState', () {
      group('with an outbox row', () {
        test('emits queued while the recipient wrap is pending', () async {
          await enqueue();

          expect(await watch().first, DmDeliveryState.queued);
        });

        test('emits queued after a failure caused by being offline', () async {
          await enqueue(
            status: OutgoingWrapStatus.failed,
            lastError: outgoingDmOfflineError,
          );

          expect(await watch().first, DmDeliveryState.queued);
        });

        test('emits failed after a relay refused the recipient wrap', () async {
          await enqueue(
            status: OutgoingWrapStatus.failed,
            lastError: 'refused',
          );

          expect(await watch().first, DmDeliveryState.failed);
        });

        test(
          'emits held while a fallback-pool relay holds a pending wrap',
          () async {
            await enqueue(heldWrap: 'pool-wrap');

            expect(await watch().first, DmDeliveryState.held);
          },
        );

        test(
          'emits held while a fallback-pool relay holds a failed wrap',
          () async {
            await enqueue(
              status: OutgoingWrapStatus.failed,
              heldWrap: 'pool-wrap',
              lastError: 'refused',
            );

            expect(await watch().first, DmDeliveryState.held);
          },
        );

        test('emits accepted once the recipient wrap is sent, while the '
            'self-wrap still retries', () async {
          await enqueue();
          await db.outgoingDmsDao.markSelfWrapStatus(
            id: rumorId,
            status: OutgoingWrapStatus.failed,
          );
          await db.outgoingDmsDao.markRecipientWrapStatus(
            id: rumorId,
            status: OutgoingWrapStatus.sent,
            eventId: 'recipient-wrap',
          );

          expect(await watch().first, DmDeliveryState.accepted);
        });

        test('emits accepted for a held wrap whose message carries the '
            'acceptance mark', () async {
          await enqueue(heldWrap: 'pool-wrap');
          await insertMessage();
          await markAccepted();

          expect(await watch().first, DmDeliveryState.accepted);
        });

        test('emits cancelled once send policy blocks the recipient, even '
            'with an acceptance mark', () async {
          await enqueue();
          await insertMessage();
          await markAccepted();
          await db.outgoingDmsDao.markRecipientBlocked(
            id: rumorId,
            lastError: 'blocked',
          );

          expect(await watch().first, DmDeliveryState.cancelled);
        });

        test('emits cancelled once the sender stops the delivery', () async {
          await enqueue();
          await db.outgoingDmsDao.markRecipientCancelled(rumorId);

          expect(await watch().first, DmDeliveryState.cancelled);
        });

        test('emits an $UnknownOutgoingWrapStatusException for a recipient '
            'status this build does not know', () async {
          await enqueue();
          await db.customStatement(
            "UPDATE outgoing_dms SET recipient_wrap_status = 'superseded'",
          );

          await expectLater(
            watch(),
            emitsError(
              isA<UnknownOutgoingWrapStatusException>().having(
                (e) => e.rawValue,
                'rawValue',
                'superseded',
              ),
            ),
          );
        });

        test('emits cancelled for a row another account queued', () async {
          await enqueue();

          expect(
            await watch(account: otherAccount).first,
            DmDeliveryState.cancelled,
          );
        });

        test(
          'emits cancelled for a row queued in another environment',
          () async {
            await enqueue();

            expect(
              await watch(env: 'production').first,
              DmDeliveryState.cancelled,
            );
          },
        );
      });

      group('without an outbox row', () {
        test('emits cancelled when no acceptance mark exists', () async {
          await insertMessage();

          expect(await watch().first, DmDeliveryState.cancelled);
        });

        test('emits accepted when one transaction removes the outbox row and '
            'marks the message', () async {
          await enqueue();
          await insertMessage();
          final stream = StreamIterator(watch());
          addTearDown(stream.cancel);
          expect(await stream.moveNext(), isTrue);
          expect(stream.current, DmDeliveryState.queued);

          final next = stream.moveNext();
          await db.transaction(() async {
            await db.outgoingDmsDao.deleteById(rumorId);
            await markAccepted();
          });

          expect(await next, isTrue);
          expect(stream.current, DmDeliveryState.accepted);
        });

        test('ignores an acceptance mark from another environment', () async {
          await insertMessage();
          await markAccepted();

          expect(
            await watch(env: 'production').first,
            DmDeliveryState.cancelled,
          );
        });

        test(
          "ignores the acceptance mark on another account's message",
          () async {
            await insertMessage();
            await markAccepted();

            expect(
              await watch(account: otherAccount).first,
              DmDeliveryState.cancelled,
            );
          },
        );
      });
    });

    group('markRecipientAccepted', () {
      test("records the environment on the sender's own message", () async {
        await insertMessage();

        await markAccepted();

        expect(await acceptedEnvironmentOf(owner), environment);
      });

      test('records an empty environment as accepted with none set', () async {
        await insertMessage();

        await markAccepted(env: '');

        expect(await acceptedEnvironmentOf(owner), isEmpty);
        expect(await watch(env: '').first, DmDeliveryState.accepted);
      });

      test('leaves a message the account received untouched', () async {
        await insertMessage(sender: peer);

        await markAccepted();

        expect(await acceptedEnvironmentOf(owner), isNull);
      });

      test("leaves another account's copy of the rumor untouched", () async {
        await insertMessage();
        await insertMessage(account: otherAccount, sender: owner);

        await markAccepted();

        expect(await acceptedEnvironmentOf(owner), environment);
        expect(await acceptedEnvironmentOf(otherAccount), isNull);
      });
    });
  });
}
