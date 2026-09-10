// ABOUTME: End-to-end regression test for #6020/#6123: a database from a
// ABOUTME: build that pre-dates personal_reactions.addressable_id self-heals
// ABOUTME: through the production initialize() path, and the backfilled
// ABOUTME: coordinate survives an offline restart.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {}

void main() {
  group('LikesRepository pre-column DB self-heal (#6020)', () {
    late AppDatabase database;
    late String tempDbPath;

    const testUserPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const oldEditEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const newEditEventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const reactionEventId =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const coordinate = '34236:$testUserPubkey:test-d-tag';
    const reactionCreatedAt = 1700000000;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync(
        'likes_repo_db_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    });

    tearDown(() async {
      await database.close();
      final dir = File(tempDbPath).parent;
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    MockEvent createReaction() {
      final event = MockEvent();
      when(() => event.id).thenReturn(reactionEventId);
      when(() => event.pubkey).thenReturn(testUserPubkey);
      when(() => event.kind).thenReturn(EventKind.reaction);
      when(() => event.content).thenReturn('+');
      when(() => event.createdAt).thenReturn(reactionCreatedAt);
      when(() => event.tags).thenReturn([
        ['e', oldEditEventId],
        ['a', coordinate],
      ]);
      return event;
    }

    MockNostrClient createClient() {
      final client = MockNostrClient();
      when(() => client.publicKey).thenReturn(testUserPubkey);
      when(client.resolvePublicKey).thenAnswer((_) async => testUserPubkey);
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => client.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      return client;
    }

    test(
      'a pre-addressable_id-column database self-heals through initialize() '
      'and the backfill survives an offline restart',
      () async {
        // 1. Legacy install: the like row exists, the addressable_id
        // column does not (same recipe as db_client's upgrade-path test).
        await database.personalReactionsDao.upsertReaction(
          targetEventId: oldEditEventId,
          reactionEventId: reactionEventId,
          userPubkey: testUserPubkey,
          createdAt: reactionCreatedAt,
        );
        await database.customStatement(
          'DROP INDEX idx_personal_reactions_addressable_id',
        );
        await database.customStatement(
          'ALTER TABLE personal_reactions DROP COLUMN addressable_id',
        );
        await database.close();

        // 2. App upgrade: beforeOpen re-adds the column, null for the
        // legacy row.
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        // 3. Cold start through the production init path only — never call
        // syncUserReactions directly. The relay carries the same reaction
        // with its `a` tag, at the same createdAt (never *newer*), so only
        // the same-id backfill exemption can re-derive the coordinate.
        final client = createClient();
        var queryCall = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async {
          queryCall++;
          return (
            events: queryCall == 1 ? [createReaction()] : <Event>[],
            timedOut: false,
            noRelays: false,
            anyRelayAnswered: false,
            unsettledRelays: const <String>[],
          );
        });
        final repository = LikesRepository(
          nostrClient: client,
          localStorage: DbLikesLocalStorage(
            dao: database.personalReactionsDao,
            userPubkey: testUserPubkey,
          ),
        );
        await repository.initialize();

        expect(
          await repository.isLikedResolvingCoordinate(
            eventId: newEditEventId,
            addressableId: coordinate,
          ),
          isTrue,
        );
        repository.dispose();

        // The backfill was persisted, not just cached in memory.
        final persisted = await database.personalReactionsDao
            .getReactionByAddressableId(
              addressableId: coordinate,
              userPubkey: testUserPubkey,
            );
        expect(persisted, isNotNull);
        expect(persisted!.targetEventId, equals(oldEditEventId));

        // 4. Offline restart over the same database: startup reconciliation
        // fails open, and the persisted coordinate still resolves without
        // making ordinary local state depend on relay availability.
        final offlineClient = createClient();
        when(
          () => offlineClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenThrow(Exception('offline'));
        final restarted = LikesRepository(
          nostrClient: offlineClient,
          localStorage: DbLikesLocalStorage(
            dao: database.personalReactionsDao,
            userPubkey: testUserPubkey,
          ),
        );
        await restarted.initialize();

        expect(
          await restarted.isLikedResolvingCoordinate(
            eventId: newEditEventId,
            addressableId: coordinate,
          ),
          isTrue,
        );
        verify(
          () => offlineClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).called(1);
        restarted.dispose();
      },
    );
  });
}
