// ABOUTME: Caches Nostr events locally for fast queries.
// ABOUTME: Wraps db_client with TTL-based staleness and filter-based lookups.

import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template event_cache}
/// Caches Nostr events locally for fast queries.
///
/// Wraps [AppDbClient] and provides:
/// - Cache-first queries with freshness checks
/// - Auto-caching of subscription events
/// - TTL-based staleness per event kind
/// - NIP-01 replaceable event handling (via db_client)
///
/// Usage:
/// ```dart
/// final cache = EventCache(appDbClient);
///
/// // Cache events from relay
/// await cache.cacheEvents(relayEvents);
///
/// // Query cache first
/// final cached = await cache.getCachedEvents(filter);
///
/// // Check staleness for replaceable events
/// if (!cache.isStale(profile)) {
///   return profile;
/// }
/// ```
/// {@endtemplate}
class EventCache {
  /// {@macro event_cache}
  EventCache(this._dbClient);

  final AppDbClient _dbClient;

  /// TTL per event kind for staleness checks.
  ///
  /// Events with TTL are considered stale after the duration passes.
  /// Events without TTL (null) are never considered stale.
  static const _ttlByKind = <int, Duration>{
    0: Duration(hours: 1), // profiles
    3: Duration(hours: 1), // contacts
    10002: Duration(hours: 1), // relay list
  };

  /// Default TTL for parameterized replaceable events (30000-39999).
  static const _parameterizedReplaceableTtl = Duration(hours: 1);

  // ---------------------------------------------------------------------------
  // Cache Operations
  // ---------------------------------------------------------------------------

  /// Cache a single event.
  ///
  /// Handles NIP-01 replaceable event semantics via db_client's
  /// [NostrEventsDao.upsertEvent].
  Future<void> cacheEvent(Event event) async {
    await _dbClient.database.nostrEventsDao.upsertEvent(event);
  }

  /// Cache multiple events in batch.
  ///
  /// More efficient than calling [cacheEvent] repeatedly.
  /// Handles NIP-01 replaceable event semantics.
  Future<void> cacheEvents(List<Event> events) async {
    if (events.isEmpty) return;
    await _dbClient.database.nostrEventsDao.upsertEventsBatch(events);
  }

  // ---------------------------------------------------------------------------
  // Query Operations
  // ---------------------------------------------------------------------------

  /// Get a cached event by ID.
  ///
  /// Returns `null` if the event is not in the cache.
  Future<Event?> getCachedEvent(String eventId) async {
    final row = await _dbClient.getEvent(eventId);
    if (row == null) return null;
    return _rowToEvent(row);
  }

  /// Get a cached profile (kind 0) by pubkey.
  ///
  /// Returns `null` if no profile is cached for this pubkey.
  Future<Event?> getCachedProfile(String pubkey) async {
    final rows = await _dbClient.getEventsByAuthor(
      pubkey,
      kind: EventKind.metadata,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Get cached events matching a filter.
  ///
  /// Supports filtering by:
  /// - kinds
  /// - authors
  /// - limit
  ///
  /// Returns events sorted by created_at descending.
  Future<List<Event>> getCachedEvents(Filter filter) async {
    // For video queries, use the specialized DAO method
    if (_isVideoFilter(filter)) {
      return _dbClient.database.nostrEventsDao.getVideoEventsByFilter(
        kinds: filter.kinds,
        authors: filter.authors,
        since: filter.since,
        until: filter.until,
        limit: filter.limit ?? 100,
      );
    }

    // For other queries, build manually
    if (filter.kinds != null && filter.kinds!.length == 1) {
      final kind = filter.kinds!.first;
      if (filter.authors != null && filter.authors!.isNotEmpty) {
        // Filter by author + kind
        final results = <NostrEventRow>[];
        for (final author in filter.authors!) {
          final rows = await _dbClient.getEventsByAuthor(
            author,
            kind: kind,
            limit: filter.limit,
          );
          results.addAll(rows);
        }
        return results.map(_rowToEvent).toList();
      } else {
        // Filter by kind only
        final rows = await _dbClient.getEventsByKind(
          kind,
          limit: filter.limit,
        );
        return rows.map(_rowToEvent).toList();
      }
    }

    if (filter.authors != null && filter.authors!.isNotEmpty) {
      // Filter by authors only
      final results = <NostrEventRow>[];
      for (final author in filter.authors!) {
        final rows = await _dbClient.getEventsByAuthor(
          author,
          limit: filter.limit,
        );
        results.addAll(rows);
      }
      // Filter by kinds if specified
      var events = results.map(_rowToEvent).toList();
      if (filter.kinds != null) {
        events = events.where((e) => filter.kinds!.contains(e.kind)).toList();
      }
      // Apply limit
      if (filter.limit != null && events.length > filter.limit!) {
        events = events.sublist(0, filter.limit);
      }
      return events;
    }

    // No supported filter criteria
    return [];
  }

  // ---------------------------------------------------------------------------
  // Staleness Checks
  // ---------------------------------------------------------------------------

  /// Check if a cached event is stale based on kind-specific TTL.
  ///
  /// Returns `false` for:
  /// - Immutable events (kind 1, 7, etc.) - never stale
  /// - Fresh replaceable events within TTL
  ///
  /// Returns `true` for:
  /// - Replaceable events older than their TTL
  ///
  /// Note: This method uses the event's createdAt as a proxy for cache time.
  /// For more accurate staleness, consider tracking actual cache timestamps.
  bool isStale(Event event) {
    final ttl = _getTtlForKind(event.kind);
    if (ttl == null) return false; // No TTL = never stale

    // Use current time vs event creation as proxy for staleness
    // In a production system, we'd track actual cache insertion time
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = Duration(seconds: now - event.createdAt);
    return age > ttl;
  }

  /// Get TTL for a specific event kind.
  Duration? _getTtlForKind(int kind) {
    // Check explicit TTL first
    if (_ttlByKind.containsKey(kind)) {
      return _ttlByKind[kind];
    }

    // Parameterized replaceable events (30000-39999) have default TTL
    if (EventKind.isParameterizedReplaceable(kind)) {
      return _parameterizedReplaceableTtl;
    }

    // Regular replaceable events (10000-19999) have default TTL
    if (EventKind.isReplaceable(kind) && kind >= 10000) {
      return const Duration(hours: 1);
    }

    // Immutable events have no TTL
    return null;
  }

  // ---------------------------------------------------------------------------
  // Cache Management
  // ---------------------------------------------------------------------------

  /// Clear all cached events.
  Future<void> clearAll() async {
    // Delete all events from the events table
    await _dbClient.database.customStatement('DELETE FROM event');
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Check if filter is for video events.
  bool _isVideoFilter(Filter filter) {
    if (filter.kinds == null) return false;
    return filter.kinds!.any((k) => k == 34236 || k == 16);
  }

  /// Convert database row to Event.
  Event _rowToEvent(NostrEventRow row) {
    final tags = (jsonDecode(row.tags) as List)
        .map((tag) => (tag as List).map((e) => e.toString()).toList())
        .toList();

    final event = Event(
      row.pubkey,
      row.kind,
      tags,
      row.content,
      createdAt: row.createdAt,
    )
      ..id = row.id
      ..sig = row.sig;
    return event;
  }
}
