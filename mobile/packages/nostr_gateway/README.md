# Nostr Gateway

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

REST client for Nostr Gateway API with caching support.

## Overview

`nostr_gateway` provides a REST client for querying Nostr events via HTTP Gateway endpoints. The gateway provides server-side caching for faster initial loads of shared content like discovery feeds, hashtag feeds, and profiles.

## Features

- **REST API Client** - HTTP-based queries for Nostr events
- **Server-Side Caching** - Fast initial loads from cached responses
- **Profile Lookups** - Quick profile (kind 0) fetching
- **Event Fetching** - Single event lookups by ID
- **Filter Queries** - NIP-01 filter support via REST

## Usage

### Basic Setup

```dart
import 'package:nostr_gateway/nostr_gateway.dart';

// Create gateway client with default URL
final gateway = GatewayClient();

// Or with custom URL
final gateway = GatewayClient(
  gatewayUrl: 'https://custom.gateway.url',
);
```

### Query Events

```dart
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/event_kind.dart';

// Query events with filter
final filter = Filter(
  kinds: [EventKind.TEXT_NOTE],
  limit: 10,
);

try {
  final response = await gateway.query(filter);
  
  if (response.hasEvents) {
    print('Received ${response.eventCount} events');
    print('Cached: ${response.cached}');
    print('Cache age: ${response.cacheAgeSeconds}s');
    
    for (final event in response.events) {
      print('Event: ${event.id}');
    }
  }
} on GatewayException catch (e) {
  print('Gateway error: $e');
}
```

### Fetch Profile

```dart
try {
  final profile = await gateway.getProfile('pubkey_here');
  if (profile != null) {
    print('Profile: ${profile.content}');
  }
} on GatewayException catch (e) {
  print('Gateway error: $e');
}
```

### Fetch Event by ID

```dart
try {
  final event = await gateway.getEvent('event_id_here');
  if (event != null) {
    print('Event: ${event.content}');
  }
} on GatewayException catch (e) {
  print('Gateway error: $e');
}
```

### Cleanup

```dart
// Always dispose when done
gateway.dispose();
```

## Response Model

### GatewayResponse

```dart
class GatewayResponse {
  final List<Event> events;      // List of events
  final bool eose;                 // End of stored events
  final bool complete;             // Query complete
  final bool cached;               // Response from cache
  final int? cacheAgeSeconds;      // Cache age in seconds
  
  bool get hasEvents;              // Has any events
  int get eventCount;              // Number of events
}
```

## Error Handling

All methods throw `GatewayException` on failure:

```dart
try {
  final response = await gateway.query(filter);
} on GatewayException catch (e) {
  print('Error: ${e.message}');
  print('Status: ${e.statusCode}');
}
```

## Best Practices

1. **Use for cacheable content** - Discovery feeds, hashtag feeds, profiles
2. **Fallback to WebSocket** - Gateway failures should fall back to WebSocket
3. **Check cache metadata** - Use `cached` and `cacheAgeSeconds` to understand freshness
4. **Handle errors gracefully** - Gateway failures are non-fatal
5. **Dispose resources** - Always call `dispose()` when done

## Integration with Nostr Client

This package is designed to be used with `nostr_client`:

```dart
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_gateway/nostr_gateway.dart';

// nostr_client automatically uses gateway when enabled
final config = NostrClientConfig(
  signer: signer,
  publicKey: publicKey,
  enableGateway: true,
);
final client = NostrClient(config);
```

[mason_link]: https://github.com/felangel/mason
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis

