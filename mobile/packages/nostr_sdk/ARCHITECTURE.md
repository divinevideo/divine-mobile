# Architecture Documentation

This document provides a detailed overview of the Nostr SDK architecture, design patterns, and internal workings.

## Overview

The Nostr SDK is built around a layered architecture that separates concerns and provides flexibility:

1. **Application Layer**: User-facing APIs and high-level operations
2. **Protocol Layer**: Nostr protocol implementation and NIP support
3. **Transport Layer**: WebSocket relay connections and messaging
4. **Storage Layer**: Local SQLite database for caching and offline support
5. **Crypto Layer**: Signing, encryption, and key management

## Core Components

### 1. Nostr Client (`lib/nostr.dart`)

The main `Nostr` class serves as the primary interface for all operations:

```dart
class Nostr {
  late RelayPool _pool;
  NostrSigner nostrSigner;
  String _publicKey;
  // ...
}
```

**Responsibilities:**
- Event lifecycle management (create, sign, send, receive)
- Relay pool coordination
- Subscription management
- High-level API methods (`sendLike`, `sendRepost`, etc.)

**Key Design Patterns:**
- **Facade Pattern**: Provides simplified interface to complex relay and signing subsystems
- **Strategy Pattern**: Uses pluggable signers for different signing strategies

### 2. Event System (`lib/event.dart`)

Events are the fundamental data structure in Nostr:

```dart
class Event {
  String id;           // SHA256 hash
  String pubkey;       // Author's public key
  int createdAt;       // Unix timestamp
  int kind;           // Event type
  List<dynamic> tags; // JSON array of tags
  String content;     // Event content
  String sig;         // Schnorr signature
}
```

**Features:**
- Automatic ID generation using SHA256
- Schnorr signature validation
- Proof-of-work support
- JSON serialization/deserialization

### 3. Relay Pool (`lib/relay/relay_pool.dart`)

Manages multiple relay connections with sophisticated routing:

```dart
class RelayPool {
  final Map<String, Relay> _tempRelays = {};
  final Map<String, Relay> _relays = {};
  final Map<String, Relay> _cacheRelays = {};
  final Map<String, Subscription> _subscriptions = {};
}
```

**Connection Types:**
- **Normal Relays**: Primary relays for reading/writing
- **Temporary Relays**: Short-lived connections for specific operations
- **Cache Relays**: Specialized relays for caching frequently accessed data

**Features:**
- Connection pooling and management
- Load balancing across relays
- Subscription multiplexing
- Automatic reconnection
- Relay health monitoring

### 4. Signing System (`lib/signer/`)

Pluggable signing architecture supporting multiple strategies:

```dart
abstract class NostrSigner {
  Future<String?> getPublicKey();
  Future<Event?> signEvent(Event event);
  Future<String?> encrypt(pubkey, plaintext);
  Future<String?> decrypt(pubkey, ciphertext);
  // NIP-44 encryption
  Future<String?> nip44Encrypt(pubkey, plaintext);
  Future<String?> nip44Decrypt(pubkey, ciphertext);
}
```

**Implementations:**
- **LocalNostrSigner**: Local private key signing
- **NostrRemoteSigner**: NIP-46 remote signing
- **PubkeyOnlyNostrSigner**: Read-only mode
- **AndroidNostrSigner**: NIP-55 Android signer integration

### 5. Local Storage (`lib/relay_local/`)

SQLite-based storage system for offline support:

**Components:**
- **RelayLocal**: Main interface for local relay functionality
- **RelayDb**: Database schema and operations
- **Event caching**: Store events locally for offline access
- **Relay metadata**: Store relay information and capabilities

## Data Flow

### 1. Sending Events

```
Application
    ↓ createEvent()
Event Creation
    ↓ signEvent()
Signer
    ↓ sendEvent()
Nostr Client
    ↓ send()
RelayPool
    ↓ WebSocket
Multiple Relays
```

### 2. Receiving Events

```
Relay WebSocket
    ↓ onMessage()
RelayPool
    ↓ processEvent()
Event Validation
    ↓ onEvent()
Subscription Callbacks
    ↓
Application
```

### 3. Subscription Management

```
Application
    ↓ subscribe()
Nostr Client
    ↓ subscribe()
RelayPool
    ↓ REQ message
Multiple Relays
    ↓ EVENT responses
Subscription Handler
    ↓ onEvent()
Application Callback
```

## Design Patterns

### 1. Observer Pattern
- Subscriptions use callbacks for event notifications
- Relay status changes notify observers

### 2. Factory Pattern
- Relay creation through `tempRelayGener` function
- Event creation with validation

### 3. Strategy Pattern
- Multiple signer implementations
- Pluggable upload services

### 4. Singleton Pattern
- Database connections per platform
- Crypto utilities

## Threading Model

The SDK is designed for asynchronous operations:

- **Main Thread**: UI and application logic
- **Background Threads**: Network operations, database I/O
- **WebSocket Threads**: Relay connection management
- **Crypto Threads**: Signing and encryption operations

## Error Handling

Comprehensive error handling at multiple levels:

### 1. Network Errors
- Connection failures
- Timeout handling
- Retry logic

### 2. Protocol Errors
- Invalid event formats
- Signature validation failures
- Relay-specific errors

### 3. Application Errors
- Invalid parameters
- State management errors
- Resource constraints

## Security Considerations

### 1. Key Management
- Private keys never leave the signer implementation
- Memory-safe key handling
- Secure random number generation

### 2. Network Security
- WebSocket over TLS (WSS)
- Certificate validation
- Protection against replay attacks

### 3. Event Validation
- Signature verification
- Event ID validation
- Timestamp validation

## Performance Optimizations

### 1. Connection Management
- Connection pooling reduces setup overhead
- Persistent connections for active relays
- Intelligent relay selection

### 2. Event Processing
- Efficient JSON parsing
- Memory-conscious event storage
- Subscription filtering

### 3. Database Operations
- Prepared statements
- Batch operations
- Indexing strategies

## Extension Points

The architecture provides several extension points:

### 1. Custom Signers
Implement `NostrSigner` interface for custom signing logic:

```dart
class CustomSigner implements NostrSigner {
  // Custom implementation
}
```

### 2. Custom Relays
Extend `Relay` class for specialized relay types:

```dart
class CustomRelay extends Relay {
  // Custom relay logic
}
```

### 3. Custom NIPs
Add new NIP implementations in dedicated directories:

```
lib/nip[number]/
├── nip[number].dart
├── [feature]_info.dart
└── [utilities].dart
```

## Testing Architecture

### 1. Unit Tests
- Individual component testing
- Mock implementations for external dependencies
- Crypto function validation

### 2. Integration Tests
- End-to-end event flow
- Multi-relay scenarios
- Signer integration

### 3. Performance Tests
- Connection handling under load
- Memory usage profiling
- Latency measurements

## Platform Considerations

### 1. Flutter Web
- WebSocket limitations
- Browser security restrictions
- Local storage alternatives

### 2. Mobile Platforms
- Background execution
- Network connectivity changes
- Battery optimization

### 3. Desktop Platforms
- File system access
- Multiple windows
- System integration

## Future Architecture Plans

### 1. Modularization
- Split into separate packages by functionality
- Core package with optional feature packages
- Reduced bundle size for specific use cases

### 2. Performance Improvements
- Event streaming optimizations
- Lazy loading strategies
- Better memory management

### 3. Enhanced Security
- Hardware security module integration
- Advanced key derivation
- Zero-knowledge proof support

This architecture provides a solid foundation for building robust Nostr applications while maintaining flexibility for future enhancements and protocol evolution.