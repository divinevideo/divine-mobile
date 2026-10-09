// ABOUTME: Unit tests for DmReactionsDao.
// ABOUTME: Covers optimistic writes, retry state transitions, soft delete,
// ABOUTME: wrapped receive dedup, and owner-scoped query behaviour.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _ownerB =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const String _reactorA = _ownerA;
const _reactorB =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _conversationId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _targetMessageId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _targetAuthor =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _pendingId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _sentId =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _giftWrapId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _otherConversationId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _otherConversationReactionId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _otherOwnerReactionId =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _otherTargetMessageId =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _recipients = '["$_targetAuthor","$_reactorB"]';

void main() {
  late AppDatabase database;
  late DmReactionsDao dao;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dm_reactions_dao_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.dmReactionsDao;
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

  group('DmReactionsDao', () {
    Future<List<String>> insertPending({
      String id = _pendingId,
      String conversationId = _conversationId,
      String ownerPubkey = _ownerA,
      String reactorPubkey = _reactorA,
      String emoji = '🔥',
      int createdAt = 1_700_000_000,
      String targetMessageId = _targetMessageId,
      String? recipientPubkeys,
    }) {
      return dao.insertOwnReactionSuperseding(
        placeholderId: id,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        ownerPubkey: ownerPubkey,
        rumorEventJson: '{"id":"$id"}',
        recipientPubkeys: recipientPubkeys,
      );
    }

    test(
      'insertOwnReactionSuperseding stores pending state and rumor json',
      () async {
        final superseded = await insertPending();
        expect(superseded, isEmpty);

        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row, isNotNull);
        expect(row!.publishStatus, equals('pending'));
        expect(row.rumorEventJson, contains(_pendingId));
        expect(row.giftWrapId, isNull);
      },
    );

    test(
      'insertOwnReactionSuperseding soft-deletes the prior live own reaction '
      'and returns its id',
      () async {
        await insertPending();
        final superseded = await insertPending(
          id: _sentId,
          emoji: '😂',
          createdAt: 1_700_000_010,
        );

        expect(superseded, equals([_pendingId]));
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['😂']));
      },
    );

    test(
      'partial unique index rejects a second live reaction for the same '
      '(target, reactor, owner) tuple',
      () async {
        await insertPending();

        Future<void> insertDuplicateLive() {
          return database
              .into(database.dmMessageReactions)
              .insert(
                DmMessageReactionsCompanion.insert(
                  id: _sentId,
                  conversationId: _conversationId,
                  targetMessageId: _targetMessageId,
                  targetMessageAuthor: _targetAuthor,
                  reactorPubkey: _reactorA,
                  emoji: '😂',
                  createdAt: 1_700_000_010,
                  ownerPubkey: _ownerA,
                ),
              );
        }

        await expectLater(insertDuplicateLive(), throwsA(isA<Exception>()));
      },
    );

    test(
      'partial unique index allows unlimited deleted rows for one tuple',
      () async {
        Future<void> insertDeleted(String id) {
          return database
              .into(database.dmMessageReactions)
              .insert(
                DmMessageReactionsCompanion.insert(
                  id: id,
                  conversationId: _conversationId,
                  targetMessageId: _targetMessageId,
                  targetMessageAuthor: _targetAuthor,
                  reactorPubkey: _reactorA,
                  emoji: '🔥',
                  createdAt: 1_700_000_000,
                  ownerPubkey: _ownerA,
                  isDeleted: const Value(true),
                ),
              );
        }

        await insertPending(); // one live
        await insertDeleted(_sentId); // deleted dup — allowed
        await insertDeleted(
          '4444444444444444444444444444444444444444444444444444444444444444',
        );

        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live, hasLength(1));
      },
    );

    test(
      'insertOwnReactionSuperseding resurrects a soft-deleted same-id row so '
      'a same-second re-react is not silently dropped',
      () async {
        // React, remove (soft-delete), then re-react the same emoji within the
        // same wall-clock second: the rebuilt rumor id is identical, so the
        // insert collides with the just-deleted row's primary key.
        await insertPending();
        await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );

        final superseded = await insertPending();

        expect(superseded, isEmpty);
        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row, isNotNull);
        expect(row!.isDeleted, isFalse);
        expect(row.publishStatus, equals('pending'));
        expect(row.rumorEventJson, contains(_pendingId));

        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['🔥']));
      },
    );

    test(
      "watchForConversation exposes only the owner's refused removal",
      () async {
        await insertPending();
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );
        await dao.markDeletionRefused(id: _pendingId, ownerPubkey: _ownerA);

        const incomingId =
            'abababababababababababababababababababababababababababababababab';
        await dao.upsertIncoming(
          id: incomingId,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _ownerA,
          reactorPubkey: _reactorB,
          emoji: '👍',
          createdAt: 1_700_000_010,
          giftWrapId: incomingId,
          ownerPubkey: _ownerA,
        );
        await dao.softDelete(id: incomingId, ownerPubkey: _ownerA);
        await (database.update(database.dmMessageReactions)..where(
              (t) => t.id.equals(incomingId) & t.ownerPubkey.equals(_ownerA),
            ))
            .write(
              const DmMessageReactionsCompanion(
                publishStatus: Value(DmReactionsDao.deletionRefused),
              ),
            );

        final visible = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(visible.map((row) => row.id), equals([_pendingId]));
      },
    );

    test(
      'insertOwnReactionSuperseding leaves a still-live same-id row untouched '
      'so an idempotent double-tap keeps its publish status',
      () async {
        await insertPending();
        await dao.swapPlaceholderId(
          placeholderId: _pendingId,
          realRumorId: _pendingId,
          ownerPubkey: _ownerA,
        );
        expect(
          (await dao.getById(
            id: _pendingId,
            ownerPubkey: _ownerA,
          ))!.publishStatus,
          equals('sent'),
        );

        final superseded = await insertPending();

        expect(superseded, isEmpty);
        // Resurrect is scoped to deleted rows, so the live 'sent' row is not
        // regressed to 'pending' and its cleared rumor json stays cleared.
        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row!.isDeleted, isFalse);
        expect(row.publishStatus, equals('sent'));
        expect(row.rumorEventJson, isNull);
      },
    );

    test(
      'insertOwnReactionSuperseding resurrects a deleted same-id row while a '
      'different-id live sibling exists, staying capped at one live row',
      () async {
        // Deleted same-id row (🔥) coexisting with a live different-id row
        // (😂): re-reacting 🔥 must supersede the sibling BEFORE resurrecting,
        // or the partial unique index would reject two live rows for the tuple.
        await insertPending();
        await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
        await insertPending(
          id: _sentId,
          emoji: '😂',
          createdAt: 1_700_000_010,
        );

        final superseded = await insertPending();

        expect(superseded, equals([_sentId]));
        expect(
          (await dao.getById(id: _pendingId, ownerPubkey: _ownerA))!.isDeleted,
          isFalse,
        );
        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.emoji), equals(['🔥']));
      },
    );

    test('swapPlaceholderId marks row sent and clears stored rumor', () async {
      await insertPending();

      await dao.swapPlaceholderId(
        placeholderId: _pendingId,
        realRumorId: _sentId,
        ownerPubkey: _ownerA,
        giftWrapId: _giftWrapId,
      );

      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
      final row = await dao.getById(id: _sentId, ownerPubkey: _ownerA);
      expect(row, isNotNull);
      expect(row!.publishStatus, equals('sent'));
      expect(row.rumorEventJson, isNull);
      expect(row.giftWrapId, equals(_giftWrapId));
    });

    test('markFailed and markPending transition publish status', () async {
      await insertPending();

      await dao.markFailed(placeholderId: _pendingId, ownerPubkey: _ownerA);
      expect(
        (await dao.getById(
          id: _pendingId,
          ownerPubkey: _ownerA,
        ))!.publishStatus,
        equals('failed'),
      );

      await dao.markPending(id: _pendingId, ownerPubkey: _ownerA);
      expect(
        (await dao.getById(
          id: _pendingId,
          ownerPubkey: _ownerA,
        ))!.publishStatus,
        equals('pending'),
      );
    });

    test(
      'markBlocked marks the row blocked, clears rumor json, and drops it '
      'from the retryable set so the sweep and a re-tap never re-drive it',
      () async {
        await insertPending();

        await dao.markBlocked(id: _pendingId, ownerPubkey: _ownerA);

        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row!.publishStatus, equals('blocked'));
        expect(
          row.rumorEventJson,
          isNull,
          reason: 'A blocked send is terminal; no rumor is kept for retry.',
        );
        // Still live (not soft-deleted) so it renders as a settled own chip.
        expect(row.isDeleted, isFalse);

        final retryable = await dao.getRetryableOwnReactions(
          ownerPubkey: _ownerA,
        );
        expect(
          retryable.map((r) => r.id),
          isNot(contains(_pendingId)),
          reason:
              'blocked is neither failed nor pending, and has no rumor '
              'json — excluded on both predicates.',
        );
      },
    );

    test(
      'getRetryableOwnReactions returns failed and pending own reactions '
      'with stored rumor json',
      () async {
        // A pending own reaction (interrupted send).
        await insertPending();

        // A failed own reaction on a different target message.
        const failedId =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const otherTarget =
            '3333333333333333333333333333333333333333333333333333333333333333';
        await dao.insertOwnReactionSuperseding(
          placeholderId: failedId,
          conversationId: _conversationId,
          targetMessageId: otherTarget,
          targetMessageAuthor: _targetAuthor,
          reactorPubkey: _reactorA,
          emoji: '😀',
          createdAt: 1_700_000_100,
          ownerPubkey: _ownerA,
          rumorEventJson: '{"id":"$failedId"}',
        );
        await dao.markFailed(placeholderId: failedId, ownerPubkey: _ownerA);

        final retryable = await dao.getRetryableOwnReactions(
          ownerPubkey: _ownerA,
        );

        expect(
          retryable.map((r) => r.id),
          containsAll(<String>[_pendingId, failedId]),
        );
        expect(retryable.every((r) => r.rumorEventJson != null), isTrue);
      },
    );

    test(
      'getRetryableOwnReactions excludes sent, deleted, incoming, and other '
      "owners' reactions",
      () async {
        // Sent own reaction: swap clears json + marks sent.
        await insertPending();
        await dao.swapPlaceholderId(
          placeholderId: _pendingId,
          realRumorId: _sentId,
          ownerPubkey: _ownerA,
        );

        // Soft-deleted own reaction (superseded / removed).
        const deletedId =
            '4444444444444444444444444444444444444444444444444444444444444444';
        const deletedTarget =
            '5555555555555555555555555555555555555555555555555555555555555555';
        await dao.insertOwnReactionSuperseding(
          placeholderId: deletedId,
          conversationId: _conversationId,
          targetMessageId: deletedTarget,
          targetMessageAuthor: _targetAuthor,
          reactorPubkey: _reactorA,
          emoji: '😀',
          createdAt: 1_700_000_100,
          ownerPubkey: _ownerA,
          rumorEventJson: '{"id":"$deletedId"}',
        );
        await dao.softDelete(id: deletedId, ownerPubkey: _ownerA);

        // Incoming reaction from someone else (publishStatus null, no json).
        await dao.upsertIncoming(
          id: _giftWrapId,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _ownerA,
          reactorPubkey: _reactorB,
          emoji: '❤️',
          createdAt: 1_700_000_200,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerA,
        );

        // A pending reaction belonging to a different owner.
        await insertPending(
          ownerPubkey: _ownerB,
          reactorPubkey: _ownerB,
        );

        final retryable = await dao.getRetryableOwnReactions(
          ownerPubkey: _ownerA,
        );

        expect(retryable, isEmpty);
      },
    );

    test(
      'softDelete hides row from live queries but preserves record',
      () async {
        await insertPending(id: _sentId);

        final before = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(before, hasLength(1));

        await dao.softDelete(id: _sentId, ownerPubkey: _ownerA);

        final row = await dao.getById(id: _sentId, ownerPubkey: _ownerA);
        expect(row!.isDeleted, isTrue);
        final after = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(after, isEmpty);
      },
    );

    test(
      'markOwnDeletionPending hides the row, stores the deletion rumor, and '
      'surfaces it in getRetryableOwnDeletions (not the add retry set)',
      () async {
        await insertPending();

        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );

        // Hidden from the live chip stream.
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live, isEmpty);

        // Excluded from the ADD retry set (it is soft-deleted)...
        expect(
          await dao.getRetryableOwnReactions(ownerPubkey: _ownerA),
          isEmpty,
        );

        // ...but surfaced in the DELETION retry set, carrying the kind-5 rumor.
        final deletions = await dao.getRetryableOwnDeletions(
          ownerPubkey: _ownerA,
        );
        expect(deletions, hasLength(1));
        expect(deletions.first.id, _pendingId);
        expect(deletions.first.rumorEventJson, contains('"kind":5'));
      },
    );

    test(
      'markDeletionSent clears the deletion from the retry set',
      () async {
        await insertPending();
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );

        await dao.markDeletionSent(id: _pendingId, ownerPubkey: _ownerA);

        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerA),
          isEmpty,
        );
        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row, isNotNull);
        expect(row!.rumorEventJson, isNull);
      },
    );

    test(
      'hasOutstandingOwnDeletion finds pending and refused removals',
      () async {
        await insertPending();
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );

        expect(
          await dao.hasOutstandingOwnDeletion(
            targetMessageId: _targetMessageId,
            ownerPubkey: _ownerA,
          ),
          isTrue,
        );

        await dao.markDeletionRefused(id: _pendingId, ownerPubkey: _ownerA);

        expect(
          await dao.hasOutstandingOwnDeletion(
            targetMessageId: _targetMessageId,
            ownerPubkey: _ownerA,
          ),
          isTrue,
        );
      },
    );

    test('hasOutstandingOwnDeletion is target- and owner-scoped', () async {
      await insertPending();
      await dao.markOwnDeletionPending(
        id: _pendingId,
        ownerPubkey: _ownerA,
        deletionRumorJson: '{"kind":5}',
      );

      expect(
        await dao.hasOutstandingOwnDeletion(
          targetMessageId: _otherTargetMessageId,
          ownerPubkey: _ownerA,
        ),
        isFalse,
      );
      expect(
        await dao.hasOutstandingOwnDeletion(
          targetMessageId: _targetMessageId,
          ownerPubkey: _ownerB,
        ),
        isFalse,
      );

      await dao.markDeletionSent(id: _pendingId, ownerPubkey: _ownerA);
      expect(
        await dao.hasOutstandingOwnDeletion(
          targetMessageId: _targetMessageId,
          ownerPubkey: _ownerA,
        ),
        isFalse,
      );
    });

    test(
      'markDeletionRefused retains the rumor and surfaces a warning row '
      'without returning it to the automatic retry set',
      () async {
        await insertPending();
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );

        await dao.markDeletionRefused(
          id: _pendingId,
          ownerPubkey: _ownerA,
        );

        final row = await dao.getById(
          id: _pendingId,
          ownerPubkey: _ownerA,
        );
        expect(row!.publishStatus, DmReactionsDao.deletionRefused);
        expect(row.isDeleted, isTrue);
        expect(row.rumorEventJson, '{"kind":5}');
        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerA),
          isEmpty,
        );
        final visible = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(visible.map((reaction) => reaction.id), [_pendingId]);
      },
    );

    test(
      'getRetryableOwnDeletions is owner-scoped',
      () async {
        await insertPending(ownerPubkey: _ownerB, reactorPubkey: _ownerB);
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerB,
          deletionRumorJson: '{"kind":5}',
        );

        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerA),
          isEmpty,
        );
        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerB),
          hasLength(1),
        );
      },
    );

    test('deleteById removes failed rows entirely', () async {
      await insertPending();

      final deleted = await dao.deleteById(
        id: _pendingId,
        ownerPubkey: _ownerA,
      );

      expect(deleted, equals(1));
      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
    });

    test('upsertIncoming deduplicates by id and owner pubkey', () async {
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_000,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_001,
        giftWrapId:
            '2222222222222222222222222222222222222222222222222222222222222222',
        ownerPubkey: _ownerA,
      );

      final rows = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerA,
          )
          .first;
      expect(rows, hasLength(1));
      expect(rows.single.id, equals(_sentId));
    });

    Future<void> upsertIncoming({
      required String id,
      required int createdAt,
      String reactorPubkey = _reactorB,
      String emoji = '😂',
      String giftWrapId = _giftWrapId,
    }) {
      return dao.upsertIncoming(
        id: id,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _ownerA,
      );
    }

    test(
      'upsertIncoming with a newer rumor id supersedes the older live reaction',
      () async {
        await upsertIncoming(
          id: _sentId,
          createdAt: 1_700_000_000,
          emoji: '🔥',
        );
        await upsertIncoming(id: _pendingId, createdAt: 1_700_000_010);

        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.id), equals([_pendingId]));
        expect(live.single.emoji, equals('😂'));
      },
    );

    test(
      'upsertIncoming with an older rumor id is recorded as already-deleted',
      () async {
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_010);
        await upsertIncoming(
          id: _pendingId,
          createdAt: 1_700_000_000,
          emoji: '🔥',
        );

        // Older reaction is recorded (history + gift-wrap dedup) but deleted.
        final older = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(older, isNotNull);
        expect(older!.isDeleted, isTrue);
        final live = await dao
            .watchForConversation(
              conversationId: _conversationId,
              ownerPubkey: _ownerA,
            )
            .first;
        expect(live.map((r) => r.id), equals([_sentId]));
      },
    );

    test(
      'upsertIncoming re-arrival of a deleted reaction does not resurrect it',
      () async {
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_000);
        await dao.softDelete(id: _sentId, ownerPubkey: _ownerA);

        // Self-wrap / relay replay of the same rumor id arrives again.
        await upsertIncoming(id: _sentId, createdAt: 1_700_000_000);

        expect(
          (await dao.getById(id: _sentId, ownerPubkey: _ownerA))!.isDeleted,
          isTrue,
        );
      },
    );

    test('watchForConversation only returns live rows for one owner', () async {
      await insertPending();
      await insertPending(id: _sentId, ownerPubkey: _ownerB, emoji: '😂');
      await dao.softDelete(id: _pendingId, ownerPubkey: _ownerA);
      await dao.upsertIncoming(
        id: '3333333333333333333333333333333333333333333333333333333333333333',
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😮',
        createdAt: 1_700_000_002,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );

      final rowsA = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerA,
          )
          .first;
      final rowsB = await dao
          .watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerB,
          )
          .first;

      expect(rowsA.map((row) => row.emoji), equals(['😮']));
      expect(rowsB.map((row) => row.emoji), equals(['😂']));
    });

    test('getById and hasGiftWrap are owner scoped', () async {
      await insertPending();
      await dao.upsertIncoming(
        id: _sentId,
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '😂',
        createdAt: 1_700_000_001,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );

      final ownRow = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
      expect(ownRow!.rumorEventJson, contains(_pendingId));
      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerB), isNull);
      expect(
        await dao.hasGiftWrap(giftWrapId: _giftWrapId, ownerPubkey: _ownerA),
        isTrue,
      );
      expect(
        await dao.hasGiftWrap(giftWrapId: _giftWrapId, ownerPubkey: _ownerB),
        isFalse,
      );
    });

    test('deleteAllForOwner clears only the targeted account', () async {
      await insertPending();
      await insertPending(id: _sentId, ownerPubkey: _ownerB);

      final deleted = await dao.deleteAllForOwner(_ownerA);

      expect(deleted, equals(1));
      expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
      expect(await dao.getById(id: _sentId, ownerPubkey: _ownerB), isNotNull);
    });

    test(
      'deleteForConversations clears only selected conversations for owner',
      () async {
        const otherConversationId =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const otherConversationReactionId =
            '3333333333333333333333333333333333333333333333333333333333333333';
        const otherOwnerReactionId =
            '4444444444444444444444444444444444444444444444444444444444444444';
        const otherTargetMessageId =
            '5555555555555555555555555555555555555555555555555555555555555555';

        await insertPending();
        await insertPending(
          id: otherConversationReactionId,
          conversationId: otherConversationId,
          targetMessageId: otherTargetMessageId,
        );
        await insertPending(
          id: otherOwnerReactionId,
          ownerPubkey: _ownerB,
          reactorPubkey: _ownerB,
        );

        final deleted = await dao.deleteForConversations(
          conversationIds: [_conversationId],
          ownerPubkey: _ownerA,
        );

        expect(deleted, equals(1));
        expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
        expect(
          await dao.getById(
            id: otherConversationReactionId,
            ownerPubkey: _ownerA,
          ),
          isNotNull,
        );
        expect(
          await dao.getById(id: otherOwnerReactionId, ownerPubkey: _ownerB),
          isNotNull,
        );
      },
    );

    group('reassignForTargetMessages', () {
      test('follows the named targets to the new conversation', () async {
        await insertPending();
        await insertPending(
          id: _sentId,
          targetMessageId: _otherTargetMessageId,
          createdAt: 1_700_000_001,
        );

        final moved = await dao.reassignForTargetMessages(
          targetMessageIds: const [_targetMessageId],
          toConversationId: _otherConversationId,
          ownerPubkey: _ownerA,
        );

        expect(moved, equals(1));
        final rows = await database.select(database.dmMessageReactions).get();
        expect(
          {for (final r in rows) r.id: r.conversationId},
          equals({
            _pendingId: _otherConversationId,
            _sentId: _conversationId,
          }),
          reason: 'only the named target moves',
        );
      });

      test(
        'forgets the recipients worked out for the conversation it leaves',
        () async {
          await insertPending(recipientPubkeys: '["$_targetAuthor"]');
          expect(
            (await dao.getById(
              id: _pendingId,
              ownerPubkey: _ownerA,
            ))!.recipientPubkeys,
            isNotNull,
            reason: 'precondition: the row holds a set before it moves',
          );

          await dao.reassignForTargetMessages(
            targetMessageIds: const [_targetMessageId],
            toConversationId: _otherConversationId,
            ownerPubkey: _ownerA,
          );

          final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
          expect(row!.conversationId, equals(_otherConversationId));
          expect(row.recipientPubkeys, isNull);
        },
      );

      test("will not move another owner's reaction", () async {
        await insertPending(id: _otherOwnerReactionId, ownerPubkey: _ownerB);

        expect(
          await dao.reassignForTargetMessages(
            targetMessageIds: const [_targetMessageId],
            toConversationId: _otherConversationId,
            ownerPubkey: _ownerA,
          ),
          equals(0),
        );
      });

      test('is a no-op for an empty target list', () async {
        expect(
          await dao.reassignForTargetMessages(
            targetMessageIds: const [],
            toConversationId: _otherConversationId,
            ownerPubkey: _ownerA,
          ),
          equals(0),
        );
      });
    });

    group('adoptReceivedForTargetMessage', () {
      /// A reaction by another account, as the receive path stores it.
      Future<void> receive({
        String id = _sentId,
        String conversationId = _conversationId,
        String targetMessageId = _targetMessageId,
        String ownerPubkey = _ownerA,
      }) => dao.upsertIncoming(
        id: id,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorB,
        emoji: '🔥',
        createdAt: 1_700_000_000,
        giftWrapId: _giftWrapId,
        ownerPubkey: ownerPubkey,
      );

      Future<int> adopt() => dao.adoptReceivedForTargetMessage(
        targetMessageId: _targetMessageId,
        toConversationId: _otherConversationId,
        ownerPubkey: _ownerA,
      );

      test('moves a received reaction out of another conversation', () async {
        await receive();

        expect(await adopt(), equals(1));
        final row = await dao.getById(id: _sentId, ownerPubkey: _ownerA);
        expect(row!.conversationId, equals(_otherConversationId));
      });

      test('leaves a received reaction already in that conversation', () async {
        await receive(conversationId: _otherConversationId);

        expect(await adopt(), equals(0));
      });

      test('leaves a received reaction to another message alone', () async {
        await receive();
        await receive(
          id: _otherConversationReactionId,
          targetMessageId: _otherTargetMessageId,
        );

        expect(
          await adopt(),
          equals(1),
          reason: 'only the reaction to the named message moves',
        );
        final other = await dao.getById(
          id: _otherConversationReactionId,
          ownerPubkey: _ownerA,
        );
        expect(other!.conversationId, equals(_conversationId));
      });

      test(
        'leaves an own queued reaction and its stored recipients alone',
        () async {
          await receive();
          await insertPending(recipientPubkeys: _recipients);

          expect(
            await adopt(),
            equals(1),
            reason: 'only the received reaction moves',
          );
          final queued = await dao.getById(
            id: _pendingId,
            ownerPubkey: _ownerA,
          );
          expect(queued!.conversationId, equals(_conversationId));
          expect(queued.recipientPubkeys, equals(_recipients));
        },
      );

      test("will not move another owner's reaction", () async {
        await receive(ownerPubkey: _ownerB);

        expect(await adopt(), equals(0));
        final row = await dao.getById(id: _sentId, ownerPubkey: _ownerB);
        expect(row!.conversationId, equals(_conversationId));
      });
    });

    group('removed-conversation tombstone suppression', () {
      /// The `createdAt` [insertPending] uses by default.
      const reactionAt = 1_700_000_000;

      Future<void> recordTombstone({
        required int removedAt,
        String conversationId = _conversationId,
        String ownerPubkey = _ownerA,
      }) {
        return database.removedConversationsDao.record(
          conversationId: conversationId,
          ownerPubkey: ownerPubkey,
          removedAt: removedAt,
        );
      }

      test(
        'a reaction stranded by an older removal is not retryable',
        () async {
          await insertPending();
          await recordTombstone(removedAt: reactionAt);

          expect(
            await dao.getRetryableOwnReactions(ownerPubkey: _ownerA),
            isEmpty,
            reason:
                'a removal at or after the reaction must take it out of the '
                'sweep, so it can never be published into the removed thread',
          );
        },
      );

      test('a reaction created after the removal stays retryable', () async {
        await insertPending(createdAt: reactionAt + 500);
        await recordTombstone(removedAt: reactionAt);

        expect(
          await dao.getRetryableOwnReactions(ownerPubkey: _ownerA),
          hasLength(1),
          reason:
              'the counterparty recreated the conversation after the removal; '
              'that reaction is still owed delivery',
        );
      });

      test("another owner's tombstone does not suppress this owner", () async {
        await insertPending();
        await recordTombstone(removedAt: reactionAt, ownerPubkey: _ownerB);

        expect(
          await dao.getRetryableOwnReactions(ownerPubkey: _ownerA),
          hasLength(1),
        );
      });

      test(
        "another conversation's tombstone does not suppress this one",
        () async {
          await insertPending();
          await recordTombstone(
            removedAt: reactionAt,
            conversationId: _otherConversationId,
          );

          expect(
            await dao.getRetryableOwnReactions(ownerPubkey: _ownerA),
            hasLength(1),
          );
        },
      );

      test('a pending kind-5 removal is suppressed the same way', () async {
        await insertPending();
        await dao.markOwnDeletionPending(
          id: _pendingId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );
        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerA),
          hasLength(1),
        );

        await recordTombstone(removedAt: reactionAt);

        expect(
          await dao.getRetryableOwnDeletions(ownerPubkey: _ownerA),
          isEmpty,
        );
      });

      test('deleteSuppressedByRemoval purges only stranded rows', () async {
        await insertPending();
        await insertPending(
          id: _otherConversationReactionId,
          conversationId: _otherConversationId,
          targetMessageId: _otherTargetMessageId,
        );
        await recordTombstone(removedAt: reactionAt);

        final purged = await dao.deleteSuppressedByRemoval(
          ownerPubkey: _ownerA,
        );

        expect(purged, equals(1));
        expect(await dao.getById(id: _pendingId, ownerPubkey: _ownerA), isNull);
        expect(
          await dao.getById(
            id: _otherConversationReactionId,
            ownerPubkey: _ownerA,
          ),
          isNotNull,
        );
      });

      test('deleteSuppressedByRemoval keeps post-removal rows', () async {
        await insertPending(createdAt: reactionAt + 500);
        await recordTombstone(removedAt: reactionAt);

        expect(
          await dao.deleteSuppressedByRemoval(ownerPubkey: _ownerA),
          isZero,
        );
        expect(
          await dao.getById(id: _pendingId, ownerPubkey: _ownerA),
          isNotNull,
        );
      });

      test('deleteSuppressedByRemoval is owner-scoped', () async {
        await insertPending();
        await insertPending(
          id: _otherOwnerReactionId,
          ownerPubkey: _ownerB,
          reactorPubkey: _ownerB,
        );
        await recordTombstone(removedAt: reactionAt);
        await recordTombstone(removedAt: reactionAt, ownerPubkey: _ownerB);

        expect(
          await dao.deleteSuppressedByRemoval(ownerPubkey: _ownerA),
          equals(1),
        );
        expect(
          await dao.getById(id: _otherOwnerReactionId, ownerPubkey: _ownerB),
          isNotNull,
        );
      });
    });

    test('deleteForConversations is a no-op for an empty id list', () async {
      await insertPending();

      final deleted = await dao.deleteForConversations(
        conversationIds: const [],
        ownerPubkey: _ownerA,
      );

      expect(deleted, equals(0));
      expect(
        await dao.getById(id: _pendingId, ownerPubkey: _ownerA),
        isNotNull,
      );
    });

    test(
      'deleteNonRetryableForOwner preserves outgoing retry rows only',
      () async {
        const failedId =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const deletionId =
            '3333333333333333333333333333333333333333333333333333333333333333';
        const incomingId =
            '4444444444444444444444444444444444444444444444444444444444444444';
        const blockedId =
            '5555555555555555555555555555555555555555555555555555555555555555';
        const otherOwnerId =
            '6666666666666666666666666666666666666666666666666666666666666666';
        const refusedId =
            'abababababababababababababababababababababababababababababababab';
        const target2 =
            '7777777777777777777777777777777777777777777777777777777777777777';
        const target3 =
            '8888888888888888888888888888888888888888888888888888888888888888';
        const target4 =
            '9999999999999999999999999999999999999999999999999999999999999999';
        const target5 =
            'acacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacac';

        await insertPending();
        await insertPending(id: failedId, targetMessageId: target2);
        await dao.markFailed(placeholderId: failedId, ownerPubkey: _ownerA);
        await insertPending(id: deletionId, targetMessageId: target3);
        await dao.markOwnDeletionPending(
          id: deletionId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );
        await insertPending(id: blockedId, targetMessageId: target4);
        await dao.markBlocked(id: blockedId, ownerPubkey: _ownerA);
        await insertPending(id: refusedId, targetMessageId: target5);
        await dao.markOwnDeletionPending(
          id: refusedId,
          ownerPubkey: _ownerA,
          deletionRumorJson: '{"kind":5}',
        );
        await dao.markDeletionRefused(id: refusedId, ownerPubkey: _ownerA);
        await dao.upsertIncoming(
          id: incomingId,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _targetAuthor,
          reactorPubkey: _reactorB,
          emoji: '😂',
          createdAt: 1_700_000_200,
          giftWrapId: incomingId,
          ownerPubkey: _ownerA,
        );
        await insertPending(
          id: otherOwnerId,
          ownerPubkey: _ownerB,
          reactorPubkey: _ownerB,
        );

        final deleted = await dao.deleteNonRetryableForOwner(_ownerA);

        expect(deleted, equals(2));
        expect(
          await dao.getById(id: _pendingId, ownerPubkey: _ownerA),
          isNotNull,
        );
        expect(
          await dao.getById(id: failedId, ownerPubkey: _ownerA),
          isNotNull,
        );
        expect(
          await dao.getById(id: deletionId, ownerPubkey: _ownerA),
          isNotNull,
        );
        expect(
          await dao.getById(id: refusedId, ownerPubkey: _ownerA),
          isNotNull,
        );
        expect(await dao.getById(id: incomingId, ownerPubkey: _ownerA), isNull);
        expect(await dao.getById(id: blockedId, ownerPubkey: _ownerA), isNull);
        expect(
          await dao.getById(id: otherOwnerId, ownerPubkey: _ownerB),
          isNotNull,
        );
      },
    );

    group('upsertIncoming of an own queued reaction', () {
      /// The reaction's own self-wrap echo, filing it under [conversationId].
      Future<void> echoUnder(String conversationId) => dao.upsertIncoming(
        id: _pendingId,
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _targetAuthor,
        reactorPubkey: _reactorA,
        emoji: '🔥',
        createdAt: 1_700_000_000,
        giftWrapId: _giftWrapId,
        ownerPubkey: _ownerA,
      );

      test(
        'keeps the conversation it was queued in when it has no recipients',
        () async {
          await insertPending();

          await echoUnder(_otherConversationId);

          final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
          expect(row!.conversationId, equals(_conversationId));
          expect(row.giftWrapId, equals(_giftWrapId));
        },
      );

      test('follows the message when it has stored recipients', () async {
        await insertPending(recipientPubkeys: '["$_targetAuthor"]');

        await echoUnder(_otherConversationId);

        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row!.conversationId, equals(_otherConversationId));
      });

      test('follows the message once it has been sent', () async {
        await insertPending();
        await dao.swapPlaceholderId(
          placeholderId: _pendingId,
          realRumorId: _pendingId,
          ownerPubkey: _ownerA,
        );

        await echoUnder(_otherConversationId);

        final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
        expect(row!.recipientPubkeys, isNull);
        expect(row.conversationId, equals(_otherConversationId));
      });
    });

    group('insertOwnReactionSuperseding recipients', () {
      test(
        'a queued reaction keeps the recipients it was queued with',
        () async {
          await insertPending(recipientPubkeys: _recipients);

          final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
          expect(row!.recipientPubkeys, equals(_recipients));
        },
      );

      test(
        're-reacting onto a removed row stores the recipients given this time',
        () async {
          await insertPending();
          await dao.markOwnDeletionPending(
            id: _pendingId,
            ownerPubkey: _ownerA,
            deletionRumorJson: '{"kind":5}',
          );

          await insertPending(recipientPubkeys: _recipients);

          final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
          expect(row!.isDeleted, isFalse);
          expect(row.recipientPubkeys, equals(_recipients));
        },
      );

      test(
        're-reacting onto a removed row without recipients keeps the ones it '
        'holds',
        () async {
          await insertPending(recipientPubkeys: _recipients);
          await dao.markOwnDeletionPending(
            id: _pendingId,
            ownerPubkey: _ownerA,
            deletionRumorJson: '{"kind":5}',
          );

          await insertPending();

          final row = await dao.getById(id: _pendingId, ownerPubkey: _ownerA);
          expect(row!.isDeleted, isFalse);
          expect(row.recipientPubkeys, equals(_recipients));
        },
      );
    });

    group('setRecipientPubkeysIfMissing', () {
      test(
        'fills a row that has none and leaves a stored set alone',
        () async {
          const other = '["$_reactorB"]';
          await insertPending();
          await insertPending(
            id: _sentId,
            targetMessageId: _otherTargetMessageId,
            recipientPubkeys: _recipients,
          );

          final filled = await dao.setRecipientPubkeysIfMissing(
            id: _pendingId,
            ownerPubkey: _ownerA,
            conversationId: _conversationId,
            recipientPubkeys: other,
          );
          final kept = await dao.setRecipientPubkeysIfMissing(
            id: _sentId,
            ownerPubkey: _ownerA,
            conversationId: _conversationId,
            recipientPubkeys: other,
          );

          expect(filled, equals(1));
          expect(kept, equals(0));
          expect(
            (await dao.getById(
              id: _pendingId,
              ownerPubkey: _ownerA,
            ))!.recipientPubkeys,
            equals(other),
          );
          expect(
            (await dao.getById(
              id: _sentId,
              ownerPubkey: _ownerA,
            ))!.recipientPubkeys,
            equals(_recipients),
          );
        },
      );

      test('writes only the row it names', () async {
        await insertPending();
        await insertPending(
          id: _sentId,
          targetMessageId: _otherTargetMessageId,
        );

        await dao.setRecipientPubkeysIfMissing(
          id: _pendingId,
          ownerPubkey: _ownerA,
          conversationId: _conversationId,
          recipientPubkeys: _recipients,
        );

        expect(
          (await dao.getById(
            id: _pendingId,
            ownerPubkey: _ownerA,
          ))!.recipientPubkeys,
          equals(_recipients),
        );
        expect(
          (await dao.getById(
            id: _sentId,
            ownerPubkey: _ownerA,
          ))!.recipientPubkeys,
          isNull,
        );
      });

      test("leaves another owner's row", () async {
        await insertPending(ownerPubkey: _ownerB, reactorPubkey: _ownerB);

        final written = await dao.setRecipientPubkeysIfMissing(
          id: _pendingId,
          ownerPubkey: _ownerA,
          conversationId: _conversationId,
          recipientPubkeys: _recipients,
        );

        expect(written, equals(0));
        expect(
          (await dao.getById(
            id: _pendingId,
            ownerPubkey: _ownerB,
          ))!.recipientPubkeys,
          isNull,
        );
      });

      test(
        'leaves a row that has left the conversation the set was worked out '
        'for',
        () async {
          await insertPending();
          await dao.reassignForTargetMessages(
            targetMessageIds: const [_targetMessageId],
            toConversationId: _otherConversationId,
            ownerPubkey: _ownerA,
          );

          final forTheOldConversation = await dao.setRecipientPubkeysIfMissing(
            id: _pendingId,
            ownerPubkey: _ownerA,
            conversationId: _conversationId,
            recipientPubkeys: _recipients,
          );
          final forTheNewConversation = await dao.setRecipientPubkeysIfMissing(
            id: _pendingId,
            ownerPubkey: _ownerA,
            conversationId: _otherConversationId,
            recipientPubkeys: _recipients,
          );

          expect(forTheOldConversation, equals(0));
          expect(forTheNewConversation, equals(1));
        },
      );
    });

    group('getOwnQueuedRowsMissingRecipients', () {
      test(
        "lists only this owner's unsent rows that have no recipients",
        () async {
          final removalId = '6' * 64;
          final withRecipientsId = '7' * 64;
          final incomingId = '8' * 64;
          final target2 = '9' * 64;
          final target3 = 'a1' * 32;
          final target4 = 'b2' * 32;

          // Listed: a queued add and a queued removal, neither with recipients.
          await insertPending();
          await insertPending(id: removalId, targetMessageId: target2);
          await dao.markOwnDeletionPending(
            id: removalId,
            ownerPubkey: _ownerA,
            deletionRumorJson: '{"kind":5}',
          );
          // Not listed: already has recipients.
          await insertPending(
            id: withRecipientsId,
            targetMessageId: target3,
            recipientPubkeys: _recipients,
          );
          // Not listed: sent, so there is nothing left to send.
          await insertPending(id: _sentId, targetMessageId: target4);
          await dao.swapPlaceholderId(
            placeholderId: _sentId,
            realRumorId: _sentId,
            ownerPubkey: _ownerA,
          );
          // Not listed: a row carrying a rumor, reacted by somebody else.
          await insertPending(
            id: incomingId,
            reactorPubkey: _reactorB,
            emoji: '😂',
          );
          // Not listed: another account's row, even one this owner reacted.
          await insertPending(
            id: _otherOwnerReactionId,
            ownerPubkey: _ownerB,
          );

          final rows = await dao.getOwnQueuedRowsMissingRecipients(
            ownerPubkey: _ownerA,
          );

          expect(
            rows.map((row) => row.id),
            unorderedEquals([_pendingId, removalId]),
          );
        },
      );
    });
  });
}
