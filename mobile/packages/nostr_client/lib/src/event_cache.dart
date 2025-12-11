// ABOUTME: Caches Nostr events locally for fast queries.
// ABOUTME: Wraps db_client with filter-based lookups and NIP-01 handling.

import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template event_cache}
/// Caches Nostr events locally for fast queries.
///
/// Wraps [AppDbClient] and provides:
/// - Cache-first queries for instant results
/// - Auto-caching of subscription events
/// - NIP-01 replaceable event handling (via db_client)
///
/// The cache always returns the latest version of replaceable events
/// (kind 0, 3, 10000-19999, 30000-39999) since db_client handles
/// the replacement logic at write time.
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
/// ```
/// {@endtemplate}
class EventCache {
  /// {@macro event_cache}
  EventCache(this._dbClient);

  final AppDbClient _dbClient;

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
          );
          results.addAll(rows);
        }
        return _sortAndLimit(results.map(_rowToEvent).toList(), filter.limit);
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
        final rows = await _dbClient.getEventsByAuthor(author);
        results.addAll(rows);
      }
      // Filter by kinds if specified
      var events = results.map(_rowToEvent).toList();
      if (filter.kinds != null) {
        events = events.where((e) => filter.kinds!.contains(e.kind)).toList();
      }
      return _sortAndLimit(events, filter.limit);
    }

    // No supported filter criteria
    return [];
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

  /// Sort events by createdAt descending and apply limit.
  List<Event> _sortAndLimit(List<Event> events, int? limit) {
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit != null && events.length > limit) {
      return events.sublist(0, limit);
    }
    return events;
  }

  /// Convert database row to Event.
  Event _rowToEvent(NostrEventRow row) {
    final tags = (jsonDecode(row.tags) as List)
        .map((tag) => (tag as List).map((e) => e.toString()).toList())
        .toList();

    final event =
        Event(
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
