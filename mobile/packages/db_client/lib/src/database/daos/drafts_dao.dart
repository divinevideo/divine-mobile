// ABOUTME: Data Access Object for video draft persistence operations.
// ABOUTME: Provides CRUD with publish-status filtering, timestamp
// ABOUTME: ordering, and per-account isolation via ownerPubkey.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'drafts_dao.g.dart';

/// Key in a draft's JSON data containing every file the serialized editor
/// state owns, stored as basenames so iOS container moves remain safe.
const draftOwnedFileBasenamesKey = 'ownedFileBasenames';

/// Data transfer object for clip insertion within a transaction.
class DraftClipData {
  const DraftClipData({
    required this.id,
    required this.orderIndex,
    required this.durationMs,
    required this.recordedAt,
    required this.data,
    this.filePath,
    this.thumbnailPath,
    this.categoryId,
    this.archivedAt,
  });

  final String id;
  final int orderIndex;
  final int durationMs;
  final DateTime recordedAt;
  final String data;
  final String? filePath;
  final String? thumbnailPath;
  final String? categoryId;
  final DateTime? archivedAt;
}

@DriftAccessor(tables: [Drafts, Clips])
class DraftsDao extends DatabaseAccessor<AppDatabase> with _$DraftsDaoMixin {
  DraftsDao(super.attachedDatabase);

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    return column.equals(ownerPubkey) | column.isNull();
  }

  /// Upsert a draft (insert or update on conflict)
  Future<void> upsertDraft({
    required String id,
    required String title,
    required String description,
    required String publishStatus,
    required DateTime createdAt,
    required DateTime lastModified,
    required String data,
    required String? renderedFilePath,
    required String? renderedThumbnailPath,
    String? customThumbnailPath,
    int publishAttempts = 0,
    String? publishError,
    String? ownerPubkey,
  }) {
    return into(drafts).insertOnConflictUpdate(
      DraftsCompanion.insert(
        id: id,
        title: Value(title),
        description: Value(description),
        publishStatus: Value(publishStatus),
        publishAttempts: Value(publishAttempts),
        publishError: Value(publishError),
        createdAt: createdAt,
        lastModified: lastModified,
        data: data,
        renderedFilePath: Value(renderedFilePath),
        renderedThumbnailPath: Value(renderedThumbnailPath),
        customThumbnailPath: Value(customThumbnailPath),
        ownerPubkey: Value(ownerPubkey),
      ),
    );
  }

  /// Get all drafts sorted by last modified (newest first).
  /// When [ownerPubkey] is provided, returns only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Future<List<DraftRow>> getAllDrafts({int? limit, String? ownerPubkey}) {
    final query = select(drafts)
      ..where((t) => _ownedOrLegacy(t.ownerPubkey, ownerPubkey))
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastModified, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Get a single draft by ID.
  ///
  /// When [ownerPubkey] is provided, returns the draft only when it belongs to
  /// that account **or** is a legacy row with no owner. Omit it to look the
  /// draft up across accounts (used to detect foreign ownership).
  Future<DraftRow?> getDraftById(String id, {String? ownerPubkey}) {
    return (select(drafts)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Get drafts filtered by publish status.
  /// When [ownerPubkey] is provided, returns only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Future<List<DraftRow>> getDraftsByStatus(
    String status, {
    int? limit,
    String? ownerPubkey,
  }) {
    final query = select(drafts)
      ..where(
        (t) =>
            t.publishStatus.equals(status) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastModified, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Update publish status and optionally error/attempts
  Future<bool> updatePublishStatus({
    required String id,
    required String publishStatus,
    String? publishError,
    int? publishAttempts,
  }) async {
    final rowsAffected = await (update(drafts)..where((t) => t.id.equals(id)))
        .write(
          DraftsCompanion(
            publishStatus: Value(publishStatus),
            publishError: Value(publishError),
            publishAttempts: publishAttempts != null
                ? Value(publishAttempts)
                : const Value.absent(),
            lastModified: Value(DateTime.now()),
          ),
        );
    return rowsAffected > 0;
  }

  /// Delete a draft by ID, along with its clip rows.
  ///
  /// The clips table declares an `ON DELETE CASCADE` FK on `draft_id`, but
  /// `foreign_keys` enforcement is not enabled on this connection, so the
  /// cascade never fires. Deleting the clip rows explicitly (mirroring
  /// [saveDraftWithClips]) keeps orphaned clip rows from surviving and keeping
  /// the draft's media referenced — which blocks file cleanup and leaks the
  /// clip/frame files. Returns the number of draft rows deleted.
  Future<int> deleteDraft(String id) {
    return transaction(() async {
      await (delete(clips)..where((t) => t.draftId.equals(id))).go();
      return (delete(drafts)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Delete drafts older than a given date
  Future<int> deleteOlderThan(DateTime dateTime) {
    return (delete(
      drafts,
    )..where((t) => t.lastModified.isSmallerThanValue(dateTime))).go();
  }

  /// Watch all drafts (reactive stream).
  /// When [ownerPubkey] is provided, returns only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Stream<List<DraftRow>> watchAllDrafts({int? limit, String? ownerPubkey}) {
    final query = select(drafts)
      ..where((t) => _ownedOrLegacy(t.ownerPubkey, ownerPubkey))
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastModified, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Watch a single draft by ID (reactive stream)
  Stream<DraftRow?> watchDraftById(String id) {
    return (select(drafts)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Watch drafts filtered by publish status (reactive stream).
  /// When [ownerPubkey] is provided, returns only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Stream<List<DraftRow>> watchDraftsByStatus(
    String status, {
    int? limit,
    String? ownerPubkey,
  }) {
    final query = select(drafts)
      ..where(
        (t) =>
            t.publishStatus.equals(status) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.lastModified, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Get count of drafts by publish status.
  /// When [ownerPubkey] is provided, counts only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Future<int> getCountByStatus(String status, {String? ownerPubkey}) async {
    final query = selectOnly(drafts)
      ..where(
        drafts.publishStatus.equals(status) &
            _ownedOrLegacy(drafts.ownerPubkey, ownerPubkey),
      )
      ..addColumns([drafts.id.count()]);
    final result = await query.getSingle();
    return result.read(drafts.id.count()) ?? 0;
  }

  /// Get total count of all drafts.
  /// When [ownerPubkey] is provided, counts only drafts owned by that
  /// account **plus** legacy drafts with no owner.
  Future<int> getCount({String? ownerPubkey}) async {
    final query = selectOnly(drafts)
      ..where(_ownedOrLegacy(drafts.ownerPubkey, ownerPubkey))
      ..addColumns([drafts.id.count()]);
    final result = await query.getSingle();
    return result.read(drafts.id.count()) ?? 0;
  }

  /// Clear all drafts, along with every draft-owned clip row.
  ///
  /// Deletes clip rows with a non-null `draft_id` too (the FK cascade does not
  /// fire — see [deleteDraft]); library clips have a NULL `draft_id` and are
  /// preserved. Returns the number of draft rows deleted.
  Future<int> clearAll() {
    return transaction(() async {
      await (delete(clips)..where((t) => t.draftId.isNotNull())).go();
      return delete(drafts).go();
    });
  }

  /// Delete all drafts owned by [userPubkey].
  ///
  /// Legacy drafts with NULL ownerPubkey are preserved because they
  /// cannot be attributed to any specific account.
  /// Used on destructive sign-out to prevent cross-account data leaks.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(
      drafts,
    )..where((t) => t.ownerPubkey.equals(userPubkey))).go();
  }

  /// Claim legacy drafts (NULL ownerPubkey) or rows owned by the optional
  /// [sourceOwnerPubkey] marker for [newOwnerPubkey].
  ///
  /// Called during session setup so that pre-multi-account drafts are
  /// attributed to the user who created them and signed-out recorder drafts
  /// are claimed by the next successful sign-in.
  Future<int> claimLegacyRows(
    String newOwnerPubkey, {
    String? sourceOwnerPubkey,
  }) {
    return (update(drafts)..where(
          (t) => sourceOwnerPubkey == null
              ? t.ownerPubkey.isNull()
              : t.ownerPubkey.isNull() |
                    t.ownerPubkey.equals(sourceOwnerPubkey),
        ))
        .write(DraftsCompanion(ownerPubkey: Value(newOwnerPubkey)));
  }

  /// Check if a filename is referenced by any draft-owned file column.
  Future<bool> isDraftFileReferenced(String filename) async {
    final query = selectOnly(drafts)
      ..addColumns([drafts.id.count()])
      ..where(
        drafts.renderedFilePath.equals(filename) |
            drafts.renderedThumbnailPath.equals(filename) |
            drafts.customThumbnailPath.equals(filename),
      );
    final result = await query.getSingle();
    if ((result.read(drafts.id.count()) ?? 0) > 0) return true;

    // Layer-owned files (including detached videos) live in the serialized
    // editor state rather than an indexed clip row. DraftStorageService writes
    // their explicit ownership manifest into `data`; scan it as the fallback
    // instead of guessing ownership from arbitrary JSON string values.
    final dataRows = await (selectOnly(
      drafts,
    )..addColumns([drafts.data])).get();
    for (final row in dataRows) {
      final Object? decoded;
      try {
        decoded = json.decode(row.read(drafts.data)!);
      } on FormatException {
        continue;
      }
      if (decoded is! Map) continue;
      final manifest = decoded[draftOwnedFileBasenamesKey];
      if (manifest is Iterable && manifest.contains(filename)) return true;
    }
    return false;
  }

  /// Atomically save a draft and its clips in a single transaction.
  ///
  /// This ensures readers never observe a draft with 0 clips during updates.
  Future<void> saveDraftWithClips({
    required String id,
    required String title,
    required String description,
    required String publishStatus,
    required DateTime createdAt,
    required DateTime lastModified,
    required String data,
    required String? renderedFilePath,
    required String? renderedThumbnailPath,
    required String? customThumbnailPath,
    required List<DraftClipData> clipDataList,
    int publishAttempts = 0,
    String? publishError,
    String? ownerPubkey,
  }) {
    return transaction(() async {
      // 1. Upsert the draft row
      await into(drafts).insertOnConflictUpdate(
        DraftsCompanion.insert(
          id: id,
          title: Value(title),
          description: Value(description),
          publishStatus: Value(publishStatus),
          publishAttempts: Value(publishAttempts),
          publishError: Value(publishError),
          createdAt: createdAt,
          lastModified: lastModified,
          data: data,
          renderedFilePath: Value(renderedFilePath),
          renderedThumbnailPath: Value(renderedThumbnailPath),
          customThumbnailPath: Value(customThumbnailPath),
          ownerPubkey: Value(ownerPubkey),
        ),
      );

      final existingClipRows = await (select(
        clips,
      )..where((t) => t.draftId.equals(id))).get();
      final existingById = {for (final row in existingClipRows) row.id: row};

      // 2. Delete existing clips for this draft
      await (delete(clips)..where((t) => t.draftId.equals(id))).go();

      // 3. Insert new clips
      for (final clipData in clipDataList) {
        final rowId = '$id:${clipData.id}';
        final existingRow = existingById[rowId];
        await into(clips).insertOnConflictUpdate(
          ClipsCompanion.insert(
            id: rowId,
            draftId: Value(id),
            orderIndex: Value(clipData.orderIndex),
            durationMs: clipData.durationMs,
            recordedAt: clipData.recordedAt,
            data: clipData.data,
            filePath: Value(clipData.filePath),
            thumbnailPath: Value(clipData.thumbnailPath),
            ownerPubkey: Value(ownerPubkey),
            categoryId: Value(clipData.categoryId ?? existingRow?.categoryId),
            archivedAt: Value(clipData.archivedAt ?? existingRow?.archivedAt),
          ),
        );
      }
    });
  }
}
