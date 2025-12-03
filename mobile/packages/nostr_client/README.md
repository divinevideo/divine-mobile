# Nostr Client

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

Nostr client abstraction layer that integrates SDK, gateway, and caching for repositories.

## Overview

`nostr_client` provides a clean abstraction layer for Nostr communication that:
- **Connects to `Nostr()` from `nostr_sdk`** - Uses the underlying SDK for WebSocket relay connections
- **Integrates Gateway** - Optional REST gateway support for cache-first queries
- **Manages Caching** - Gateway provides server-side caching for faster initial loads
- **Prevents Duplicates** - Connection and subscription deduplication to avoid churn
- **Clean API** - Simple interface for repositories to use

## Features

### Connection Management
- Prevents duplicate relay connections
- Tracks connected relays
- Proper resource cleanup

### Subscription Management
- Automatic subscription deduplication based on filter content
- Stream-based event subscriptions
- Proper lifecycle management

### Gateway Integration
- Cache-first query pattern (gateway → WebSocket fallback)
- Fast initial loads for shared content
- Automatic fallback on gateway failure

### Event Operations
- Query events with filters
- Publish events to relays
- Subscribe to event streams
- Fetch single events and profiles

## Usage

### Basic Setup

```dart
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Create signer
final privateKey = generatePrivateKey();
final signer = LocalNostrSigner(privateKey);
final publicKey = await signer.getPublicKey()!;

// Create client config
final config = NostrClientConfig(
  signer: signer,
  publicKey: publicKey,
  enableGateway: true, // Enable gateway for cache-first queries
  gatewayUrl: 'https://gateway.divine.video',
);

// Create client
final client = NostrClient(config);

// Add relays
await client.addRelay('wss://relay.damus.io');
await client.addRelay('wss://nos.lol');
```

### Query Events

```dart
// Query events (uses gateway first if enabled, falls back to WebSocket)
final filters = [
  Filter(kinds: [EventKind.TEXT_NOTE], limit: 10),
];
final events = await client.queryEvents(filters);

// Fetch single event by ID
final event = await client.fetchEventById('event_id_here');

// Fetch profile
final profile = await client.fetchProfile('pubkey_here');
```

### Subscribe to Events

```dart
// Subscribe to events (automatically deduplicates identical filters)
final stream = client.subscribe(
  [Filter(kinds: [EventKind.TEXT_NOTE], limit: 10)],
  onEose: () => print('End of stored events'),
);

stream.listen((event) {
  print('Received event: ${event.id}');
});
```

### Publish Events

```dart
// Create and publish event
final event = Event(
  publicKey,
  EventKind.TEXT_NOTE,
  [],
  'Hello, Nostr!',
);

final sentEvent = await client.publishEvent(event);
if (sentEvent != null) {
  print('Published event: ${sentEvent.id}');
} else {
  print('Failed to publish event');
}
```

### Cleanup

```dart
// Always close the client when done
client.close();
// or
client.dispose();
```

## Architecture

The client integrates three layers:

1. **SDK Layer** (`nostr_sdk`) - WebSocket relay connections
2. **Gateway Layer** (`nostr_gateway`) - REST API for cached queries
3. **Cache Layer** - Server-side caching via gateway

Query flow:
```
queryEvents() → Gateway (if enabled) → WebSocket (fallback)
```

This provides:
- Fast initial loads from cached gateway responses
- Real-time updates via WebSocket subscriptions
- Automatic fallback on gateway failure

## Configuration

### Gateway Settings

- `enableGateway`: Enable/disable gateway support
- `gatewayUrl`: Custom gateway URL (defaults to `https://gateway.divine.video`)

### Relay Settings

- `autoSubscribe`: Automatically resubscribe when relay connects
- `relayType`: Normal, cache, or both
- `sendAfterAuth`: Wait for authentication before sending

## Best Practices

1. **Always close the client** when done to free resources
2. **Use gateway for cacheable content** (discovery feeds, profiles)
3. **Use WebSocket for real-time** (home feeds, live updates)
4. **Let the client handle deduplication** - don't manually track subscriptions
5. **Handle gateway failures gracefully** - they fall back to WebSocket automatically

[mason_link]: https://github.com/felangel/mason
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
