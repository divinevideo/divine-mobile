// ABOUTME: Persists owner-scoped followers for offline relationship lookups.
// ABOUTME: Supports monotonic merges and transactional reconciliation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'my_followers_dao.g.dart';

/// Local follower relationships belonging to each signed-in account.
@DriftAccessor(tables: [MyFollowers])
class MyFollowersDao extends DatabaseAccessor<AppDatabase>
    with _$MyFollowersDaoMixin {
  /// Creates a DAO for [attachedDatabase].
  MyFollowersDao(super.attachedDatabase);

  static const _candidateChunkSize = 500;

  /// Returns the owner's followers, newest known follow first, then pubkey.
  Future<List<({String pubkey, int? followedAt})>> followersOf(
    String ownerPubkey,
  ) async {
    final rows =
        await (select(myFollowers)
              ..where((t) => t.ownerPubkey.equals(ownerPubkey))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.followedAt,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
                (t) => OrderingTerm.asc(t.followerPubkey),
              ]))
            .get();
    return [
      for (final row in rows)
        (pubkey: row.followerPubkey, followedAt: row.followedAt),
    ];
  }

  /// Intersects [candidates] with this owner's followers in bounded IN queries.
  Future<Set<String>> followerSubset({
    required String ownerPubkey,
    required Iterable<String> candidates,
  }) async {
    final keys = candidates.toSet().toList(growable: false);
    final matches = <String>{};
    for (var offset = 0; offset < keys.length; offset += _candidateChunkSize) {
      final end = offset + _candidateChunkSize;
      final chunk = keys.sublist(offset, end < keys.length ? end : keys.length);
      final query = selectOnly(myFollowers)
        ..addColumns([myFollowers.followerPubkey])
        ..where(
          myFollowers.ownerPubkey.equals(ownerPubkey) &
              myFollowers.followerPubkey.isIn(chunk),
        );
      for (final row in await query.get()) {
        matches.add(row.read(myFollowers.followerPubkey)!);
      }
    }
    return matches;
  }

  /// Merges a sync result, keeping the larger non-null follow timestamp.
  Future<void> upsertAll({
    required String ownerPubkey,
    required Iterable<({String pubkey, int? followedAt})> followers,
    required int seenAt,
  }) async {
    await batch((batch) {
      for (final follower in followers) {
        batch.insert(
          myFollowers,
          MyFollowersCompanion.insert(
            ownerPubkey: ownerPubkey,
            followerPubkey: follower.pubkey,
            followedAt: Value(follower.followedAt),
            lastSeenAt: seenAt,
          ),
          onConflict: DoUpdate<MyFollowers, MyFollower>(
            (old) => MyFollowersCompanion.custom(
              followedAt: follower.followedAt == null
                  ? old.followedAt
                  : CaseWhenExpression(
                      cases: [
                        CaseWhen(
                          old.followedAt.isNull() |
                              old.followedAt.isSmallerThanValue(
                                follower.followedAt!,
                              ),
                          then: Variable<int>(follower.followedAt),
                        ),
                      ],
                      orElse: old.followedAt,
                    ),
              lastSeenAt: Variable<int>(seenAt),
            ),
          ),
        );
      }
    });
  }

  /// Replaces one owner's complete follower snapshot atomically.
  Future<void> replaceAll({
    required String ownerPubkey,
    required Iterable<({String pubkey, int? followedAt})> followers,
    required int seenAt,
  }) {
    return transaction(() async {
      await clearAllForUser(ownerPubkey);
      await upsertAll(
        ownerPubkey: ownerPubkey,
        followers: followers,
        seenAt: seenAt,
      );
    });
  }

  /// Returns the largest known follow timestamp, or null when none is known.
  Future<int?> newestFollowedAt(String ownerPubkey) async {
    final newest = myFollowers.followedAt.max();
    final query = selectOnly(myFollowers)
      ..addColumns([newest])
      ..where(myFollowers.ownerPubkey.equals(ownerPubkey));
    return (await query.getSingle()).read(newest);
  }

  /// Clears the departing owner's rows without touching other accounts.
  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      myFollowers,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
