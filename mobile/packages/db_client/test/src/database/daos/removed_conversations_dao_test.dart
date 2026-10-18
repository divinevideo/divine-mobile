// ABOUTME: Tests durable, owner-scoped removed-conversation tombstones.
// ABOUTME: Tombstones prevent replayed DM history from restoring removed chats.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conversationA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conversationB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const ownerA =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const ownerB =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  late AppDatabase database;
  late RemovedConversationsDao dao;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.removedConversationsDao;
  });

  tearDown(() => database.close());

  group(RemovedConversationsDao, () {
    test('records and replaces an owner-scoped removal timestamp', () async {
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerA,
        removedAt: 100,
      );
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerA,
        removedAt: 200,
      );

      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        ),
        200,
      );
      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerB,
        ),
        isNull,
      );
    });

    test('recordAll and clearAllForUser preserve other owners', () async {
      await dao.recordAll(
        conversationIds: [conversationA, conversationB],
        ownerPubkey: ownerA,
        removedAt: 300,
      );
      await dao.record(
        conversationId: conversationA,
        ownerPubkey: ownerB,
        removedAt: 400,
      );

      expect(await dao.clearAllForUser(ownerA), 2);
      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerB,
        ),
        400,
      );
    });

    group('tombstoneFor', () {
      test('returns the removal and the rejoin', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        final tombstone = await dao.tombstoneFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.removedAt, 100);
        expect(tombstone.rejoinedAt, 150);
      });

      test('is null for a conversation that was never removed', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerB,
          ),
          isNull,
        );
      });
    });

    group('markRejoined', () {
      test('fills a rejoin the removal left empty', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        final marked = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        expect(marked, isTrue);
        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerA,
          ))!.rejoinedAt,
          150,
        );
      });

      test('keeps an earlier rejoin when a later one arrives', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        final marked = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 300,
        );

        expect(marked, isFalse);
        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerA,
          ))!.rejoinedAt,
          150,
        );
      });

      // The user's own copies arrive out of order, so the one processed
      // second can be the one written first.
      test('moves the rejoin back to an earlier one that arrives '
          'later', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 300,
        );

        final marked = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        expect(marked, isTrue);
        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerA,
          ))!.rejoinedAt,
          150,
        );
      });

      for (final at in [50, 100]) {
        test('ignores a write at $at, not after the removal at 100', () async {
          await dao.record(
            conversationId: conversationA,
            ownerPubkey: ownerA,
            removedAt: 100,
          );

          final marked = await dao.markRejoined(
            conversationId: conversationA,
            ownerPubkey: ownerA,
            at: at,
          );

          expect(marked, isFalse);
          expect(
            (await dao.tombstoneFor(
              conversationId: conversationA,
              ownerPubkey: ownerA,
            ))!.rejoinedAt,
            isNull,
          );
        });
      }

      test('does not move a rejoin back to or before the removal', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 300,
        );

        final marked = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 100,
        );

        expect(marked, isFalse);
        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerA,
          ))!.rejoinedAt,
          300,
        );
      });

      test(
        'records nothing for a conversation that was never removed',
        () async {
          final marked = await dao.markRejoined(
            conversationId: conversationA,
            ownerPubkey: ownerA,
            at: 150,
          );

          expect(marked, isFalse);
          expect(
            await dao.tombstoneFor(
              conversationId: conversationA,
              ownerPubkey: ownerA,
            ),
            isNull,
          );
        },
      );

      test("leaves another owner's removal untouched", () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerB,
          removedAt: 100,
        );

        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerB,
          ))!.rejoinedAt,
          isNull,
        );
      });
    });

    group('removing again', () {
      test('record clears an earlier rejoin', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 200,
        );

        final tombstone = await dao.tombstoneFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        );
        expect(tombstone!.removedAt, 200);
        expect(tombstone.rejoinedAt, isNull);
      });

      test('counts only a rejoin after the latest removal', () async {
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );
        await dao.record(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          removedAt: 200,
        );

        // A late copy of the write that rejoined after the first removal.
        final stale = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );
        final fresh = await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 250,
        );

        expect(stale, isFalse);
        expect(fresh, isTrue);
        expect(
          (await dao.tombstoneFor(
            conversationId: conversationA,
            ownerPubkey: ownerA,
          ))!.rejoinedAt,
          250,
        );
      });

      test('recordAll clears an earlier rejoin', () async {
        await dao.recordAll(
          conversationIds: [conversationA, conversationB],
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.markRejoined(
          conversationId: conversationA,
          ownerPubkey: ownerA,
          at: 150,
        );

        await dao.recordAll(
          conversationIds: [conversationA],
          ownerPubkey: ownerA,
          removedAt: 200,
        );

        final tombstone = await dao.tombstoneFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        );
        expect(tombstone!.removedAt, 200);
        expect(tombstone.rejoinedAt, isNull);
      });
    });

    test('transaction rollback does not leave a tombstone', () async {
      await expectLater(
        database.transaction(() async {
          await dao.record(
            conversationId: conversationA,
            ownerPubkey: ownerA,
            removedAt: 500,
          );
          throw StateError('rollback');
        }),
        throwsStateError,
      );

      expect(
        await dao.removedAtFor(
          conversationId: conversationA,
          ownerPubkey: ownerA,
        ),
        isNull,
      );
    });
  });
}
