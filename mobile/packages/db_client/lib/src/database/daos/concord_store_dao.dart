// ABOUTME: Stores Concord ciphertext and delivery metadata durably.
// ABOUTME: Every operation is scoped to an explicit account and room.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'concord_store_dao.g.dart';

@DriftAccessor(tables: [ConcordStoreEntries])
class ConcordStoreDao extends DatabaseAccessor<AppDatabase>
    with _$ConcordStoreDaoMixin {
  ConcordStoreDao(super.attachedDatabase);

  /// Writes sealed event data or non-secret delivery metadata.
  Future<void> put({
    required String account,
    required String scope,
    required String key,
    required String value,
  }) async {
    await into(concordStoreEntries).insertOnConflictUpdate(
      ConcordStoreEntriesCompanion.insert(
        account: account,
        scope: scope,
        key: key,
        value: value,
      ),
    );
  }

  /// Reads one account's value in a single relay/channel scope.
  Future<String?> get({
    required String account,
    required String scope,
    required String key,
  }) async {
    final row =
        await (select(concordStoreEntries)..where(
              (t) =>
                  t.account.equals(account) &
                  t.scope.equals(scope) &
                  t.key.equals(key),
            ))
            .getSingleOrNull();
    return row?.value;
  }

  /// Removes one value without touching other scopes or accounts.
  Future<void> remove({
    required String account,
    required String scope,
    required String key,
  }) async {
    await (delete(concordStoreEntries)..where(
          (t) =>
              t.account.equals(account) &
              t.scope.equals(scope) &
              t.key.equals(key),
        ))
        .go();
  }

  /// Removes an account's values across every relay and channel.
  Future<void> clearAccount(String account) async {
    await (delete(
      concordStoreEntries,
    )..where((t) => t.account.equals(account))).go();
  }
}
