// ABOUTME: Data Access Object for Nostr event operations with reactive
// ABOUTME: Drift queries. Provides CRUD operations for all Nostr events
// ABOUTME: stored in the shared database. Handles NIP-01 replaceable events.

import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/drift.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

part 'nostr_events_dao.g.dart';

/// Default cache expiry duration for Nostr events (1 day).
///
/// All events stored in the database will expire after this duration
/// to prevent unbounded cache growth. Events can be refreshed by
/// re-fetching from relays.
const Duration defaultEventCacheExpiry = Duration(days: 1);

/// `expire_at` for rows that must survive [NostrEventsDao.deleteExpiredEvents].
///
/// NULL cannot express this: the sweep deletes `expire_at IS NULL` rows as well
/// as past-dated ones, so NULL means *already expired*, not *never expires*.
/// Anything that must outlive a cold start needs a real timestamp far enough
/// out that it never arrives in practice (#8316).
const int neverExpiresAtUnix = 4102444800; // 2100-01-01T00:00:00Z

@DriftAccessor(tables: [NostrEvents, VideoMetrics])
class NostrEventsDao extends DatabaseAccessor<AppDatabase>
    with _$NostrEventsDaoMixin {
  NostrEventsDao(super.attachedDatabase);

  /// Calculate expire_at Unix timestamp for an event using default expiry.
  int _defaultExpireAt() {
    return DateTime.now().add(defaultEventCacheExpiry).millisecondsSinceEpoch ~/
        1000;
  }

  /// Insert or replace event with NIP-01 replaceable event handling.
  ///
  /// All events are stored with a default 1-day expiry to prevent unbounded
  /// cache growth. To customize the expiry, provide [expireAt] as a Unix
  /// timestamp.
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
  Future<void> upsertEvent(Event event, {int? expireAt}) async {
    await _upsertEvent(
      event,
      expireAt: expireAt ?? _defaultExpireAt(),
      transactionActive: false,
    );
  }

  Future<void> _upsertEvent(
    Event event, {
    required int expireAt,
    required bool transactionActive,
  }) async {
    // Handle replaceable events (kind 0, 3, 10000-19999)
    if (EventKind.isReplaceable(event.kind)) {
      if (transactionActive) {
        await _upsertReplaceableEvent(event, expireAt: expireAt);
      } else {
        await transaction(
          () => _upsertReplaceableEvent(event, expireAt: expireAt),
        );
      }
      return;
    }

    // Handle parameterized replaceable events (kind 30000-39999)
    if (EventKind.isParameterizedReplaceable(event.kind)) {
      if (transactionActive) {
        await _upsertParameterizedReplaceableEvent(
          event,
          expireAt: expireAt,
        );
      } else {
        await transaction(
          () => _upsertParameterizedReplaceableEvent(
            event,
            expireAt: expireAt,
          ),
        );
      }
      return;
    }

    // Regular event: simple insert or replace by ID
    await _insertEvent(event, expireAt: expireAt);

    // Also upsert video metrics for video events (kind 34236 only)
    // Note: Kind 16 reposts reference videos but don't contain video metadata
    if (event.kind == 34236) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Insert event without replaceable logic (by event ID)
  ///
  /// If [expireAt] is provided, the event will be marked for cache eviction
  /// after that Unix timestamp.
  ///
  /// Uses customInsert with updates parameter to notify stream watchers.
  Future<void> _insertEvent(Event event, {int? expireAt}) async {
    await customInsert(
      'INSERT OR REPLACE INTO event '
      '(id, pubkey, created_at, kind, tags, content, sig, sources, '
      'expire_at, d_tag) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(event.id),
        Variable.withString(event.pubkey),
        Variable.withInt(event.createdAt),
        Variable.withInt(event.kind),
        Variable.withString(jsonEncode(event.tags)),
        Variable.withString(event.content),
        Variable.withString(event.sig),
        const Variable(null), // sources - not used yet
        if (expireAt != null)
          Variable.withInt(expireAt)
        else
          const Variable(null),
        // Denormalized d-tag so replaceable upserts can use an indexed
        // lookup; NULL for kinds without NIP-33 d-tag semantics.
        if (EventKind.isParameterizedReplaceable(event.kind))
          Variable.withString(event.dTagValue)
        else
          const Variable(null),
      ],
      updates: {nostrEvents},
    );
  }

  /// Upsert replaceable event (kind 0, 3, 10000-19999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind exists,
  /// or if the new event has a higher created_at timestamp.
  Future<void> _upsertReplaceableEvent(
    Event event, {
    required int expireAt,
  }) async {
    // Compare against the newest stored version. MAX over all versions (rather
    // than an arbitrary first row) keeps the newest even when raw ingestion via
    // cacheEventsBatch left multiple versions behind — event_router sends
    // every non-parameterized kind there, so several rows per (pubkey, kind)
    // is the normal case rather than the exception. An aggregate without
    // GROUP BY always yields exactly one row (NULL when no version exists).
    final existingRow = await customSelect(
      'SELECT MAX(created_at) AS max_created_at FROM event '
      'WHERE pubkey = ? AND kind = ?',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
      ],
      readsFrom: {nostrEvents},
    ).getSingle();

    final maxCreatedAt = existingRow.read<int?>('max_created_at');
    if (maxCreatedAt != null) {
      if (event.createdAt <= maxCreatedAt) {
        // Existing event is newer or same age, don't replace
        return;
      }
      // Delete every superseded version before inserting the new one. Deleting
      // a single arbitrary row left the rest behind, so the count never fell
      // and the table grew without bound.
      await customUpdate(
        'DELETE FROM event WHERE pubkey = ? AND kind = ?',
        variables: [
          Variable.withString(event.pubkey),
          Variable.withInt(event.kind),
        ],
        updates: {nostrEvents},
        updateKind: UpdateKind.delete,
      );
    }

    await _insertEvent(event, expireAt: expireAt);
  }

  /// Upsert parameterized replaceable event (kind 30000-39999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind+d-tag
  /// exists, or if the new event has a higher created_at timestamp.
  ///
  /// Uses the indexed d_tag column for the existing-version lookup instead
  /// of decoding the tags JSON of every (pubkey, kind) row — the decode
  /// loop dominated main-isolate CPU (~23%) during feed ingestion.
  Future<void> _upsertParameterizedReplaceableEvent(
    Event event, {
    required int expireAt,
  }) async {
    final dTagValue = event.dTagValue;

    // Compare against the newest stored version. MAX over all versions
    // (rather than an arbitrary first row) keeps the newest even when raw
    // ingestion via cacheEventsBatch left multiple versions behind. An
    // aggregate without GROUP BY always yields exactly one row (NULL when
    // no version exists).
    final existingRow = await customSelect(
      'SELECT MAX(created_at) AS max_created_at FROM event '
      'WHERE pubkey = ? AND kind = ? AND d_tag = ?',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
        Variable.withString(dTagValue),
      ],
      readsFrom: {nostrEvents},
    ).getSingle();

    final maxCreatedAt = existingRow.read<int?>('max_created_at');
    if (maxCreatedAt != null) {
      if (event.createdAt <= maxCreatedAt) {
        // Existing event is newer or same age, don't replace
        return;
      }
      // Delete all older versions before inserting the new one
      await customUpdate(
        'DELETE FROM event WHERE pubkey = ? AND kind = ? AND d_tag = ?',
        variables: [
          Variable.withString(event.pubkey),
          Variable.withInt(event.kind),
          Variable.withString(dTagValue),
        ],
        updates: {nostrEvents},
        updateKind: UpdateKind.delete,
      );
    }

    await _insertEvent(event, expireAt: expireAt);

    // Also upsert video metrics for video events
    if (event.kind == 34236) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Batch insert or replace multiple events in a single transaction.
  ///
  /// All events are stored with a default 1-day expiry. To customize
  /// the expiry, provide [expireAt] as a Unix timestamp.
  ///
  /// Much more efficient than calling upsertEvent() repeatedly.
  /// Uses a single database transaction to avoid lock contention.
  /// Handles NIP-01 replaceable event semantics.
  Future<void> upsertEventsBatch(List<Event> events, {int? expireAt}) async {
    if (events.isEmpty) return;

    final eventsSnapshot = List<Event>.of(events);
    final effectiveExpireAt = expireAt ?? _defaultExpireAt();

    await transaction(() async {
      // Batch upsert all events with replaceable logic
      for (final event in eventsSnapshot) {
        await _upsertEvent(
          event,
          expireAt: effectiveExpireAt,
          transactionActive: true,
        );
      }
    });
  }

  /// Cache raw events by ID without applying replaceable-event deletion.
  ///
  /// Relay ingestion needs to preserve every raw event it receives while
  /// denormalized tables decide which replaceable value is current.
  Future<void> cacheEventsBatch(List<Event> events, {int? expireAt}) async {
    if (events.isEmpty) return;

    final effectiveExpireAt = expireAt ?? _defaultExpireAt();

    await transaction(() async {
      for (final event in events) {
        await _insertEvent(event, expireAt: effectiveExpireAt);
        if (event.kind == 34236) {
          await db.videoMetricsDao.upsertVideoMetrics(event);
        }
      }
    });
  }

  /// Watch events with a Nostr Filter (reactive stream)
  ///
  /// Returns a Stream that emits whenever the matching events change in the
  /// database. Uses Drift's reactive query mechanism to automatically re-emit
  /// when inserts, updates, or deletes occur on the events table.
  ///
  /// Supports all the same filter parameters as [getEventsByFilter].
  ///
  /// Example:
  /// ```dart
  /// dao.watchEventsByFilter(Filter(kinds: [1])).listen((events) {
  ///   print('Got ${events.length} events');
  /// });
  /// ```
  Stream<List<Event>> watchEventsByFilter(
    Filter filter, {
    String? sortBy,
  }) {
    return _buildFilterQuery(
      filter,
      sortBy: sortBy,
    ).watch().map((rows) => rows.map(_rowToEvent).toList());
  }

  /// Query events with a Nostr Filter (cache-first strategy)
  ///
  /// Supports all standard Nostr filter parameters:
  /// - ids: List of event IDs to match
  /// - kinds: Event kinds to match (no default - returns all kinds if null)
  /// - authors: List of pubkeys to filter by
  /// - t: List of hashtags to filter by (searches tags JSON)
  /// - e: List of referenced event IDs (e tags)
  /// - p: List of mentioned pubkeys (p tags)
  /// - h: List of relay-specific values (h tags)
  /// - d: List of addressable event identifiers (d tags)
  /// - a: List of addressable event references (a tags)
  /// - uppercaseE: List of root event IDs (E tags)
  /// - uppercaseA: List of root addressable event references (A tags)
  /// - uppercaseK: List of root event kind values (K tags)
  /// - m: List of MIME types (m tags, NIP-94 file metadata)
  /// - search: Full-text search in content (NIP-50)
  /// - since: Minimum created_at timestamp (Unix seconds)
  /// - until: Maximum created_at timestamp (Unix seconds)
  /// - limit: Maximum number of events to return
  ///
  /// Additional parameter:
  /// - sortBy: Field to sort by (loop_count, likes, views, created_at).
  ///   Defaults to created_at DESC.
  ///
  /// Used by cache-first query strategy to return instant results before
  /// relay query.
  Future<List<Event>> getEventsByFilter(
    Filter filter, {
    String? sortBy,
  }) async {
    final rows = await _buildFilterQuery(filter, sortBy: sortBy).get();
    return rows.map(_rowToEvent).toList();
  }

  /// Builds a Selectable query for events matching the given filter.
  ///
  /// This method is used internally by both [getEventsByFilter] (one-shot)
  /// and [watchEventsByFilter] (reactive stream).
  Selectable<QueryRow> _buildFilterQuery(
    Filter filter, {
    String? sortBy,
  }) {
    // Build dynamic SQL query based on provided filters
    final conditions = <String>[];
    final variables = <Variable>[];

    // IDs filter
    final ids = filter.ids;
    if (ids != null && ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(', ');
      conditions.add('id IN ($placeholders)');
      variables.addAll(ids.map(Variable.withString));
    }

    // Kind filter (no default - returns all kinds if not specified)
    final kinds = filter.kinds;
    if (kinds != null && kinds.isNotEmpty) {
      if (kinds.length == 1) {
        conditions.add('kind = ?');
        variables.add(Variable.withInt(kinds.first));
      } else {
        final placeholders = List.filled(kinds.length, '?').join(', ');
        conditions.add('kind IN ($placeholders)');
        variables.addAll(kinds.map(Variable.withInt));
      }
    }

    // Authors filter
    final authors = filter.authors;
    if (authors != null && authors.isNotEmpty) {
      final placeholders = List.filled(authors.length, '?').join(', ');
      conditions.add('pubkey IN ($placeholders)');
      variables.addAll(authors.map(Variable.withString));
    }

    _addExactTagCondition('t', filter.t, conditions, variables);
    _addExactTagCondition('e', filter.e, conditions, variables);
    _addExactTagCondition('p', filter.p, conditions, variables);
    _addExactTagCondition('h', filter.h, conditions, variables);
    _addExactTagCondition('d', filter.d, conditions, variables);
    _addExactTagCondition('a', filter.a, conditions, variables);
    _addExactTagCondition('E', filter.uppercaseE, conditions, variables);
    _addExactTagCondition('A', filter.uppercaseA, conditions, variables);
    _addExactTagCondition('K', filter.uppercaseK, conditions, variables);
    _addExactTagCondition('m', filter.m, conditions, variables);

    // Content search filter (NIP-50 style, case insensitive)
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      conditions.add('content LIKE ? COLLATE NOCASE');
      variables.add(Variable.withString('%$search%'));
    }

    // Time range filters
    final since = filter.since;
    if (since != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(since));
    }
    final until = filter.until;
    if (until != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(until));
    }

    // Build WHERE clause (or no WHERE if no conditions)
    final whereClause = conditions.isEmpty ? '1=1' : conditions.join(' AND ');

    // Determine ORDER BY clause and whether we need to join video_metrics
    String orderByClause;
    var needsMetricsJoin = false;

    if (sortBy != null && sortBy != 'created_at') {
      needsMetricsJoin = true;

      final sortColumn =
          {
            'loop_count': 'loop_count',
            'likes': 'likes',
            'views': 'views',
            'comments': 'comments',
            'avg_completion': 'avg_completion',
          }[sortBy] ??
          'loop_count';

      orderByClause = 'COALESCE(m.$sortColumn, 0) DESC, e.created_at DESC';
    } else {
      orderByClause = 'e.created_at DESC';
    }

    // Use filter.limit or default to 100
    final limit = filter.limit ?? 100;

    final String sql;
    if (needsMetricsJoin) {
      sql =
          '''
        SELECT e.* FROM event e
        LEFT JOIN video_metrics m ON e.id = m.event_id
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    } else {
      sql =
          '''
        SELECT * FROM event e
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    }

    variables.add(Variable.withInt(limit));

    return customSelect(
      sql,
      variables: variables,
      readsFrom: needsMetricsJoin ? {nostrEvents, videoMetrics} : {nostrEvents},
    );
  }

  void _addExactTagCondition(
    String tagName,
    List<String>? values,
    List<String> conditions,
    List<Variable> variables,
  ) {
    if (values == null || values.isEmpty) return;

    final placeholders = List.filled(values.length, '?').join(', ');
    variables
      ..add(Variable.withString(tagName))
      ..addAll(values.map(Variable.withString));

    conditions.add(
      '''
      EXISTS (
        SELECT 1
        FROM json_each(e.tags) AS tag
        WHERE json_extract(tag.value, '\$[0]') COLLATE BINARY = ?
          AND json_extract(tag.value, '\$[1]') COLLATE BINARY IN ($placeholders)
      )
      ''',
    );
  }

  /// Get a single event by ID.
  ///
  /// Returns `null` if the event is not found.
  Future<Event?> getEventById(String eventId) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE id = ? LIMIT 1',
      variables: [Variable.withString(eventId)],
      readsFrom: {nostrEvents},
    ).get();

    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Get a profile (kind 0) event by pubkey.
  ///
  /// Returns the most recent profile event for the given pubkey,
  /// or `null` if no profile is found.
  Future<Event?> getProfileByPubkey(String pubkey) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE pubkey = ? AND kind = ? '
      'ORDER BY created_at DESC LIMIT 1',
      variables: [
        Variable.withString(pubkey),
        Variable.withInt(EventKind.metadata),
      ],
      readsFrom: {nostrEvents},
    ).get();

    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Delete all events from the cache.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteAllEvents() async {
    return customUpdate(
      'DELETE FROM event',
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Delete all events of a specific kind.
  ///
  /// Useful for clearing cached video events (kind 34236) when switching
  /// environments.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteEventsByKind(int kind) async {
    return customUpdate(
      'DELETE FROM event WHERE kind = ?',
      variables: [Variable.withInt(kind)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Delete a single event by its ID.
  ///
  /// Used when processing NIP-09 deletion events (Kind 5) to remove the
  /// target events from the local cache.
  ///
  /// Returns true if an event was deleted, false if no event was found.
  Future<bool> deleteEventById(String eventId) async {
    final rowsDeleted = await customUpdate(
      'DELETE FROM event WHERE id = ?',
      variables: [Variable.withString(eventId)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
    return rowsDeleted > 0;
  }

  /// Delete multiple events by their IDs.
  ///
  /// Used when processing NIP-09 deletion events (Kind 5) that reference
  /// multiple events via 'e' tags.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return 0;

    final placeholders = List.filled(eventIds.length, '?').join(', ');
    return customUpdate(
      'DELETE FROM event WHERE id IN ($placeholders)',
      variables: eventIds.map(Variable.withString).toList(),
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
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

  // ---------------------------------------------------------------------------
  // Cache Expiry Management
  // ---------------------------------------------------------------------------

  /// Set the expiry timestamp for an existing event.
  ///
  /// Returns true if the event was found and updated, false if not found.
  Future<bool> setEventExpiry(String eventId, int expireAt) async {
    final rowsAffected = await customUpdate(
      'UPDATE event SET expire_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(expireAt),
        Variable.withString(eventId),
      ],
      updates: {nostrEvents},
      updateKind: UpdateKind.update,
    );
    return rowsAffected > 0;
  }

  /// Delete events that have expired or have no expiry set.
  ///
  /// If [before] is provided, deletes events expired before that timestamp.
  /// Also deletes events with NULL expire_at (legacy events without expiry).
  ///
  /// Returns the number of events deleted.
  Future<int> deleteExpiredEvents(int? before) async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return customUpdate(
      'DELETE FROM event WHERE expire_at IS NULL OR expire_at < ?',
      variables: [Variable.withInt(before ?? nowUnix)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Get the count of events that will expire before [before] Unix timestamp.
  Future<int> countExpiredEvents(int before) async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM event '
      'WHERE expire_at IS NOT NULL AND expire_at < ?',
      variables: [Variable.withInt(before)],
      readsFrom: {nostrEvents},
    ).getSingle();
    return result.read<int>('count');
  }

  /// Get total count of all events in the database.
  Future<int> getEventCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM event',
      readsFrom: {nostrEvents},
    ).getSingle();
    return result.read<int>('count');
  }

  /// Returns the `(id, sig)` pairs of the most recently created events,
  /// newest first, capped at [limit].
  ///
  /// Used to seed the relay pool's already-verified set: every event in this
  /// table was signature-verified before being written, so re-verifying the
  /// same events when relays re-send them on the next cold start is wasted
  /// work. The signature is returned alongside the id because a Nostr event
  /// id commits to the event body but not to `sig`, so trust must be keyed by
  /// the exact `(id, sig)` pair that was verified — an id alone would let a
  /// replayed id carrying a forged signature bypass verification.
  ///
  /// The default [limit] is intentionally large: on-device profiling showed
  /// this seed take cold-start relay verify from ~37% of startup CPU to ~1%,
  /// i.e. the re-send flood in this app approaches this scale, so a smaller
  /// cap would re-introduce the expensive EC verify for the tail. The one-time
  /// seed cost (~SQLite read + string/set builds) is negligible against the
  /// per-event verify seconds it saves. Newest-first so the cap keeps the
  /// most-likely-re-sent events.
  Future<List<({String id, String sig})>> getRecentEventIdSigs({
    int limit = 50000,
  }) async {
    final rows = await customSelect(
      'SELECT id, sig FROM event ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {nostrEvents},
    ).get();
    return rows
        .map(
          (row) => (
            id: row.read<String>('id'),
            sig: row.read<String>('sig'),
          ),
        )
        .toList();
  }
}
