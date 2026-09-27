// ABOUTME: Data Access Object for the processed-gift-wrap dedup ledger.
// ABOUTME: Records terminally-processed kind-1059 wrap ids so they never
// ABOUTME: re-decrypt on a later launch. See #5452.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'processed_gift_wraps_dao.g.dart';

@DriftAccessor(tables: [ProcessedGiftWraps])
class ProcessedGiftWrapsDao extends DatabaseAccessor<AppDatabase>
    with _$ProcessedGiftWrapsDaoMixin {
  ProcessedGiftWrapsDao(super.attachedDatabase);

  /// Has the gift wrap [giftWrapId] already been terminally processed?
  ///
  /// Global (NOT owner-scoped): gift-wrap event ids are globally unique, so a
  /// wrap processed under any local account dedups for all of them — matching
  /// [DirectMessagesDao.hasGiftWrap].
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(processedGiftWraps.giftWrapId.equals(giftWrapId))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Has [giftWrapId] been terminally processed *by [ownerPubkey]*?
  ///
  /// [hasGiftWrap] answers "has any local account handled this", which is the
  /// right question for deciding whether to pay a decrypt again. This answers
  /// "did THIS account handle it", which is the right question for deciding
  /// whether the account may move its own sync boundary past the event.
  ///
  /// The global form rests on a gift-wrap id being unique to one recipient,
  /// which holds for kind 1059 because NIP-59 mints a fresh ephemeral key and
  /// a separate wrap per recipient. It does not hold for an unwrapped kind 4,
  /// whose single event id is shared by sender and recipient — so when both
  /// are accounts on this device the ledger genuinely holds one id for two
  /// accounts. See #8209 for why moving a boundary for a message this account
  /// never stored is permanent damage.
  ///
  /// Rows with no owner are treated as this account's, matching
  /// [clearForAccountSwitch] and `DirectMessagesDao`'s legacy handling, so an
  /// upgrade does not reclassify an account's own history as somebody else's.
  Future<bool> hasGiftWrapForOwner({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(
        processedGiftWraps.giftWrapId.equals(giftWrapId) &
            (processedGiftWraps.ownerPubkey.equals(ownerPubkey) |
                processedGiftWraps.ownerPubkey.isNull() |
                processedGiftWraps.ownerPubkey.equals('')),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Which of [giftWrapIds] are already recorded in the ledger. Batched
  /// counterpart to [hasGiftWrap]: one `IN` query instead of N single-id
  /// lookups, used by the history-drain dedup probe to avoid a per-wrap DB
  /// round trip. Returns an empty set for an empty input.
  Future<Set<String>> giftWrapIdsPresent(Set<String> giftWrapIds) async {
    if (giftWrapIds.isEmpty) return const <String>{};
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(processedGiftWraps.giftWrapId.isIn(giftWrapIds));
    final rows = await query.get();
    final present = <String>{};
    for (final row in rows) {
      final id = row.read(processedGiftWraps.giftWrapId);
      if (id != null) present.add(id);
    }
    return present;
  }

  /// Records [giftWrapId] as terminally processed (idempotent — a re-delivered
  /// wrap or a concurrent writer never throws). [ownerPubkey] is not part of
  /// the dedup key, but is required so account cleanup can remove the correct
  /// ledger entry without affecting another local account.
  Future<void> record({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    if (ownerPubkey.isEmpty) {
      throw ArgumentError.value(
        ownerPubkey,
        'ownerPubkey',
        'must not be empty',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await into(processedGiftWraps).insert(
      ProcessedGiftWrapsCompanion.insert(
        giftWrapId: giftWrapId,
        processedAt: now,
        ownerPubkey: Value(ownerPubkey),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Deletes ledger rows for the departing account plus unattributed legacy
  /// rows, while preserving every other known account's ledger entries.
  Future<int> clearForAccountSwitch(String ownerPubkey) {
    return (delete(processedGiftWraps)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) |
              t.ownerPubkey.isNull() |
              t.ownerPubkey.equals(''),
        ))
        .go();
  }

  /// Deletes only processed wraps owned by [ownerPubkey].
  Future<int> deleteAllForOwner(String ownerPubkey) {
    return (delete(
      processedGiftWraps,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Deletes only unattributed legacy rows when the departing account is
  /// unknown, preserving every row with a valid owner.
  Future<int> clearUnowned() {
    return (delete(
      processedGiftWraps,
    )..where((t) => t.ownerPubkey.isNull() | t.ownerPubkey.equals(''))).go();
  }

  /// Total processed-wrap rows (diagnostics / tests).
  Future<int> count() async {
    final rows = await select(processedGiftWraps).get();
    return rows.length;
  }
}
