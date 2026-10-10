// ABOUTME: Unit tests for OutgoingDmsDao — durable outgoing-DM queue
// ABOUTME: with per-wrap publish status. Tests CRUD, reactive streams,
// ABOUTME: retry filtering, and owner-pubkey isolation.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OutgoingDmsDao dao;
  late String tempDbPath;

  // Valid 64-char hex pubkeys for testing.
  const ownerA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const ownerB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const recipient =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const recipient2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const conversationId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const conversationId2 =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  // Helper: build a fresh queued OutgoingDm with both wraps pending.
  OutgoingDm makeDm({
    required String id,
    String? rumorId,
    String owner = ownerA,
    String recipientPubkey = recipient,
    String conversationIdValue = conversationId,
    OutgoingWrapStatus recipientStatus = OutgoingWrapStatus.pending,
    OutgoingWrapStatus selfStatus = OutgoingWrapStatus.pending,
    int retryCount = 0,
    DateTime? queuedAt,
    int createdAt = 1700000000,
    String? sendBatchId,
  }) {
    return OutgoingDm(
      id: id,
      conversationId: conversationIdValue,
      recipientPubkey: recipientPubkey,
      content: 'hello',
      createdAt: createdAt,
      rumorEventJson: '{"id":"${rumorId ?? id}","kind":14,"content":"hello"}',
      recipientWrapStatus: recipientStatus,
      selfWrapStatus: selfStatus,
      retryCount: retryCount,
      queuedAt: queuedAt ?? DateTime.utc(2026, 5),
      ownerPubkey: owner,
      sendBatchId: sendBatchId,
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('outgoing_dms_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.outgoingDmsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('OutgoingDm value equality', () {
    test('rumorId reads the wire id independently of the queue handle', () {
      final row = makeDm(id: 'queue-handle', rumorId: 'wire-rumor');

      expect(row.id, equals('queue-handle'));
      expect(row.rumorId, equals('wire-rumor'));
    });

    test(
      'rows differing only in wrap status are NOT equal — id-only equality '
      'made a pending row compare equal to its failed re-read, so Bloc.emit '
      'suppressed the red-bubble repaint',
      () {
        final pending = makeDm(id: 'eq-check-1');
        final failed = pending.copyWith(
          recipientWrapStatus: OutgoingWrapStatus.failed,
          selfWrapStatus: OutgoingWrapStatus.failed,
          recipientWrapLastError: 'device offline',
        );

        expect(pending, isNot(equals(failed)));
        expect(pending.hashCode, isNot(equals(failed.hashCode)));
      },
    );

    test('field-identical copies are equal with equal hash codes', () {
      final row = makeDm(id: 'eq-check-2', retryCount: 3);
      final copy = row.copyWith();

      expect(row, equals(copy));
      expect(row.hashCode, equals(copy.hashCode));
    });

    test('rows differing only in sendBatchId are NOT equal', () {
      final batchOne = makeDm(id: 'eq-batch', sendBatchId: 'batch-1');
      final batchTwo = makeDm(id: 'eq-batch', sendBatchId: 'batch-2');

      expect(batchOne, isNot(equals(batchTwo)));
      expect(batchOne.hashCode, isNot(equals(batchTwo.hashCode)));
    });

    test('copyWith(sendBatchId:) round-trips the field', () {
      final base = makeDm(id: 'eq-batch-rt');
      expect(base.sendBatchId, isNull);

      final withBatch = base.copyWith(sendBatchId: 'batch-x');
      expect(withBatch.sendBatchId, equals('batch-x'));
    });
  });

  group('conversation removal', () {
    test('deletes only the selected conversation for the owner', () async {
      await dao.enqueue(makeDm(id: 'owner-a-target'));
      await dao.enqueue(
        makeDm(id: 'owner-a-other', conversationIdValue: conversationId2),
      );
      await dao.enqueue(makeDm(id: 'owner-b-target', owner: ownerB));

      expect(
        await dao.deleteForConversation(
          conversationId: conversationId,
          ownerPubkey: ownerA,
        ),
        1,
      );
      expect(await dao.getById('owner-a-target'), isNull);
      expect(await dao.getById('owner-a-other'), isNotNull);
      expect(await dao.getById('owner-b-target'), isNotNull);
    });

    test('deletes multiple selected conversations for the owner', () async {
      await dao.enqueue(makeDm(id: 'owner-a-first'));
      await dao.enqueue(
        makeDm(id: 'owner-a-second', conversationIdValue: conversationId2),
      );
      await dao.enqueue(makeDm(id: 'owner-b-first', owner: ownerB));

      expect(
        await dao.deleteForConversations(
          conversationIds: [conversationId, conversationId2],
          ownerPubkey: ownerA,
        ),
        2,
      );
      expect(await dao.getById('owner-a-first'), isNull);
      expect(await dao.getById('owner-a-second'), isNull);
      expect(await dao.getById('owner-b-first'), isNotNull);
    });

    test('an empty selection deletes nothing', () async {
      await dao.enqueue(makeDm(id: 'owner-a-queued'));

      expect(
        await dao.deleteForConversations(
          conversationIds: const [],
          ownerPubkey: ownerA,
        ),
        0,
      );
      expect(await dao.getById('owner-a-queued'), isNotNull);
    });
  });

  group('OutgoingDmsDao', () {
    group('enqueue', () {
      test('inserts a new row in pending/pending state', () async {
        final dm = makeDm(id: 'aaaa');
        await dao.enqueue(dm);

        final fetched = await dao.getById('aaaa');
        expect(fetched, isNotNull);
        expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(fetched.selfWrapStatus, OutgoingWrapStatus.pending);
        expect(fetched.retryCount, equals(0));
        expect(fetched.recipientWrapLastError, isNull);
        expect(fetched.selfWrapLastError, isNull);
      });

      test('finds a per-recipient queue row by its shared rumor id', () async {
        await dao.enqueue(
          makeDm(id: 'wire-rumor:$recipient', rumorId: 'wire-rumor'),
        );
        await dao.enqueue(
          makeDm(
            id: 'wire-rumor:$recipient2',
            rumorId: 'wire-rumor',
            recipientPubkey: recipient2,
          ),
        );

        final row = await dao.getByRumorId(
          rumorId: 'wire-rumor',
          ownerPubkey: ownerA,
        );

        expect(row, isNotNull);
        expect(row!.rumorId, equals('wire-rumor'));
        expect(row.id, isNot(equals(row.rumorId)));
      });

      test('ignores an unrelated row with a corrupt wrap status', () async {
        await dao.enqueue(makeDm(id: 'corrupt-row'));
        await database.customStatement(
          "UPDATE outgoing_dms SET recipient_wrap_status = 'superseded' "
          "WHERE id = 'corrupt-row'",
        );
        await dao.enqueue(
          makeDm(id: 'wire-rumor:$recipient', rumorId: 'wire-rumor'),
        );

        final row = await dao.getByRumorId(
          rumorId: 'wire-rumor',
          ownerPubkey: ownerA,
        );

        expect(row?.id, equals('wire-rumor:$recipient'));
      });

      test(
        're-enqueueing the same id is a no-op — leaves mutable delivery '
        'state on the existing row untouched',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));

          // Move the row out of the initial pending/pending state.
          await dao.markRecipientWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.sent,
            eventId: 'rcpt-evt-id',
          );
          await dao.markSelfWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.failed,
            lastError: 'self-wrap relay rejected',
          );
          await dao.incrementRetry('aaaa');

          // A second enqueue with a fresh OutgoingDm (retry_count = 0,
          // both wraps pending, no eventId, no lastError) must NOT
          // overwrite the in-flight delivery state.
          await dao.enqueue(makeDm(id: 'aaaa'));

          final fetched = await dao.getById('aaaa');
          expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.sent);
          expect(fetched.recipientWrapEventId, equals('rcpt-evt-id'));
          expect(fetched.selfWrapStatus, OutgoingWrapStatus.failed);
          expect(
            fetched.selfWrapLastError,
            equals('self-wrap relay rejected'),
          );
          expect(
            fetched.recipientWrapLastError,
            isNull,
            reason: 'recipient wrap never failed; its error column stays null',
          );
          expect(fetched.retryCount, equals(1));
        },
      );

      test('persists sendBatchId through enqueue and getById', () async {
        await dao.enqueue(makeDm(id: 'batched', sendBatchId: 'batch-e'));

        final fetched = await dao.getById('batched');
        expect(fetched, isNotNull);
        expect(fetched!.sendBatchId, equals('batch-e'));
      });

      test('leaves sendBatchId null when the caller omits it', () async {
        await dao.enqueue(makeDm(id: 'solo'));

        final fetched = await dao.getById('solo');
        expect(fetched!.sendBatchId, isNull);
      });
    });

    group('markRecipientWrapStatus / markSelfWrapStatus', () {
      test('flips recipient status to sent and records eventId', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));

        final ok = await dao.markRecipientWrapStatus(
          id: 'aaaa',
          status: OutgoingWrapStatus.sent,
          eventId: 'rcpt-evt-id',
        );

        expect(ok, isTrue);
        final fetched = await dao.getById('aaaa');
        expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.sent);
        expect(fetched.recipientWrapEventId, equals('rcpt-evt-id'));
        expect(fetched.lastAttemptAt, isNotNull);
        expect(
          fetched.selfWrapStatus,
          OutgoingWrapStatus.pending,
          reason: 'self status is independent of recipient status',
        );
      });

      test(
        'flips self status to failed and records lastError independent '
        'of recipient status (the partial-delivery state)',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));
          await dao.markRecipientWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.sent,
            eventId: 'rcpt-evt-id',
          );

          final ok = await dao.markSelfWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.failed,
            lastError: 'self-wrap relay rejected',
          );

          expect(ok, isTrue);
          final fetched = await dao.getById('aaaa');
          expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.sent);
          expect(fetched.selfWrapStatus, OutgoingWrapStatus.failed);
          expect(
            fetched.selfWrapLastError,
            equals('self-wrap relay rejected'),
          );
          expect(
            fetched.recipientWrapLastError,
            isNull,
            reason: 'recipient wrap succeeded; its error column must stay null',
          );
          expect(fetched.isFullyDelivered, isFalse);
          expect(fetched.hasRetryableFailure, isTrue);
        },
      );

      test(
        'recipient failure followed by self failure preserves both '
        'errors independently — neither overwrites the other',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));

          await dao.markRecipientWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.failed,
            lastError: 'recipient relay rejected: rate-limited',
          );
          await dao.markSelfWrapStatus(
            id: 'aaaa',
            status: OutgoingWrapStatus.failed,
            lastError: 'self-relay timeout',
          );

          final fetched = await dao.getById('aaaa');
          expect(
            fetched!.recipientWrapLastError,
            equals('recipient relay rejected: rate-limited'),
            reason:
                'B2 contract: per-wrap error columns mean a later self '
                'failure must not overwrite the earlier recipient reason',
          );
          expect(
            fetched.selfWrapLastError,
            equals('self-relay timeout'),
          );
          expect(fetched.recipientWrapStatus, OutgoingWrapStatus.failed);
          expect(fetched.selfWrapStatus, OutgoingWrapStatus.failed);
        },
      );

      test('terminal block leaves neither wrap retryable or pending', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));

        final ok = await dao.markRecipientBlocked(
          id: 'aaaa',
          lastError: 'recipient retired',
        );

        expect(ok, isTrue);
        final fetched = await dao.getById('aaaa');
        expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.blocked);
        expect(fetched.selfWrapStatus, OutgoingWrapStatus.blocked);
        expect(fetched.recipientWrapLastError, 'recipient retired');
        expect(fetched.hasRetryableFailure, isFalse);
        expect(fetched.isFullyDelivered, isFalse);
        expect(
          await dao.getRetryableForOwner(ownerPubkey: ownerA, maxRetries: 5),
          isEmpty,
        );
        expect(await dao.getStillPendingForOwner(ownerA), isEmpty);
      });

      test('a cancelled delivery keeps its row but is neither retryable nor '
          'pending', () async {
        await dao.enqueue(
          makeDm(
            id: 'aaaa',
            recipientStatus: OutgoingWrapStatus.failed,
            selfStatus: OutgoingWrapStatus.failed,
          ),
        );
        expect(
          await dao.getRetryableForOwner(ownerPubkey: ownerA, maxRetries: 5),
          hasLength(1),
          reason: 'the row is retryable until the sender stops it',
        );

        final ok = await dao.markRecipientCancelled('aaaa');

        expect(ok, isTrue);
        final fetched = await dao.getById('aaaa');
        expect(
          fetched,
          isNotNull,
          reason: 'the row is the record, so it stays',
        );
        expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.cancelled);
        expect(fetched.selfWrapStatus, OutgoingWrapStatus.cancelled);
        expect(fetched.hasRetryableFailure, isFalse);
        expect(fetched.isFullyDelivered, isFalse);
        expect(
          await dao.getRetryableForOwner(ownerPubkey: ownerA, maxRetries: 5),
          isEmpty,
        );
        expect(await dao.getStillPendingForOwner(ownerA), isEmpty);
      });

      test('cancelling a missing row reports false', () async {
        expect(await dao.markRecipientCancelled('missing'), isFalse);
      });

      // A publish that was in flight when the sender stopped the delivery
      // reports back afterwards, and the retry service terminalizes rows from
      // a snapshot it read earlier. Neither may reopen the row.
      for (final MapEntry(key: name, value: lateWrite)
          in <String, Future<bool> Function(OutgoingDmsDao)>{
            'a recipient-wrap status': (dao) => dao.markRecipientWrapStatus(
              id: 'aaaa',
              status: OutgoingWrapStatus.failed,
              lastError: 'relay refused the wrap',
            ),
            'a self-wrap status': (dao) => dao.markSelfWrapStatus(
              id: 'aaaa',
              status: OutgoingWrapStatus.failed,
              lastError: 'relay refused the wrap',
            ),
            'a policy block': (dao) => dao.markRecipientBlocked(
              id: 'aaaa',
              lastError: 'recipient retired',
            ),
          }.entries) {
        test('a cancelled delivery is not reopened by $name written '
            'afterwards', () async {
          await dao.enqueue(
            makeDm(
              id: 'aaaa',
              recipientStatus: OutgoingWrapStatus.failed,
              selfStatus: OutgoingWrapStatus.failed,
            ),
          );
          expect(await dao.markRecipientCancelled('aaaa'), isTrue);

          final written = await lateWrite(dao);

          expect(written, isFalse);
          final fetched = await dao.getById('aaaa');
          expect(fetched!.recipientWrapStatus, OutgoingWrapStatus.cancelled);
          expect(fetched.selfWrapStatus, OutgoingWrapStatus.cancelled);
          expect(
            await dao.getRetryableForOwner(ownerPubkey: ownerA, maxRetries: 5),
            isEmpty,
          );
        });
      }

      for (final status in [
        OutgoingWrapStatus.sent,
        OutgoingWrapStatus.blocked,
      ]) {
        test('a ${status.name} recipient wrap is not put on record as '
            'stopped', () async {
          // Only a delivery still in progress can be stopped. A member the
          // wrap already reached, or a policy refusal, keeps what it says.
          await dao.enqueue(
            makeDm(
              id: 'aaaa',
              recipientStatus: status,
              selfStatus: OutgoingWrapStatus.failed,
            ),
          );

          final ok = await dao.markRecipientCancelled('aaaa');

          expect(ok, isFalse);
          final fetched = await dao.getById('aaaa');
          expect(fetched!.recipientWrapStatus, status);
          expect(fetched.selfWrapStatus, OutgoingWrapStatus.failed);
        });
      }

      test('returns false when the row does not exist', () async {
        final ok = await dao.markRecipientWrapStatus(
          id: 'missing',
          status: OutgoingWrapStatus.sent,
        );
        expect(ok, isFalse);
      });
    });

    group('incrementRetry', () {
      test('increases retry_count by one and updates lastAttemptAt', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));

        final before = await dao.getById('aaaa');
        expect(before!.retryCount, equals(0));
        expect(before.lastAttemptAt, isNull);

        // Capture wall-clock before/after the increment. The decoded
        // lastAttemptAt must land inside this window — locks the codec
        // contract so a future regression to a raw-SQL writer that
        // disagreed about ms-vs-seconds (the bug rabble flagged on
        // `outgoing_dms_dao.dart:306`) fails the test loudly instead of
        // returning a year-57000 timestamp.
        final beforeNow = DateTime.now();
        await dao.incrementRetry('aaaa');
        await dao.incrementRetry('aaaa');
        final afterNow = DateTime.now();

        final after = await dao.getById('aaaa');
        expect(after!.retryCount, equals(2));
        expect(after.lastAttemptAt, isNotNull);
        // Drift's int DateTime codec stores seconds, so the truncation
        // may push lastAttemptAt up to one second behind beforeNow.
        // Allow a 2-second slack on each side to absorb that and any
        // CI scheduling noise; the bug we're guarding against would
        // produce a value ~50,000 years off, not 2 seconds.
        final lower = beforeNow.subtract(const Duration(seconds: 2));
        final upper = afterNow.add(const Duration(seconds: 2));
        expect(
          after.lastAttemptAt!.isAfter(lower),
          isTrue,
          reason:
              'lastAttemptAt ${after.lastAttemptAt} should be after $lower; '
              'a value far in the past would suggest a codec mismatch in the '
              'opposite direction',
        );
        expect(
          after.lastAttemptAt!.isBefore(upper),
          isTrue,
          reason:
              'lastAttemptAt ${after.lastAttemptAt} should be before $upper; '
              'a value far in the future suggests incrementRetry is writing '
              'milliseconds into a seconds-typed column',
        );
      });
    });

    group('resetRetryCount', () {
      test('zeroes retry_count while preserving lastAttemptAt', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.incrementRetry('aaaa');
        await dao.incrementRetry('aaaa');
        final charged = await dao.getById('aaaa');
        expect(charged!.retryCount, equals(2));
        expect(charged.lastAttemptAt, isNotNull);

        final reset = await dao.resetRetryCount('aaaa');

        expect(reset, isTrue);
        final after = await dao.getById('aaaa');
        expect(after!.retryCount, equals(0));
        // The attempt clock stays: backoff is derived from retryCount, so a
        // zeroed count is enough to re-arm the sweep immediately.
        expect(after.lastAttemptAt, equals(charged.lastAttemptAt));
      });

      test('returns false when the row does not exist', () async {
        expect(await dao.resetRetryCount('missing'), isFalse);
      });
    });

    group('deleteById', () {
      test('removes the row and returns the affected count', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));

        final deleted = await dao.deleteById('aaaa');

        expect(deleted, equals(1));
        expect(await dao.getById('aaaa'), isNull);
      });

      test('returns 0 when the row does not exist', () async {
        expect(await dao.deleteById('missing'), equals(0));
      });
    });

    group('getForConversation', () {
      test(
        'returns only the conversation-and-owner scoped rows, newest '
        'createdAt first',
        () async {
          await dao.enqueue(makeDm(id: 'older'));
          await dao.enqueue(makeDm(id: 'newer', createdAt: 1700000060));
          await dao.enqueue(
            makeDm(
              id: 'other-conversation',
              conversationIdValue: conversationId2,
            ),
          );
          await dao.enqueue(makeDm(id: 'other-owner', owner: ownerB));

          final rows = await dao.getForConversation(
            conversationId: conversationId,
            ownerPubkey: ownerA,
          );

          expect(rows.map((r) => r.id), equals(['newer', 'older']));
        },
      );

      test('returns an empty list when nothing matches', () async {
        expect(
          await dao.getForConversation(
            conversationId: conversationId,
            ownerPubkey: ownerA,
          ),
          isEmpty,
        );
      });
    });

    group('clearAllForUser', () {
      test('removes only rows owned by the given pubkey', () async {
        await dao.enqueue(makeDm(id: 'a1'));
        await dao.enqueue(makeDm(id: 'a2'));
        await dao.enqueue(makeDm(id: 'b1', owner: ownerB));

        final cleared = await dao.clearAllForUser(ownerA);

        expect(cleared, equals(2));
        expect(await dao.getById('a1'), isNull);
        expect(await dao.getById('a2'), isNull);
        expect(await dao.getById('b1'), isNotNull);
      });

      test('returns 0 when the user has no queued rows', () async {
        await dao.enqueue(makeDm(id: 'b1', owner: ownerB));

        final cleared = await dao.clearAllForUser(ownerA);

        expect(cleared, equals(0));
        expect(await dao.getById('b1'), isNotNull);
      });
    });

    group('watchForConversation', () {
      test('emits initial empty list for an empty conversation', () async {
        final stream = dao.watchForConversation(
          conversationId: conversationId,
          ownerPubkey: ownerA,
        );

        await expectLater(
          stream,
          emits(isEmpty),
        );
      });

      test('emits a new list after enqueue', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));

        // After the row is committed, the stream's first emission to a
        // fresh subscriber is the post-enqueue state.
        await expectLater(
          dao.watchForConversation(
            conversationId: conversationId,
            ownerPubkey: ownerA,
          ),
          emits(
            allOf(
              hasLength(1),
              contains(
                isA<OutgoingDm>()
                    .having((e) => e.id, 'id', 'aaaa')
                    .having(
                      (e) => e.recipientWrapStatus,
                      'recipientWrapStatus',
                      OutgoingWrapStatus.pending,
                    ),
              ),
            ),
          ),
        );
      });

      test('emits the new status after markRecipientWrapStatus', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.markRecipientWrapStatus(
          id: 'aaaa',
          status: OutgoingWrapStatus.sent,
          eventId: 'evt-1',
        );

        await expectLater(
          dao.watchForConversation(
            conversationId: conversationId,
            ownerPubkey: ownerA,
          ),
          emits(
            contains(
              isA<OutgoingDm>().having(
                (e) => e.recipientWrapStatus,
                'recipientWrapStatus',
                OutgoingWrapStatus.sent,
              ),
            ),
          ),
        );
      });

      test(
        're-emits on a LIVE subscription when a row is marked failed',
        () async {
          // The open conversation relies on watchForConversation re-emitting
          // when a row transitions pending -> failed WHILE the subscription is
          // already live. The tests above enqueue/mark BEFORE subscribing, so
          // they only prove the initial snapshot, not a live UPDATE re-emit.
          final expectation = expectLater(
            dao.watchForConversation(
              conversationId: conversationId,
              ownerPubkey: ownerA,
            ),
            emitsInOrder([
              isEmpty,
              predicate<List<OutgoingDm>>(
                (rows) =>
                    rows.length == 1 &&
                    rows.single.recipientWrapStatus ==
                        OutgoingWrapStatus.pending,
                'one pending row',
              ),
              predicate<List<OutgoingDm>>(
                (rows) =>
                    rows.length == 1 &&
                    rows.single.recipientWrapStatus ==
                        OutgoingWrapStatus.failed,
                'one failed row',
              ),
            ]),
          );

          await pumpEventQueue();
          await dao.enqueue(makeDm(id: 'live1'));
          await pumpEventQueue();
          await dao.markRecipientWrapStatus(
            id: 'live1',
            status: OutgoingWrapStatus.failed,
            lastError: 'offline',
          );
          await expectation;
        },
      );

      test('emits empty after deleteById', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.deleteById('aaaa');

        await expectLater(
          dao.watchForConversation(
            conversationId: conversationId,
            ownerPubkey: ownerA,
          ),
          emits(isEmpty),
        );
      });

      test('owner-pubkey isolation — does not include other owners', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.enqueue(makeDm(id: 'bbbb', owner: ownerB));

        final stream = dao.watchForConversation(
          conversationId: conversationId,
          ownerPubkey: ownerA,
        );

        await expectLater(
          stream,
          emits(
            allOf(
              hasLength(1),
              contains(isA<OutgoingDm>().having((e) => e.id, 'id', 'aaaa')),
            ),
          ),
        );
      });

      test('does not include rows from a different conversation', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.enqueue(
          makeDm(id: 'bbbb', conversationIdValue: conversationId2),
        );

        final stream = dao.watchForConversation(
          conversationId: conversationId,
          ownerPubkey: ownerA,
        );

        await expectLater(
          stream,
          emits(
            allOf(
              hasLength(1),
              contains(isA<OutgoingDm>().having((e) => e.id, 'id', 'aaaa')),
            ),
          ),
        );
      });
    });

    group('getAllForOwner', () {
      test(
        'returns every row for the owner whatever its wrap state or retry '
        'count, ordered oldest queuedAt first',
        () async {
          // Chronological order differs from insertion order, from id order
          // and from either status column's order, so the assertion only
          // holds if the query sorts by queuedAt.
          await dao.enqueue(
            makeDm(id: 'pending', queuedAt: DateTime.utc(2026, 5, 2)),
          );
          await dao.enqueue(
            makeDm(
              id: 'self-failed',
              recipientStatus: OutgoingWrapStatus.sent,
              selfStatus: OutgoingWrapStatus.failed,
              queuedAt: DateTime.utc(2026, 5, 5),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'both-sent',
              recipientStatus: OutgoingWrapStatus.sent,
              selfStatus: OutgoingWrapStatus.sent,
              queuedAt: DateTime.utc(2026, 5),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'exhausted',
              recipientStatus: OutgoingWrapStatus.failed,
              selfStatus: OutgoingWrapStatus.failed,
              retryCount: 5,
              queuedAt: DateTime.utc(2026, 5, 4),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'blocked',
              recipientStatus: OutgoingWrapStatus.blocked,
              selfStatus: OutgoingWrapStatus.blocked,
              queuedAt: DateTime.utc(2026, 5, 3),
            ),
          );

          final rows = await dao.getAllForOwner(ownerA);

          expect(
            rows.map((e) => e.id),
            equals([
              'both-sent',
              'pending',
              'blocked',
              'exhausted',
              'self-failed',
            ]),
          );
        },
      );

      test('excludes rows owned by another account', () async {
        await dao.enqueue(makeDm(id: 'aaaa'));
        await dao.enqueue(makeDm(id: 'bbbb', owner: ownerB));

        expect(
          (await dao.getAllForOwner(ownerA)).map((e) => e.id),
          equals(['aaaa']),
        );
        expect(
          (await dao.getAllForOwner(ownerB)).map((e) => e.id),
          equals(['bbbb']),
        );
      });
    });

    group('getRetryableForOwner', () {
      test(
        'returns rows where either wrap is failed and retry_count is '
        'under the cap, ordered oldest queuedAt first (FIFO)',
        () async {
          // Distinct queuedAt timestamps so the ordering assertion is
          // meaningful — the retry service depends on FIFO so older
          // failures are replayed before newer ones.
          // 'self-failed' is queued FIRST and 'rcpt-failed' SECOND, so
          // ordering by queuedAt asc must surface 'self-failed' before
          // 'rcpt-failed' regardless of the row insertion order or
          // alphabetical id ordering.

          // Both pending: not retryable yet (no failure recorded).
          await dao.enqueue(
            makeDm(
              id: 'pending',
              queuedAt: DateTime.utc(2026, 5),
            ),
          );
          // Self failed (the F3 partial-delivery): retryable, queued earliest.
          await dao.enqueue(
            makeDm(
              id: 'self-failed',
              recipientStatus: OutgoingWrapStatus.sent,
              selfStatus: OutgoingWrapStatus.failed,
              queuedAt: DateTime.utc(2026, 5, 2),
            ),
          );
          // Recipient failed: retryable, queued LATER than self-failed.
          await dao.enqueue(
            makeDm(
              id: 'rcpt-failed',
              recipientStatus: OutgoingWrapStatus.failed,
              queuedAt: DateTime.utc(2026, 5, 3),
            ),
          );
          // Both sent: not retryable.
          await dao.enqueue(
            makeDm(
              id: 'both-sent',
              recipientStatus: OutgoingWrapStatus.sent,
              selfStatus: OutgoingWrapStatus.sent,
              queuedAt: DateTime.utc(2026, 5, 4),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'blocked',
              recipientStatus: OutgoingWrapStatus.blocked,
              selfStatus: OutgoingWrapStatus.blocked,
              queuedAt: DateTime.utc(2026, 5, 4, 12),
            ),
          );
          // Failed but past the retry cap: excluded.
          await dao.enqueue(
            makeDm(
              id: 'exhausted',
              recipientStatus: OutgoingWrapStatus.failed,
              retryCount: 5,
              queuedAt: DateTime.utc(2026, 5, 5),
            ),
          );

          final retryable = await dao.getRetryableForOwner(
            ownerPubkey: ownerA,
            maxRetries: 5,
          );

          expect(
            retryable.map((e) => e.id),
            equals(['self-failed', 'rcpt-failed']),
            reason:
                'FIFO contract: getRetryableForOwner orders by queuedAt asc, '
                'so self-failed (2026-05-02) must precede rcpt-failed '
                '(2026-05-03)',
          );
        },
      );

      test('owner-pubkey isolation', () async {
        await dao.enqueue(
          makeDm(
            id: 'aaaa',
            recipientStatus: OutgoingWrapStatus.failed,
          ),
        );
        await dao.enqueue(
          makeDm(
            id: 'bbbb',
            owner: ownerB,
            recipientStatus: OutgoingWrapStatus.failed,
          ),
        );

        final retryable = await dao.getRetryableForOwner(
          ownerPubkey: ownerA,
          maxRetries: 5,
        );

        expect(retryable.map((e) => e.id), equals(['aaaa']));
      });
    });

    group('getStillPendingForOwner', () {
      test(
        'returns rows with at least one wrap still pending, ordered '
        'oldest queuedAt first (FIFO)',
        () async {
          // 'half-pending' is queued FIRST (oldest), 'pending' SECOND.
          // Insertion order is reversed from chronological order to
          // prove the query orders by queuedAt, not by row id or
          // primary-key default order.
          await dao.enqueue(
            makeDm(
              id: 'half-pending',
              recipientStatus: OutgoingWrapStatus.sent,
              queuedAt: DateTime.utc(2026, 5),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'pending',
              queuedAt: DateTime.utc(2026, 5, 2),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'both-sent',
              recipientStatus: OutgoingWrapStatus.sent,
              selfStatus: OutgoingWrapStatus.sent,
              queuedAt: DateTime.utc(2026, 5, 3),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'failed',
              recipientStatus: OutgoingWrapStatus.failed,
              selfStatus: OutgoingWrapStatus.failed,
              queuedAt: DateTime.utc(2026, 5, 4),
            ),
          );
          await dao.enqueue(
            makeDm(
              id: 'blocked',
              recipientStatus: OutgoingWrapStatus.blocked,
              selfStatus: OutgoingWrapStatus.blocked,
              queuedAt: DateTime.utc(2026, 5, 5),
            ),
          );

          final pending = await dao.getStillPendingForOwner(ownerA);

          expect(
            pending.map((e) => e.id),
            equals(['half-pending', 'pending']),
            reason:
                'FIFO contract: getStillPendingForOwner orders by queuedAt '
                'asc, so half-pending (2026-05-01) must precede pending '
                '(2026-05-02) even though pending was inserted second',
          );
        },
      );
    });

    group('unknown wrap status', () {
      // The DAO refuses to coerce unrecognised persisted statuses back
      // to `pending` because that would silently re-activate a row a
      // newer client (or a corrupt write) already moved to a terminal
      // state — for a retry queue, that risks double-delivery. See the
      // doc on `_parseStatus` and the table-column doc on
      // `recipient_wrap_status`.
      test(
        'getById throws UnknownOutgoingWrapStatusException when a row '
        'carries an unrecognised recipient_wrap_status',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));
          // Simulate a newer client persisting `superseded`, or a corrupt
          // write — bypass the DAO and write a raw value directly.
          await database.customStatement(
            "UPDATE outgoing_dms SET recipient_wrap_status = 'superseded' "
            "WHERE id = 'aaaa'",
          );

          await expectLater(
            dao.getById('aaaa'),
            throwsA(
              isA<UnknownOutgoingWrapStatusException>().having(
                (e) => e.rawValue,
                'rawValue',
                'superseded',
              ),
            ),
          );
        },
      );

      test(
        'getById throws when a row carries an unrecognised '
        'self_wrap_status',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));
          await database.customStatement(
            "UPDATE outgoing_dms SET self_wrap_status = 'archived' "
            "WHERE id = 'aaaa'",
          );

          await expectLater(
            dao.getById('aaaa'),
            throwsA(
              isA<UnknownOutgoingWrapStatusException>().having(
                (e) => e.rawValue,
                'rawValue',
                'archived',
              ),
            ),
          );
        },
      );

      test(
        'getStillPendingForOwner does not silently include rows with an '
        'unknown status — it throws so the caller can surface corruption',
        () async {
          await dao.enqueue(makeDm(id: 'aaaa'));
          await database.customStatement(
            "UPDATE outgoing_dms SET recipient_wrap_status = 'superseded' "
            "WHERE id = 'aaaa'",
          );

          await expectLater(
            dao.getStillPendingForOwner(ownerA),
            throwsA(isA<UnknownOutgoingWrapStatusException>()),
          );
        },
      );
    });

    group('isFullyDelivered + hasRetryableFailure (model getters)', () {
      test('isFullyDelivered is true only when both wraps are sent', () async {
        final dm = makeDm(id: 'aaaa');
        expect(dm.isFullyDelivered, isFalse);
        expect(
          dm
              .copyWith(
                recipientWrapStatus: OutgoingWrapStatus.sent,
                selfWrapStatus: OutgoingWrapStatus.sent,
              )
              .isFullyDelivered,
          isTrue,
        );
        expect(
          dm
              .copyWith(
                recipientWrapStatus: OutgoingWrapStatus.sent,
                selfWrapStatus: OutgoingWrapStatus.failed,
              )
              .isFullyDelivered,
          isFalse,
        );
      });

      test('hasRetryableFailure is true if either wrap is failed', () async {
        final dm = makeDm(id: 'aaaa');
        expect(dm.hasRetryableFailure, isFalse);
        expect(
          dm
              .copyWith(recipientWrapStatus: OutgoingWrapStatus.failed)
              .hasRetryableFailure,
          isTrue,
        );
        expect(
          dm
              .copyWith(selfWrapStatus: OutgoingWrapStatus.failed)
              .hasRetryableFailure,
          isTrue,
        );
      });
    });

    test(
      'multiple owners + recipients + conversations stay isolated end-to-end',
      () async {
        await dao.enqueue(makeDm(id: 'a-1'));
        await dao.enqueue(makeDm(id: 'a-2', recipientPubkey: recipient2));
        await dao.enqueue(makeDm(id: 'b-1', owner: ownerB));

        final ownerAStream = dao.watchAllForOwner(ownerA);
        await expectLater(
          ownerAStream,
          emits(hasLength(2)),
        );

        final ownerBStream = dao.watchAllForOwner(ownerB);
        await expectLater(
          ownerBStream,
          emits(hasLength(1)),
        );
      },
    );
  });
}
