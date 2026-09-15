// ABOUTME: DAO for the caption styles a user saved from the video editor's
// ABOUTME: caption picker. Provides CRUD, ordering, and per-account isolation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'saved_caption_styles_dao.g.dart';

@DriftAccessor(tables: [SavedCaptionStyles])
class SavedCaptionStylesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedCaptionStylesDaoMixin {
  SavedCaptionStylesDao(super.attachedDatabase);

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(String? ownerPubkey) {
    if (ownerPubkey == null) return const Constant(true);
    return savedCaptionStyles.ownerPubkey.equals(ownerPubkey) |
        savedCaptionStyles.ownerPubkey.isNull();
  }

  /// Get all styles in picker order, oldest-saved first within the same
  /// order index. When [ownerPubkey] is provided, returns only styles owned
  /// by that account **plus** legacy rows with no owner.
  Future<List<SavedCaptionStyleRow>> getStyles({String? ownerPubkey}) {
    final query = select(savedCaptionStyles)
      ..where((_) => _ownedOrLegacy(ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.orderIndex),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.get();
  }

  /// Insert a style, or update it when [id] already exists.
  Future<void> upsertStyle({
    required String id,
    required String name,
    required String style,
    required DateTime createdAt,
    int orderIndex = 0,
    String? ownerPubkey,
  }) {
    return into(savedCaptionStyles).insertOnConflictUpdate(
      SavedCaptionStylesCompanion.insert(
        id: id,
        name: name,
        style: style,
        createdAt: createdAt,
        orderIndex: Value(orderIndex),
        ownerPubkey: Value(ownerPubkey),
      ),
    );
  }

  /// Rename an existing style.
  ///
  /// Returns true if a row was updated.
  Future<bool> renameStyle({required String id, required String name}) async {
    final rows =
        await (update(savedCaptionStyles)..where((t) => t.id.equals(id))).write(
          SavedCaptionStylesCompanion(name: Value(name)),
        );
    return rows > 0;
  }

  /// Delete the style [id].
  ///
  /// Returns true if the style existed.
  Future<bool> deleteStyle(String id) async {
    final rows = await (delete(
      savedCaptionStyles,
    )..where((t) => t.id.equals(id))).go();
    return rows > 0;
  }

  /// Rewrite [SavedCaptionStyles.orderIndex] so [orderedIds] read back in
  /// that order.
  ///
  /// Every id is written in one transaction, so a reorder can never leave two
  /// styles sharing an index. Ids not in the table are skipped.
  Future<void> reorderStyles(List<String> orderedIds) {
    return transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await (update(
          savedCaptionStyles,
        )..where((t) => t.id.equals(orderedIds[index]))).write(
          SavedCaptionStylesCompanion(orderIndex: Value(index)),
        );
      }
    });
  }

  /// The highest [SavedCaptionStyles.orderIndex] currently in use, or `null`
  /// when the account has no styles yet. Callers append after it.
  Future<int?> highestOrderIndex({String? ownerPubkey}) async {
    final maxOrder = savedCaptionStyles.orderIndex.max();
    final query = selectOnly(savedCaptionStyles)
      ..where(_ownedOrLegacy(ownerPubkey))
      ..addColumns([maxOrder]);
    final row = await query.getSingleOrNull();
    return row?.read(maxOrder);
  }

  /// Delete all styles owned by [userPubkey].
  ///
  /// Legacy styles with NULL ownerPubkey are preserved because they cannot
  /// be attributed to any specific account. Used on destructive sign-out to
  /// prevent cross-account data leaks.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(
      savedCaptionStyles,
    )..where((t) => t.ownerPubkey.equals(userPubkey))).go();
  }

  /// Claim legacy styles (NULL ownerPubkey) or rows owned by the optional
  /// [sourceOwnerPubkey] marker for [newOwnerPubkey].
  ///
  /// Mirrors `ClipCategoriesDao.claimLegacyRows` so styles saved before
  /// sign-in follow the signing-in account.
  Future<int> claimLegacyRows(
    String newOwnerPubkey, {
    String? sourceOwnerPubkey,
  }) {
    return (update(savedCaptionStyles)..where(
          (t) => sourceOwnerPubkey == null
              ? t.ownerPubkey.isNull()
              : t.ownerPubkey.isNull() |
                    t.ownerPubkey.equals(sourceOwnerPubkey),
        ))
        .write(SavedCaptionStylesCompanion(ownerPubkey: Value(newOwnerPubkey)));
  }
}
