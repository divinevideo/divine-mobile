# db_client Integration Plan for nostr_client

This document outlines the steps to integrate db_client (SQLite cache) into nostr_client for local event and relay metadata caching.

## Goals

1. **Event caching** - Cache-first query strategy for faster responses
2. **Relay metadata caching** - Persist relay info beyond just URLs
3. **Subscription caching** - Auto-cache events received from subscriptions

## Architecture

```
NostrClient
├── _relayManager (RelayManager)
│   └── db_client (relays table) ← NEW: relay metadata
├── _eventCache (EventCache)     ← NEW: event caching wrapper
│   └── db_client (events table)
└── _gatewayClient (GatewayClient)

Query flow: Cache → Gateway → WebSocket
```

## Implementation Steps

### Step 1: Add db_client Dependency

**File**: `packages/nostr_client/pubspec.yaml`

```yaml
dependencies:
  db_client:
    path: ../db_client
```

---

### Step 2: RelayManager - Relay Metadata Caching

RelayManager will use db_client to persist relay metadata beyond just URLs.

#### What to Cache

| Field | Description |
|-------|-------------|
| url | Relay WebSocket URL |
| lastConnectedAt | Last successful connection timestamp |
| errorCount | Cumulative error count |
| nip11Info | NIP-11 relay info (name, supported NIPs, limitations) |
| readPermission | Whether relay allows reads |
| writePermission | Whether relay allows writes |
| priority | User-defined priority (higher = preferred) |
| enabled | User toggle to disable relay |

#### Changes Needed

1. **Create RelayMetadata model** in db_client:
   - Add `relay_metadata` table to schema
   - Add `RelayMetadataDao` for CRUD operations

2. **Extend RelayStorage interface** or create new `RelayMetadataRepository`:
   ```dart
   abstract class RelayMetadataStorage {
     Future<RelayMetadata?> getMetadata(String url);
     Future<void> saveMetadata(RelayMetadata metadata);
     Future<List<RelayMetadata>> getAllMetadata();
     Future<void> deleteMetadata(String url);
   }
   ```

3. **Update RelayManager**:
   - Accept optional `RelayMetadataStorage` in config
   - Save metadata on connect/disconnect/error
   - Load metadata on initialization
   - Expose metadata via `getRelayMetadata(url)`

---

### Step 3: Create EventCache Wrapper Class

Create an `EventCache` class that wraps db_client for cleaner abstraction.

**File**: `packages/nostr_client/lib/src/event_cache.dart`

```dart
/// Caches Nostr events locally for fast queries.
///
/// Wraps db_client and provides:
/// - Cache-first queries with freshness checks
/// - Auto-caching of subscription events
/// - TTL-based staleness per event kind
class EventCache {
  EventCache(this._dbClient);

  final AppDbClient _dbClient;

  /// Cache a single event (handles NIP-01 replaceable semantics)
  Future<void> cacheEvent(Event event);

  /// Cache multiple events in batch
  Future<void> cacheEvents(List<Event> events);

  /// Get cached events matching filter
  Future<List<Event>> getCachedEvents(Filter filter);

  /// Get cached profile by pubkey (kind 0)
  Future<Event?> getCachedProfile(String pubkey);

  /// Get cached event by ID
  Future<Event?> getCachedEvent(String eventId);

  /// Check if cached event is stale based on kind-specific TTL
  bool isStale(Event event);

  /// Invalidate cache for specific filter/kind
  Future<void> invalidate({int? kind, String? pubkey});

  /// Clear all cached events
  Future<void> clearAll();
}
```

---

### Step 4: TTL Strategy Per Event Kind

Different event kinds have different staleness requirements:

| Kind | Description | TTL | Rationale |
|------|-------------|-----|-----------|
| 0 | Profile metadata | 1 hour | Profiles change infrequently |
| 3 | Contact list | 1 hour | Follows change infrequently |
| 1 | Text notes | No TTL | Immutable once created |
| 7 | Reactions | No TTL | Immutable once created |
| 10002 | Relay list | 1 hour | User relay preferences |
| 34236 | Videos | No TTL | Immutable content |
| 30000-39999 | Parameterized replaceable | 1 hour | May be updated |

```dart
class EventCache {
  static const _ttlByKind = <int, Duration>{
    0: Duration(hours: 1),      // profiles
    3: Duration(hours: 1),      // contacts
    10002: Duration(hours: 1),  // relay list
  };

  /// Check if event is stale based on kind-specific TTL
  bool isStale(Event event, DateTime cachedAt) {
    final ttl = _ttlByKind[event.kind];
    if (ttl == null) return false; // No TTL = never stale
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
```

---

### Step 4b: Query Result Caching (Future Enhancement)

Beyond caching individual events, we can cache entire query results to skip network calls for repeated queries.

#### Use Cases

| Query Type | Cache Key | TTL | Example |
|------------|-----------|-----|---------|
| Video feed | `videos:discovery:page0` | 5 min | Home feed, explore |
| Hashtag videos | `videos:hashtag:nostr:page0` | 5 min | #nostr videos |
| User's videos | `videos:author:{pubkey}` | 10 min | Profile page |
| Reactions | `reactions:{eventId}` | 1 min | Like counts |
| Following list | `following:{pubkey}` | 1 hour | Contact list |

#### Query Cache Table

```sql
CREATE TABLE query_cache (
  query_hash TEXT PRIMARY KEY,  -- SHA256 of normalized filter JSON
  event_ids TEXT NOT NULL,      -- JSON array of event IDs
  cached_at INTEGER NOT NULL,   -- Unix timestamp
  ttl_seconds INTEGER NOT NULL  -- TTL for this query type
);
```

#### EventCache Methods for Query Caching

```dart
class EventCache {
  /// Cache a query result (filter → event IDs)
  Future<void> cacheQueryResult(
    Filter filter,
    List<String> eventIds, {
    Duration ttl = const Duration(minutes: 5),
  });

  /// Get cached query result if fresh
  /// Returns null if not cached or stale
  Future<List<String>?> getCachedQueryResult(Filter filter);

  /// Check if query result is cached and fresh
  Future<bool> hasValidQueryCache(Filter filter);

  /// Invalidate query cache matching pattern
  Future<void> invalidateQueryCache({
    List<int>? kinds,
    List<String>? authors,
    List<String>? hashtags,
  });
}
```

#### Query Flow with Query Cache

```dart
Future<List<Event>> queryEvents(List<Filter> filters, ...) async {
  // 1. Check query cache first (skips network entirely)
  if (useCache && _eventCache != null && filters.length == 1) {
    final cachedIds = await _eventCache!.getCachedQueryResult(filters.first);
    if (cachedIds != null) {
      // Query result is fresh - load events from event cache
      final events = await _eventCache!.getEventsByIds(cachedIds);
      if (events.length == cachedIds.length) {
        return events; // All events still in cache, return immediately
      }
      // Some events missing, fall through to network
    }
  }

  // 2. Cache → Gateway → WebSocket (existing flow)
  // ...

  // 3. Cache query result for next time
  if (_eventCache != null && filters.length == 1) {
    final eventIds = results.map((e) => e.id).toList();
    await _eventCache!.cacheQueryResult(filters.first, eventIds);
  }

  return results;
}
```

#### Invalidation Strategy

Query cache should be invalidated when:
- User publishes a new event (invalidate own author queries)
- User follows/unfollows someone (invalidate contact-based queries)
- TTL expires (automatic)
- App detects stale data from relay

```dart
// Example: After publishing a video
await _eventCache.invalidateQueryCache(
  kinds: [34236],
  authors: [myPubkey],
);
```

> **Note**: Query result caching is a future enhancement. Initial implementation focuses on event caching (Steps 1-8). Query caching can be added in a follow-up PR.

---

### Step 5: Update NostrClient Constructor

**File**: `packages/nostr_client/lib/src/nostr_client.dart`

```dart
class NostrClient {
  NostrClient({
    required NostrClientConfig config,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
    EventCache? eventCache,  // NEW
  }) : _nostr = _createNostr(config),
       _relayManager = relayManager,
       _gatewayClient = gatewayClient,
       _eventCache = eventCache;

  final EventCache? _eventCache;

  // ...
}
```

---

### Step 6: Update Query Methods with Cache-First Logic

#### queryEvents()

Query flow: **Cache → Gateway → WebSocket**

```dart
Future<List<Event>> queryEvents(
  List<Filter> filters, {
  bool useCache = true,
  bool useGateway = true,
  // ... existing params
}) async {
  final results = <Event>[];
  final seenIds = <String>{};

  // 1. Check cache first (instant)
  if (useCache && _eventCache != null && filters.length == 1) {
    final cached = await _eventCache!.getCachedEvents(filters.first);
    for (final event in cached) {
      if (!_eventCache!.isStale(event)) {
        seenIds.add(event.id);
        results.add(event);
      }
    }
  }

  // 2. Try gateway (fast REST)
  if (useGateway && _gatewayClient != null && filters.length == 1) {
    final response = await _tryGateway(() => _gatewayClient!.query(filters.first));
    if (response != null && response.hasEvents) {
      for (final event in response.events) {
        if (seenIds.add(event.id)) results.add(event);
      }
      // Cache gateway results
      if (_eventCache != null) {
        await _eventCache!.cacheEvents(response.events);
      }
      return results;
    }
  }

  // 3. Fall back to WebSocket
  final filtersJson = filters.map((f) => f.toJson()).toList();
  final relayEvents = await _nostr.queryEvents(filtersJson, ...);

  // 4. Cache relay results
  if (_eventCache != null) {
    await _eventCache!.cacheEvents(relayEvents);
  }

  // 5. Merge results
  for (final event in relayEvents) {
    if (seenIds.add(event.id)) results.add(event);
  }

  return results;
}
```

#### fetchProfile()

```dart
Future<Event?> fetchProfile(String pubkey, {bool useGateway = true}) async {
  // 1. Check cache first
  if (_eventCache != null) {
    final cached = await _eventCache!.getCachedProfile(pubkey);
    if (cached != null && !_eventCache!.isStale(cached)) {
      return cached;
    }
  }

  // 2. Gateway / WebSocket (existing logic)
  final event = await _fetchProfileFromNetwork(pubkey, useGateway);

  // 3. Cache result
  if (event != null && _eventCache != null) {
    await _eventCache!.cacheEvent(event);
  }

  return event;
}
```

#### fetchEventById()

```dart
Future<Event?> fetchEventById(String eventId, {bool useGateway = true}) async {
  // 1. Check cache first
  if (_eventCache != null) {
    final cached = await _eventCache!.getCachedEvent(eventId);
    if (cached != null) {
      return cached; // No staleness check for immutable events
    }
  }

  // 2. Gateway / WebSocket (existing logic)
  final event = await _fetchEventFromNetwork(eventId, useGateway);

  // 3. Cache result
  if (event != null && _eventCache != null) {
    await _eventCache!.cacheEvent(event);
  }

  return event;
}
```

---

### Step 7: Auto-Cache Subscription Events

Modify `subscribe()` to cache incoming events:

```dart
Stream<Event> subscribe(List<Filter> filters, ...) {
  final controller = StreamController<Event>.broadcast();

  // 1. Emit cached events immediately (optional)
  if (_eventCache != null) {
    _emitCachedEventsAsync(controller, filters);
  }

  // 2. Subscribe to relays
  _nostr.subscribe(filtersJson, (event) {
    // 3. Cache incoming event
    if (_eventCache != null) {
      _eventCache!.cacheEvent(event);
    }

    // 4. Emit to stream
    if (!controller.isClosed) {
      controller.add(event);
    }
  }, ...);

  return controller.stream;
}

Future<void> _emitCachedEventsAsync(
  StreamController<Event> controller,
  List<Filter> filters,
) async {
  if (filters.length != 1) return;

  final cached = await _eventCache!.getCachedEvents(filters.first);
  for (final event in cached) {
    if (!controller.isClosed && !_eventCache!.isStale(event)) {
      controller.add(event);
    }
  }
}
```

---

### Step 8: Update Tests

Add tests for:

1. **EventCache unit tests**
   - `cacheEvent()` stores event
   - `getCachedEvents()` returns matching events
   - `isStale()` returns correct staleness
   - Replaceable events handled correctly

2. **NostrClient cache integration tests**
   - Cache-first returns cached data
   - Stale cache triggers network fetch
   - Network results are cached
   - Works without cache (backward compat)

3. **RelayManager metadata tests**
   - Metadata persisted on connect
   - Metadata loaded on init
   - Error count incremented on failures

---

## Files to Create/Modify

### New Files
- `packages/nostr_client/lib/src/event_cache.dart` - EventCache class
- `packages/db_client/lib/src/database/tables/relay_metadata.dart` - Relay metadata table
- `packages/db_client/lib/src/database/daos/relay_metadata_dao.dart` - Relay metadata DAO

### Modified Files
- `packages/nostr_client/pubspec.yaml` - Add db_client dependency
- `packages/nostr_client/lib/src/nostr_client.dart` - Add cache logic
- `packages/nostr_client/lib/src/relay_manager.dart` - Add metadata caching
- `packages/nostr_client/lib/src/models/relay_manager_config.dart` - Add metadata storage config

---

## Implementation Order

1. **Step 1**: Add db_client dependency
2. **Step 3**: Create EventCache wrapper class
3. **Step 4**: Implement TTL strategy
4. **Step 5-7**: Update NostrClient with cache logic
5. **Step 8**: Add tests for event caching
6. **Step 2**: Add relay metadata caching (can be done later)

---

## Success Criteria

- [ ] NostrClient works without EventCache (backward compatible)
- [ ] Cache-first queries return instant results
- [ ] Stale events trigger network refresh
- [ ] Relay events are persisted to cache
- [ ] Subscription events are auto-cached
- [ ] Replaceable events handled correctly (kind 0, 3, 10000-19999, 30000-39999)
- [ ] All existing tests pass
- [ ] New tests cover caching behavior
