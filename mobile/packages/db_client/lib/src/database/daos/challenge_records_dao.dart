import 'dart:math';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'challenge_records_dao.g.dart';

/// A revoked session must be replaced through the active account provider.
class ChallengeOwnerRevoked implements Exception {
  const ChallengeOwnerRevoked();
}

/// All writes check the durable generation inside the same transaction as the
/// mutation. The check is independent of the caller's in-memory account test.
@DriftAccessor(tables: [ChallengeOwners, ChallengeRecords])
class ChallengeRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$ChallengeRecordsDaoMixin {
  ChallengeRecordsDao(super.attachedDatabase);

  static String _generation() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String> openOwner(String owner) => transaction(() async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(owner)) {
      throw ArgumentError.value(owner, 'owner', 'Expected full public key');
    }
    await into(challengeOwners).insert(
      ChallengeOwnersCompanion.insert(
        ownerPubkey: owner,
        generation: _generation(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return (await (select(
      challengeOwners,
    )..where((t) => t.ownerPubkey.equals(owner))).getSingle()).generation;
  });

  Future<void> checkOwner(String owner, String generation) async {
    final row =
        await (select(challengeOwners)..where(
              (t) =>
                  t.ownerPubkey.equals(owner) & t.generation.equals(generation),
            ))
            .getSingleOrNull();
    if (row == null) throw const ChallengeOwnerRevoked();
  }

  Future<List<ChallengeRecord>> read(
    String owner,
    String generation,
    String category,
  ) => transaction(() async {
    await checkOwner(owner, generation);
    return (select(challengeRecords)..where(
          (t) =>
              t.ownerPubkey.equals(owner) &
              t.generation.equals(generation) &
              t.category.equals(category),
        ))
        .get();
  });

  /// Atomically inserts, or updates metadata while preserving original signed
  /// bytes. [insertOnly] returns the winner of a racing first insertion.
  Future<String> put(
    String owner,
    String generation,
    String category,
    String key,
    String payload, {
    String? signedBody,
    bool insertOnly = false,
  }) => transaction(() async {
    await checkOwner(owner, generation);
    final query = select(challengeRecords)
      ..where(
        (t) =>
            t.ownerPubkey.equals(owner) &
            t.category.equals(category) &
            t.recordKey.equals(key),
      );
    final old = await query.getSingleOrNull();
    if (old != null && insertOnly) return old.payload;
    if (old != null && old.signedBody != signedBody) {
      throw StateError('Signed challenge bytes are immutable');
    }
    await into(challengeRecords).insertOnConflictUpdate(
      ChallengeRecordsCompanion.insert(
        ownerPubkey: owner,
        generation: generation,
        category: category,
        recordKey: key,
        payload: payload,
        signedBody: Value(signedBody),
      ),
    );
    return payload;
  });

  Future<void> remove(
    String owner,
    String generation,
    String category,
    String key,
  ) => transaction(() async {
    await checkOwner(owner, generation);
    await (delete(challengeRecords)..where(
          (t) =>
              t.ownerPubkey.equals(owner) &
              t.category.equals(category) &
              t.recordKey.equals(key),
        ))
        .go();
  });

  /// Account deletion and revocation commit together. A re-added account opens
  /// a new generation; old asynchronous work remains revoked permanently.
  Future<void> removeOwner(String owner) => transaction(() async {
    await (delete(
      challengeOwners,
    )..where((t) => t.ownerPubkey.equals(owner))).go();
    await (delete(
      challengeRecords,
    )..where((t) => t.ownerPubkey.equals(owner))).go();
  });
}
