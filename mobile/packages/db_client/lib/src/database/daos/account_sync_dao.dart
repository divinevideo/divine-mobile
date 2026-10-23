import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
part 'account_sync_dao.g.dart';

@DriftAccessor(
  tables: [AccountSyncRecords, NotificationReads, NotificationReadMembers],
)
class AccountSyncDao extends DatabaseAccessor<AppDatabase>
    with _$AccountSyncDaoMixin {
  AccountSyncDao(super.attachedDatabase);

  Future<List<AccountSyncRecord>> readState(String owner, String namespace) =>
      (select(accountSyncRecords)..where(
            (t) => t.ownerPubkey.equals(owner) & t.namespace.equals(namespace),
          ))
          .get();

  /// Diff records inside one transaction: growing journals do not rewrite
  /// unchanged fields or encrypted sources on every edit.
  Future<void> writeState(
    String owner,
    String namespace,
    Map<String, Map<String, String>> sections,
  ) => transaction(() async {
    final old = {
      for (final row in await readState(owner, namespace))
        (row.section, row.recordKey): row,
    };
    await batch((b) {
      for (final section in sections.entries) {
        for (final entry in section.value.entries) {
          if (old.remove((section.key, entry.key))?.value == entry.value) {
            continue;
          }
          b.insert(
            accountSyncRecords,
            AccountSyncRecordsCompanion.insert(
              ownerPubkey: owner,
              namespace: namespace,
              section: section.key,
              recordKey: entry.key,
              value: entry.value,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      for (final row in old.values) {
        b.deleteWhere(
          accountSyncRecords,
          (t) =>
              t.ownerPubkey.equals(owner) &
              t.namespace.equals(namespace) &
              t.section.equals(row.section) &
              t.recordKey.equals(row.recordKey),
        );
      }
    });
  });

  Future<List<NotificationReadRow>> readNotificationReads(String owner) =>
      (select(
        notificationReads,
      )..where((t) => t.ownerPubkey.equals(owner))).get();
  Future<List<NotificationReadMember>> readNotificationMembers(String owner) =>
      (select(
        notificationReadMembers,
      )..where((t) => t.ownerPubkey.equals(owner))).get();

  /// Pending intent survives cache eviction. Acknowledged overlays shrink to
  /// current exact raw membership, keeping replica-lag protection bounded.
  Future<void> writeNotificationReads(
    String owner,
    Set<String> read,
    Set<String> pending,
    Map<String, List<String>> members,
  ) => transaction(() async {
    final retained = {
      ...pending,
      ...read.intersection(members.values.expand((ids) => ids).toSet()),
    };
    final old = {
      for (final row in await readNotificationReads(owner))
        row.notificationId: row,
    };
    final oldMembers = {
      for (final row in await readNotificationMembers(owner))
        (row.cacheId, row.notificationId): true,
    };
    final nextMembers = {
      for (final entry in members.entries)
        for (final id in entry.value) (entry.key, id),
    };
    await batch((b) {
      for (final id in retained) {
        if (old.remove(id)?.pending == pending.contains(id)) continue;
        b.insert(
          notificationReads,
          NotificationReadsCompanion.insert(
            ownerPubkey: owner,
            notificationId: id,
            pending: pending.contains(id),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final id in old.keys) {
        b.deleteWhere(
          notificationReads,
          (t) => t.ownerPubkey.equals(owner) & t.notificationId.equals(id),
        );
      }
      for (final member in nextMembers) {
        if (oldMembers.remove(member) != null) continue;
        b.insert(
          notificationReadMembers,
          NotificationReadMembersCompanion.insert(
            ownerPubkey: owner,
            cacheId: member.$1,
            notificationId: member.$2,
          ),
        );
      }
      for (final member in oldMembers.keys) {
        b.deleteWhere(
          notificationReadMembers,
          (t) =>
              t.ownerPubkey.equals(owner) &
              t.cacheId.equals(member.$1) &
              t.notificationId.equals(member.$2),
        );
      }
    });
  });

  Future<void> clearAccount(String owner) => transaction(() async {
    await (delete(
      accountSyncRecords,
    )..where((t) => t.ownerPubkey.equals(owner))).go();
    await (delete(
      notificationReads,
    )..where((t) => t.ownerPubkey.equals(owner))).go();
    await (delete(
      notificationReadMembers,
    )..where((t) => t.ownerPubkey.equals(owner))).go();
  });
}
