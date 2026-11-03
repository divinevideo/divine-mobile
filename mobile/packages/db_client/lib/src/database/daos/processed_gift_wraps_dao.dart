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

  /// Has [giftWrapId] been terminally processed *by [ownerPubkey]*?
  ///
  /// Owner-scoped, because an id is unique to one account only for an inbound
  /// kind 1059: NIP-59 mints a separate wrap per recipient. An unwrapped kind 4
  /// has one event id shared by sender and recipient, so when both are accounts
  /// on this device each records its own outcome for the id, and one must not
  /// read the other's row as its own handling: it never stored the message
  /// (#6645, #8209).
  ///
  /// A row with the empty-string owner is a legacy one from before the owner
  /// was part of the key. It counts as this account's, matching
  /// [clearForAccountSwitch] and `DirectMessagesDao`'s legacy handling, so an
  /// upgrade does not reclassify an account's own history as somebody else's.
  Future<bool> hasGiftWrapForOwner({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(
        processedGiftWraps.giftWrapId.equals(giftWrapId) & _heldBy(ownerPubkey),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Which of [giftWrapIds] [ownerPubkey] has already recorded in the ledger.
  /// Batched counterpart to [hasGiftWrapForOwner]: one `IN` query instead of N
  /// single-id lookups, used by the history-drain dedup probe to avoid a
  /// per-wrap DB round trip. Returns an empty set for an empty input.
  Future<Set<String>> giftWrapIdsPresent(
    Set<String> giftWrapIds, {
    required String ownerPubkey,
  }) async {
    if (giftWrapIds.isEmpty) return const <String>{};
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(
        processedGiftWraps.giftWrapId.isIn(giftWrapIds) & _heldBy(ownerPubkey),
      );
    final rows = await query.get();
    final present = <String>{};
    for (final row in rows) {
      final id = row.read(processedGiftWraps.giftWrapId);
      if (id != null) present.add(id);
    }
    return present;
  }

  /// Rows [ownerPubkey] has recorded, counting an ownerless legacy row as its
  /// own.
  Expression<bool> _heldBy(String ownerPubkey) {
    return processedGiftWraps.ownerPubkey.equals(ownerPubkey) |
        processedGiftWraps.ownerPubkey.equals('');
  }

  /// Records [giftWrapId] as terminally processed for [ownerPubkey] (idempotent
  /// — a re-delivered wrap or a concurrent writer never throws).
  ///
  /// The key is the id and the account, so two local accounts can each record
  /// the same id (a kind 4 is shared by both ends) and each finds its own row
  /// again ([hasGiftWrapForOwner]). Account cleanup removes only the leaving
  /// account's rows.
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
          (t) => t.ownerPubkey.equals(ownerPubkey) | t.ownerPubkey.equals(''),
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
    )..where((t) => t.ownerPubkey.equals(''))).go();
  }

  /// Total processed-wrap rows (diagnostics / tests).
  Future<int> count() async {
    final rows = await select(processedGiftWraps).get();
    return rows.length;
  }
}
