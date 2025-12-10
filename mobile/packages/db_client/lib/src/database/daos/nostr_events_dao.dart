// ABOUTME: Data Access Object for Nostr event operations with reactive
// ABOUTME: Drift queries. Provides CRUD operations for all Nostr events
// ABOUTME: stored in the shared database. Handles NIP-01 replaceable events.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

part 'nostr_events_dao.g.dart';

@DriftAccessor(tables: [NostrEvents, VideoMetrics])
class NostrEventsDao extends DatabaseAccessor<AppDatabase>
    with _$NostrEventsDaoMixin {
  NostrEventsDao(super.attachedDatabase);

  /// Insert or replace event with NIP-01 replaceable event handling
  ///
  /// For regular events: uses INSERT OR REPLACE by event ID.
  ///
  /// For replaceable events (kind 0, 3, 10000-19999): replaces existing event
  /// with same pubkey+kind only if the new event has a higher created_at.
  ///
  /// For parameterized replaceable events (kind 30000-39999): replaces existing
  /// event with same pubkey+kind+d-tag only if the new event has a higher
  /// created_at.
  ///
  /// For video events (kind 34236 or 16), also upserts video metrics to the
  /// video_metrics table for fast sorted queries.
  Future<void> upsertEvent(Event event) async {
    // Handle replaceable events (kind 0, 3, 10000-19999)
    if (EventKind.isReplaceable(event.kind)) {
      await _upsertReplaceableEvent(event);
      return;
    }

    // Handle parameterized replaceable events (kind 30000-39999)
    if (EventKind.isParameterizedReplaceable(event.kind)) {
      await _upsertParameterizedReplaceableEvent(event);
      return;
    }

    // Regular event: simple insert or replace by ID
    await _insertEvent(event);

    // Also upsert video metrics for video events and reposts
    if (event.kind == 34236 || event.kind == 16) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Insert event without replaceable logic (by event ID)
  Future<void> _insertEvent(Event event) async {
    await customInsert(
      'INSERT OR REPLACE INTO event '
      '(id, pubkey, created_at, kind, tags, content, sig, sources) '
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

  /// Upsert replaceable event (kind 0, 3, 10000-19999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind exists,
  /// or if the new event has a higher created_at timestamp.
  Future<void> _upsertReplaceableEvent(Event event) async {
    // Check if a newer event already exists for this pubkey+kind
    final existingRows = await customSelect(
      'SELECT id, created_at FROM event WHERE pubkey = ? AND kind = ? LIMIT 1',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
      ],
      readsFrom: {nostrEvents},
    ).get();

    if (existingRows.isNotEmpty) {
      final existingCreatedAt = existingRows.first.read<int>('created_at');
      if (event.createdAt <= existingCreatedAt) {
        // Existing event is newer or same age, don't replace
        return;
      }
      // Delete the old event before inserting the new one
      final existingId = existingRows.first.read<String>('id');
      await customUpdate(
        'DELETE FROM event WHERE id = ?',
        variables: [Variable.withString(existingId)],
        updates: {nostrEvents},
        updateKind: UpdateKind.delete,
      );
    }

    await _insertEvent(event);
  }

  /// Upsert parameterized replaceable event (kind 30000-39999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind+d-tag
  /// exists, or if the new event has a higher created_at timestamp.
  Future<void> _upsertParameterizedReplaceableEvent(Event event) async {
    final dTagValue = event.dTagValue;

    // Check if a newer event already exists for this pubkey+kind+d-tag
    // We need to check tags JSON for the d-tag value
    final existingRows = await customSelect(
      'SELECT id, created_at, tags FROM event '
      'WHERE pubkey = ? AND kind = ?',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
      ],
      readsFrom: {nostrEvents},
    ).get();

    for (final row in existingRows) {
      final tagsJson = row.read<String>('tags');
      final tags = (jsonDecode(tagsJson) as List)
          .map((tag) => (tag as List).map((e) => e.toString()).toList())
          .toList();
      final existingDTag = _extractDTagFromTags(tags);

      if (existingDTag == dTagValue) {
        final existingCreatedAt = row.read<int>('created_at');
        if (event.createdAt <= existingCreatedAt) {
          // Existing event is newer or same age, don't replace
          return;
        }
        // Delete the old event before inserting the new one
        final existingId = row.read<String>('id');
        await customUpdate(
          'DELETE FROM event WHERE id = ?',
          variables: [Variable.withString(existingId)],
          updates: {nostrEvents},
          updateKind: UpdateKind.delete,
        );
        break;
      }
    }

    await _insertEvent(event);

    // Also upsert video metrics for video events
    if (event.kind == 34236) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Batch insert or replace multiple events in a single transaction
  ///
  /// Much more efficient than calling upsertEvent() repeatedly.
  /// Uses a single database transaction to avoid lock contention.
  /// Handles NIP-01 replaceable event semantics.
  Future<void> upsertEventsBatch(List<Event> events) async {
    if (events.isEmpty) return;

    await transaction(() async {
      // Batch upsert all events with replaceable logic
      for (final event in events) {
        await upsertEvent(event);
      }
    });
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
  /// - sortBy: Field to sort by (loop_count, likes, views, created_at).
  ///   Defaults to created_at DESC.
  ///
  /// Used by cache-first query strategy to return instant results before
  /// relay query.
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
      variables.addAll(effectiveKinds.map(Variable.withInt));
    }

    // Authors filter
    if (authors != null && authors.isNotEmpty) {
      final placeholders = List.filled(authors.length, '?').join(', ');
      conditions.add('pubkey IN ($placeholders)');
      variables.addAll(authors.map(Variable.withString));
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
    var needsMetricsJoin = false;

    if (sortBy != null && sortBy != 'created_at') {
      // Server-side sorting by engagement metrics requires join with
      // video_metrics
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

  /// Convert database row to Event model
  Event _rowToEvent(QueryRow row) {
    final tags = (jsonDecode(row.read<String>('tags')) as List)
        .map((tag) => (tag as List).map((e) => e.toString()).toList())
        .toList();

    final event = Event(
      row.read<String>('pubkey'),
      row.read<int>('kind'),
      tags,
      row.read<String>('content'),
      createdAt: row.read<int>('created_at'),
    );
    // Set id and sig manually since they're stored fields
    return event
      ..id = row.read<String>('id')
      ..sig = row.read<String>('sig');
  }

  /// Extracts the d-tag value from raw tag list (for database queries).
  ///
  /// Returns empty string if no d-tag is found (per NIP-01 spec).
  String _extractDTagFromTags(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == 'd') {
        return tag.length > 1 ? tag[1] : '';
      }
    }
    return '';
  }
}
