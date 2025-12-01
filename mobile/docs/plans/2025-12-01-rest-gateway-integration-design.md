# REST Gateway Integration Design

**Date:** 2025-12-01
**Status:** Approved
**Author:** Claude (with Rabble)

## Overview

Integrate the Divine REST Gateway (`gateway.divine.video`) as an optimization layer for loading cacheable content faster. The gateway provides REST endpoints for Nostr queries with server-side caching, reducing load times for shared content like discovery feeds, hashtag feeds, and profiles.

**Key principle:** Gateway supplements WebSocket, doesn't replace it. Both paths feed the same SQLite storage in the embedded relay.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                              │
├─────────────────────┬───────────────────────────────────────┤
│  REST Gateway       │  WebSocket (Embedded Relay)           │
│  (batch fetch)      │  (real-time streaming)                │
│                     │                                       │
│  • Fast initial     │  • Home feed (always)                 │
│    load             │  • Real-time updates                  │
│  • Cached shared    │  • Fallback for everything            │
│    content          │  • Users on other relays              │
│  • Profile lookups  │                                       │
└─────────┬───────────┴───────────────┬───────────────────────┘
          │                           │
          └───────────┬───────────────┘
                      ↓
          ┌───────────────────────┐
          │  Embedded Relay       │
          │  SQLite Storage       │
          │  (single source of    │
          │   truth for app)      │
          └───────────┬───────────┘
                      ↓
          ┌───────────────────────┐
          │  VideoEventService    │
          │  UserProfileService   │
          │  (read from SQLite)   │
          └───────────────────────┘
```

## Gateway API

The gateway at `https://gateway.divine.video` provides:

| Endpoint | Method | Purpose | Cache TTL |
|----------|--------|---------|-----------|
| `/query?filter=<base64url>` | GET | NIP-01 filter query | 2-15 min by kind |
| `/profile/{pubkey}` | GET | Profile lookup (kind 0) | 15 min |
| `/event/{id}` | GET | Single event fetch | 5 min |
| `/publish` | POST | Publish (NIP-98 auth) | N/A |

### Response Format

```json
{
  "events": [...],
  "eose": true,
  "complete": true,
  "cached": true,
  "cache_age_seconds": 42
}
```

## Use Cases

### Gateway SHOULD be used for:

- **Discovery/Popular/Trending feeds** - Same content for all users, highly cacheable
- **Hashtag feeds** - Same for all users querying that tag
- **Profile lookups** - Shared data, 15-minute cache is appropriate
- **Single event fetches** - When viewing shared video links

### Gateway should NOT be used for:

- **Home feed** - Personalized by who you follow, not cacheable across users
- **Users on other relays** - Gateway only works with relay.divine.video

## Components

### 1. RelayGatewayService

New service for HTTP communication with gateway.

**Location:** `lib/services/relay_gateway_service.dart`

```dart
class RelayGatewayService {
  static const String defaultGatewayUrl = 'https://gateway.divine.video';

  final String gatewayUrl;
  final http.Client _client;

  /// Query events via REST gateway
  Future<GatewayResponse> query(Filter filter);

  /// Get profile directly by pubkey
  Future<NostrEvent?> getProfile(String pubkey);

  /// Get single event by ID
  Future<NostrEvent?> getEvent(String eventId);
}

class GatewayResponse {
  final List<NostrEvent> events;
  final bool eose;
  final bool complete;
  final bool cached;
  final int? cacheAgeSeconds;
}
```

### 2. EmbeddedNostrRelay.importEvents()

New method in flutter_embedded_nostr_relay package to batch-insert events.

**Location:** `flutter_embedded_nostr_relay/lib/src/core/embedded_nostr_relay.dart`

```dart
/// Import events from external source (e.g., REST gateway) into local storage.
/// Returns count of events actually stored (excludes duplicates).
Future<int> importEvents(List<NostrEvent> events) async {
  return await _eventStore.storeEvents(events);
}
```

### 3. Settings Persistence

Store gateway preference in SharedPreferences alongside relay config.

**Keys:**
- `relay_gateway_enabled` - Boolean toggle
- `relay_gateway_url` - Custom URL (defaults to gateway.divine.video)

**Default behavior:** Gateway enabled when using relay.divine.video

### 4. UI Toggle

Section in `RelaySettingsScreen` (only visible when divine relay configured):

```
┌─────────────────────────────────────────┐
│ ⚡ REST Gateway                         │
│                                         │
│ Use caching gateway for faster loading  │
│ of discovery feeds and profiles.        │
│                                         │
│ [Toggle: ON/OFF]                        │
│                                         │
│ Only available when using               │
│ relay.divine.video                      │
└─────────────────────────────────────────┘
```

## Integration Flow

When a feed provider initializes:

```dart
Future<void> _loadInitialEvents(SubscriptionType type, Filter filter) async {
  // 1. Check if gateway should be used
  if (_shouldUseGateway(type)) {
    try {
      // 2. Fetch from gateway (fast, cached)
      final response = await _gatewayService.query(filter);

      // 3. Import into SQLite
      await _embeddedRelay.importEvents(response.events);

      Log.info('Gateway: ${response.events.length} events (cached: ${response.cached})');
    } catch (e) {
      Log.warning('Gateway failed, WebSocket will handle: $e');
    }
  }

  // 4. WebSocket subscription always runs
  await _subscribeViaWebSocket(type, filter);
}

bool _shouldUseGateway(SubscriptionType type) {
  // Only for cacheable, shared content
  if (type == SubscriptionType.homeFeed) return false;

  // Only when using divine relay
  if (!_isUsingDivineRelay()) return false;

  // Only if user has gateway enabled
  return _settings.gatewayEnabled;
}
```

## Error Handling

- Gateway failures are non-fatal - WebSocket always provides fallback
- Network timeouts: 10 second limit for gateway requests
- Invalid responses: Log and fall back to WebSocket
- HTTP errors (4xx, 5xx): Log and fall back to WebSocket

## Testing Strategy (TDD)

### Unit Tests

```
test/services/relay_gateway_service_test.dart
├── query() encodes filter as base64url correctly
├── query() parses response with events
├── query() parses response with cache metadata
├── query() handles empty response
├── query() handles network timeout
├── query() handles HTTP errors
├── getProfile() returns profile event for valid pubkey
├── getProfile() returns null for missing profile
├── getProfile() handles network error
├── getEvent() returns event for valid ID
├── getEvent() returns null for missing event
└── getEvent() handles network error
```

### Integration Tests

```
test/integration/gateway_sqlite_integration_test.dart
├── gateway events inserted into SQLite correctly
├── duplicate events deduplicated on import
├── events queryable after gateway import
├── WebSocket continues receiving after gateway load
└── WebSocket fallback works when gateway fails
```

### Widget Tests

```
test/screens/relay_settings_gateway_test.dart
├── gateway toggle visible when divine relay configured
├── gateway toggle hidden when using other relay
├── toggle state persists across app restart
├── toggle disabled state shows explanation
└── gateway URL editable in advanced settings (if implemented)
```

## Constraints

1. **Divine relay only:** Gateway is infrastructure for relay.divine.video, not a general Nostr gateway
2. **Read optimization:** Gateway is for reads; publishing still uses WebSocket/NIP-98
3. **No WebSocket replacement:** Gateway supplements, never replaces real-time connection
4. **Graceful degradation:** All gateway failures must fall back silently to WebSocket

## Future Considerations

- **Profile prefetch:** Could use gateway to batch-load profiles for video authors
- **Publish via gateway:** POST /publish with NIP-98 auth (not in initial scope)
- **Cache warming:** Proactively fetch likely-needed content on app launch
- **Offline support:** Gateway responses could seed offline cache

## Dependencies

- `http` package (already in pubspec)
- `flutter_embedded_nostr_relay` package (local, needs `importEvents()` method)
- No new external dependencies required
