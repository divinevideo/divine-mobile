// ABOUTME: Persists the text-overlay looks a user saves from the video
// ABOUTME: editor's timeline in Drift, scoped to the signed-in account (#7742).

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/video_editor/saved_title_style.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

/// Saved title styles for one account, backed by `saved_title_styles`.
///
/// The picker is the only reader, and it reads the whole list, so a write
/// reports only whether it landed and the caller reloads through [getStyles].
///
/// Throws whatever the database throws; the cubit above turns that into a
/// status rather than a string.
class SavedTitleStyleRepository {
  /// Creates a repository over [dao] for [ownerPubkey].
  ///
  /// [ownerPubkey] stamps every saved row and scopes every read. A `null`
  /// owner is unscoped rather than ownerless: the DAO drops the predicate
  /// entirely, so reads return every row in the table, including other
  /// accounts'. Nothing passes null today, because
  /// `resolveLocalContentOwnerPubkey` always returns a value, falling back to
  /// the anonymous marker the next sign-in claims.
  SavedTitleStyleRepository({
    required SavedTitleStylesDao dao,
    this.ownerPubkey,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  }) : _dao = dao,
       _uuid = uuid,
       _now = now;

  final SavedTitleStylesDao _dao;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Hex pubkey of the account whose styles this repository reads and
  /// writes, or `null` before an account is known.
  final String? ownerPubkey;

  /// Every saved style, in picker order.
  ///
  /// A row whose payload no longer decodes is skipped and logged rather than
  /// failing the whole list — one corrupt style must not hide the others.
  Future<List<SavedTitleStyle>> getStyles() async {
    final rows = await _dao.getStyles(ownerPubkey: ownerPubkey);
    return [for (final row in rows) ?_decode(row)];
  }

  /// Saves [style] under [rawName], appended after the existing styles.
  ///
  /// Returns the saved style, or `null` when [rawName] holds no usable text
  /// after trimming — a blank name is rejected rather than stored.
  Future<SavedTitleStyle?> save({
    required String rawName,
    required TitleStyle style,
  }) async {
    final name = SavedTitleStyle.sanitizeName(rawName);
    if (name == null) return null;

    final highest = await _dao.highestOrderIndex(ownerPubkey: ownerPubkey);
    final saved = SavedTitleStyle(
      id: _uuid.v4(),
      name: name,
      style: style,
      createdAt: _now(),
      orderIndex: (highest ?? -1) + 1,
    );
    await _dao.upsertStyle(
      id: saved.id,
      name: saved.name,
      style: jsonEncode(style.toJson()),
      createdAt: saved.createdAt,
      orderIndex: saved.orderIndex,
      ownerPubkey: ownerPubkey,
    );
    Log.debug(
      '🎨 Saved title style: ${saved.id}',
      name: 'SavedTitleStyleRepository',
      category: LogCategory.video,
    );
    return saved;
  }

  /// Renames the style [id] to [rawName].
  ///
  /// Returns false when the style is gone or [rawName] holds no usable text
  /// after trimming.
  Future<bool> rename({required String id, required String rawName}) async {
    final name = SavedTitleStyle.sanitizeName(rawName);
    if (name == null) return false;
    return _dao.renameStyle(id: id, name: name);
  }

  /// Deletes the style [id]. Titles already using it keep their look — the
  /// style was copied onto them when applied.
  ///
  /// Returns true if the style existed.
  Future<bool> delete(String id) async {
    final deleted = await _dao.deleteStyle(id);
    if (deleted) {
      Log.debug(
        '🎨 Deleted title style: $id',
        name: 'SavedTitleStyleRepository',
        category: LogCategory.video,
      );
    }
    return deleted;
  }

  /// Stores [orderedIds] as the new picker order.
  Future<void> reorder(List<String> orderedIds) =>
      _dao.reorderStyles(orderedIds);

  SavedTitleStyle? _decode(SavedTitleStyleRow row) {
    Object? json;
    try {
      json = jsonDecode(row.style);
    } on FormatException {
      json = null;
    }
    final style = TitleStyle.fromJson(json);
    if (style == null) {
      Log.warning(
        '🎨 Skipping title style with unreadable payload: ${row.id}',
        name: 'SavedTitleStyleRepository',
        category: LogCategory.video,
      );
      return null;
    }
    return SavedTitleStyle(
      id: row.id,
      name: row.name,
      style: style,
      createdAt: row.createdAt,
      orderIndex: row.orderIndex,
    );
  }
}
