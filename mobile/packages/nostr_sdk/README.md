# nostr_sdk

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: the workspace Nostr protocol SDK used by Divine for events, relays, signing, encryption, uploads, and related NIP support.

Used by: the app plus multiple workspace repositories and clients.

Notes:

- This is a workspace package, not a published dependency contract for P1 launch.
- Prefer linking other package docs to this package instead of duplicating protocol details.

---

## Key Features

- **Full Nostr Protocol Support** -- complete event-based protocol implementation
- **22 NIPs Implemented** -- one of the most comprehensive NIP coverage in any Dart SDK
- **Pluggable Signing** -- local, remote (NIP-46), hardware (NIP-55), and keyless signers
- **Relay Pooling** -- connection management, subscriptions, load balancing, and NIP-42 auth
- **Offline-First** -- SQLite-based event caching and local relay support
- **Cross-Platform** -- Android, iOS, web, and desktop via Flutter
- **File Upload** -- NIP-96 and Blossom server integrations
- **Lightning Integration** -- zaps, LNURL, and wallet connectivity (NIP-47)

## Supported NIPs

| NIP | Description | Status |
|-----|-------------|--------|
| [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) | Basic protocol flow | Supported |
| [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md) | Contact Lists | Supported |
| [NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md) | Encrypted Direct Messages | Supported (deprecated) |
| [NIP-05](https://github.com/nostr-protocol/nips/blob/master/05.md) | DNS-based identity verification | Supported |
| [NIP-07](https://github.com/nostr-protocol/nips/blob/master/07.md) | Browser extension signing | Supported |
| [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md) | bech32-encoded entities | Supported |
| [NIP-23](https://github.com/nostr-protocol/nips/blob/master/23.md) | Long-form content | Supported |
| [NIP-29](https://github.com/nostr-protocol/nips/blob/master/29.md) | Relay-based Groups | Supported |
| [NIP-42](https://github.com/nostr-protocol/nips/blob/master/42.md) | Authentication of clients to relays | Supported |
| [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md) | Versioned Encryption | Supported |
| [NIP-46](https://github.com/nostr-protocol/nips/blob/master/46.md) | Remote Signing | Supported |
| [NIP-47](https://github.com/nostr-protocol/nips/blob/master/47.md) | Wallet Connect | Supported |
| [NIP-50](https://github.com/nostr-protocol/nips/blob/master/50.md) | Search Capability | Supported |
| [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md) | Lists (bookmarks, follow sets) | Supported |
| [NIP-55](https://github.com/nostr-protocol/nips/blob/master/55.md) | Android signer integration | Supported |
| [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md) | Badges | Supported |
| [NIP-59](https://github.com/nostr-protocol/nips/blob/master/59.md) | Gift Wrapping | Supported |
| [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md) | Relay List Metadata | Supported |
| [NIP-69](https://github.com/nostr-protocol/nips/blob/master/69.md) | Polls | Supported |
| [NIP-75](https://github.com/nostr-protocol/nips/blob/master/75.md) | Zap Goals | Supported |
| [NIP-94](https://github.com/nostr-protocol/nips/blob/master/94.md) | File Metadata | Supported |
| [NIP-96](https://github.com/nostr-protocol/nips/blob/master/96.md) | File Storage | Supported |
| [NIP-172](https://github.com/nostr-protocol/nips/blob/master/172.md) | Community Support | Supported |

## Architecture Overview

### Core Classes

**`Nostr`** (`lib/nostr.dart`) -- Main client that orchestrates all operations: relay management, event publishing (`sendEvent`, `sendLike`, `sendRepost`), event retrieval (`subscribe`, `query`, `readEvents`, `readAllEvents`, `queryEvents`), and relay lifecycle (`addRelay`, `removeRelay`).

**`Event`** (`lib/event.dart`) -- Represents a Nostr event with automatic ID generation, Schnorr signature support, proof-of-work capabilities, and JSON serialization.

**`NostrSigner`** (`lib/signer/nostr_signer.dart`) -- Abstract signing interface. Implementations include `LocalNostrSigner` (private key), `NostrRemoteSigner` (NIP-46), and `UnauthenticatedSigner` (keyless signed-out state).

### Relay System

**`RelayPool`** (`lib/relay/relay_pool.dart`) -- Manages multiple relay connections with support for normal, temporary, and cache relay types. Handles subscription fan-out, load balancing, and NIP-42 authentication.

### File Structure

```
lib/
├── nostr.dart              # Main client
├── event.dart              # Event class and utilities
├── event_kind.dart         # Event type constants
├── signer/                 # Signing implementations
│   ├── nostr_signer.dart
│   ├── local_nostr_signer.dart
│   └── unauthenticated_signer.dart
├── relay/                  # Relay management
│   ├── relay_pool.dart
│   ├── relay.dart
│   └── event_filter.dart
├── nip02/                  # Contact lists
├── nip04/                  # Encrypted DMs (deprecated)
├── nip44/                  # Versioned encryption
├── nip46/                  # Remote signing
├── nip47/                  # Wallet connect
├── nip29/                  # Relay-based groups
├── upload/                 # File upload (NIP-96, Blossom)
├── zap/                    # Lightning payments
└── utils/                  # Utility functions
```

## Basic Usage

```dart
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/relay/relay.dart';

// Generate a new key pair
final signer = LocalNostrSigner.generate();
final publicKey = await signer.getPublicKey();

// Initialize client
final nostr = Nostr(
  signer,
  publicKey!,
  [EventFilter(kinds: [EventKind.TEXT_NOTE], limit: 100)],
  (relayUrl) => Relay(relayUrl),
  onNotice: (relayUrl, notice) => print('Notice from $relayUrl: $notice'),
);

// Connect to relays
await nostr.addRelay(Relay('wss://relay.damus.io'));
await nostr.addRelay(Relay('wss://nos.lol'));

// Publish a text note
final event = Event(
  publicKey,
  EventKind.TEXT_NOTE,
  [['t', 'nostr']],
  'Hello from nostr_sdk!',
);
await nostr.sendEvent(event);

// Subscribe to events
nostr.subscribe(
  [{'kinds': [EventKind.TEXT_NOTE], 'limit': 50}],
  (Event event) => print('${event.pubkey}: ${event.content}'),
);

// Query events
final events = await nostr.queryEvents([
  {'kinds': [EventKind.TEXT_NOTE], 'authors': [publicKey], 'limit': 20},
]);

// Clean up
nostr.close();
```

## Testing

Run the full test suite:

```bash
cd mobile/packages/nostr_sdk
flutter test
```

Run a specific test file:

```bash
flutter test test/nip44/nip44_test.dart
```

Run with coverage:

```bash
flutter test --coverage
```
