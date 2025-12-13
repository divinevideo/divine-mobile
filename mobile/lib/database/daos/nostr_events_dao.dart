// ABOUTME: Data Access Object for Nostr event operations with reactive Drift queries
// ABOUTME: Provides CRUD operations for all Nostr events stored in the shared database

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/database/tables.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'nostr_events_dao.g.dart';

@DriftAccessor(tables: [NostrEvents, VideoMetrics])
class NostrEventsDao extends DatabaseAccessor<AppDatabase>
    with _$NostrEventsDaoMixin {
  NostrEventsDao(AppDatabase db) : super(db);

  /// Insert or replace event
  ///
  /// Uses INSERT OR REPLACE for upsert behavior - if event with same ID exists,
  /// it will be replaced with the new data.
  ///
  /// For video events (kind 34236 or 16), also upserts video metrics to the
  /// video_metrics table for fast sorted queries.
  Future<void> upsertEvent(Event event) async {
    await customInsert(
      'INSERT OR REPLACE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(event.id),
        Variable.withString(event.pubkey),
        Variable.withInt(event.createdAt),
        Variable.withInt(event.kind),
        Variable.withString(jsonEncode(event.tags)),
        Variable.withString(event.content),
        Variable.withString(event.sig),
        const Variable(null), // sources - not used yet
      ],
    );

    // Also upsert video metrics for video events and reposts
    if (event.kind == 34236 || event.kind == 16) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Batch insert or replace multiple events in a single transaction
  ///
  /// Much more efficient than calling upsertEvent() repeatedly.
  /// Uses a single database transaction to avoid lock contention.
  Future<void> upsertEventsBatch(List<Event> events) async {
    if (events.isEmpty) return;

    await transaction(() async {
      // Batch insert all events
      for (final event in events) {
        await customInsert(
          'INSERT OR REPLACE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(event.id),
            Variable.withString(event.pubkey),
            Variable.withInt(event.createdAt),
            Variable.withInt(event.kind),
            Variable.withString(jsonEncode(event.tags)),
            Variable.withString(event.content),
            Variable.withString(event.sig),
            const Variable(null), // sources - not used yet
          ],
        );
      }

      // Batch upsert video metrics for video events and reposts
      final videoEvents = events
          .where((e) => e.kind == 34236 || e.kind == 16)
          .toList();
      for (final event in videoEvents) {
        await db.videoMetricsDao.upsertVideoMetrics(event);
      }
    });
  }

  /// Get event by ID (one-time fetch)
  ///
  /// Returns null if event doesn't exist in database.
  Future<Event?> getEvent(String id) async {
    final result = await customSelect(
      'SELECT * FROM event WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
      readsFrom: {nostrEvents},
    ).getSingleOrNull();

    return result != null ? _rowToEvent(result) : null;
  }

  /// Watch event by ID (reactive stream)
  ///
  /// Stream emits whenever the event is inserted, updated, or deleted.
  /// Emits null if event doesn't exist.
  Stream<Event?> watchEvent(String id) {
    return customSelect(
      'SELECT * FROM event WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
      readsFrom: {nostrEvents},
    ).watchSingleOrNull().map((row) => row != null ? _rowToEvent(row) : null);
  }

  /// Get events by kind (one-time fetch)
  ///
  /// Returns events sorted by created_at descending (newest first).
  Future<List<Event>> getEventsByKind(int kind, {int limit = 100}) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE kind = ? ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withInt(kind), Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).get();

    return rows.map(_rowToEvent).toList();
  }

  /// Watch events by kind (reactive stream)
  ///
  /// Stream emits whenever any event of this kind changes.
  Stream<List<Event>> watchEventsByKind(int kind, {int limit = 100}) {
    return customSelect(
      'SELECT * FROM event WHERE kind = ? ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withInt(kind), Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).watch().map((rows) => rows.map(_rowToEvent).toList());
  }

  /// Watch all video events (kind 34236 or 6)
  ///
  /// Stream emits whenever any video event changes. Used by video feeds.
  Stream<List<Event>> watchVideoEvents({int limit = 100}) {
    return customSelect(
      'SELECT * FROM event WHERE kind IN (34236, 6) ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).watch().map((rows) => rows.map(_rowToEvent).toList());
  }

  /// Get events by author (one-time fetch)
  ///
  /// Returns all events from a specific pubkey.
  Future<List<Event>> getEventsByAuthor(
    String pubkey, {
    int limit = 100,
  }) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE pubkey = ? ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withString(pubkey), Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).get();

    return rows.map(_rowToEvent).toList();
  }

  /// Watch events by author (reactive stream)
  ///
  /// Stream emits whenever any event from this author changes.
  Stream<List<Event>> watchEventsByAuthor(String pubkey, {int limit = 100}) {
    return customSelect(
      'SELECT * FROM event WHERE pubkey = ? ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withString(pubkey), Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).watch().map((rows) => rows.map(_rowToEvent).toList());
  }

  /// Query video events with filter parameters (cache-first strategy)
  ///
  /// Supports the same filter parameters as relay subscriptions:
  /// - kinds: Event kinds to match (defaults to video kinds: 34236, 6)
  /// - authors: List of pubkeys to filter by
  /// - hashtags: List of hashtags to filter by (searches tags JSON)
  /// - since: Minimum created_at timestamp (Unix seconds)
  /// - until: Maximum created_at timestamp (Unix seconds)
  /// - limit: Maximum number of events to return
  /// - sortBy: Field to sort by (loop_count, likes, views, created_at). Defaults to created_at DESC.
  ///
  /// Used by cache-first query strategy to return instant results before relay query.
  Future<List<Event>> getVideoEventsByFilter({
    List<int>? kinds,
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 100,
    String? sortBy,
  }) async {
    // Build dynamic SQL query based on provided filters
    final conditions = <String>[];
    final variables = <Variable>[];

    // Kind filter (defaults to video kinds if not specified)
    final effectiveKinds = kinds ?? [34236, 16];
    if (effectiveKinds.length == 1) {
      conditions.add('kind = ?');
      variables.add(Variable.withInt(effectiveKinds.first));
    } else {
      final placeholders = List.filled(effectiveKinds.length, '?').join(', ');
      conditions.add('kind IN ($placeholders)');
      variables.addAll(effectiveKinds.map((k) => Variable.withInt(k)));
    }

    // Authors filter
    if (authors != null && authors.isNotEmpty) {
      final placeholders = List.filled(authors.length, '?').join(', ');
      conditions.add('pubkey IN ($placeholders)');
      variables.addAll(authors.map((a) => Variable.withString(a)));
    }

    // Hashtags filter (search in tags JSON)
    // Tags are stored as JSON array, search for hashtag entries
    if (hashtags != null && hashtags.isNotEmpty) {
      final hashtagConditions = hashtags.map((tag) {
        // Convert to lowercase to match NIP-24 requirement
        final lowerTag = tag.toLowerCase();
        // Search for ["t", "hashtag"] in tags JSON
        variables.add(Variable.withString('%"t"%"$lowerTag"%'));
        return 'tags LIKE ?';
      }).toList();
      // OR condition: match ANY hashtag
      conditions.add('(${hashtagConditions.join(' OR ')})');
    }

    // Time range filters
    if (since != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(since));
    }
    if (until != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(until));
    }

    // Build final query with optional video_metrics join for sorting
    final whereClause = conditions.join(' AND ');

    // Determine ORDER BY clause and whether we need to join video_metrics
    String orderByClause;
    bool needsMetricsJoin = false;

    if (sortBy != null && sortBy != 'created_at') {
      // Server-side sorting by engagement metrics requires join with video_metrics
      needsMetricsJoin = true;

      // Map sort field names to column names
      final sortColumn =
          {
            'loop_count': 'loop_count',
            'likes': 'likes',
            'views': 'views',
            'comments': 'comments',
            'avg_completion': 'avg_completion',
          }[sortBy] ??
          'loop_count';

      // COALESCE to handle null metrics (treat as 0) and sort DESC
      orderByClause = 'COALESCE(m.$sortColumn, 0) DESC, e.created_at DESC';
    } else {
      // Default: sort by created_at DESC
      orderByClause = 'e.created_at DESC';
    }

    final String sql;
    if (needsMetricsJoin) {
      // Join with video_metrics for sorted queries
      sql =
          '''
        SELECT e.* FROM event e
        LEFT JOIN video_metrics m ON e.id = m.event_id
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    } else {
      // Simple query without join
      sql =
          '''
        SELECT * FROM event e
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    }

    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      sql,
      variables: variables,
      readsFrom: needsMetricsJoin ? {nostrEvents, videoMetrics} : {nostrEvents},
    ).get();

    return rows.map(_rowToEvent).toList();
  }

  /// Delete event by ID
  ///
  /// Removes event from database. Automatically triggers watchers.
  Future<void> deleteEvent(String id) async {
    await customStatement('DELETE FROM event WHERE id = ?', [
      Variable.withString(id),
    ]);
  }

  /// Get total count of events in database
  ///
  /// Used to check if database is empty before loading seed data.
  Future<int> getEventCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) as cnt FROM event',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Convert database row to Event model
  ///
  /// Handles malformed JSON in tags field gracefully by using empty tags list
  /// instead of crashing. This can happen if database becomes corrupted.
  Event _rowToEvent(QueryRow row) {
    List<List<String>> tags;
    try {
      tags = (jsonDecode(row.read<String>('tags')) as List)
          .map((tag) => (tag as List).map((e) => e.toString()).toList())
          .toList();
    } catch (e) {
      Log.warning(
        '⚠️ Failed to parse tags JSON for event ${row.read<String>('id')}: $e',
        name: 'NostrEventsDao',
        category: LogCategory.storage,
      );
      tags = [];
    }

    final event = Event(
      row.read<String>('pubkey'),
      row.read<int>('kind'),
      tags,
      row.read<String>('content'),
      createdAt: row.read<int>('created_at'),
    );
    // Set id and sig manually since they're stored fields
    event.id = row.read<String>('id');
    event.sig = row.read<String>('sig');
    return event;
  }
}
